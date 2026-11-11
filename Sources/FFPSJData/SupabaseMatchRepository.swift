import FFPSJDomain
import Foundation
import Supabase

private let matchListSelect = """
id,competition,round,scheduled_at,venue,status,home_score,away_score,observations,started_at,finished_at,assigned_referee_id,
home_team:teams!matches_home_team_id_fkey(id,name,short_name,color,logo_url),
away_team:teams!matches_away_team_id_fkey(id,name,short_name,color,logo_url),
referee:profiles!matches_assigned_referee_id_fkey(id,full_name,avatar_url)
"""

private let matchDetailSelect = """
\(matchListSelect),
match_players(id,match_id,team_id,player_id,shirt_number,position,starter,player:players(id,full_name,document_number,shirt_number,position,active)),
events(id,match_id,event_type,minute,period,team_id,player_id,replacement_player_id,description,client_request_id,created_at,player:players!events_player_id_fkey(id,full_name,document_number,shirt_number,position,active),replacement_player:players!events_replacement_player_id_fkey(id,full_name,document_number,shirt_number,position,active))
"""

public actor SupabaseMatchRepository: MatchRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) { self.client = client }

    public func listMatches() async throws -> [Match] {
        try await client
            .from("matches")
            .select(matchListSelect)
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }

    public func match(id: UUID) async throws -> Match {
        try await client
            .from("matches")
            .select(matchDetailSelect)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    public func startMatch(id: UUID) async throws -> Match {
        _ = try await client.rpc("start_match", params: ["p_match_id": id.uuidString]).execute()
        return try await match(id: id)
    }

    public func finishMatch(id: UUID) async throws -> Match {
        _ = try await client.rpc("finish_match", params: ["p_match_id": id.uuidString]).execute()
        return try await match(id: id)
    }

    public func recordEvent(matchID: UUID, draft: EventDraft) async throws -> MatchEvent {
        try MatchRules.validate(draft)
        let params = RecordEventParameters(matchID: matchID, draft: draft)
        return try await client
            .rpc("record_match_event", params: params)
            .single()
            .execute()
            .value
    }

    public func event(matchID: UUID, clientRequestID: UUID) async throws -> MatchEvent? {
        let items: [MatchEvent] = try await client
            .from("events")
            .select("id,match_id,event_type,minute,period,team_id,player_id,replacement_player_id,description,client_request_id,created_at")
            .eq("match_id", value: matchID.uuidString)
            .eq("client_request_id", value: clientRequestID.uuidString)
            .limit(1)
            .execute()
            .value
        return items.first
    }

    public func deleteEvent(id: UUID) async throws {
        try await client.from("events").delete().eq("id", value: id.uuidString).execute()
    }

    public func replaceLineup(matchID: UUID, entries: [LineupEntry]) async throws {
        try await client
            .rpc("replace_match_lineup", params: ReplaceLineupParameters(matchID: matchID, entries: entries))
            .execute()
    }

    public func updateObservations(matchID: UUID, observations: String?) async throws {
        try await client
            .rpc("update_match_observations", params: UpdateObservationsParameters(matchID: matchID, observations: observations))
            .execute()
    }
}

private struct RecordEventParameters: Encodable {
    let p_match_id: UUID
    let p_event_type: MatchEventType
    let p_minute: Int
    let p_period: Int
    let p_team_id: UUID?
    let p_player_id: UUID?
    let p_replacement_player_id: UUID?
    let p_description: String?
    let p_client_request_id: UUID

    init(matchID: UUID, draft: EventDraft) {
        p_match_id = matchID
        p_event_type = draft.type
        p_minute = draft.minute
        p_period = draft.period
        p_team_id = draft.teamID
        p_player_id = draft.playerID
        p_replacement_player_id = draft.replacementPlayerID
        p_description = draft.description
        p_client_request_id = draft.clientRequestID
    }
}

private struct ReplaceLineupParameters: Encodable {
    let p_match_id: UUID
    let p_entries: [LineupEntry]

    init(matchID: UUID, entries: [LineupEntry]) {
        p_match_id = matchID
        p_entries = entries
    }
}

private struct UpdateObservationsParameters: Encodable {
    let p_match_id: UUID
    let p_observations: String?

    init(matchID: UUID, observations: String?) {
        p_match_id = matchID
        p_observations = observations
    }
}
