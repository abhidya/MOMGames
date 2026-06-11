import SwiftUI

struct GamePickerView: View {
    @ObservedObject var controller: GameController

    @State private var pending: GameKind?
    @State private var count: Int = 2

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("MOM Games")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Pick a game to start your turn.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(GameKind.allCases) { kind in
                        Button {
                            select(kind)
                        } label: {
                            gameCard(kind)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }

            if let pending {
                playerCountSheet(for: pending)
            }
        }
    }

    private func select(_ kind: GameKind) {
        if kind.supportsGroup {
            count = kind.playerRange.lowerBound
            pending = kind
        } else {
            controller.startGame(kind, playerCount: kind.playerRange.lowerBound)
        }
    }

    private func gameCard(_ kind: GameKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: kind.symbol)
                    .font(.title)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if kind.supportsGroup {
                    Text("2–\(kind.playerRange.upperBound)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.background, in: Capsule())
                }
            }
            Text(kind.title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(kind.tagline)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func playerCountSheet(for kind: GameKind) -> some View {
        VStack(spacing: 16) {
            Text("\(kind.title)")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Everyone in the chat takes a turn until the board fills.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Stepper(value: $count, in: kind.playerRange) {
                Text("\(count) players")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            HStack(spacing: 12) {
                Button("Cancel") { pending = nil }
                    .buttonStyle(.bordered)
                    .tint(Theme.textSecondary)
                Button("Start") {
                    controller.startGame(kind, playerCount: count)
                    pending = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .padding(24)
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }
}
