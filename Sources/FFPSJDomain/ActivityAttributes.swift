import ActivityKit
import Foundation

public struct FFPSJMatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var homeScore: Int
        public var awayScore: Int
        public var status: MatchStatus
        public var startedAt: Date?

        public init(homeScore: Int, awayScore: Int, status: MatchStatus, startedAt: Date?) {
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.status = status
            self.startedAt = startedAt
        }
    }

    public var matchID: UUID
    public var homeTeamID: UUID?
    public var awayTeamID: UUID?
    public var homeName: String
    public var awayName: String
    public var homeShortName: String
    public var awayShortName: String
    public var homeColor: String
    public var awayColor: String

    public init(match: Match) {
        matchID = match.id
        homeTeamID = match.homeTeam?.id
        awayTeamID = match.awayTeam?.id
        homeName = match.homeTeam?.name ?? "Local"
        awayName = match.awayTeam?.name ?? "Visitante"
        homeShortName = match.homeTeam?.shortName ?? "LOC"
        awayShortName = match.awayTeam?.shortName ?? "VIS"
        homeColor = match.homeTeam?.color ?? "#1769E0"
        awayColor = match.awayTeam?.color ?? "#1769E0"
    }
}
