extends Control

signal back_requested

var board_grid: GridContainer
var status_label: Label
var error_label: Label
var selected_square: Array = []

func _ready() -> void:
  _build()
  GameState.active_match_changed.connect(_on_match_changed)
  _render()

func _build() -> void:
  var outer := VBoxContainer.new()
  outer.set_anchors_preset(Control.PRESET_FULL_RECT)
  outer.add_theme_constant_override("separation", ThemeTokens.SPACE_3)
  add_child(outer)

  var top := HBoxContainer.new()
  top.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  outer.add_child(top)

  var back := Button.new()
  back.text = "Back"
  back.custom_minimum_size = Vector2(74, 42)
  back.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.PAPER))
  back.pressed.connect(func(): back_requested.emit())
  top.add_child(back)

  var copy := VBoxContainer.new()
  copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  top.add_child(copy)

  var title := Label.new()
  title.text = "Checkers"
  title.add_theme_font_size_override("font_size", 28)
  title.add_theme_color_override("font_color", ThemeTokens.INK)
  copy.add_child(title)

  status_label = Label.new()
  status_label.add_theme_color_override("font_color", ThemeTokens.SLATE)
  copy.add_child(status_label)

  var board_panel := PanelContainer.new()
  board_panel.add_theme_stylebox_override("panel", ThemeTokens.panel_style(Color("#2c352f"), ThemeTokens.INK, 22))
  board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  outer.add_child(board_panel)

  board_grid = GridContainer.new()
  board_grid.columns = 8
  board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  board_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
  board_grid.add_theme_constant_override("h_separation", 0)
  board_grid.add_theme_constant_override("v_separation", 0)
  board_panel.add_child(board_grid)

  for row in range(8):
    for col in range(8):
      var square := Button.new()
      square.custom_minimum_size = Vector2(46, 46)
      square.focus_mode = Control.FOCUS_NONE
      square.pressed.connect(_on_square_pressed.bind(row, col))
      board_grid.add_child(square)

  error_label = Label.new()
  error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  error_label.add_theme_color_override("font_color", ThemeTokens.CORAL)
  outer.add_child(error_label)

func _on_match_changed(_match_model) -> void:
  selected_square = []
  _render()

func _on_square_pressed(row: int, col: int) -> void:
  var model = GameState.active_match
  if model == null or model.status == "finished":
    return

  if selected_square.is_empty():
    var piece := String(model.state.get("board", [])[row][col])
    if piece != "":
      selected_square = [row, col]
      error_label.text = ""
    _render()
    return

  var move = {
    "player_id": model.current_turn,
    "from": selected_square,
    "to": [row, col]
  }
  var result = await GameState.apply_move(move)
  selected_square = []
  if not bool(result.get("ok", false)):
    error_label.text = String(result.get("error", "Move failed."))
  else:
    error_label.text = ""
  _render()

func _render() -> void:
  if board_grid == null:
    return

  var model = GameState.active_match
  if model == null:
    status_label.text = "No active match."
    return

  if model.status == "finished":
    status_label.text = _winner_label(model) + " wins."
  else:
    status_label.text = GameState.current_player_name() + " to move."

  var board: Array = model.state.get("board", [])
  for row in range(8):
    for col in range(8):
      var index = row * 8 + col
      var square = board_grid.get_child(index) as Button
      var piece = String(board[row][col])
      square.text = _piece_label(piece)
      square.add_theme_font_size_override("font_size", 16)
      square.add_theme_color_override("font_color", _piece_text_color(piece))
      square.add_theme_stylebox_override("normal", _square_style(row, col))
      square.add_theme_stylebox_override("hover", _square_style(row, col, true))
      square.add_theme_stylebox_override("pressed", _square_style(row, col, true))

func _square_style(row: int, col: int, lifted: bool = false) -> StyleBoxFlat:
  var dark = (row + col) % 2 == 1
  var fill = ThemeTokens.BOARD_DARK if dark else ThemeTokens.BOARD_LIGHT
  if selected_square.size() == 2 and int(selected_square[0]) == row and int(selected_square[1]) == col:
    fill = ThemeTokens.GOLD
  elif lifted:
    fill = fill.lightened(0.08)

  var style := StyleBoxFlat.new()
  style.bg_color = fill
  style.border_color = Color("#263128")
  style.set_border_width_all(1)
  style.set_corner_radius_all(0)
  return style

func _piece_label(piece: String) -> String:
  match piece:
    "r":
      return "RED"
    "R":
      return "RED K"
    "b":
      return "BLK"
    "B":
      return "BLK K"
    _:
      return ""

func _piece_text_color(piece: String) -> Color:
  if piece == "r" or piece == "R":
    return Color("#7d2626")
  if piece == "b" or piece == "B":
    return Color("#151a20")
  return ThemeTokens.INK

func _winner_label(model) -> String:
  for player in model.players:
    if _player_id(player) == model.winner:
      return String(player.get("display_name", model.winner))
  return model.winner

func _player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)
