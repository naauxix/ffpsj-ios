@preconcurrency import ActivityKit
import FFPSJData
import FFPSJDomain
import Foundation
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    enum Phase: Equatable {
        case configurationRequired(String)
        case loading
        case signedOut
        case restricted
        case authenticated
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var matches: [Match] = []
    @Published private(set) var teams: [Team] = []
    @Published var presentedError: UserFacingError?
    @Published var pendingRoute: FFPSJDeepLink?

    let network = NetworkMonitor()
    private let auth: (any AuthRepository)?
    private let matchesRepository: (any MatchRepository)?
    private let administration: (any AdministrationRepository)?
    private let eventSubmission: EventSubmissionService?
    private let realtime: MatchRealtimeObserver?
    private let liveActivity = LiveActivityManager()

    init() {
        do {
            let client = try SupabaseConfiguration.load().makeClient()
            let auth = SupabaseAuthRepository(client: client)
            let matches = SupabaseMatchRepository(client: client)
            self.auth = auth
            matchesRepository = matches
            administration = SupabaseAdministrationRepository(client: client)
            eventSubmission = EventSubmissionService(repository: matches, pendingStore: PendingOperationStore())
            realtime = MatchRealtimeObserver(client: client)
            Task { await restoreSession() }
        } catch {
            auth = nil
            matchesRepository = nil
            administration = nil
            eventSubmission = nil
            realtime = nil
            phase = .configurationRequired(error.localizedDescription)
        }
    }

    var isAdministrator: Bool { currentUser?.role == .admin }

    func restoreSession() async {
        guard let auth else { return }
        phase = .loading
        do {
            guard let id = try await auth.restoreSession() else {
                currentUser = nil
                phase = .signedOut
                return
            }
            let user = try await auth.currentUser(id: id)
            currentUser = user
            phase = user.isActive ? .authenticated : .restricted
            if user.isActive {
                await loadMatches()
                await reconcilePendingOperations()
            }
        } catch {
            currentUser = nil
            phase = .signedOut
            presentedError = UserFacingError(error)
        }
    }

    func signIn(email: String, password: String) async {
        guard let auth else { return }
        phase = .loading
        do {
            let id = try await auth.signIn(email: email, password: password)
            let user = try await auth.currentUser(id: id)
            currentUser = user
            phase = user.isActive ? .authenticated : .restricted
            if user.isActive {
                await loadMatches()
                await reconcilePendingOperations()
            }
        } catch {
            currentUser = nil
            phase = .signedOut
            presentedError = UserFacingError(error)
        }
    }

    func requestAccount(fullName: String, email: String, password: String) async throws {
        guard let auth else { throw ConfigurationError.missingSupabaseConfiguration }
        try await auth.signUp(fullName: fullName, email: email, password: password)
    }

    func recoverPassword(email: String) async throws {
        guard let auth else { throw ConfigurationError.missingSupabaseConfiguration }
        try await auth.recoverPassword(email: email, redirectURL: URL(string: "ffpsj://matches")!)
    }

    func signOut() async {
        do { try await auth?.signOut() } catch { presentedError = UserFacingError(error) }
        currentUser = nil
        matches = []
        phase = .signedOut
    }

    func loadMatches() async {
        guard let matchesRepository else { return }
        do {
            matches = try await matchesRepository.listMatches()
        } catch {
            presentedError = UserFacingError(error)
        }
    }

    func loadTeams() async {
        guard let administration else { return }
        do { teams = try await administration.listTeams() }
        catch { presentedError = UserFacingError(error) }
    }

    func users() async throws -> [AppUser] {
        guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
        return try await administration.listUsers()
    }

    func updateUser(id: UUID, role: AppRole?, status: AccountStatus?) async {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            try await administration.updateUser(id: id, role: role, status: status)
        } catch { presentedError = UserFacingError(error) }
    }

    func createTeam(_ draft: TeamDraft) async {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            try await administration.createTeam(draft)
            await loadTeams()
        } catch { presentedError = UserFacingError(error) }
    }

    func updateTeam(id: UUID, draft: TeamDraft) async {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            try await administration.updateTeam(id: id, draft: draft)
            await loadTeams()
        } catch { presentedError = UserFacingError(error) }
    }

    func deleteTeam(id: UUID) async {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            try await administration.deleteTeam(id: id)
            await loadTeams()
        } catch { presentedError = UserFacingError(error) }
    }

    func createPlayer(teamID: UUID, draft: PlayerDraft) async {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            try await administration.createPlayer(teamID: teamID, draft: draft)
            await loadTeams()
        } catch { presentedError = UserFacingError(error) }
    }

    func saveMatch(id: UUID?, draft: MatchScheduleDraft) async -> UUID? {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            let savedID = try await administration.saveMatch(id: id, draft: draft)
            await loadMatches()
            return savedID
        } catch {
            presentedError = UserFacingError(error)
            return nil
        }
    }

    func deleteMatch(id: UUID) async {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            try await administration.deleteMatch(id: id)
            await loadMatches()
        } catch { presentedError = UserFacingError(error) }
    }

    func settings() async throws -> FederationSettings? {
        guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
        return try await administration.settings()
    }

    func saveSettings(_ settings: FederationSettings) async {
        do {
            guard let administration else { throw ConfigurationError.missingSupabaseConfiguration }
            try await administration.saveSettings(settings)
        } catch { presentedError = UserFacingError(error) }
    }

    func match(id: UUID) async throws -> Match {
        guard let matchesRepository else { throw ConfigurationError.missingSupabaseConfiguration }
        let official = try await matchesRepository.match(id: id)
        upsert(official)
        return official
    }

    func start(match: Match) async {
        guard let matchesRepository, let currentUser else { return }
        do {
            try MatchRules.validate(.start, match: match, user: currentUser)
            let official = try await matchesRepository.startMatch(id: match.id)
            upsert(official)
            do {
                try await liveActivity.start(official)
            } catch {
                // El inicio ya es oficial; la Live Activity se puede reintentar sin tocar Supabase.
                presentedError = UserFacingError(
                    title: "Partido iniciado",
                    message: "El inicio fue confirmado, pero no se pudo crear la Live Activity: \(error.localizedDescription)"
                )
            }
        } catch {
            presentedError = UserFacingError(error)
        }
    }

    func finish(match: Match) async {
        guard let matchesRepository, let currentUser else { return }
        do {
            try MatchRules.validate(.finish, match: match, user: currentUser)
            let official = try await matchesRepository.finishMatch(id: match.id)
            upsert(official)
            do {
                try await liveActivity.finish(official)
            } catch {
                presentedError = UserFacingError(
                    title: "Resultado confirmado",
                    message: "El partido finalizó oficialmente. No se pudo actualizar la Live Activity aún: \(error.localizedDescription)"
                )
            }
        } catch {
            presentedError = UserFacingError(error)
        }
    }

    func submitEvent(match: Match, draft: EventDraft) async -> EventSubmissionResult? {
        guard let currentUser, let eventSubmission else { return nil }
        do {
            try MatchRules.validate(.recordEvent, match: match, user: currentUser)
            let result = try await eventSubmission.submit(matchID: match.id, draft: draft)
            switch result {
            case .confirmed:
                try await refreshOfficialMatch(match.id)
            case .awaitingConfirmation:
                presentedError = UserFacingError(
                    title: "Pendiente de confirmar",
                    message: "No se confirmó la incidencia. Se consultará el servidor antes de reintentarla; no figura como oficial."
                )
            }
            return result
        } catch {
            presentedError = UserFacingError(error)
            return nil
        }
    }

    func deleteEvent(id: UUID, from match: Match) async {
        guard let matchesRepository, let currentUser else { return }
        do {
            try MatchRules.validate(.deleteEvent, match: match, user: currentUser)
            try await matchesRepository.deleteEvent(id: id)
            try await refreshOfficialMatch(match.id)
        } catch {
            presentedError = UserFacingError(error)
        }
    }

    func saveLineup(match: Match, entries: [LineupEntry]) async {
        guard let matchesRepository, let currentUser else { return }
        do {
            try MatchRules.validate(.changeLineup, match: match, user: currentUser)
            try await matchesRepository.replaceLineup(matchID: match.id, entries: entries)
            try await refreshOfficialMatch(match.id)
        } catch {
            presentedError = UserFacingError(error)
        }
    }

    func saveObservations(match: Match, observations: String) async {
        guard let matchesRepository, let currentUser else { return }
        do {
            try MatchRules.validate(.editObservations, match: match, user: currentUser)
            try await matchesRepository.updateObservations(matchID: match.id, observations: observations)
            try await refreshOfficialMatch(match.id)
        } catch {
            presentedError = UserFacingError(error)
        }
    }

    func retryLiveActivity(for match: Match) async {
        do {
            if match.status == .inProgress { try await liveActivity.startOrUpdate(match) }
            if match.status == .finished { try await liveActivity.finish(match) }
        } catch { presentedError = UserFacingError(error) }
    }

    func observe(matchID: UUID) -> Task<Void, Never>? {
        guard let realtime else { return nil }
        return Task { [weak self] in
            let stream = await realtime.changes(for: matchID)
            for await _ in stream {
                do {
                try await self?.refreshOfficialMatch(matchID)
                 } catch {
                print("Error al actualizar el partido \(matchID): \(error)")
                }
            }
        }
    }

    func handle(url: URL) {
        pendingRoute = FFPSJDeepLink(url: url)
    }

    private func reconcilePendingOperations() async {
        guard let eventSubmission else { return }
        let affectedMatches = await eventSubmission.reconcile()
        for id in Set(affectedMatches) { try? await refreshOfficialMatch(id) }
    }

    private func refreshOfficialMatch(_ id: UUID) async throws {
        guard let matchesRepository else { return }
        let official = try await matchesRepository.match(id: id)
        upsert(official)
        try? await liveActivity.update(official)
    }

    private func upsert(_ match: Match) {
        if let index = matches.firstIndex(where: { $0.id == match.id }) {
            matches[index] = match
        } else {
            matches.append(match)
            matches.sort { ($0.scheduledAt.date ?? .distantFuture) < ($1.scheduledAt.date ?? .distantFuture) }
        }
    }
}

