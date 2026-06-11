import Foundation

/// The catalog of games shipped in the extension. The raw value is the stable
/// identifier persisted inside the message payload, so do not rename cases
/// without a migration.
enum GameKind: String, Codable, CaseIterable, Identifiable {
    case checkers
    case archery
    case artillery
    case launch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checkers: return "Checkers"
        case .archery: return "Archery Duel"
        case .artillery: return "Artillery Duel"
        case .launch: return "Launch Duel"
        }
    }

    var tagline: String {
        switch self {
        case .checkers: return "Classic diagonal tactics"
        case .archery: return "Aim, power, and one clean shot"
        case .artillery: return "Wind, terrain, and turn-based arcs"
        case .launch: return "Angle, bounce pads, and distance runs"
        }
    }

    var symbol: String {
        switch self {
        case .checkers: return "circle.grid.3x3.fill"
        case .archery: return "target"
        case .artillery: return "burst.fill"
        case .launch: return "paperplane.fill"
        }
    }

    /// Games where players accumulate over several rounds use a different turn
    /// banner than first-to-finish games.
    var isDuel: Bool { self != .checkers }
}
