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
    /// Winning seat index when `finished`, or `nil` for a draw / non-terminal
    /// move. The controller maps the seat to a participant identifier.
    var winnerSeat: Int?
}
