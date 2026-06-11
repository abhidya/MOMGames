import Foundation

/// The full match snapshot that travels inside a single `MSMessage` URL. Every
/// turn replaces the previous snapshot in the same message session, so the
/// bubble updates in place in the Messages thread.
///
/// Player identity comes from `MSConversation` participant identifiers (opaque,
/// per-conversation UUIDs). `players` is the roster in seat order; it grows as
/// people take their first turn, up to `maxPlayers`. `turnSeat` is the seat
/// expected to act next.
struct MatchEnvelope: Codable, Equatable {
    var kind: GameKind
    var players: [String]
    var maxPlayers: Int
    var turnSeat: Int
    var status: Status
    /// Participant identifier of the winner, or "" while unresolved.
    var winner: String
    var turnNumber: Int
    /// Game-specific state, JSON-encoded by the owning game type.
    var state: Data

    enum Status: String, Codable {
        case active
        case finished
    }

    // MARK: - Seats & turns

    func seatedIndex(of participantID: String) -> Int? {
        players.firstIndex(of: participantID)
    }

    /// `true` when `turnSeat` points at an unfilled seat that a new participant
    /// may claim by acting.
    var isOpenSeat: Bool {
        turnSeat == players.count && players.count < maxPlayers
    }

    /// Whether the given participant may act on this snapshot — either it is
    /// their seated turn, or they can claim the open seat.
    func canAct(_ participantID: String) -> Bool {
        guard status == .active else { return false }
        if turnSeat < players.count {
            return players[turnSeat] == participantID
        }
        return isOpenSeat && !players.contains(participantID)
    }

    /// The seat the participant would occupy if they acted now, or `nil`.
    func actingSeat(for participantID: String) -> Int? {
        guard canAct(participantID) else { return nil }
        return seatedIndex(of: participantID) ?? players.count
    }

    /// The seat used to render a participant's perspective, even when it is not
    /// their turn (their existing seat, or the seat they would claim).
    func perspectiveSeat(for participantID: String) -> Int? {
        if let seated = seatedIndex(of: participantID) { return seated }
        return isOpenSeat ? players.count : nil
    }

    func winnerSeat() -> Int? {
        guard !winner.isEmpty else { return nil }
        return players.firstIndex(of: winner)
    }
}
