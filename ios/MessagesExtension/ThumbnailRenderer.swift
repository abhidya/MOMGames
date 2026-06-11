import UIKit

/// Renders a branded card image for the message bubble so a sent turn shows a
/// game-colored thumbnail with its headline instead of a bare text layout.
enum ThumbnailRenderer {
    static func image(for envelope: MatchEnvelope, caption: String) -> UIImage {
        let size = CGSize(width: 600, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)

            // Background gradient.
            let base = tint(for: envelope.kind)
            let colors = [base.cgColor, base.darkened(by: 0.45).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero,
                                      end: CGPoint(x: 0, y: size.height), options: [])
            } else {
                base.setFill()
                cg.fill(bounds)
            }

            // Game symbol, top-right.
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 150, weight: .bold)
            if let symbol = UIImage(systemName: envelope.kind.symbol, withConfiguration: symbolConfig)?
                .withTintColor(.white.withAlphaComponent(0.22), renderingMode: .alwaysOriginal) {
                symbol.draw(at: CGPoint(x: size.width - symbol.size.width - 30, y: 30))
            }

            // Eyebrow.
            draw("MOM GAMES", at: CGPoint(x: 40, y: 40),
                 font: .systemFont(ofSize: 22, weight: .semibold),
                 color: .white.withAlphaComponent(0.7))

            // Title.
            draw(envelope.kind.title, at: CGPoint(x: 40, y: 150),
                 font: .systemFont(ofSize: 52, weight: .heavy), color: .white)

            // Caption (the move headline), wrapped.
            let captionRect = CGRect(x: 40, y: 230, width: size.width - 220, height: 110)
            drawWrapped(caption, in: captionRect,
                        font: .systemFont(ofSize: 30, weight: .medium),
                        color: .white.withAlphaComponent(0.92))

            // Roster chip for multiplayer matches.
            if envelope.maxPlayers > 2 {
                draw("Players \(envelope.players.count)/\(envelope.maxPlayers)",
                     at: CGPoint(x: 40, y: size.height - 50),
                     font: .systemFont(ofSize: 22, weight: .semibold),
                     color: .white.withAlphaComponent(0.7))
            }
        }
    }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func drawWrapped(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }

    private static func tint(for kind: GameKind) -> UIColor {
        switch kind {
        case .checkers: return UIColor(red: 0.86, green: 0.28, blue: 0.30, alpha: 1)
        case .archery: return UIColor(red: 0.20, green: 0.62, blue: 0.42, alpha: 1)
        case .artillery: return UIColor(red: 0.78, green: 0.46, blue: 0.18, alpha: 1)
        case .launch: return UIColor(red: 0.26, green: 0.46, blue: 0.86, alpha: 1)
        }
    }
}

private extension UIColor {
    func darkened(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let f = max(0, 1 - amount)
        return UIColor(red: r * f, green: g * f, blue: b * f, alpha: a)
    }
}
