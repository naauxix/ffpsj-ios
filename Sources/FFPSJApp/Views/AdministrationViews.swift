import FFPSJDomain
import SwiftUI

struct TeamsView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var editingTeam: Team?
    @State private var showNewTeam = false
    @State private var playerTeam: Team?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLANTELES").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(FFPSJColor.blue)
                    Text("Equipos y jugadores").font(.largeTitle.weight(.bold))
                    Text("Clubes registrados y sus plantillas oficiales.").foregroundStyle(FFPSJColor.muted)
                }
                if container.teams.isEmpty {
                    ContentUnavailableView("Aún no hay equipos", systemImage: "trophy", description: Text("Crea los equipos antes de programar partidos."))
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(container.teams) { team in
                            TeamRosterCard(team: team) {
                                playerTeam = team
                            } edit: {
                                editingTeam = team
                            } delete: {
                                Task { await container.deleteTeam(id: team.id) }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Equipos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if container.isAdministrator {
                    Button { showNewTeam = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .sheet(item: $editingTeam) { team in TeamEditorSheet(team: team) }
        .sheet(isPresented: $showNewTeam) { TeamEditorSheet(team: nil) }
        .sheet(item: $playerTeam) { team in PlayerEditorSheet(team: team) }
        .task { await container.loadTeams() }
        .refreshable { await container.loadTeams() }
        .ffpsjPageBackground()
    }
}

private struct TeamRosterCard: View {
    let team: Team
    let addPlayer: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    @EnvironmentObject private var container: AppContainer
    @State private var deleteConfirmation = false

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    TeamCrest(team: team, size: 42)
                    VStack(alignment: .leading) {
                        Text(team.name).font(.headline)
                        Text(team.shortName).font(.caption).foregroundStyle(FFPSJColor.muted)
                    }
                    Spacer()
                    if container.isAdministrator {
                        Menu {
                            Button("Editar equipo", action: edit)
                            Button("Eliminar equipo", role: .destructive) { deleteConfirmation = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3).foregroundStyle(FFPSJColor.muted)
                        }
                    }
                }
                Divider()
                HStack {
                    Label("\(team.players?.count ?? 0) jugadores", systemImage: "person.3")
                        .font(.footnote.weight(.semibold)).foregroundStyle(FFPSJColor.muted)
                    Spacer()
                    if container.isAdministrator {
                        Button(action: addPlayer) { Label("Agregar", systemImage: "plus") }
                            .font(.footnote.weight(.bold)).foregroundStyle(FFPSJColor.blue)
                    }
                }
                ForEach((team.players ?? []).sorted { $0.shirtNumber < $1.shirtNumber }) { player in
                    HStack(spacing: 10) {
                        Text("\(player.shirtNumber)")
                            .font(.caption.weight(.bold)).frame(width: 24, height: 24)
                            .background(FFPSJColor.background, in: RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading) {
                            Text(player.fullName).font(.subheadline)
                            Text("\(player.position ?? "Jugador")\(player.active ? "" : " · Inactivo")")
                                .font(.caption2).foregroundStyle(FFPSJColor.muted)
                        }
                    }
                }
            }
        }
        .confirmationDialog("¿Eliminar \(team.name)?", isPresented: $deleteConfirmation, titleVisibility: .visible) {
            Button("Eliminar equipo y jugadores", role: .destructive, action: delete)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Solo se completará si Supabase lo autoriza. Los partidos asociados están protegidos por el esquema.")
        }
    }
}

private struct TeamEditorSheet: View {
    let team: Team?
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var shortName: String
    @State private var color: String
    @State private var logoURL: String

    init(team: Team?) {
        self.team = team
        _name = State(initialValue: team?.name ?? "")
        _shortName = State(initialValue: team?.shortName ?? "")
        _color = State(initialValue: team?.color ?? "#1769E0")
        _logoURL = State(initialValue: team?.logoURL ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre del equipo", text: $name)
                TextField("Nombre corto (máx. 8)", text: $shortName)
                TextField("Color institucional #RRGGBB", text: $color)
                    .textInputAutocapitalization(.characters)
                TextField("URL del escudo oficial (opcional)", text: $logoURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never)
            }
            .navigationTitle(team == nil ? "Nuevo equipo" : "Editar equipo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                }
            }
        }
    }

    private func save() async {
        let normalized = color.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2, (2...8).contains(shortName.count),
              normalized.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
            container.presentedError = UserFacingError(title: "Datos no válidos", message: "Completa nombre, nombre corto de 2 a 8 caracteres y un color #RRGGBB.")
            return
        }
        let draft = TeamDraft(name: name, shortName: shortName.uppercased(), color: normalized, logoURL: logoURL.isEmpty ? nil : logoURL)
        if let team { await container.updateTeam(id: team.id, draft: draft) }
        else { await container.createTeam(draft) }
        dismiss()
    }
}

