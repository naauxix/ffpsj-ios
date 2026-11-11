import FFPSJDomain
import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable { case summary, matches, teams, users, settings }

    @EnvironmentObject private var container: AppContainer
    @State private var selected: Tab = .summary
    @State private var matchPath: [UUID] = []

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Resumen", systemImage: "rectangle.3.group.fill") }
            .tag(Tab.summary)

            NavigationStack(path: $matchPath) {
                MatchListView()
                    .navigationDestination(for: UUID.self) { id in
                        MatchDetailScreen(matchID: id)
                    }
            }
            .tabItem { Label("Partidos", systemImage: "calendar") }
            .tag(Tab.matches)

            NavigationStack {
                TeamsView()
            }
            .tabItem { Label("Equipos", systemImage: "trophy") }
            .tag(Tab.teams)

            if container.isAdministrator {
                NavigationStack {
                    UsersView()
                }
                .tabItem { Label("Usuarios", systemImage: "person.2") }
                .tag(Tab.users)

                NavigationStack {
                    SettingsView()
                }
                .tabItem { Label("Sistema", systemImage: "gearshape") }
                .tag(Tab.settings)
            }
        }
        .tint(FFPSJColor.blue)
        .onChange(of: container.pendingRoute) { _, route in
            guard let route else { return }
            switch route {
            case let .match(id), let .event(id, _, _), let .finish(id):
                selected = .matches
                matchPath = [id]
            }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var container: AppContainer

    private var scheduled: Int { container.matches.filter { $0.status == .scheduled }.count }
    private var live: Int { container.matches.filter { $0.status == .inProgress }.count }
    private var finished: Int { container.matches.filter { $0.status == .finished }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !container.network.isConnected {
                    OfflineBanner()
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DashboardStat(title: "Programados", value: scheduled, symbol: "calendar", tint: FFPSJColor.blue)
                    DashboardStat(title: "En juego", value: live, symbol: "soccerball", tint: FFPSJColor.warning)
                    DashboardStat(title: "Actas finalizadas", value: finished, symbol: "checklist", tint: FFPSJColor.success)
                    DashboardStat(title: "Total de partidos", value: container.matches.count, symbol: "trophy", tint: .purple)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("Próximos partidos").font(.title3.weight(.bold))
                        Text("Agenda habilitada para tu perfil.").font(.footnote).foregroundStyle(FFPSJColor.muted)
                    }
                    Spacer()
                }
                if container.matches.isEmpty {
                    ContentUnavailableView("Todavía no hay partidos", systemImage: "calendar.badge.exclamationmark", description: Text("Cuando se creen en Supabase aparecerán aquí."))
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ForEach(Array(container.matches.prefix(6))) { match in
                        NavigationLink { MatchDetailScreen(matchID: match.id) } label: { MatchCard(match: match) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Resumen deportivo")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountMenu() } }
        .task { await container.loadMatches() }
        .refreshable { await container.loadMatches() }
        .ffpsjPageBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PANEL PRINCIPAL").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(FFPSJColor.blue)
            Text("Resumen deportivo").font(.largeTitle.weight(.bold))
            Text("Supervisa la actividad y accede a tus próximos compromisos.")
                .foregroundStyle(FFPSJColor.muted)
        }
    }
}

private struct DashboardStat: View {
    let title: String
    let value: Int
    let symbol: String
    let tint: Color

    var body: some View {
        SectionCard {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading) {
                    Text(title).font(.caption).foregroundStyle(FFPSJColor.muted)
                    Text(value, format: .number).font(.title2.weight(.bold))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct OfflineBanner: View {
    var body: some View {
        Label("Sin conexión. Las incidencias pendientes no se consideran oficiales hasta confirmarse.", systemImage: "wifi.slash")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FFPSJColor.warning)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FFPSJColor.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct AccountMenu: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Menu {
            Text(container.currentUser?.displayName ?? "Usuario")
            Button(role: .destructive) { Task { await container.signOut() } } label: {
                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(FFPSJColor.blue)
        }
        .accessibilityLabel("Cuenta")
    }
}
