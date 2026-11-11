import Foundation

public enum AppRole: String, Codable, CaseIterable, Sendable {
    case admin
    case referee

    public var label: String { self == .admin ? "Administrador" : "Árbitro" }
}

public enum AccountStatus: String, Codable, Sendable {
    case active
    case inactive
}

public enum MatchStatus: String, Codable, CaseIterable, Sendable {
    case scheduled
    case inProgress = "in_progress"
    case finished
    case cancelled

    public var label: String {
        switch self {
        case .scheduled: "Programado"
        case .inProgress: "En juego"
        case .finished: "Finalizado"
        case .cancelled: "Cancelado"
        }
    }
}

public enum MatchEventType: String, Codable, CaseIterable, Sendable {
    case goal
    case yellowCard = "yellow_card"
    case redCard = "red_card"
    case substitution
    case note

    public var label: String {
        switch self {
        case .goal: "Gol"
        case .yellowCard: "Tarjeta amarilla"
        case .redCard: "Tarjeta roja"
        case .substitution: "Sustitución"
        case .note: "Observación"
        }
    }
}

/// Conserva la fecha textual enviada por PostgREST y la transforma en un instante solo al usarla.
/// Así la app tolera fracciones de segundo y offsets que varían según la configuración de Supabase.
public struct ServerDate: Codable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var date: Date? {
        Self.fractional.date(from: rawValue) ?? Self.standard.date(from: rawValue)
    }

   
    private static var fractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static var standard: ISO8601DateFormatter {
        ISO8601DateFormatter()
    }
}

public struct Profile: Codable, Hashable, Sendable {
    public var fullName: String
    public var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case avatarURL = "avatar_url"
    }
}

public struct AppUser: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var email: String
    public var role: AppRole
    public var status: AccountStatus
    public var deactivatedAt: ServerDate?
    public var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, email, role, status, profile
        case deactivatedAt = "deactivated_at"
    }

    public var displayName: String { profile?.fullName.isEmpty == false ? profile!.fullName : email }
    public var isActive: Bool { status == .active }
}

public struct Team: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var shortName: String
    public var color: String
    public var logoURL: String?
    public var players: [Player]?

    enum CodingKeys: String, CodingKey {
        case id, name, color, players
        case shortName = "short_name"
        case logoURL = "logo_url"
    }
}

public struct Player: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var fullName: String
    public var documentNumber: String?
    public var shirtNumber: Int
    public var position: String?
    public var active: Bool

    enum CodingKeys: String, CodingKey {
        case id, position, active
        case fullName = "full_name"
        case documentNumber = "document_number"
        case shirtNumber = "shirt_number"
    }
}

public struct MatchPlayer: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var matchID: UUID?
    public var teamID: UUID
    public var playerID: UUID?
    public var shirtNumber: Int
    public var position: String?
    public var starter: Bool
    public var player: Player?

    enum CodingKeys: String, CodingKey {
        case id, position, starter, player
        case matchID = "match_id"
        case teamID = "team_id"
        case playerID = "player_id"
        case shirtNumber = "shirt_number"
    }
}

public struct MatchEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var matchID: UUID?
    public var type: MatchEventType
    public var minute: Int
    public var period: Int
    public var teamID: UUID?
    public var playerID: UUID?
    public var replacementPlayerID: UUID?
    public var description: String?
    public var clientRequestID: UUID?
    public var player: Player?
    public var replacementPlayer: Player?
    public var createdAt: ServerDate?

    enum CodingKeys: String, CodingKey {
        case id, minute, period, description, player, createdAt
        case matchID = "match_id"
        case type = "event_type"
        case teamID = "team_id"
        case playerID = "player_id"
        case replacementPlayerID = "replacement_player_id"
        case clientRequestID = "client_request_id"
        case replacementPlayer = "replacement_player"
    }
}

public struct Match: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var competition: String
    public var round: String?
    public var scheduledAt: ServerDate
    public var venue: String
    public var status: MatchStatus
    public var homeScore: Int
    public var awayScore: Int
    public var observations: String?
    public var startedAt: ServerDate?
    public var finishedAt: ServerDate?
    public var homeTeam: Team?
    public var awayTeam: Team?
    public var referee: Profile?
    public var assignedRefereeID: UUID?
    public var matchPlayers: [MatchPlayer]?
    public var events: [MatchEvent]?

    enum CodingKeys: String, CodingKey {
        case id, competition, round, venue, status, observations, referee, events
        case scheduledAt = "scheduled_at"
        case homeScore = "home_score"
        case awayScore = "away_score"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case assignedRefereeID = "assigned_referee_id"
        case matchPlayers = "match_players"
    }

    public var hasStarted: Bool { startedAt?.date != nil && status == .inProgress }
    public var scoreText: String { "\(homeScore) — \(awayScore)" }
}

