import Foundation

public protocol AuthRepository: Sendable {
    func restoreSession() async throws -> UUID?
    func signIn(email: String, password: String) async throws -> UUID
    func signUp(fullName: String, email: String, password: String) async throws
    func signOut() async throws
    func recoverPassword(email: String, redirectURL: URL) async throws
    func currentUser(id: UUID) async throws -> AppUser
}

public protocol MatchRepository: Sendable {
    func listMatches() async throws -> [Match]
    func match(id: UUID) async throws -> Match
    func startMatch(id: UUID) async throws -> Match
    func finishMatch(id: UUID) async throws -> Match
    func recordEvent(matchID: UUID, draft: EventDraft) async throws -> MatchEvent
    func event(matchID: UUID, clientRequestID: UUID) async throws -> MatchEvent?
    func deleteEvent(id: UUID) async throws
    func replaceLineup(matchID: UUID, entries: [LineupEntry]) async throws
    func updateObservations(matchID: UUID, observations: String?) async throws
}

public protocol AdministrationRepository: Sendable {
    func listTeams() async throws -> [Team]
    func listUsers() async throws -> [AppUser]
    func createTeam(_ draft: TeamDraft) async throws
    func updateTeam(id: UUID, draft: TeamDraft) async throws
    func deleteTeam(id: UUID) async throws
    func createPlayer(teamID: UUID, draft: PlayerDraft) async throws
    func updatePlayer(id: UUID, draft: PlayerDraft) async throws
    func saveMatch(id: UUID?, draft: MatchScheduleDraft) async throws -> UUID
    func deleteMatch(id: UUID) async throws
    func updateUser(id: UUID, role: AppRole?, status: AccountStatus?) async throws
    func settings() async throws -> FederationSettings?
    func saveSettings(_ settings: FederationSettings) async throws
}
