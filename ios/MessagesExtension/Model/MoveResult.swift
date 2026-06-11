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
    /// Explicit next active seat. When `nil`, the controller round-robins
    /// `(turnSeat + 1) % maxPlayers` (simple games). Games with response
    /// windows or lobbies (Karachi Coup) set this directly.
    var nextTurnSeat: Int?

    init(state: Data, caption: String, subcaption: String, finished: Bool,
         winnerSeat: Int?, nextTurnSeat: Int? = nil) {
        self.state = state
        self.caption = caption
        self.subcaption = subcaption
        self.finished = finished
        self.winnerSeat = winnerSeat
        self.nextTurnSeat = nextTurnSeat
    }
}
