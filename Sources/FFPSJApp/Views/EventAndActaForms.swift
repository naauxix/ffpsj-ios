import FFPSJDomain
import SwiftUI

struct EventFormSheet: View {
    let match: Match
    let request: EventRequest
    let completed: () async -> Void
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var type: MatchEventType
    @State private var minute = ""
    @State private var period = 1
    @State private var teamID: UUID?
    @State private var playerID: UUID?
    @State private var replacementPlayerID: UUID?
    @State private var description = ""
    @State private var isSaving = false

    init(match: Match, request: EventRequest, completed: @escaping () async -> Void) {
        self.match = match
        self.request = request
        self.completed = completed
        _type = State(initialValue: request.type)
        _teamID = State(initialValue: request.teamID)
    }

    private var players: [MatchPlayer] {
        (match.matchPlayers ?? [])
            .filter { teamID == nil || $0.teamID == teamID }
            .sorted { $0.shirtNumber < $1.shirtNumber }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Incidencia") {
                    Picker("Tipo", selection: $type) {
                        ForEach(MatchEventType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Picker("Minuto", selection: $minute) {
                        Text("Seleccionar").tag("")
                        ForEach(0...99, id: \.self) { Text("\($0)'").tag(String($0)) }
                    }
                    Picker("Período", selection: $period) {
                        Text("1.º período").tag(1)
                        Text("2.º período").tag(2)
                        Text("Prórroga").tag(3)
                    }
                }
                Section("Equipo") {
                    Picker("Equipo implicado", selection: $teamID) {
                        Text("Seleccionar").tag(nil as UUID?)
                        Text(match.homeTeam?.name ?? "Local").tag(match.homeTeam?.id as UUID?)
                        Text(match.awayTeam?.name ?? "Visitante").tag(match.awayTeam?.id as UUID?)
                    }
                    .onChange(of: teamID) { _, _ in
                        playerID = nil
                        replacementPlayerID = nil
                    }
                }
                if type == .substitution {
                    Section("Sustitución") {
                        playerPicker(label: "Jugador que sale", selection: $playerID)
                        playerPicker(label: "Jugador que entra", selection: $replacementPlayerID)
                    }
                } else if type != .note {
                    Section("Jugador") {
                        playerPicker(label: "Jugador implicado", selection: $playerID)
                    }
                }
                Section("Detalle") {
                    TextField("Observación opcional", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Text("La incidencia no se mostrará como oficial hasta que Supabase confirme la operación.")
                        .font(.footnote)
                        .foregroundStyle(FFPSJColor.muted)
                }
            }
            .navigationTitle("Registrar evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Guardando…" : "Guardar") { Task { await submit() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    @ViewBuilder
    private func playerPicker(label: String, selection: Binding<UUID?>) -> some View {
        Picker(label, selection: selection) {
            Text("Seleccionar").tag(nil as UUID?)
            ForEach(players) { line in
                Text("\(line.shirtNumber) · \(line.player?.fullName ?? "Jugador")")
                    .tag(line.playerID as UUID?)
            }
        }
        .disabled(teamID == nil)
    }

    private func submit() async {
        guard let minute = Int(minute) else {
            container.presentedError = UserFacingError(title: "Minuto requerido", message: "Selecciona el minuto de la incidencia.")
            return
        }
        let draft = EventDraft(
            type: type,
            minute: minute,
            period: period,
            teamID: teamID,
            playerID: playerID,
            replacementPlayerID: replacementPlayerID,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isSaving = true
        defer { isSaving = false }
        if let result = await container.submitEvent(match: match, draft: draft) {
            await completed()
            switch result {
            case .confirmed, .awaitingConfirmation:
                dismiss()
            }
        }
    }
}

struct LineupEditorSheet: View {
    let match: Match
    let completed: () async -> Void
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [UUID: LineupEntry]
    @State private var isSaving = false

    init(match: Match, completed: @escaping () async -> Void) {
        self.match = match
        self.completed = completed
        _entries = State(initialValue: Dictionary(uniqueKeysWithValues: (match.matchPlayers ?? []).compactMap { line -> (UUID, LineupEntry)? in
            guard let playerID = line.playerID else { return nil }
            return (playerID, LineupEntry(teamID: line.teamID, playerID: playerID, shirtNumber: line.shirtNumber, position: line.position, starter: line.starter))
        }))
    }

    private var participatingTeams: [Team] {
        container.teams.filter { $0.id == match.homeTeam?.id || $0.id == match.awayTeam?.id }
    }

    var body: some View {
        NavigationStack {
            List {
                if participatingTeams.isEmpty {
                    ContentUnavailableView("Cargando plantillas…", systemImage: "person.3")
                }
                ForEach(participatingTeams) { team in
                    Section(team.name) {
                        ForEach((team.players ?? []).filter(\.active).sorted { $0.shirtNumber < $1.shirtNumber }) { player in
                            HStack {
                                Toggle(isOn: selectedBinding(team: team, player: player)) {
                                    VStack(alignment: .leading) {
                                        Text("\(player.shirtNumber) · \(player.fullName)")
                                        Text(player.position ?? "Jugador").font(.caption).foregroundStyle(FFPSJColor.muted)
                                    }
                                }
                                if entries[player.id] != nil {
                                    Button {
                                        if var entry = entries[player.id] {
                                            entry.starter.toggle()
                                            entries[player.id] = entry
                                        }
                                    } label: {
                                        Text(entries[player.id]?.starter == true ? "Titular" : "Suplente")
                                            .font(.caption.weight(.bold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(entries[player.id]?.starter == true ? FFPSJColor.blue : FFPSJColor.muted)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alineaciones")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Guardando…" : "Guardar") { Task { await save() } }.disabled(isSaving)
                }
            }
        }
        .task { await container.loadTeams() }
    }

    private func selectedBinding(team: Team, player: Player) -> Binding<Bool> {
        Binding(
            get: { entries[player.id] != nil },
            set: { selected in
                if selected {
                    entries[player.id] = LineupEntry(teamID: team.id, playerID: player.id, shirtNumber: player.shirtNumber, position: player.position, starter: false)
                } else {
                    entries[player.id] = nil
                }
            }
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        await container.saveLineup(match: match, entries: Array(entries.values))
        await completed()
        dismiss()
    }
}

struct ObservationsSheet: View {
    let match: Match
    let completed: () async -> Void
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var observations: String

    init(match: Match, completed: @escaping () async -> Void) {
        self.match = match
        self.completed = completed
        _observations = State(initialValue: match.observations ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Acta") {
                    TextEditor(text: $observations).frame(minHeight: 180)
                }
                Section {
                    Text("Las observaciones se guardan en el acta oficial y quedan auditadas en Supabase.")
                        .font(.footnote).foregroundStyle(FFPSJColor.muted)
                }
            }
            .navigationTitle("Observaciones")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await container.saveObservations(match: match, observations: observations)
                            await completed()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
