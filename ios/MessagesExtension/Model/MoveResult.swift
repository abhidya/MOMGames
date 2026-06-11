import Foundation

/// The product of a player committing a move in a game view. The controller
/// wraps this into the next `MatchEnvelope` and inserts it as an `MSMessage`.
struct MoveResult {
    /// New game-specific state, JSON-encoded by the game type.
    var state: Data
    /// Short headline shown as the message caption.
    var caption: String
    /// Secondary line shown under the caption.
    var subcaption: String
    /// `true` when this move ends the match.
    var finished: Bool
    /// `true` when the committing player won. Only meaningful if `finished`.
    var committerWon: Bool
}
