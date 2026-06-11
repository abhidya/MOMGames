import CoreGraphics
import Foundation

/// Free-for-all distance run with bounce pads. Each seated player takes a fixed
/// number of launches; the highest cumulative distance wins. Ported from
/// `launch_module.gd` and generalized to 2–6 players for group chats.
enum LaunchDuel {
    static let gravity = 9.8
    static let worldWidth = 560.0
    static let minAngle = 15.0
    static let maxAngle = 70.0
    static let minPower = 20.0
    static let maxPower = 72.0
    static let roundsPerPlayer = 3

    struct Zone { var kind: String; var x: Double; var width: Double }

    static let field: [Zone] = [
        Zone(kind: "boost", x: 88, width: 22),
        Zone(kind: "drag", x: 158, width: 18),
        Zone(kind: "boost", x: 230, width: 24),
        Zone(kind: "drag", x: 325, width: 20),
        Zone(kind: "boost", x: 405, width: 26)
    ]

    struct State: Codable {
        var playerCount = 2
        var turnNumber = 1
        var wind = 1.5
        var scores: [Double] = [0, 0]
        var launches: [Launch] = []
    }

    struct Launch: Codable {
        var seat: Int
        var angle: Double
        var power: Double
        var wind: Double
        var distance: Double
        var bounces: Int
    }

    static var config: DuelConfig {
        DuelConfig(
            kind: .launch,
            minAngle: minAngle, maxAngle: maxAngle,
            minPower: minPower, maxPower: maxPower,
            defaultAngle: 38, defaultPower: 52,
            initialState: { count in
                State(playerCount: count, scores: Array(repeating: 0, count: count)).jsonData()
            },
            wind: { $0.decoded(State.self, fallback: State()).wind },
            statusLine: { data in
                let s = data.decoded(State.self, fallback: State())
                let total = s.playerCount * roundsPerPlayer
                let scoreboard = s.scores.enumerated()
                    .map { String(format: "P%d %.0f", $0.offset + 1, $0.element) }
                    .joined(separator: " · ")
                return String(format: "Launch %d/%d • %@ • wind %@",
                              min(s.launches.count + 1, total), total, scoreboard, windText(s.wind))
            },
            history: { data in
                data.decoded(State.self, fallback: State()).launches.suffix(4).map {
                    String(format: "P%d  %.0f° / %.0f  →  %.1f m (%d bounces)",
                           $0.seat + 1, $0.angle, $0.power, $0.distance, $0.bounces)
                }
            },
            scene: { data, _ in scene(data) },
            fire: { data, seat, angle, power in fire(data, seat: seat, angle: angle, power: power) }
        )
    }

    private static func scene(_ data: Data) -> DuelScene {
        var markers: [DuelMarker] = [
            DuelMarker(kind: .me, rect: CGRect(x: 0, y: 0, width: 4, height: 8))
        ]
        for zone in field {
            markers.append(DuelMarker(
                kind: zone.kind == "boost" ? .boost : .drag,
                rect: CGRect(x: zone.x, y: 0, width: zone.width, height: 5)
            ))
        }
        return DuelScene(
            worldWidth: CGFloat(worldWidth),
            worldHeight: 90,
            ground: [CGPoint(x: 0, y: 0), CGPoint(x: worldWidth, y: 0)],
            markers: markers
        )
    }

    private static func fire(_ data: Data, seat: Int, angle: Double, power: Double) -> DuelShot {
        var state = data.decoded(State.self, fallback: State())
        let result = simulate(wind: state.wind, angle: angle, power: power)

        state.launches.append(Launch(seat: seat, angle: round(angle * 10) / 10, power: round(power * 10) / 10,
                                      wind: state.wind, distance: result.distance, bounces: result.bounces))
        while state.scores.count <= seat { state.scores.append(0) }
        state.scores[seat] += result.distance
        state.turnNumber += 1

        let finished = state.launches.count >= state.playerCount * roundsPerPlayer
        let leader = finished ? leaderSeat(state) : nil
        if !finished { state.wind = nextWind(state.turnNumber) }

        let caption = String(format: "Launch traveled %.1f m", result.distance)
        let sub: String
        if finished {
            sub = "P\((leader ?? 0) + 1) wins the run!"
        } else {
            sub = "Next launch • wind \(windText(state.wind))"
        }
        return DuelShot(
            newState: state.jsonData(),
            trajectory: result.path,
            caption: caption,
            subcaption: sub,
            hit: result.bounces > 0,
            finished: finished,
            winnerSeat: leader
        )
    }

    private static func simulate(wind: Double, angle: Double, power: Double)
        -> (distance: Double, bounces: Int, path: [CGPoint]) {
        let radians = angle * .pi / 180
        var vx = cos(radians) * power + wind * 0.35
        var vy = sin(radians) * power
        var x = 0.0
        var y = 10.0
        var distance = 0.0
        var bounces = 0
        let step = 0.12
        var elapsed = 0.0
        var path: [CGPoint] = [CGPoint(x: 0, y: 10)]

        while elapsed < 18, x < worldWidth, abs(vx) > 1 {
            x += vx * step
            vy -= gravity * step
            y += vy * step
            distance = max(distance, x)

            if y <= 0 {
                switch zone(at: x) {
                case "boost":
                    vx *= 1.18
                    vy = abs(vy) * 0.62 + 14
                case "drag":
                    vx *= 0.58
                    vy = abs(vy) * 0.28
                default:
                    vx *= 0.74
                    vy = abs(vy) * 0.46
                }
                bounces += 1
                y = 0
            }
            path.append(CGPoint(x: x, y: max(0, y)))
            elapsed += step
        }
        return (round(min(max(distance, 0), worldWidth) * 10) / 10, bounces, path)
    }

    private static func zone(at x: Double) -> String {
        for zone in field where x >= zone.x && x <= zone.x + zone.width {
            return zone.kind
        }
        return ""
    }

    private static func leaderSeat(_ state: State) -> Int {
        var bestSeat = 0
        var bestScore = -1.0
        for seat in state.scores.indices where state.scores[seat] > bestScore {
            bestScore = state.scores[seat]
            bestSeat = seat
        }
        return bestSeat
    }

    private static func nextWind(_ turn: Int) -> Double {
        let pattern = [1.5, -2.0, 0.0, 3.0, -1.0, 2.5]
        return pattern[turn % pattern.count]
    }
}
