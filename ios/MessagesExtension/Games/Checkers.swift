import Foundation

/// Pure checkers rules, ported from the original `checkers_module.gd`. The logic
/// is identity-agnostic: seat 0 plays "red" (moves up the board, promotes on
/// row 0) and seat 1 plays "black". The controller maps seats to iMessage
/// participants.
enum Checkers {
    static let boardSize = 8
    static let empty = ""

    struct State: Codable, Equatable {
        var board: [[String]]
        var turnNumber: Int
        var lastMove: LastMove?
    }

    struct LastMove: Codable, Equatable {
        var from: [Int]
        var to: [Int]
        var capture: Bool
        var side: String
    }

    struct Move: Equatable {
        var from: (row: Int, col: Int)
        var to: (row: Int, col: Int)

        static func == (lhs: Move, rhs: Move) -> Bool {
            lhs.from == rhs.from && lhs.to == rhs.to
        }
    }

    enum Side: String {
        case red
        case black

        static func forSeat(_ seat: Int) -> Side { seat == 0 ? .red : .black }

        var opponent: Side { self == .red ? .black : .red }
    }

    // MARK: - Setup

    static func initialState() -> State {
        var board: [[String]] = []
        for row in 0..<boardSize {
            var line: [String] = []
            for col in 0..<boardSize {
                if !isDark(row, col) {
                    line.append(empty)
                } else if row < 3 {
                    line.append("b")
                } else if row > 4 {
                    line.append("r")
                } else {
                    line.append(empty)
                }
            }
            board.append(line)
        }
        return State(board: board, turnNumber: 1, lastMove: nil)
    }

    // MARK: - Validation

    static func isValid(_ state: State, move: Move, side: Side) -> Bool {
        guard inside(move.from.row, move.from.col), inside(move.to.row, move.to.col) else { return false }
        let board = state.board
        guard board.count == boardSize else { return false }

        let piece = board[move.from.row][move.from.col]
        guard piece != empty, pieceSide(piece) == side else { return false }
        guard board[move.to.row][move.to.col] == empty, isDark(move.to.row, move.to.col) else { return false }

        let rowDelta = move.to.row - move.from.row
        let colDelta = move.to.col - move.from.col
        guard abs(colDelta) == abs(rowDelta) else { return false }

        let isCapture = abs(rowDelta) == 2
        if hasCapture(board, side: side), !isCapture { return false }

        if abs(rowDelta) == 1 {
            return directionAllowed(piece, rowDelta: rowDelta)
        }

        if isCapture {
            guard directionAllowed(piece, rowDelta: rowDelta) else { return false }
            let jumpedRow = move.from.row + rowDelta / 2
            let jumpedCol = move.from.col + colDelta / 2
            let jumped = board[jumpedRow][jumpedCol]
            return jumped != empty && pieceSide(jumped) != side
        }
        return false
    }

    /// All legal destinations for the piece on `square`, honoring forced
    /// capture. Used to drive the board UI's highlights.
    static func legalDestinations(_ state: State, from square: (row: Int, col: Int), side: Side) -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        for rowDelta in [-2, -1, 1, 2] {
            for colDelta in [-2, -1, 1, 2] where abs(rowDelta) == abs(colDelta) {
                let target = (row: square.row + rowDelta, col: square.col + colDelta)
                if isValid(state, move: Move(from: square, to: target), side: side) {
                    result.append(target)
                }
            }
        }
        return result
    }

    // MARK: - Application

    /// Applies a move assumed valid. Returns the next state and whether the
    /// opponent is now defeated (no pieces or no moves).
    static func apply(_ state: State, move: Move) -> (state: State, opponentDefeated: Bool) {
        var next = state
        var piece = next.board[move.from.row][move.from.col]
        let side = pieceSide(piece)

        next.board[move.from.row][move.from.col] = empty
        let capture = abs(move.to.row - move.from.row) == 2
        if capture {
            let jumpedRow = (move.from.row + move.to.row) / 2
            let jumpedCol = (move.from.col + move.to.col) / 2
            next.board[jumpedRow][jumpedCol] = empty
        }

        if side == .red, move.to.row == 0 {
            piece = "R"
        } else if side == .black, move.to.row == boardSize - 1 {
            piece = "B"
        }
        next.board[move.to.row][move.to.col] = piece
        next.turnNumber += 1
        next.lastMove = LastMove(
            from: [move.from.row, move.from.col],
            to: [move.to.row, move.to.col],
            capture: capture,
            side: (side ?? .red).rawValue
        )

        let other = (side ?? .red).opponent
        let defeated = count(next.board, side: other) == 0 || !hasAnyMove(next.board, side: other)
        return (next, defeated)
    }

    // MARK: - Helpers

    static func inside(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < boardSize && col >= 0 && col < boardSize
    }

    static func isDark(_ row: Int, _ col: Int) -> Bool { (row + col) % 2 == 1 }

    static func isKing(_ piece: String) -> Bool { piece == "R" || piece == "B" }

    static func pieceSide(_ piece: String) -> Side? {
        switch piece {
        case "r", "R": return .red
        case "b", "B": return .black
        default: return nil
        }
    }

    private static func directionAllowed(_ piece: String, rowDelta: Int) -> Bool {
        if isKing(piece) { return true }
        switch pieceSide(piece) {
        case .red: return rowDelta < 0
        case .black: return rowDelta > 0
        case nil: return false
        }
    }

    private static func hasCapture(_ board: [[String]], side: Side) -> Bool {
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                let piece = board[row][col]
                guard pieceSide(piece) == side else { continue }
                for rowDelta in [-2, 2] {
                    for colDelta in [-2, 2] {
                        if capturePossible(board, piece: piece, fromRow: row, fromCol: col,
                                           toRow: row + rowDelta, toCol: col + colDelta) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    private static func capturePossible(_ board: [[String]], piece: String, fromRow: Int, fromCol: Int, toRow: Int, toCol: Int) -> Bool {
        guard inside(toRow, toCol), board[toRow][toCol] == empty else { return false }
        let rowDelta = toRow - fromRow
        guard directionAllowed(piece, rowDelta: rowDelta) else { return false }
        let jumpedRow = (fromRow + toRow) / 2
        let jumpedCol = (fromCol + toCol) / 2
        let jumped = board[jumpedRow][jumpedCol]
        return jumped != empty && pieceSide(jumped) != pieceSide(piece)
    }

    private static func hasAnyMove(_ board: [[String]], side: Side) -> Bool {
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                let piece = board[row][col]
                guard pieceSide(piece) == side else { continue }
                if pieceHasMove(board, piece: piece, row: row, col: col) { return true }
            }
        }
        return false
    }

    private static func pieceHasMove(_ board: [[String]], piece: String, row: Int, col: Int) -> Bool {
        for rowDelta in [-1, 1] {
            for colDelta in [-1, 1] {
                if directionAllowed(piece, rowDelta: rowDelta) {
                    let targetRow = row + rowDelta
                    let targetCol = col + colDelta
                    if inside(targetRow, targetCol), board[targetRow][targetCol] == empty { return true }
                }
                if capturePossible(board, piece: piece, fromRow: row, fromCol: col,
                                   toRow: row + rowDelta * 2, toCol: col + colDelta * 2) {
                    return true
                }
            }
        }
        return false
    }

    static func count(_ board: [[String]], side: Side) -> Int {
        var total = 0
        for row in board {
            for piece in row where pieceSide(piece) == side {
                total += 1
            }
        }
        return total
    }
}
