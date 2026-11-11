import FFPSJDomain
import Foundation
import SwiftUI

struct MatchDetailScreen: View {
    let matchID: UUID
    @EnvironmentObject private var container: AppContainer
    @State private var match: Match?
    @State private var isLoading = true
    @State private var eventRequest: EventRequest?
    @State private var showFinishConfirmation = false
    @State private var showLineups = false
    @State private var showObservations = false
    @State private var showEditMatch = false
    @State private var observeTask: Task<Void, Never>?
    @State private var pdfURL: URL?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando acta oficial…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let match {
                ScrollView {
                    VStack(spacing: 16) {
                        hero(match)
                        if !container.network.isConnected { OfflineBanner() }
                        actions(match)
                        chronology(match)
                        lineups(match)
                        observations(match)
                    }
                    .padding(16)
                }
                .confirmationDialog(
                    "¿Finalizar el partido?",
                    isPresented: $showFinishConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Finalizar partido", role: .destructive) { Task { await container.finish(match: match); await reload() } }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("El resultado y el acta se cerrarán oficialmente tras la confirmación de Supabase.")
                }
                .sheet(item: $eventRequest) { request in
                    EventFormSheet(match: match, request: request) { await reload() }
                }
                .sheet(isPresented: $showLineups) {
                    LineupEditorSheet(match: match) { await reload() }
                }
                .sheet(isPresented: $showObservations) {
                    ObservationsSheet(match: match) { await reload() }
                }
            } else {
                ContentUnavailableView("Partido no disponible", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Acta del partido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if container.isAdministrator, let match {
                    Button { showEditMatch = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("Editar partido")
                }
                AccountMenu()
            }
        }
        .sheet(isPresented: $showEditMatch) {
            if let match { AdminMatchEditor(match: match) }
        }
        .task { await load() }
        .onAppear { observeTask = container.observe(matchID: matchID) }
        .onDisappear { observeTask?.cancel() }
        .ffpsjPageBackground()
    }

