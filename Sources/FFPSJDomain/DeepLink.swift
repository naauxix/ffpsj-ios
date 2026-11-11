import Foundation

public enum FFPSJDeepLink: Equatable, Sendable {
    case match(UUID)
    case event(matchID: UUID, type: MatchEventType, teamID: UUID?)
    case finish(matchID: UUID)

    public init?(url: URL) {
        guard url.scheme == "ffpsj", url.host == "matches" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let matchID = parts.first.flatMap(UUID.init(uuidString:)) else { return nil }

        if parts.dropFirst().first == "events" {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let rawType = items.first(where: { $0.name == "kind" })?.value,
                  let type = MatchEventType(rawValue: rawType) else { return nil }
            let teamID = items.first(where: { $0.name == "team" })?.value.flatMap(UUID.init(uuidString:))
            self = .event(matchID: matchID, type: type, teamID: teamID)
        } else if parts.dropFirst().first == "finish" {
            self = .finish(matchID: matchID)
        } else {
            self = .match(matchID)
        }
    }

    public static func eventURL(matchID: UUID, type: MatchEventType, teamID: UUID? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "ffpsj"
        components.host = "matches"
        components.path = "/\(matchID.uuidString)/events"
        components.queryItems = [
            URLQueryItem(name: "kind", value: type.rawValue),
            URLQueryItem(name: "team", value: teamID?.uuidString)
        ]
        return components.url!
    }

    public static func finishURL(matchID: UUID) -> URL {
        URL(string: "ffpsj://matches/\(matchID.uuidString)/finish")!
    }
}
