import Combine
import Foundation
import Messages
import UIKit

/// Holds the current screen and translates committed moves into `MSMessage`
/// payloads. Owns no networking — every turn is a message in the conversation.
/// The seat/roster model supports 2-player and N-player (group) matches.
final class GameController: ObservableObject {
    enum Screen {
        case picker
        case game(MatchEnvelope)
    }

    @Published private(set) var screen: Screen = .picker
    /// Mirrors the host's presentation style so the UI can show a compact card.
    @Published var isCompact: Bool = true

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

    func canAct(in envelope: MatchEnvelope) -> Bool {
        envelope.canAct(localParticipantID)
    }

    /// Seat used to render the local player's perspective, defaulting to seat 0
    /// for spectators so boards still draw.
    func perspectiveSeat(in envelope: MatchEnvelope) -> Int {
        envelope.perspectiveSeat(for: localParticipantID) ?? 0
    }

    func isSeated(in envelope: MatchEnvelope) -> Bool {
        envelope.seatedIndex(of: localParticipantID) != nil
    }

    // MARK: - Actions

    func startGame(_ kind: GameKind, playerCount: Int) {
        let maxPlayers = min(max(playerCount, kind.playerRange.lowerBound), kind.playerRange.upperBound)
        let state: Data
        if kind == .checkers {
            state = Checkers.initialState().jsonData()
        } else {
            state = DuelRegistry.config(for: kind)?.initialState(maxPlayers) ?? Data()
        }
        let envelope = MatchEnvelope(
            kind: kind,
            players: [localParticipantID],
            maxPlayers: maxPlayers,
            turnSeat: 0,
            status: .active,
            winner: "",
            turnNumber: 1,
            state: state
        )
        session = MSSession()
        screen = .game(envelope)
        onRequestExpanded?()
    }

    func rematch(from envelope: MatchEnvelope) {
        startGame(envelope.kind, playerCount: envelope.maxPlayers)
    }

    func backToPicker() {
        screen = .picker
    }

    /// Commits a move produced by a game view and inserts the next message.
    func commit(_ result: MoveResult, in envelope: MatchEnvelope) {
        var next = envelope

        // Seat the local player if they are claiming an open seat.
        let seat: Int
        if let existing = next.seatedIndex(of: localParticipantID) {
            seat = existing
        } else {
            seat = next.players.count
            next.players.append(localParticipantID)
        }
        _ = seat

        next.turnNumber += 1
        next.state = result.state

        if result.finished {
            next.status = .finished
            if let winnerSeat = result.winnerSeat, next.players.indices.contains(winnerSeat) {
                next.winner = next.players[winnerSeat]
            }
        } else {
            next.turnSeat = (next.turnSeat + 1) % next.maxPlayers
        }

        let layout = MSMessageTemplateLayout()
        layout.image = ThumbnailRenderer.image(for: next, caption: result.caption)
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
