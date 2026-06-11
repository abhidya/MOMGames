import SwiftUI

struct RootView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
                .padding(12)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if controller.isCompact {
            CompactView(controller: controller)
        } else {
            switch controller.screen {
            case .picker:
                GamePickerView(controller: controller)
            case .game(let envelope):
                GameHostView(controller: controller, envelope: envelope)
            }
        }
    }
}

/// The short card shown in the Messages input strip before the user expands.
struct CompactView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                title
                subtitle
            }
            Spacer()
            Button {
                controller.onRequestExpanded?()
            } label: {
                Text("Open")
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var icon: some View {
        let symbol: String = {
            if case .game(let env) = controller.screen { return env.kind.symbol }
            return "gamecontroller.fill"
        }()
        Image(systemName: symbol)
            .font(.title)
            .foregroundStyle(Theme.accent)
    }

    @ViewBuilder private var title: some View {
        switch controller.screen {
        case .picker:
            Text("MOM Games").font(.headline).foregroundStyle(Theme.textPrimary)
        case .game(let env):
            Text(env.kind.title).font(.headline).foregroundStyle(Theme.textPrimary)
        }
    }

    @ViewBuilder private var subtitle: some View {
        switch controller.screen {
        case .picker:
            Text("Tap Open to start a game")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        case .game(let env):
            Text(compactStatus(env))
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    private func compactStatus(_ env: MatchEnvelope) -> String {
        if env.status == .finished {
            if let seat = env.winnerSeat() {
                if env.players.indices.contains(seat), env.players[seat] == controller.localParticipantID {
                    return "You won 🎉"
                }
                return "Player \(seat + 1) won"
            }
            return "Game over"
        }
        return controller.canAct(in: env) ? "Your turn" : "Waiting…"
    }
}
