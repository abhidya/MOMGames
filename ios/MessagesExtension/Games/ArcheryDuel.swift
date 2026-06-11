import CoreGraphics
import Foundation

/// First archer to land inside the target ring wins. Ported from
/// `archery_module.gd`.
enum ArcheryDuel {
    static let gravity = 9.8
    static let minAngle = 15.0
    static let maxAngle = 75.0
    static let minPower = 18.0
    static let maxPower = 42.0
    static let targetDistance = 98.0
    static let hitRadius = 6.0

    struct State: Codable {
        var turnNumber = 1
        var wind = 0.0
        var shots: [Shot] = []
    }

    struct Shot: Codable {
        var seat: Int
        var angle: Double
        var power: Double
        var wind: Double
        var distance: Double
        var miss: Double
        var hit: Bool
    }

    static var config: DuelConfig {
        DuelConfig(
            kind: .archery,
            minAngle: minAngle, maxAngle: maxAngle,
            minPower: minPower, maxPower: maxPower,
            defaultAngle: 45, defaultPower: 30,
            initialState: { State().jsonData() },
            wind: { $0.decoded(State.self, fallback: State()).wind },
            statusLine: { data in
                let s = data.decoded(State.self, fallback: State())
                return String(format: "Target %.0f m • ring ±%.0f m • wind %@",
                              targetDistance, hitRadius, windText(s.wind))
            },
            history: { data in
                data.decoded(State.self, fallback: State()).shots.suffix(4).map {
                    String(format: "P%d  %.0f° / %.0f  →  %.1f m (miss %+.1f)",
                           $0.seat + 1, $0.angle, $0.power, $0.distance, $0.miss)
                }
            },
            scene: { _, _ in scene() },
            fire: { data, seat, angle, power in fire(data, seat: seat, angle: angle, power: power) }
        )
    }

    private static func scene() -> DuelScene {
        let width: CGFloat = 120
        let height: CGFloat = 60
        return DuelScene(
            worldWidth: width,
            worldHeight: height,
            ground: [CGPoint(x: 0, y: 0), CGPoint(x: width, y: 0)],
            markers: [
                DuelMarker(kind: .me, rect: CGRect(x: 0, y: 0, width: 3, height: 6)),
                DuelMarker(kind: .target, rect: CGRect(x: targetDistance - hitRadius, y: 0,
                                                       width: hitRadius * 2, height: 10))
            ]
        )
    }

    private static func fire(_ data: Data, seat: Int, angle: Double, power: Double) -> DuelShot {
        var state = data.decoded(State.self, fallback: State())
        let wind = state.wind
        let distance = shotDistance(angle: angle, power: power, wind: wind)
        let miss = distance - targetDistance
        let hit = abs(miss) <= hitRadius

        let shot = Shot(seat: seat, angle: round(angle * 10) / 10, power: round(power * 10) / 10,
                        wind: wind, distance: round(distance * 10) / 10,
                        miss: round(miss * 10) / 10, hit: hit)
        state.shots.append(shot)
        state.turnNumber += 1
        if !hit { state.wind = nextWind(state.turnNumber) }

        let caption = hit
            ? "Bullseye at \(Int(targetDistance)) m!"
            : String(format: "Landed %.1f m (%@ %.1f m)", distance, miss > 0 ? "long" : "short", abs(miss))
        return DuelShot(
            newState: state.jsonData(),
            trajectory: trajectory(distance: distance),
            caption: caption,
            subcaption: hit ? "" : "Your opponent shoots into wind \(windText(state.wind))",
            hit: hit,
            finished: hit,
            committerWon: hit
        )
    }

    static func shotDistance(angle: Double, power: Double, wind: Double) -> Double {
        let radians = angle * .pi / 180
        let base = (power * power * sin(2 * radians)) / gravity
        return max(0, base + wind * 4)
    }

    private static func trajectory(distance: Double) -> [CGPoint] {
        guard distance > 0 else { return [] }
        let apex = distance / 4
        var points: [CGPoint] = []
        let steps = 24
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = distance * t
            let y = 4 * apex * t * (1 - t)
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    private static func nextWind(_ turn: Int) -> Double {
        let pattern = [-2.0, 1.5, 0.0, 2.5, -1.0, 3.0]
        return pattern[turn % pattern.count]
    }

    private static func windText(_ wind: Double) -> String {
        wind == 0 ? "calm" : String(format: "%+.1f", wind)
    }
}