public struct EventDraft: Codable, Hashable, Sendable {
    public var type: MatchEventType
    public var minute: Int
    public var period: Int
    public var teamID: UUID?
    /// Goleador, amonestado, expulsado o jugador que sale en un cambio.
    public var playerID: UUID?
    /// Jugador que entra. Solo se usa para sustituciones tras aplicar la migración iOS.
    public var replacementPlayerID: UUID?
    public var description: String?
    public let clientRequestID: UUID

    public init(
        type: MatchEventType,
        minute: Int,
        period: Int = 1,
        teamID: UUID?,
        playerID: UUID?,
        replacementPlayerID: UUID? = nil,
        description: String? = nil,
        clientRequestID: UUID = UUID()
    ) {
        self.type = type
        self.minute = minute
        self.period = period
        self.teamID = teamID
        self.playerID = playerID
        self.replacementPlayerID = replacementPlayerID
        self.description = description
        self.clientRequestID = clientRequestID
    }
}

public struct LineupEntry: Codable, Hashable, Sendable {
    public var teamID: UUID
    public var playerID: UUID
    public var shirtNumber: Int
    public var position: String?
    public var starter: Bool

    public init(teamID: UUID, playerID: UUID, shirtNumber: Int, position: String? = nil, starter: Bool) {
        self.teamID = teamID
        self.playerID = playerID
        self.shirtNumber = shirtNumber
        self.position = position
        self.starter = starter
    }

    enum CodingKeys: String, CodingKey {
        case position, starter
        case teamID = "team_id"
        case playerID = "player_id"
        case shirtNumber = "shirt_number"
    }
}

public struct FederationSettings: Codable, Hashable, Sendable {
    public var id: UUID?
    public var federationName: String
    public var seasonName: String
    public var supportEmail: String

    enum CodingKeys: String, CodingKey {
        case id
        case federationName = "federation_name"
        case seasonName = "season_name"
        case supportEmail = "support_email"
    }

    public init(id: UUID?, federationName: String, seasonName: String, supportEmail: String) {
        self.id = id
        self.federationName = federationName
        self.seasonName = seasonName
        self.supportEmail = supportEmail
    }
}

public struct TeamDraft: Codable, Hashable, Sendable {
    public var name: String
    public var shortName: String
    public var color: String
    public var logoURL: String?

    enum CodingKeys: String, CodingKey {
        case name, color
        case shortName = "short_name"
        case logoURL = "logo_url"
    }

    public init(name: String, shortName: String, color: String, logoURL: String? = nil) {
        self.name = name
        self.shortName = shortName
        self.color = color
        self.logoURL = logoURL
    }
}

public struct PlayerDraft: Codable, Hashable, Sendable {
    public var fullName: String
    public var documentNumber: String?
    public var shirtNumber: Int
    public var position: String?
    public var active: Bool

    enum CodingKeys: String, CodingKey {
        case position, active
        case fullName = "full_name"
        case documentNumber = "document_number"
        case shirtNumber = "shirt_number"
    }

    public init(fullName: String, documentNumber: String?, shirtNumber: Int, position: String?, active: Bool = true) {
        self.fullName = fullName
        self.documentNumber = documentNumber
        self.shirtNumber = shirtNumber
        self.position = position
        self.active = active
    }
}

public struct MatchScheduleDraft: Codable, Hashable, Sendable {
    public var competition: String
    public var round: String?
    public var scheduledAt: String
    public var venue: String
    public var homeTeamID: UUID
    public var awayTeamID: UUID
    public var assignedRefereeID: UUID?
    public var status: MatchStatus

    enum CodingKeys: String, CodingKey {
        case competition, round, venue, status
        case scheduledAt = "scheduled_at"
        case homeTeamID = "home_team_id"
        case awayTeamID = "away_team_id"
        case assignedRefereeID = "assigned_referee_id"
    }

    public init(
        competition: String,
        round: String?,
        scheduledAt: String,
        venue: String,
        homeTeamID: UUID,
        awayTeamID: UUID,
        assignedRefereeID: UUID?,
        status: MatchStatus = .scheduled
    ) {
        self.competition = competition
        self.round = round
        self.scheduledAt = scheduledAt
        self.venue = venue
        self.homeTeamID = homeTeamID
        self.awayTeamID = awayTeamID
        self.assignedRefereeID = assignedRefereeID
        self.status = status
    }
}
