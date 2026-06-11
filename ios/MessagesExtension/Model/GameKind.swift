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
        case .launch: return "Free-for-all distance run"
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

    /// Supported number of players. Two-player games seat the first two people
    /// who act in a group and treat everyone else as spectators; games whose
    /// range goes above two can fill more seats as people join.
    var playerRange: ClosedRange<Int> {
        switch self {
        case .checkers: return 2...2
        case .archery: return 2...2
        case .artillery: return 2...2
        case .launch: return 2...6
        }
    }

    var supportsGroup: Bool { playerRange.upperBound > 2 }
}
