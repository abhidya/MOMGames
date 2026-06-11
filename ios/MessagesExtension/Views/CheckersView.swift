import SwiftUI

struct CheckersView: View {
    @ObservedObject var controller: GameController
    let envelope: MatchEnvelope
    let seat: Int
    let isMyTurn: Bool

    @State private var selected: Square?

    private struct Square: Equatable { var row: Int; var col: Int }

    private var state: Checkers.State {
        envelope.state.decoded(Checkers.State.self, fallback: Checkers.initialState())
    }

    private var side: Checkers.Side { Checkers.Side.forSeat(seat) }

    private var destinations: [Square] {
        guard let selected else { return [] }
        return Checkers.legalDestinations(state, from: (selected.row, selected.col), side: side)
            .map { Square(row: $0.row, col: $0.col) }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(side == .red ? "You play red" : "You play black")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                let cell = geo.size.width / 8
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                cellView(row: row, col: col, size: cell)
                            }
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let dark = Checkers.isDark(row, col)
        let piece = state.board[row][col]
        let isSelected = selected == Square(row: row, col: col)
        let isDestination = destinations.contains(Square(row: row, col: col))

        return ZStack {
            Rectangle()
                .fill(dark ? Theme.boardDark : Theme.boardLight)
            if isDestination {
                Circle()
                    .fill(Theme.positive.opacity(0.35))
                    .frame(width: size * 0.4, height: size * 0.4)
            }
            if piece != Checkers.empty {
                pieceView(piece, size: size)
                    .overlay(
                        Circle()
                            .strokeBorder(Theme.accent, lineWidth: isSelected ? 3 : 0)
                            .frame(width: size * 0.78, height: size * 0.78)
                    )
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { tap(row: row, col: col) }
    }

    private func pieceView(_ piece: String, size: CGFloat) -> some View {
        let isRed = Checkers.pieceSide(piece) == .red
        return Circle()
            .fill(isRed ? Theme.redPiece : Theme.blackPiece)
            .frame(width: size * 0.72, height: size * 0.72)
            .overlay {
                if Checkers.isKing(piece) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .shadow(radius: 1)
    }

    // MARK: - Interaction

    private func tap(row: Int, col: Int) {
        guard isMyTurn, envelope.status == .active else { return }
        let target = Square(row: row, col: col)

        if selected != nil, destinations.contains(target) {
            makeMove(to: target)
            return
        }

        if Checkers.pieceSide(state.board[row][col]) == side {
            selected = target
        } else {
            selected = nil
        }
    }

    private func makeMove(to target: Square) {
        guard let from = selected else { return }
        let move = Checkers.Move(from: (from.row, from.col), to: (target.row, target.col))
        guard Checkers.isValid(state, move: move, side: side) else { return }

        let captured = abs(target.row - from.row) == 2
        let (newState, defeated) = Checkers.apply(state, move: move)
        selected = nil

        let caption: String
        if defeated {
            caption = "Checkmate — you cleared the board!"
        } else if captured {
            caption = "Captured a piece"
        } else {
            caption = "Made a move"
        }
        let result = MoveResult(
            state: newState.jsonData(),
            caption: caption,
            subcaption: defeated ? "" : "Your move, opponent",
            finished: defeated,
            committerWon: defeated
        )
        controller.commit(result, in: envelope)
    }
}
