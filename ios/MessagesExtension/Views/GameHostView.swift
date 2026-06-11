import SwiftUI

/// Wraps a single game with the turn banner and routes to the right board.
struct GameHostView: View {
    @ObservedObject var controller: GameController
    let envelope: MatchEnvelope

    private var seat: Int { controller.seat(in: envelope) }
    private var isMyTurn: Bool { controller.isMyTurn(in: envelope) }

    var body: some View {
        VStack(spacing: 12) {
            header
            banner
            gameBody
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
            let won = envelope.winner == controller.localParticipantID
            StatusBanner(text: won ? "You won! 🎉" : "Opponent won",
                         tint: won ? Theme.positive : Theme.danger)
        } else if isMyTurn {
            StatusBanner(text: "Your turn", tint: Theme.accent)
        } else {
            StatusBanner(text: "Waiting for opponent…", tint: Theme.warning)
        }
    }

    @ViewBuilder
    private var gameBody: some View {
        switch envelope.kind {
        case .checkers:
            CheckersView(controller: controller, envelope: envelope, seat: seat, isMyTurn: isMyTurn)
        case .archery, .artillery, .launch:
            if let config = DuelRegistry.config(for: envelope.kind) {
                DuelView(controller: controller, envelope: envelope, config: config,
                         seat: seat, isMyTurn: isMyTurn)
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
