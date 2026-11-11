import FFPSJDomain
import Foundation
import Testing

@Suite("Reglas oficiales de partido")
struct MatchRulesTests {
    @Test("Solo un partido programado puede iniciarse")
    func scheduledMatchCanStart() throws {
        let user = try fixtureUser()
        try MatchRules.validate(.start, match: try fixtureMatch(status: .scheduled), user: user)
        #expect(throws: MatchRuleError.self) {
            try MatchRules.validate(.start, match: try fixtureMatch(status: .inProgress), user: user)
        }
    }

    @Test("Un árbitro no puede gestionar otro partido")
    func refereeCannotManageOtherMatch() throws {
        let user = try fixtureUser()
        var match = try fixtureMatch(status: .scheduled)
        match.assignedRefereeID = UUID()
        #expect(throws: MatchRuleError.forbidden) {
            try MatchRules.validate(.start, match: match, user: user)
        }
    }

    @Test("Una sustitución exige salida y entrada distintas")
    func substitutionRequiresTwoPlayers() throws {
        let team = UUID()
        let player = UUID()
        #expect(throws: MatchRuleError.invalidSubstitution) {
            try MatchRules.validate(EventDraft(type: .substitution, minute: 4, teamID: team, playerID: player, replacementPlayerID: player))
        }
        try MatchRules.validate(EventDraft(type: .substitution, minute: 4, teamID: team, playerID: player, replacementPlayerID: UUID()))
    }

    @Test("Una observación de evento tiene un límite compatible con el servidor")
    func eventDescriptionLengthIsValidatedLocally() {
        let tooLong = String(repeating: "a", count: 501)
        #expect(throws: MatchRuleError.descriptionTooLong) {
            try MatchRules.validate(EventDraft(type: .note, minute: 4, teamID: nil, playerID: nil, description: tooLong))
        }
    }

    @Test("El identificador de idempotencia no cambia entre reintentos")
    func eventRequestIdentifierIsStable() {
        let requestID = UUID()
        let firstTry = EventDraft(type: .goal, minute: 7, teamID: UUID(), playerID: UUID(), clientRequestID: requestID)
        let retry = EventDraft(type: .goal, minute: 7, teamID: firstTry.teamID, playerID: firstTry.playerID, clientRequestID: requestID)
        #expect(firstTry.clientRequestID == retry.clientRequestID)
    }

    @Test("El cronómetro deriva del instante persistido")
    func elapsedTimeUsesReferenceDate() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        #expect(MatchClock.elapsedSeconds(startedAt: startedAt, now: Date(timeIntervalSince1970: 1_075)) == 75)
        #expect(MatchClock.elapsedSeconds(startedAt: nil) == nil)
    }
}

private func fixtureUser() throws -> AppUser {
    try JSONDecoder().decode(AppUser.self, from: Data("""
    {"id":"00000000-0000-0000-0000-000000000001","email":"referee@ffpsj.org","role":"referee","status":"active"}
    """.utf8))
}

private func fixtureMatch(status: MatchStatus) throws -> Match {
    try JSONDecoder().decode(Match.self, from: Data("""
    {
      "id":"00000000-0000-0000-0000-000000000099",
      "competition":"Liga Provincial",
      "scheduled_at":"2026-10-27T18:00:00Z",
      "venue":"Complejo",
      "status":"\(status.rawValue)",
      "home_score":0,
      "away_score":0,
      "assigned_referee_id":"00000000-0000-0000-0000-000000000001"
    }
    """.utf8))
}
