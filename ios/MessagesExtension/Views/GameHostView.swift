import SwiftUI

/// Wraps a single game with the turn banner and routes to the right board.
struct GameHostView: View {
    @ObservedObject var controller: GameController
    let envelope: MatchEnvelope

    private var canAct: Bool { controller.canAct(in: envelope) }

    var body: some View {
        VStack(spacing: 12) {
            header
            banner
            if envelope.maxPlayers > 2 {
                rosterLine
            }
            gameBody
            if envelope.status == .finished {
                rematchButton
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack {
            Button {
                controller.backToPicker()
            } label: {
                Label("Games", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            Spacer()
            Text(envelope.kind.title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if envelope.status == .finished {
            finishedBanner
        } else if canAct {
            let joining = envelope.isOpenSeat && !controller.isSeated(in: envelope)
            StatusBanner(text: joining ? "Your turn — you're in!" : "Your turn", tint: Theme.accent)
        } else if envelope.isOpenSeat {
            StatusBanner(text: "Waiting for a player to join…", tint: Theme.warning)
        } else {
            StatusBanner(text: "Waiting for Player \(envelope.turnSeat + 1)…", tint: Theme.warning)
        }
    }

    private var finishedBanner: some View {
        let seat = envelope.winnerSeat()
        let localWon = seat.map { envelope.players.indices.contains($0) && envelope.players[$0] == controller.localParticipantID } ?? false
        let text: String
        if localWon {
            text = "You won! 🎉"
        } else if let seat {
            text = controller.isSeated(in: envelope) ? "Player \(seat + 1) won — you lost" : "Player \(seat + 1) won"
        } else {
            text = "Game over"
        }
        return StatusBanner(text: text, tint: localWon ? Theme.positive : Theme.danger)
    }

    private var rosterLine: some View {
        Text("Players \(envelope.players.count)/\(envelope.maxPlayers)")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rematchButton: some View {
        Button {
            controller.rematch(from: envelope)
        } label: {
            Label("Rematch", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var gameBody: some View {
        switch envelope.kind {
        case .checkers:
            CheckersView(controller: controller, envelope: envelope)
        case .archery, .artillery, .launch:
            if let config = DuelRegistry.config(for: envelope.kind) {
                DuelView(controller: controller, envelope: envelope, config: config)
            }
        }
    }
}

struct StatusBanner: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
