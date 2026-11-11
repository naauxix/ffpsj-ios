import FFPSJDomain
import Foundation
import SwiftUI

struct AdminMatchEditor: View {
    let match: Match?
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var competition: String
    @State private var round: String
    @State private var date: Date
    @State private var venue: String
    @State private var homeTeamID: UUID?
    @State private var awayTeamID: UUID?
    @State private var refereeID: UUID?
    @State private var status: MatchStatus
    @State private var referees: [AppUser] = []

    init(match: Match?) {
        self.match = match
        _competition = State(initialValue: match?.competition ?? "")
        _round = State(initialValue: match?.round ?? "")
        _date = State(initialValue: match?.scheduledAt.date ?? .now)
        _venue = State(initialValue: match?.venue ?? "")
        _homeTeamID = State(initialValue: match?.homeTeam?.id)
        _awayTeamID = State(initialValue: match?.awayTeam?.id)
        _refereeID = State(initialValue: match?.assignedRefereeID)
        _status = State(initialValue: match?.status ?? .scheduled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Información del encuentro") {
                    TextField("Competencia", text: $competition)
                    TextField("Jornada / fecha", text: $round)
                    DatePicker("Fecha y hora", selection: $date)
                    TextField("Sede", text: $venue)
                }
                Section("Participantes") {
                    Picker("Equipo local", selection: $homeTeamID) {
                        Text("Seleccionar").tag(nil as UUID?)
                        ForEach(container.teams) { Text($0.name).tag($0.id as UUID?) }
                    }
                    Picker("Equipo visitante", selection: $awayTeamID) {
                        Text("Seleccionar").tag(nil as UUID?)
                        ForEach(container.teams) { Text($0.name).tag($0.id as UUID?) }
                    }
                }
                Section("Acta y responsable") {
                    Picker("Árbitro asignado", selection: $refereeID) {
                        Text("Sin asignar").tag(nil as UUID?)
                        ForEach(referees) { Text($0.displayName).tag($0.id as UUID?) }
                    }
                    Picker("Estado", selection: $status) {
                        ForEach(MatchStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
            }
            .navigationTitle(match == nil ? "Nuevo partido" : "Editar partido")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { Task { await save() } } }
            }
        }
        .task {
            await container.loadTeams()
            do { referees = try (await container.users()).filter { $0.role == .referee && $0.status == .active } }
            catch { container.presentedError = UserFacingError(error) }
        }
    }

    private func save() async {
        guard competition.count >= 2, venue.count >= 2,
              let homeTeamID, let awayTeamID, homeTeamID != awayTeamID else {
            container.presentedError = UserFacingError(title: "Datos no válidos", message: "Completa competencia, sede y dos equipos distintos.")
            return
        }
        let formatter = ISO8601DateFormatter()
        let draft = MatchScheduleDraft(
            competition: competition,
            round: round.isEmpty ? nil : round,
            scheduledAt: formatter.string(from: date),
            venue: venue,
            homeTeamID: homeTeamID,
            awayTeamID: awayTeamID,
            assignedRefereeID: refereeID,
            status: status
        )
        if await container.saveMatch(id: match?.id, draft: draft) != nil { dismiss() }
    }
}
