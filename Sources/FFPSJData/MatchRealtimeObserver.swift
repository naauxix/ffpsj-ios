import FFPSJDomain
import Foundation
import Supabase

/// Las notificaciones Realtime sólo disparan una lectura nueva. Nunca aplican deltas al marcador local.
public actor MatchRealtimeObserver {
    private let client: SupabaseClient

    public init(client: SupabaseClient) { self.client = client }

    public func changes(for matchID: UUID) -> AsyncStream<Void> {
        let channel = client.channel("ffpsj.match.\(matchID.uuidString)")
        let matchUpdates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "matches",
            filter: "id=eq.\(matchID.uuidString)"
        )
        let lineupInsertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "match_players",
            filter: "match_id=eq.\(matchID.uuidString)"
        )
        let lineupDeletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "match_players",
            filter: "match_id=eq.\(matchID.uuidString)"
        )

        return AsyncStream { continuation in
            let tasks = [
                Task {
                    await channel.subscribe()
                    for await _ in matchUpdates { continuation.yield() }
                },
                Task {
                    for await _ in lineupInsertions { continuation.yield() }
                },
                Task {
                    for await _ in lineupDeletions { continuation.yield() }
                }
            ]
            continuation.onTermination = { _ in
                tasks.forEach { $0.cancel() }
                Task { await self.client.removeChannel(channel) }
            }
        }
    }
}
