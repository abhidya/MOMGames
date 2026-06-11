import Combine
import Foundation
import Messages

/// Holds the current screen and translates committed moves into `MSMessage`
/// payloads. Owns no networking — every turn is a message in the conversation.
final class GameController: ObservableObject {
    enum Screen {
        case picker
        case game(MatchEnvelope)
    }

    @Published private(set) var screen: Screen = .picker

    /// Called with a ready-to-send message; the view controller inserts it.
    var onSend: ((MSMessage) -> Void)?
    /// Asks the host to grow to the expanded presentation for full gameplay.
    var onRequestExpanded: (() -> Void)?

    private(set) var localParticipantID = ""
    private var session: MSSession?

    // MARK: - Lifecycle

    func update(with conversation: MSConversation) {
        localParticipantID = conversation.localParticipantIdentifier.uuidString
        if let envelope = MatchCoder.decode(conversation.selectedMessage?.url) {
            session = conversation.selectedMessage?.session
            screen = .game(envelope)
        } else {
            session = nil
            screen = .picker
        }
    }

    // MARK: - Player view helpers

    func seat(in envelope: MatchEnvelope) -> Int {
        envelope.seat(for: localParticipantID) ?? 0
    }

    func isMyTurn(in envelope: MatchEnvelope) -> Bool {
        envelope.isTurn(of: localParticipantID)
    }

    // MARK: - Actions

    func startGame(_ kind: GameKind) {
        let state: Data
        if kind == .checkers {
            state = (try? JSONEncoder().encode(Checkers.initialState())) ?? Data()
        } else {
            state = DuelRegistry.config(for: kind)?.initialState() ?? Data()
        }
        var players = MatchEnvelope.seats()
        players[0] = localParticipantID
        let envelope = MatchEnvelope(
            kind: kind,
            players: players,
            lastMover: "",
            status: .active,
            winner: "",
            turnNumber: 1,
            state: state
        )
        session = MSSession()
        screen = .game(envelope)
        onRequestExpanded?()
    }

    func backToPicker() {
        screen = .picker
    }

    /// Commits a move produced by a game view and inserts the next message.
    func commit(_ result: MoveResult, in envelope: MatchEnvelope) {
        var next = envelope
        let seat = next.seat(for: localParticipantID) ?? 0
        if seat < next.players.count { next.players[seat] = localParticipantID }
        next.lastMover = localParticipantID
        next.turnNumber += 1
        next.state = result.state
        if result.finished {
            next.status = .finished
            if result.committerWon {
                next.winner = localParticipantID
            } else {
                let opponentSeat = 1 - seat
                next.winner = next.players.indices.contains(opponentSeat) ? next.players[opponentSeat] : ""
            }
        }

        let layout = MSMessageTemplateLayout()
        layout.caption = result.caption
        if !result.subcaption.isEmpty { layout.subcaption = result.subcaption }
        layout.trailingCaption = envelope.kind.title

        let message = MSMessage(session: session ?? MSSession())
        message.url = MatchCoder.encode(next)
        message.layout = layout
        message.summaryText = "\(envelope.kind.title): \(result.caption)"

        onSend?(message)
        screen = .game(next)
    }
}
