import ActivityKit
import FFPSJDomain
import SwiftUI
import WidgetKit

@main
struct FFPSJActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        FFPSJMatchLiveActivity()
    }
}

struct FFPSJMatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FFPSJMatchAttributes.self) { context in
            LockScreenMatchView(attributes: context.attributes, state: context.state)
                .padding()
                .activityBackgroundTint(Color(hex: "#123B7C"))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(matchURL(context.attributes.matchID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        IslandCrest(shortName: context.attributes.homeShortName, color: context.attributes.homeColor)
                        Text(context.attributes.homeName).lineLimit(1).font(.caption2.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        IslandCrest(shortName: context.attributes.awayShortName, color: context.attributes.awayColor)
                        Text(context.attributes.awayName).lineLimit(1).font(.caption2.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        ScoreView(state: context.state)
                        MatchTimeView(state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedActions(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                IslandCrest(shortName: context.attributes.homeShortName, color: context.attributes.homeColor, size: 20)
            } compactTrailing: {
                Text("\(context.state.homeScore)–\(context.state.awayScore)")
                    .font(.caption.weight(.bold).monospacedDigit())
            } minimal: {
                Text("\(context.state.homeScore)–\(context.state.awayScore)")
                    .font(.caption2.weight(.bold).monospacedDigit())
            }
            .widgetURL(matchURL(context.attributes.matchID))
            .keylineTint(Color(hex: "#1769E0"))
        }
    }

    private func matchURL(_ id: UUID) -> URL {
        URL(string: "ffpsj://matches/\(id.uuidString)")!
    }
}

private struct LockScreenMatchView: View {
    let attributes: FFPSJMatchAttributes
    let state: FFPSJMatchAttributes.ContentState

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                Text(state.status.label.uppercased()).font(.caption2.weight(.heavy))
                Spacer()
                MatchTimeView(state: state)
            }
            HStack {
                TeamLockup(name: attributes.homeName, shortName: attributes.homeShortName, color: attributes.homeColor, trailing: false)
                Spacer(minLength: 10)
                ScoreView(state: state)
                Spacer(minLength: 10)
                TeamLockup(name: attributes.awayName, shortName: attributes.awayShortName, color: attributes.awayColor, trailing: true)
            }
            if state.status == .inProgress {
                ExpandedActions(attributes: attributes, state: state)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct TeamLockup: View {
    let name: String
    let shortName: String
    let color: String
    let trailing: Bool

    var body: some View {
        HStack(spacing: 7) {
            if !trailing { IslandCrest(shortName: shortName, color: color, size: 28) }
            Text(name).lineLimit(2).font(.caption.weight(.semibold)).multilineTextAlignment(trailing ? .trailing : .leading)
            if trailing { IslandCrest(shortName: shortName, color: color, size: 28) }
        }
        .frame(maxWidth: 100, alignment: trailing ? .trailing : .leading)
    }
}

private struct ScoreView: View {
    let state: FFPSJMatchAttributes.ContentState

    var body: some View {
        Text("\(state.homeScore) — \(state.awayScore)")
            .font(.title3.weight(.bold).monospacedDigit())
            .contentTransition(.numericText())
            .accessibilityLabel("Marcador \(state.homeScore) a \(state.awayScore)")
    }
}

private struct MatchTimeView: View {
    let state: FFPSJMatchAttributes.ContentState

    var body: some View {
        if state.status == .inProgress, let startedAt = state.startedAt {
            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                .font(.caption.weight(.medium).monospacedDigit())
        } else {
            Text(state.status.label).font(.caption2.weight(.medium))
        }
    }
}

private struct ExpandedActions: View {
    let attributes: FFPSJMatchAttributes
    let state: FFPSJMatchAttributes.ContentState

    var body: some View {
        if state.status == .inProgress {
            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    eventLink("GOL", type: .goal)
                    eventLink("AMARILLA", type: .yellowCard)
                    eventLink("ROJA", type: .redCard)
                    eventLink("CAMBIO", type: .substitution)
                }
                Link(destination: FFPSJDeepLink.finishURL(matchID: attributes.matchID)) {
                    Label("FINALIZAR PARTIDO", systemImage: "flag.checkered")
                        .font(.caption.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.25), in: Capsule())
                }
            }
        } else {
            Text(state.status == .finished ? "Resultado final confirmado" : state.status.label)
                .font(.caption.weight(.semibold))
        }
    }

    private func eventLink(_ label: String, type: MatchEventType) -> some View {
        Link(destination: FFPSJDeepLink.eventURL(matchID: attributes.matchID, type: type)) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(.white.opacity(0.15), in: Capsule())
        }
    }
}

private struct IslandCrest: View {
    let shortName: String
    let color: String
    var size: CGFloat = 25

    var body: some View {
        Text(String(shortName.prefix(2)).uppercased())
            .font(.system(size: size * 0.35, weight: .black, design: .rounded))
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: color), in: RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}