private struct PlayerEditorSheet: View {
    let team: Team
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var documentNumber = ""
    @State private var shirtNumber = ""
    @State private var position = "Jugador"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre completo", text: $fullName)
                TextField("Dorsal", text: $shirtNumber).keyboardType(.numberPad)
                Picker("Posición", selection: $position) {
                    ForEach(["Jugador", "Portero", "Defensa", "Ala", "Pivot"], id: \.self) { Text($0) }
                }
                TextField("Documento", text: $documentNumber)
            }
            .navigationTitle("Jugador · \(team.shortName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { Task { await save() } } }
            }
        }
    }

    private func save() async {
        guard fullName.count >= 3, let dorsal = Int(shirtNumber), (0...99).contains(dorsal) else {
            container.presentedError = UserFacingError(title: "Datos no válidos", message: "Indica nombre completo y un dorsal entre 0 y 99.")
            return
        }
        await container.createPlayer(teamID: team.id, draft: PlayerDraft(fullName: fullName, documentNumber: documentNumber.isEmpty ? nil : documentNumber, shirtNumber: dorsal, position: position == "Jugador" ? nil : position))
        dismiss()
    }
}

struct UsersView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var users: [AppUser] = []
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                Text("Asigna permisos y habilita las cuentas registradas.")
                    .font(.footnote).foregroundStyle(FFPSJColor.muted)
            }
            ForEach(users) { user in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(FFPSJColor.blue)
                        VStack(alignment: .leading) {
                            Text(user.displayName).font(.headline)
                            Text(user.email).font(.caption).foregroundStyle(FFPSJColor.muted)
                        }
                        Spacer()
                        Text(user.status == .active ? "Activo" : "Inactivo")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(user.status == .active ? FFPSJColor.success : FFPSJColor.danger)
                    }
                    HStack {
                        Picker("Rol", selection: roleBinding(for: user)) {
                            Text("Árbitro").tag(AppRole.referee)
                            Text("Administrador").tag(AppRole.admin)
                        }
                        .pickerStyle(.menu)
                        Spacer()
                        Button(user.status == .active ? "Suspender" : "Habilitar") {
                            Task {
                                await container.updateUser(id: user.id, role: nil, status: user.status == .active ? .inactive : .active)
                                await load()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(user.status == .active ? FFPSJColor.danger : FFPSJColor.success)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .navigationTitle("Usuarios")
        .task { await load() }
        .refreshable { await load() }
    }

    private func roleBinding(for user: AppUser) -> Binding<AppRole> {
        Binding(
            get: { users.first(where: { $0.id == user.id })?.role ?? user.role },
            set: { role in
                Task {
                    await container.updateUser(id: user.id, role: role, status: nil)
                    await load()
                }
            }
        )
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { users = try await container.users() }
        catch { container.presentedError = UserFacingError(error) }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var settings: FederationSettings?
    @State private var federationName = ""
    @State private var seasonName = ""
    @State private var supportEmail = ""

    var body: some View {
        Form {
            Section("Identidad institucional") {
                TextField("Nombre de la Federación", text: $federationName)
                TextField("Temporada activa", text: $seasonName)
                TextField("Correo de soporte", text: $supportEmail)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
            }
            Section {
                Label("El acceso usa Supabase Auth, RLS y auditoría de datos.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(FFPSJColor.muted)
            }
            Section {
                Button("Guardar configuración") { Task { await save() } }
                    .frame(maxWidth: .infinity).foregroundStyle(FFPSJColor.blue)
            }
        }
        .navigationTitle("Sistema")
        .task { await load() }
    }

    private func load() async {
        do {
            settings = try await container.settings()
            federationName = settings?.federationName ?? ""
            seasonName = settings?.seasonName ?? ""
            supportEmail = settings?.supportEmail ?? ""
        } catch { container.presentedError = UserFacingError(error) }
    }

    private func save() async {
        guard supportEmail.contains("@"), federationName.count >= 3, seasonName.count >= 2 else {
            container.presentedError = UserFacingError(title: "Datos no válidos", message: "Completa los datos institucionales y un correo de soporte válido.")
            return
        }
        guard let id = settings?.id else {
            container.presentedError = UserFacingError(title: "Configuración no disponible", message: "No se encontró el registro institucional de Supabase.")
            return
        }
        await container.saveSettings(FederationSettings(id: id, federationName: federationName, seasonName: seasonName, supportEmail: supportEmail))
    }
}
