import CoreGraphics
import Foundation

/// Turn-based tank artillery. First direct hit wins. Ported from
/// `artillery_module.gd`. Terrain is deterministic, so only crater centers are
/// stored in the payload and the height field is recomputed on both devices.
enum ArtilleryDuel {
    static let worldWidth = 320.0
    static let gravity = 9.8
    static let minAngle = 20.0
    static let maxAngle = 80.0
    static let minPower = 28.0
    static let maxPower = 72.0
    static let blastRadius = 13.0
    static let step = 0.08

    struct State: Codable {
        var turnNumber = 1
        var wind = -2.0
        var craters: [Double] = []
        var shots: [Shot] = []
    }

    struct Shot: Codable {
        var seat: Int
        var angle: Double
        var power: Double
        var wind: Double
        var impactX: Double
        var impactY: Double
        var hit: Bool
    }

    static func tankX(_ seat: Int) -> Double { seat == 0 ? 36 : 284 }
    static func direction(_ seat: Int) -> Double { seat == 0 ? 1 : -1 }

    static var config: DuelConfig {
        DuelConfig(
            kind: .artillery,
            minAngle: minAngle, maxAngle: maxAngle,
            minPower: minPower, maxPower: maxPower,
            defaultAngle: 50, defaultPower: 50,
            initialState: { State().jsonData() },
            wind: { $0.decoded(State.self, fallback: State()).wind },
            statusLine: { data in
                let s = data.decoded(State.self, fallback: State())
                return "Wind \(windText(s.wind)) • blast \(Int(blastRadius)) m"
            },
            history: { data in
                data.decoded(State.self, fallback: State()).shots.suffix(4).map {
                    String(format: "P%d  %.0f° / %.0f  →  impact %.0f, %.0f%@",
                           $0.seat + 1, $0.angle, $0.power, $0.impactX, $0.impactY, $0.hit ? "  HIT" : "")
                }
            },
            scene: { data, seat in scene(data, seat: seat) },
            fire: { data, seat, angle, power in fire(data, seat: seat, angle: angle, power: power) }
        )
    }

    private static func scene(_ data: Data, seat: Int) -> DuelScene {
        let state = data.decoded(State.self, fallback: State())
        let terrain = terrain(craters: state.craters)
        var ground: [CGPoint] = []
        var x = 0
        while x <= Int(worldWidth) {
            ground.append(CGPoint(x: CGFloat(x), y: CGFloat(terrain[x])))
            x += 4
        }
        let opponent = 1 - seat
        let markers = [
            DuelMarker(kind: .me, rect: CGRect(x: tankX(seat) - 4, y: terrainAt(terrain, tankX(seat)),
                                               width: 8, height: 6)),
            DuelMarker(kind: .opponent, rect: CGRect(x: tankX(opponent) - 4, y: terrainAt(terrain, tankX(opponent)),
                                                     width: 8, height: 6))
        ]
        return DuelScene(worldWidth: CGFloat(worldWidth), worldHeight: 140, ground: ground, markers: markers)
    }

    private static func fire(_ data: Data, seat: Int, angle: Double, power: Double) -> DuelShot {
        var state = data.decoded(State.self, fallback: State())
        let terrain = terrain(craters: state.craters)
        let result = simulate(terrain: terrain, seat: seat, angle: angle, power: power, wind: state.wind)

        let opponent = 1 - seat
        let ox = tankX(opponent)
        let oy = terrainAt(terrain, ox)
        let dx = result.impact.x - ox
        let dy = result.impact.y - oy
        let hit = (dx * dx + dy * dy).squareRoot() <= blastRadius

        state.shots.append(Shot(seat: seat, angle: round(angle * 10) / 10, power: round(power * 10) / 10,
                                wind: state.wind, impactX: round(result.impact.x * 10) / 10,
                                impactY: round(result.impact.y * 10) / 10, hit: hit))
        state.turnNumber += 1
        if hit == false {
            applyCrater(&state, x: result.impact.x)
            state.wind = nextWind(state.turnNumber)
        }

        let caption = hit ? "Direct hit!" : String(format: "Impact at %.0f m", result.impact.x)
        return DuelShot(
            newState: state.jsonData(),
            trajectory: result.path,
            caption: caption,
            subcaption: hit ? "" : "Opponent returns fire • wind \(windText(state.wind))",
            hit: hit,
            finished: hit,
            committerWon: hit
        )
    }

    private static func simulate(terrain: [Double], seat: Int, angle: Double, power: Double, wind: Double)
        -> (impact: CGPoint, path: [CGPoint]) {
        let originX = tankX(seat)
        let originY = terrainAt(terrain, originX) + 6
        let radians = angle * .pi / 180
        let vx = cos(radians) * power * direction(seat)
        let vy = sin(radians) * power

        var path: [CGPoint] = []
        var t = 0.0
        var x = originX
        var y = originY
        while t <= 12 {
            x = originX + vx * t + 0.5 * wind * t * t
            y = originY + vy * t - 0.5 * gravity * t * t
            path.append(CGPoint(x: x, y: max(0, y)))
            if x < 0 || x > worldWidth {
                return (CGPoint(x: min(max(x, 0), worldWidth), y: max(0, y)), path)
            }
            if y <= terrainAt(terrain, x) {
                let groundY = terrainAt(terrain, x)
                return (CGPoint(x: round(x * 10) / 10, y: round(groundY * 10) / 10), path)
            }
            t += step
        }
        return (CGPoint(x: round(x * 10) / 10, y: round(y * 10) / 10), path)
    }

    private static func applyCrater(_ state: inout State, x: Double) {
        state.craters.append(min(max(x, 0), worldWidth - 1))
    }

    static func baseTerrain() -> [Double] {
        var terrain: [Double] = []
        for i in 0...Int(worldWidth) {
            let x = Double(i)
            let height = 82 + 12 * sin(x / 37) + 6 * sin(x / 13)
            terrain.append(round(height * 10) / 10)
        }
        return terrain
    }

    static func terrain(craters: [Double]) -> [Double] {
        var terrain = baseTerrain()
        for craterX in craters {
            let center = Int(round(min(max(craterX, 0), worldWidth - 1)))
            for offset in -10...10 {
                let index = center + offset
                guard index >= 0, index < terrain.count else { continue }
                let depth = max(0, 9 - abs(Double(offset)))
                terrain[index] = max(24, terrain[index] - depth)
            }
        }
        return terrain
    }

    static func terrainAt(_ terrain: [Double], _ x: Double) -> Double {
        guard !terrain.isEmpty else { return 80 }
        let index = Int(round(min(max(x, 0), Double(terrain.count - 1))))
        return terrain[index]
    }

    private static func nextWind(_ turn: Int) -> Double {
        let pattern = [-2.0, 3.0, 0.0, -4.0, 2.0, 1.0]
        return pattern[turn % pattern.count]
    }

    private static func windText(_ wind: Double) -> String {
        wind == 0 ? "calm" : String(format: "%+.1f", wind)
    }
}