    private func hero(_ match: Match) -> some View {
        VStack(spacing: 14) {
            HStack {
                MatchStatusPill(status: match.status)
                    .background(.white, in: Capsule())
                Spacer()
                Label(match.scheduledAt.date?.ffpsjShortDate ?? "Sin fecha", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Text([match.competition, match.round].compactMap { $0 }.joined(separator: " · "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .center, spacing: 10) {
                VStack(spacing: 7) {
                    TeamCrest(team: match.homeTeam, size: 52)
                    Text(match.homeTeam?.name ?? "Local").font(.headline).multilineTextAlignment(.center).lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text(match.scoreText).font(.system(size: 29, weight: .bold, design: .rounded).monospacedDigit())
                    Text(match.venue).font(.caption2).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
                }
                .frame(minWidth: 86)
                VStack(spacing: 7) {
                    TeamCrest(team: match.awayTeam, size: 52)
                    Text(match.awayTeam?.name ?? "Visitante").font(.headline).multilineTextAlignment(.center).lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }
            if match.status == .inProgress, let startedAt = match.startedAt?.date {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Label("En juego · \(elapsedText(startedAt: startedAt, now: context.date))", systemImage: "timer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            Text(match.referee.map { "Árbitro asignado: \($0.fullName)" } ?? "Árbitro aún no asignado")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(
            LinearGradient(colors: [FFPSJColor.navy, FFPSJColor.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    @ViewBuilder
    private func actions(_ match: Match) -> some View {
        VStack(spacing: 10) {
            HStack {
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Compartir PDF", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        do { pdfURL = try ActaPDFExporter.export(match: match) }
                        catch { container.presentedError = UserFacingError(error) }
                    } label: {
                        Label("Descargar PDF", systemImage: "arrow.down.doc")
                    }
                }
                Spacer()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FFPSJColor.blue)
            if canManage(match), match.status == .scheduled {
                Button {
                    Task { await container.start(match: match); await reload() }
                } label: {
                    Label("INICIAR PARTIDO", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.heavy))
                }
                .buttonStyle(.borderedProminent)
                .tint(FFPSJColor.blue)
                .controlSize(.large)
                .accessibilityHint("Confirma el inicio oficial en Supabase antes de activar la Live Activity.")
            }
            if canManage(match), match.status == .inProgress {
                HStack(spacing: 8) {
                    Button {
                        eventRequest = EventRequest(type: .goal, teamID: nil)
                    } label: {
                        Label("Registrar evento", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FFPSJColor.blue)
                    Button(role: .destructive) {
                        showFinishConfirmation = true
                    } label: {
                        Label("Finalizar", systemImage: "flag.checkered")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }
            if canManage(match) {
                HStack {
                    Button { showLineups = true } label: { Label("Alineaciones", systemImage: "person.3") }
                    Spacer()
                    Button { showObservations = true } label: { Label("Observaciones", systemImage: "note.text") }
                    Spacer()
                    Button { Task { await container.retryLiveActivity(for: match) } } label: { Image(systemName: "rectangle.inset.filled") }
                        .accessibilityLabel("Reintentar Live Activity")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FFPSJColor.blue)
                .padding(.horizontal, 4)
            }
        }
    }

    private func chronology(_ match: Match) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACTA DIGITAL").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(FFPSJColor.blue)
                        Text("Cronología").font(.title3.weight(.bold))
                    }
                    Spacer()
                    if canManage(match), match.status == .inProgress {
                        Button { eventRequest = EventRequest(type: .goal, teamID: nil) } label: {
                            Image(systemName: "plus").font(.headline)
                        }
                        .accessibilityLabel("Registrar evento")
                    }
                }
                let events = (match.events ?? []).sorted {
                    $0.minute == $1.minute
                        ? ($0.createdAt?.date ?? .distantPast) < ($1.createdAt?.date ?? .distantPast)
                        : $0.minute < $1.minute
                }
                if events.isEmpty {
                    ContentUnavailableView("Aún no hay eventos", systemImage: "list.bullet.clipboard", description: Text("El acta registrará aquí los sucesos confirmados."))
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    ForEach(events) { event in
                        EventRow(event: event, canDelete: canManage(match)) {
                            Task { await container.deleteEvent(id: event.id, from: match); await reload() }
                        }
                    }
                }
            }
        }
    }

    private func lineups(_ match: Match) -> some View {
        VStack(spacing: 12) {
            LineupCard(team: match.homeTeam, lines: match.matchPlayers ?? [])
            LineupCard(team: match.awayTeam, lines: match.matchPlayers ?? [])
        }
    }

    private func observations(_ match: Match) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 7) {
                Text("Observaciones").font(.headline)
                Text(match.observations?.isEmpty == false ? match.observations! : "Sin observaciones registradas.")
                    .font(.subheadline)
                    .foregroundStyle(FFPSJColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func canManage(_ match: Match) -> Bool {
        container.currentUser?.role == .admin || container.currentUser?.id == match.assignedRefereeID
    }

    private func elapsedText(startedAt: Date, now: Date) -> String {
        let seconds = Int(MatchClock.elapsedSeconds(startedAt: startedAt, now: now) ?? 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            match = try await container.match(id: matchID)
            processPendingRoute()
        } catch {
            container.presentedError = UserFacingError(error)
        }
    }

    private func reload() async {
        do {
            match = try await container.match(id: matchID)
            pdfURL = nil
        }
        catch { container.presentedError = UserFacingError(error) }
    }

    private func processPendingRoute() {
        guard let route = container.pendingRoute else { return }
        switch route {
        case let .event(id, type, teamID) where id == matchID:
            eventRequest = EventRequest(type: type, teamID: teamID)
            container.pendingRoute = nil
        case let .finish(id) where id == matchID:
            showFinishConfirmation = true
            container.pendingRoute = nil
        case let .match(id) where id == matchID:
            container.pendingRoute = nil
        default:
            break
        }
    }
}

struct EventRequest: Identifiable {
    let id = UUID()
    let type: MatchEventType
    let teamID: UUID?
}

private struct EventRow: View {
    let event: MatchEvent
    let canDelete: Bool
    let delete: () -> Void
    @State private var showDelete = false

    private var icon: String {
        switch event.type {
        case .goal: "soccerball"
        case .yellowCard: "rectangle.fill"
        case .redCard: "rectangle.fill"
        case .substitution: "arrow.left.arrow.right"
        case .note: "note.text"
        }
    }

    private var tint: Color {
        switch event.type {
        case .goal: FFPSJColor.blue
        case .yellowCard: FFPSJColor.warning
        case .redCard: FFPSJColor.danger
        case .substitution, .note: FFPSJColor.muted
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(event.type == .redCard ? .white : tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(event.type == .redCard ? 1 : 0.12), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.type.label).font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(event.minute)' · P\(event.period)").font(.caption.weight(.bold)).foregroundStyle(FFPSJColor.muted)
                }
                Text(eventDescription)
                    .font(.footnote)
                    .foregroundStyle(FFPSJColor.muted)
            }
            if canDelete {
                Button(role: .destructive) { showDelete = true } label: {
                    Image(systemName: "trash").font(.footnote)
                }
                .confirmationDialog("¿Eliminar esta incidencia?", isPresented: $showDelete, titleVisibility: .visible) {
                    Button("Eliminar", role: .destructive, action: delete)
                    Button("Cancelar", role: .cancel) {}
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var eventDescription: String {
        if event.type == .substitution {
            let out = event.player?.fullName ?? "Jugador que sale"
            let incoming = event.replacementPlayer?.fullName ?? "Jugador que entra"
            return "\(out) → \(incoming)\(event.description.map { " · \($0)" } ?? "")"
        }
        return "\(event.player?.fullName ?? "Evento de equipo")\(event.description.map { " · \($0)" } ?? "")"
    }
}

private struct LineupCard: View {
    let team: Team?
    let lines: [MatchPlayer]

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    TeamCrest(team: team, size: 30)
                    Text(team?.name ?? "Equipo").font(.headline)
                }
                let players = lines.filter { $0.teamID == team?.id }.sorted {
                    $0.starter != $1.starter ? $0.starter && !$1.starter : $0.shirtNumber < $1.shirtNumber
                }
                if players.isEmpty {
                    Text("Sin alineación cargada.").font(.footnote).foregroundStyle(FFPSJColor.muted)
                } else {
                    ForEach(players) { line in
                        HStack(spacing: 9) {
                            Text("\(line.shirtNumber)").font(.caption.weight(.bold)).frame(width: 25, height: 25).background(FFPSJColor.background, in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading) {
                                Text(line.player?.fullName ?? "Jugador").font(.subheadline)
                                Text("\(line.position ?? "Jugador")\(line.starter ? " · Titular" : "")").font(.caption2).foregroundStyle(FFPSJColor.muted)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
