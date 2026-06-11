import SwiftUI

struct GamePickerView: View {
    @ObservedObject var controller: GameController

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
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
                        controller.startGame(kind)
                    } label: {
                        gameCard(kind)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func gameCard(_ kind: GameKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: kind.symbol)
                .font(.title)
                .foregroundStyle(Theme.accent)
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
}