struct UserFacingError: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ error: Error) {
        title = "No se completó la operación"
        message = error.localizedDescription
    }

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}


@MainActor
private final class LiveActivityManager {
    private func attributes(for match: Match) -> FFPSJMatchAttributes {
        FFPSJMatchAttributes(match: match)
    }

    private func content(
        for match: Match
    ) -> ActivityContent<FFPSJMatchAttributes.ContentState> {
        ActivityContent(
            state: .init(
                homeScore: match.homeScore,
                awayScore: match.awayScore,
                status: match.status,
                startedAt: match.startedAt?.date
            ),
            staleDate: nil
        )
    }

    func start(_ match: Match) async throws {
        guard match.status == .inProgress else { return }

        let activityID = match.id
        if let existing = Activity<FFPSJMatchAttributes>.activities.first(
            where: { $0.attributes.matchID == activityID }
        ) {
            await existing.update(content(for: match))
        } else {
            _ = try Activity.request(
                attributes: attributes(for: match),
                content: content(for: match),
                pushType: nil
            )
        }
    }

    func startOrUpdate(_ match: Match) async throws {
        try await start(match)
    }

    func update(_ match: Match) async throws {
        let matchingActivities = Activity<FFPSJMatchAttributes>.activities.filter {
            $0.attributes.matchID == match.id
        }
        let newContent = content(for: match)

        for activity in matchingActivities {
            await activity.update(newContent)
        }
    }

    func finish(_ match: Match) async throws {
        let matchingActivities = Activity<FFPSJMatchAttributes>.activities.filter {
            $0.attributes.matchID == match.id
        }
        let finalContent = content(for: match)

        for activity in matchingActivities {
            await activity.end(
                finalContent,
                dismissalPolicy: .after(
                    .now.addingTimeInterval(15 * 60)
                )
            )
        }
    }
}
