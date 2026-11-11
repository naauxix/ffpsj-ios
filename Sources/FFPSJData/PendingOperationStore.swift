import FFPSJDomain
import Foundation

/// Solo persiste intenciones de escritura sin confirmar; nunca actas, resultados ni marcadores.
public struct PendingEventOperation: Codable, Hashable, Identifiable, Sendable {
    public enum State: String, Codable, Sendable {
        case awaitingConfirmation
        case failed
    }

    public let id: UUID
    public let matchID: UUID
    public let draft: EventDraft
    public var state: State
    public var lastError: String?
    public let createdAt: Date

    public init(matchID: UUID, draft: EventDraft, state: State = .awaitingConfirmation, lastError: String? = nil) {
        id = draft.clientRequestID
        self.matchID = matchID
        self.draft = draft
        self.state = state
        self.lastError = lastError
        createdAt = .now
    }
}

public actor PendingOperationStore {
    private let defaults: UserDefaults
    private let storageKey = "org.ffpsj.actas.pending-events.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func all() -> [PendingEventOperation] {
        guard let data = defaults.data(forKey: storageKey),
              let operations = try? JSONDecoder().decode([PendingEventOperation].self, from: data) else {
            return []
        }
        return operations
    }

    public func save(_ operation: PendingEventOperation) {
        var operations = all().filter { $0.id != operation.id }
        operations.append(operation)
        persist(operations)
    }

    public func remove(id: UUID) {
        persist(all().filter { $0.id != id })
    }

    private func persist(_ operations: [PendingEventOperation]) {
        defaults.set(try? JSONEncoder().encode(operations), forKey: storageKey)
    }
}

public enum EventSubmissionResult: Sendable {
    case confirmed(MatchEvent)
    case awaitingConfirmation(PendingEventOperation)
}

public actor EventSubmissionService {
    private let repository: any MatchRepository
    private let pendingStore: PendingOperationStore

    public init(repository: any MatchRepository, pendingStore: PendingOperationStore) {
        self.repository = repository
        self.pendingStore = pendingStore
    }

    /// Primero consulta el request-id en caso de reintento. Una respuesta incierta queda pendiente,
    /// no se representa como incidencia oficial hasta volver a consultar al servidor.
    public func submit(matchID: UUID, draft: EventDraft) async throws -> EventSubmissionResult {
        // Estas reglas son deterministas y locales. No deben convertirse en una operación
        // "pendiente": el usuario puede corregir el formulario inmediatamente.
        try MatchRules.validate(draft)

        do {
            if let existing = try await repository.event(matchID: matchID, clientRequestID: draft.clientRequestID) {
                await pendingStore.remove(id: draft.clientRequestID)
                return .confirmed(existing)
            }
        } catch {
            // Si ni siquiera se pudo comprobar el request-id, la red puede haber
            // fallado antes de enviar esta operación. Se conserva la intención.
            let pending = PendingEventOperation(matchID: matchID, draft: draft, lastError: error.localizedDescription)
            await pendingStore.save(pending)
            return .awaitingConfirmation(pending)
        }

        do {
            let event = try await repository.recordEvent(matchID: matchID, draft: draft)
            await pendingStore.remove(id: draft.clientRequestID)
            return .confirmed(event)
        } catch {
            let pending = PendingEventOperation(matchID: matchID, draft: draft, lastError: error.localizedDescription)
            await pendingStore.save(pending)
            return .awaitingConfirmation(pending)
        }
    }

    public func reconcile() async -> [UUID] {
        var confirmed: [UUID] = []
        for pending in await pendingStore.all() {
            // No se reenvía automáticamente una escritura cuya respuesta fue incierta:
            // primero se consulta el identificador idempotente en el servidor.
            if let _ = try? await repository.event(matchID: pending.matchID, clientRequestID: pending.id) {
                await pendingStore.remove(id: pending.id)
                confirmed.append(pending.matchID)
            }
        }
        return confirmed
    }
}
