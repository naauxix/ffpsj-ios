import FFPSJDomain
import Foundation
import Supabase

public actor SupabaseAdministrationRepository: AdministrationRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) { self.client = client }

    public func listTeams() async throws -> [Team] {
        try await client
            .from("teams")
            .select("id,name,short_name,color,logo_url,players(id,full_name,document_number,shirt_number,position,active)")
            .order("name")
            .execute()
            .value
    }

    public func listUsers() async throws -> [AppUser] {
        try await client
            .from("users")
            .select("id,email,role,status,deactivated_at,profile:profiles(full_name,avatar_url)")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func createTeam(_ draft: TeamDraft) async throws {
        try await client.from("teams").insert(draft).execute()
    }

    public func updateTeam(id: UUID, draft: TeamDraft) async throws {
        try await client.from("teams").update(draft).eq("id", value: id.uuidString).execute()
    }

    public func deleteTeam(id: UUID) async throws {
        try await client.from("teams").delete().eq("id", value: id.uuidString).execute()
    }

    public func createPlayer(teamID: UUID, draft: PlayerDraft) async throws {
        try await client.from("players").insert(CreatePlayer(teamID: teamID, draft: draft)).execute()
    }

    public func updatePlayer(id: UUID, draft: PlayerDraft) async throws {
        try await client.from("players").update(draft).eq("id", value: id.uuidString).execute()
    }

    public func saveMatch(id: UUID?, draft: MatchScheduleDraft) async throws -> UUID {
        if let id {
            let response: MatchIdentifier = try await client
                .from("matches")
                .update(draft)
                .eq("id", value: id.uuidString)
                .select("id")
                .single()
                .execute()
                .value
            return response.id
        }
        let response: MatchIdentifier = try await client
            .from("matches")
            .insert(draft)
            .select("id")
            .single()
            .execute()
            .value
        return response.id
    }

    public func deleteMatch(id: UUID) async throws {
        try await client.from("matches").delete().eq("id", value: id.uuidString).execute()
    }

    public func updateUser(id: UUID, role: AppRole?, status: AccountStatus?) async throws {
        try await client
            .from("users")
            .update(UserUpdate(role: role, status: status))
            .eq("id", value: id.uuidString)
            .execute()
    }

    public func settings() async throws -> FederationSettings? {
        let values: [FederationSettings] = try await client
            .from("settings")
            .select("id,federation_name,season_name,support_email")
            .limit(1)
            .execute()
            .value
        return values.first
    }

    public func saveSettings(_ settings: FederationSettings) async throws {
        guard let id = settings.id else {
            throw AdministrationError.missingSettingsIdentifier
        }
        try await client.from("settings").update(settings).eq("id", value: id.uuidString).execute()
    }
}

private struct UserUpdate: Encodable {
    let role: AppRole?
    let status: AccountStatus?
}

private struct CreatePlayer: Encodable {
    let team_id: UUID
    let full_name: String
    let document_number: String?
    let shirt_number: Int
    let position: String?
    let active: Bool

    init(teamID: UUID, draft: PlayerDraft) {
        team_id = teamID
        full_name = draft.fullName
        document_number = draft.documentNumber
        shirt_number = draft.shirtNumber
        position = draft.position
        active = draft.active
    }
}

private struct MatchIdentifier: Decodable {
    let id: UUID
}

public enum AdministrationError: LocalizedError, Sendable {
    case missingSettingsIdentifier
    public var errorDescription: String? { "No existe el registro de configuración institucional." }
}
