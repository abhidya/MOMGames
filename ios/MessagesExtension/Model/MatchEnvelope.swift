import Foundation

/// The full match snapshot that travels inside a single `MSMessage` URL. Every
/// turn replaces the previous snapshot in the same message session, so the
/// bubble updates in place in the Messages thread.
///
/// Player identity comes from `MSConversation` participant identifiers (opaque,
/// per-conversation UUIDs). `players[0]` is the match creator, `players[1]` the
/// opponent; an empty slot means that seat has not made a move yet.
struct MatchEnvelope: Codable, Equatable {
    var kind: GameKind
    var players: [String]
    var lastMover: String
    var status: Status
    var winner: String
    var turnNumber: Int
    /// Game-specific state, JSON-encoded by the owning game type.
    var state: Data

    enum Status: String, Codable {
        case active
        case finished
    }

    static func seats() -> [String] { ["", ""] }

    /// The seat index for a participant, or the first open seat if they have
    /// not been seated yet. Returns `nil` only when the board is full of other
    /// players (should not happen in a 1:1 conversation).
    func seat(for participantID: String) -> Int? {
        if let existing = players.firstIndex(of: participantID) {
            return existing
        }
        return players.firstIndex(of: "")
    }

    func isTurn(of participantID: String) -> Bool {
        status == .active && lastMover != participantID
    }
}
