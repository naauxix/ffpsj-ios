import FFPSJDomain
import SwiftUI

struct MatchListView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var query = ""
    @State private var selectedStatus: MatchStatus?
    @State private var showNewMatch = false

    private var filtered: [Match] {
        container.matches.filter { match in
            let text = "\(match.homeTeam?.name ?? "") \(match.awayTeam?.name ?? "") \(match.competition)".lowercased()
            return (selectedStatus == nil || match.status == selectedStatus) &&
                (query.isEmpty || text.contains(query.lowercased()))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMPETENCIA").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(FFPSJColor.blue)
                    Text("Partidos").font(.largeTitle.weight(.bold))
                    Text("Agenda, asignaciones y actas de la Federación.").foregroundStyle(FFPSJColor.muted)
                }
                HStack {
                    TextField("Buscar equipo o competencia", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Menu {
                        Button("Todos los estados") { selectedStatus = nil }
                        ForEach(MatchStatus.allCases, id: \.self) { status in
                            Button(status.label) { selectedStatus = status }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .frame(width: 42, height: 38)
                            .background(.background, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
                if let selectedStatus {
                    Button {
                        self.selectedStatus = nil
                    } label: {
                        Label(selectedStatus.label, systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(FFPSJColor.blue)
                }
                if filtered.isEmpty {
                    ContentUnavailableView("No encontramos partidos", systemImage: "magnifyingglass", description: Text("Ajusta la búsqueda o el filtro."))
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { match in
                            NavigationLink(value: match.id) { MatchCard(match: match) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Partidos")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if container.isAdministrator {
                    Button { showNewMatch = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Nuevo partido")
                }
                AccountMenu()
            }
        }
        .sheet(isPresented: $showNewMatch) { AdminMatchEditor(match: nil) }
        .task { await container.loadMatches() }
        .refreshable { await container.loadMatches() }
        .ffpsjPageBackground()
    }
}
