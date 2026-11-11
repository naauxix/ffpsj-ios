import FFPSJDomain
import Foundation
import UIKit

enum ActaPDFExporter {
    static func export(match: Match) throws -> URL {
        let fileName = "Acta-\(safeName(match.homeTeam?.shortName ?? "LOCAL"))-\(safeName(match.awayTeam?.shortName ?? "VISITANTE")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let blue = UIColor(red: 23 / 255, green: 105 / 255, blue: 224 / 255, alpha: 1)
            blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: page.width, height: 88))
            write("FFPSJ · ACTA OFICIAL DE PARTIDO", at: CGPoint(x: 42, y: 39), font: .boldSystemFont(ofSize: 18), color: .white)
            write("Generada el \(Date().ffpsjLongDate)", at: CGPoint(x: 42, y: 64), font: .systemFont(ofSize: 9), color: .white)

            var y: CGFloat = 120
            write(match.competition, at: CGPoint(x: 42, y: y), font: .boldSystemFont(ofSize: 16), color: .darkText)
            y += 22
            write("\(match.scheduledAt.date?.ffpsjLongDate ?? "Sin fecha") · \(match.venue)", at: CGPoint(x: 42, y: y), font: .systemFont(ofSize: 10), color: .darkGray)
            y += 37
            write(match.homeTeam?.name ?? "Local", at: CGPoint(x: 42, y: y), font: .boldSystemFont(ofSize: 13), color: .darkText)
            write(match.awayTeam?.name ?? "Visitante", at: CGPoint(x: 553, y: y), font: .boldSystemFont(ofSize: 13), color: .darkText, alignment: .right)
            y += 26
            write(match.scoreText, at: CGPoint(x: 297, y: y), font: .boldSystemFont(ofSize: 23), color: .darkText, alignment: .center)
            y += 36
            write("Árbitro responsable: \(match.referee?.fullName ?? "Sin asignar")", at: CGPoint(x: 42, y: y), font: .systemFont(ofSize: 10), color: .darkGray)
            y += 35
            write("Cronología de eventos", at: CGPoint(x: 42, y: y), font: .boldSystemFont(ofSize: 13), color: .darkText)
            y += 20

            let events = (match.events ?? []).sorted { $0.minute < $1.minute }
            if events.isEmpty {
                write("Sin eventos registrados.", at: CGPoint(x: 42, y: y), font: .systemFont(ofSize: 10), color: .darkGray)
                y += 18
            }
            for event in events {
                if y > 785 {
                    context.beginPage()
                    y = 45
                }
                let player = event.player?.fullName ?? "Evento de equipo"
                let replacement = event.replacementPlayer.map { " → \($0.fullName)" } ?? ""
                let detail = event.description.map { " — \($0)" } ?? ""
                write("\(event.minute)' P\(event.period)  \(event.type.label) · \(player)\(replacement)\(detail)", at: CGPoint(x: 42, y: y), font: .systemFont(ofSize: 10), color: .darkText)
                y += 18
            }
            if let observations = match.observations, !observations.isEmpty {
                y += 12
                if y > 760 { context.beginPage(); y = 45 }
                write("Observaciones", at: CGPoint(x: 42, y: y), font: .boldSystemFont(ofSize: 13), color: .darkText)
                y += 18
                writeMultiline(observations, at: CGPoint(x: 42, y: y), width: 510, font: .systemFont(ofSize: 10), color: .darkGray)
            }
        }
        return url
    }

    private static func write(_ text: String, at point: CGPoint, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        (text as NSString).draw(
            in: CGRect(x: point.x, y: point.y, width: 511, height: 24),
            withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
    }

    private static func writeMultiline(_ text: String, at point: CGPoint, width: CGFloat, font: UIFont, color: UIColor) {
        (text as NSString).draw(
            in: CGRect(x: point.x, y: point.y, width: width, height: 180),
            withAttributes: [.font: font, .foregroundColor: color]
        )
    }

    private static func safeName(_ string: String) -> String {
        string.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
    }
}
