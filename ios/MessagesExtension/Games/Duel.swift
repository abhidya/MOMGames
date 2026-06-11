import CoreGraphics
import Foundation

/// A marker drawn on the duel scene (target, tanks, bounce pads).
struct DuelMarker {
    enum Kind { case target, me, opponent, boost, drag, landing }
    var kind: Kind
    /// World-space rect (x grows right, y grows up).
    var rect: CGRect
}

/// Static geometry for rendering a duel, in world coordinates.
struct DuelScene {
    var worldWidth: CGFloat
    var worldHeight: CGFloat
    /// Ground profile, left to right. A flat duel uses two points.
    var ground: [CGPoint]
    var markers: [DuelMarker]
}

/// The result of simulating a shot. Produced for preview before committing and
/// reused as the committed state.
struct DuelShot {
    var newState: Data
    /// Trajectory in world coordinates for animation/drawing.
    var trajectory: [CGPoint]
    var caption: String
    var subcaption: String
    var hit: Bool
    var finished: Bool
    var committerWon: Bool
}

/// Closure-based description of a projectile duel, so a single SwiftUI view can
/// drive archery, artillery, and launch without generics.
struct DuelConfig {
    var kind: GameKind
    var minAngle: Double
    var maxAngle: Double
    var minPower: Double
    var maxPower: Double
    var defaultAngle: Double
    var defaultPower: Double

    var initialState: () -> Data
    var wind: (Data) -> Double
    var statusLine: (Data) -> String
    var history: (Data) -> [String]
    var scene: (_ state: Data, _ seat: Int) -> DuelScene
    var fire: (_ state: Data, _ seat: Int, _ angle: Double, _ power: Double) -> DuelShot
}

enum DuelRegistry {
    static func config(for kind: GameKind) -> DuelConfig? {
        switch kind {
        case .archery: return ArcheryDuel.config
        case .artillery: return ArtilleryDuel.config
        case .launch: return LaunchDuel.config
        case .checkers: return nil
        }
    }
}

/// Small JSON helpers shared by the duel state types.
extension Encodable {
    func jsonData() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
}

extension Data {
    func decoded<T: Decodable>(_ type: T.Type, fallback: T) -> T {
        (try? JSONDecoder().decode(T.self, from: self)) ?? fallback
    }
}
