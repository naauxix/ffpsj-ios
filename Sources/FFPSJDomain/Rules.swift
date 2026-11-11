import Foundation

public enum MatchAction: Sendable, Equatable {
    case start
    case finish
    case recordEvent
    case changeLineup
    case editObservations
    case deleteEvent
}

public enum MatchRuleError: LocalizedError, Equatable, Sendable {
    case inactiveAccount
    case forbidden
    case invalidState(expected: String, actual: MatchStatus)
    case invalidMinute
    case invalidPeriod
    case missingTeam
    case invalidSubstitution
    case descriptionTooLong

    public var errorDescription: String? {
        switch self {
        case .inactiveAccount: "Tu cuenta no está habilitada."
        case .forbidden: "No tienes autorización para gestionar este partido."
        case let .invalidState(expected, actual): "Esta acción requiere un partido \(expected). Estado actual: \(actual.label)."
        case .invalidMinute: "El minuto debe estar entre 0 y 99."
        case .invalidPeriod: "El período debe estar entre 1 y 3."
        case .missingTeam: "Selecciona el equipo implicado."
        case .invalidSubstitution: "Selecciona el jugador que sale y el que entra; deben ser distintos."
        case .descriptionTooLong: "La observación no puede superar los 500 caracteres."
        }
    }
}

/// Validación anticipada para orientar al usuario. La autorización definitiva está en RLS/RPC.
public enum MatchRules {
    public static func validate(_ action: MatchAction, match: Match, user: AppUser) throws {
        guard user.isActive else { throw MatchRuleError.inactiveAccount }
        guard user.role == .admin || match.assignedRefereeID == user.id else {
            throw MatchRuleError.forbidden
        }

        switch action {
        case .start:
            guard match.status == .scheduled else {
                throw MatchRuleError.invalidState(expected: "programado", actual: match.status)
            }
        case .finish, .recordEvent:
            guard match.status == .inProgress else {
                throw MatchRuleError.invalidState(expected: "en juego", actual: match.status)
            }
        case .changeLineup:
            guard match.status == .scheduled || match.status == .inProgress else {
                throw MatchRuleError.invalidState(expected: "programado o en juego", actual: match.status)
            }
        case .editObservations, .deleteEvent:
            break // El producto web original permite estas correcciones a un gestor autorizado.
        }
    }

    public static func validate(_ draft: EventDraft) throws {
        guard (0...99).contains(draft.minute) else { throw MatchRuleError.invalidMinute }
        guard (1...3).contains(draft.period) else { throw MatchRuleError.invalidPeriod }
        guard (draft.description?.count ?? 0) <= 500 else {
            throw MatchRuleError.descriptionTooLong
        }
        if draft.type != .note, draft.teamID == nil { throw MatchRuleError.missingTeam }
        if draft.type == .substitution {
            guard let outgoing = draft.playerID,
                  let incoming = draft.replacementPlayerID,
                  outgoing != incoming else {
                throw MatchRuleError.invalidSubstitution
            }
        }
    }
}

public enum MatchClock {
    /// ActivityKit usa este mismo instante; nunca se mantiene un contador independiente.
    public static func elapsedSeconds(startedAt: Date?, now: Date = .now) -> TimeInterval? {
        guard let startedAt else { return nil }
        return max(0, now.timeIntervalSince(startedAt))
    }
}
