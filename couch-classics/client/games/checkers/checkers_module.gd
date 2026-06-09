class_name CheckersModule
extends "res://core/game_module.gd"

const BOARD_SIZE := 8
const EMPTY := ""

func init_state(players: Array = []) -> Dictionary:
  var board: Array = []
  for row in range(BOARD_SIZE):
    var line: Array = []
    for col in range(BOARD_SIZE):
      if not _is_dark(row, col):
        line.append(EMPTY)
      elif row < 3:
        line.append("b")
      elif row > 4:
        line.append("r")
      else:
        line.append(EMPTY)
    board.append(line)

  return {
    "board": board,
    "players": players,
    "turn_number": 1,
    "winner": "",
    "last_move": {},
    "rules": {"forced_capture": true, "multi_jump": false}
  }

func is_valid_move(state: Dictionary, move: Dictionary) -> bool:
  if not move.has("from") or not move.has("to"):
    return false

  var from_sq: Array = move["from"]
  var to_sq: Array = move["to"]
  if from_sq.size() != 2 or to_sq.size() != 2:
    return false

  var from_row = int(from_sq[0])
  var from_col = int(from_sq[1])
  var to_row = int(to_sq[0])
  var to_col = int(to_sq[1])
  if not _inside(from_row, from_col) or not _inside(to_row, to_col):
    return false

  var board: Array = state.get("board", [])
  if board.size() != BOARD_SIZE:
    return false

  var piece = String(board[from_row][from_col])
  if piece == EMPTY:
    return false

  var player_id = String(move.get("player_id", ""))
  var side = _side_for_player(state, player_id)
  if side == "" or _piece_side(piece) != side:
    return false

  if String(board[to_row][to_col]) != EMPTY or not _is_dark(to_row, to_col):
    return false

  var row_delta = to_row - from_row
  var col_delta = to_col - from_col
  if abs(col_delta) != abs(row_delta):
    return false

  var move_is_capture: bool = abs(row_delta) == 2
  if _has_capture_for_side(board, side) and not move_is_capture:
    return false

  if abs(row_delta) == 1:
    return _direction_allowed(piece, row_delta)

  if move_is_capture:
    if not _direction_allowed(piece, row_delta):
      return false
    var jumped_row = from_row + int(row_delta / 2)
    var jumped_col = from_col + int(col_delta / 2)
    var jumped_piece = String(board[jumped_row][jumped_col])
    return jumped_piece != EMPTY and _piece_side(jumped_piece) != side

  return false

func apply_move(state: Dictionary, move: Dictionary) -> Dictionary:
  var next = deserialize(serialize(state))
  var board: Array = next["board"]
  var from_sq: Array = move["from"]
  var to_sq: Array = move["to"]
  var from_row = int(from_sq[0])
  var from_col = int(from_sq[1])
  var to_row = int(to_sq[0])
  var to_col = int(to_sq[1])
  var piece = String(board[from_row][from_col])
  var side = _piece_side(piece)

  board[from_row][from_col] = EMPTY
  if abs(to_row - from_row) == 2:
    var jumped_row = int((from_row + to_row) / 2)
    var jumped_col = int((from_col + to_col) / 2)
    board[jumped_row][jumped_col] = EMPTY

  if side == "red" and to_row == 0:
    piece = "R"
  elif side == "black" and to_row == BOARD_SIZE - 1:
    piece = "B"

  board[to_row][to_col] = piece
  next["turn_number"] = int(next.get("turn_number", 1)) + 1
  next["last_move"] = {
    "player_id": String(move.get("player_id", "")),
    "from": [from_row, from_col],
    "to": [to_row, to_col],
    "capture": abs(to_row - from_row) == 2
  }

  var other_side = "black" if side == "red" else "red"
  if _count_side(board, other_side) == 0 or not _has_any_move_for_side(board, other_side):
    next["winner"] = String(move.get("player_id", ""))

  return next

func is_terminal(state: Dictionary) -> bool:
  return String(state.get("winner", "")) != ""

func render(state: Dictionary) -> String:
  var lines: Array = []
  for row in state.get("board", []):
    lines.append(" ".join(row))
  return "\n".join(lines)

func _inside(row: int, col: int) -> bool:
  return row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE

func _is_dark(row: int, col: int) -> bool:
  return (row + col) % 2 == 1

func _piece_side(piece: String) -> String:
  if piece == "r" or piece == "R":
    return "red"
  if piece == "b" or piece == "B":
    return "black"
  return ""

func _side_for_player(state: Dictionary, player_id: String) -> String:
  var players: Array = state.get("players", [])
  if players.size() > 0 and _player_id(players[0]) == player_id:
    return "red"
  if players.size() > 1 and _player_id(players[1]) == player_id:
    return "black"
  return ""

func _player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)

func _is_king(piece: String) -> bool:
  return piece == "R" or piece == "B"

func _direction_allowed(piece: String, row_delta: int) -> bool:
  if _is_king(piece):
    return true
  if _piece_side(piece) == "red":
    return row_delta < 0
  if _piece_side(piece) == "black":
    return row_delta > 0
  return false

func _has_capture_for_side(board: Array, side: String) -> bool:
  for row in range(BOARD_SIZE):
    for col in range(BOARD_SIZE):
      var piece = String(board[row][col])
      if _piece_side(piece) != side:
        continue
      for row_delta in [-2, 2]:
        for col_delta in [-2, 2]:
          if _capture_possible(board, piece, row, col, row + row_delta, col + col_delta):
            return true
  return false

func _capture_possible(board: Array, piece: String, from_row: int, from_col: int, to_row: int, to_col: int) -> bool:
  if not _inside(to_row, to_col) or String(board[to_row][to_col]) != EMPTY:
    return false
  var row_delta = to_row - from_row
  if not _direction_allowed(piece, row_delta):
    return false
  var jumped_row = int((from_row + to_row) / 2)
  var jumped_col = int((from_col + to_col) / 2)
  var jumped_piece = String(board[jumped_row][jumped_col])
  return jumped_piece != EMPTY and _piece_side(jumped_piece) != _piece_side(piece)

func _has_any_move_for_side(board: Array, side: String) -> bool:
  for row in range(BOARD_SIZE):
    for col in range(BOARD_SIZE):
      var piece = String(board[row][col])
      if _piece_side(piece) != side:
        continue
      if _piece_has_move(board, piece, row, col):
        return true
  return false

func _piece_has_move(board: Array, piece: String, row: int, col: int) -> bool:
  for row_delta in [-1, 1]:
    for col_delta in [-1, 1]:
      if _direction_allowed(piece, row_delta):
        var target_row: int = row + row_delta
        var target_col: int = col + col_delta
        if _inside(target_row, target_col) and String(board[target_row][target_col]) == EMPTY:
          return true
      if _capture_possible(board, piece, row, col, row + (row_delta * 2), col + (col_delta * 2)):
        return true
  return false

func _count_side(board: Array, side: String) -> int:
  var count = 0
  for row in board:
    for piece in row:
      if _piece_side(String(piece)) == side:
        count += 1
  return count
