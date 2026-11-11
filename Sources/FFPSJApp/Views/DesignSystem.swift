import FFPSJDomain
import SwiftUI

enum FFPSJColor {
    static let blue = Color(hex: "#1769E0")
    static let navy = Color(hex: "#123B7C")
    static let ink = Color(hex: "#192434")
    static let muted = Color(hex: "#68778C")
    static let background = Color(hex: "#F5F7FB")
    static let border = Color(hex: "#E3EAF2")
    static let success = Color(hex: "#058165")
    static let warning = Color(hex: "#BD7B00")
    static let danger = Color(hex: "#C03341")
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}

struct BrandMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            Text("F")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 31, height: 31)
                .background(FFPSJColor.blue, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            if !compact {
                Text("FFPSJ ")
                    .font(.headline.weight(.heavy))
                + Text("Actas")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(FFPSJColor.blue)
            }
        }
        .foregroundStyle(FFPSJColor.ink)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FFPSJ Actas")
    }
}

struct MatchStatusPill: View {
    let status: MatchStatus

    private var tint: Color {
        switch status {
        case .scheduled: FFPSJColor.blue
        case .inProgress: FFPSJColor.warning
        case .finished: FFPSJColor.success
        case .cancelled: FFPSJColor.danger
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.11), in: Capsule())
    }
}

struct TeamCrest: View {
    let team: Team?
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let logo = team?.logoURL, let url = URL(string: logo) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit().padding(3)
                } placeholder: {
                    monogram
                }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .background(Color(hex: team?.color ?? "#1769E0"), in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(.white.opacity(0.65), lineWidth: 1))
        .accessibilityLabel(team?.name ?? "Equipo pendiente")
    }

    private var monogram: some View {
        Text(String((team?.shortName ?? team?.name ?? "FF").prefix(2)).uppercased())
            .font(.system(size: size * 0.27, weight: .black, design: .rounded))
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(FFPSJColor.border, lineWidth: 1))
    }
}

struct MatchCard: View {
    let match: Match

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    MatchStatusPill(status: match.status)
                    Spacer()
                    Label(match.scheduledAt.date?.ffpsjShortDate ?? "Sin fecha", systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(FFPSJColor.muted)
                }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.homeTeam?.shortName ?? match.homeTeam?.name ?? "Local")
                            .lineLimit(1)
                        Text(match.awayTeam?.shortName ?? match.awayTeam?.name ?? "Visitante")
                            .lineLimit(1)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(match.scoreText)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(FFPSJColor.ink)
                    VStack(spacing: 4) {
                        TeamCrest(team: match.homeTeam, size: 24)
                        TeamCrest(team: match.awayTeam, size: 24)
                    }
                }
                Label(match.venue, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(FFPSJColor.muted)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(match.homeTeam?.name ?? "Local") \(match.homeScore), \(match.awayScore) \(match.awayTeam?.name ?? "Visitante"), \(match.status.label)")
    }
}

extension Date {
    var ffpsjShortDate: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(Locale(identifier: "es_ES")))
    }

    var ffpsjLongDate: String {
        formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "es_ES")))
    }
}

extension View {
    func ffpsjPageBackground() -> some View {
        background(FFPSJColor.background.ignoresSafeArea())
    }
}
