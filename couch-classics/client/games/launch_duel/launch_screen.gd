extends Control

signal back_requested

var status_label: Label
var field_label: Label
var history_label: Label
var angle_slider: HSlider
var power_slider: HSlider
var angle_value: Label
var power_value: Label

func _ready() -> void:
  _build()
  GameState.active_match_changed.connect(_on_match_changed)
  _sync_suggestion()
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
  title.text = "Launch Duel"
  title.add_theme_font_size_override("font_size", 28)
  title.add_theme_color_override("font_color", ThemeTokens.INK)
  copy.add_child(title)

  status_label = Label.new()
  status_label.add_theme_color_override("font_color", ThemeTokens.SLATE)
  copy.add_child(status_label)

  var field := PanelContainer.new()
  field.add_theme_stylebox_override("panel", ThemeTokens.panel_style(Color("#eef2dd"), ThemeTokens.GREEN, 22))
  outer.add_child(field)

  field_label = Label.new()
  field_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  field_label.add_theme_font_size_override("font_size", 16)
  field_label.add_theme_color_override("font_color", ThemeTokens.INK)
  field.add_child(field_label)

  var angle_controls := _add_slider(outer, "Angle", 15, 70, 38)
  angle_slider = angle_controls["slider"]
  angle_value = angle_controls["value"]

  var power_controls := _add_slider(outer, "Power", 20, 72, 52)
  power_slider = power_controls["slider"]
  power_value = power_controls["value"]

  angle_slider.value_changed.connect(func(_value): _render_controls())
  power_slider.value_changed.connect(func(_value): _render_controls())

  var actions := HBoxContainer.new()
  actions.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  outer.add_child(actions)

  var suggest := Button.new()
  suggest.text = "Tune"
  suggest.custom_minimum_size = Vector2(108, 46)
  suggest.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.BLUE))
  suggest.pressed.connect(func():
    _sync_suggestion()
    _render()
  )
  actions.add_child(suggest)

  var launch := Button.new()
  launch.text = "Launch"
  launch.custom_minimum_size = Vector2(108, 46)
  launch.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.GOLD))
  launch.pressed.connect(_launch)
  actions.add_child(launch)

  history_label = Label.new()
  history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  history_label.add_theme_color_override("font_color", ThemeTokens.SLATE)
  outer.add_child(history_label)

func _add_slider(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, default_value: float) -> Dictionary:
  var panel := PanelContainer.new()
  panel.add_theme_stylebox_override("panel", ThemeTokens.panel_style(ThemeTokens.PANEL, Color("#d7ccb8"), 16))
  parent.add_child(panel)

  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  panel.add_child(row)

  var label := Label.new()
  label.text = label_text
  label.custom_minimum_size = Vector2(58, 32)
  label.add_theme_color_override("font_color", ThemeTokens.INK)
  row.add_child(label)

  var slider := HSlider.new()
  slider.name = "Slider"
  slider.min_value = min_value
  slider.max_value = max_value
  slider.step = 1
  slider.value = default_value
  slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(slider)

  var value := Label.new()
  value.name = "Value"
  value.custom_minimum_size = Vector2(42, 32)
  value.add_theme_color_override("font_color", ThemeTokens.INK)
  row.add_child(value)
  return {"slider": slider, "value": value}

func _on_match_changed(_model) -> void:
  _sync_suggestion()
  _render()

func _sync_suggestion() -> void:
  var model = GameState.active_match
  if model == null:
    return
  var module = GameState.module_for("launch_duel")
  if module == null:
    return
  var suggestion: Dictionary = module.suggested_launch(model.state)
  if angle_slider != null:
    angle_slider.value = float(suggestion.get("angle", 38.0))
  if power_slider != null:
    power_slider.value = round(float(suggestion.get("power", 52.0)))

func _launch() -> void:
  var model = GameState.active_match
  if model == null:
    return
  var result = await GameState.apply_move({
    "player_id": model.current_turn,
    "angle": angle_slider.value,
    "power": power_slider.value
  })
  if not bool(result.get("ok", false)):
    field_label.text = String(result.get("error", "Launch failed."))
  _sync_suggestion()
  _render()

func _render() -> void:
  var model = GameState.active_match
  if model == null or status_label == null:
    return
  if model.status == "finished":
    status_label.text = _winner_label(model) + " wins the distance line."
  else:
    status_label.text = GameState.current_player_name() + " launches next."

  var state: Dictionary = model.state
  var last: Dictionary = state.get("last_move", {})
  var last_text = "No launches yet."
  if not last.is_empty():
    last_text = "Last launch: %.1f m, %d bounces, %d boosts, %d drags." % [
      float(last.get("distance", 0.0)),
      int(last.get("bounces", 0)),
      int(last.get("boost_hits", 0)),
      int(last.get("drag_hits", 0))
    ]

  field_label.text = "Best of %d each | Wind %+.1f | Boost pads at 88, 230, 405\n%s\n%s" % [
    int(state.get("rounds_to_win", 3)),
    float(state.get("wind", 0.0)),
    last_text,
    _score_text(model)
  ]
  history_label.text = _history_text(state.get("launches", []))
  _render_controls()

func _render_controls() -> void:
  if angle_value != null:
    angle_value.text = str(int(angle_slider.value)) + " deg"
  if power_value != null:
    power_value.text = str(int(power_slider.value))

func _score_text(model) -> String:
  var scores: Dictionary = model.state.get("scores", {})
  var chunks: Array = []
  for player in model.players:
    var id = _player_id(player)
    chunks.append("%s %.1f" % [String(player.get("display_name", id)), float(scores.get(id, 0.0))])
  return "Score: " + " | ".join(chunks)

func _history_text(launches: Array) -> String:
  if launches.is_empty():
    return "Launch history will appear here."
  var lines: Array = []
  for i in range(max(0, launches.size() - 5), launches.size()):
    var launch: Dictionary = launches[i]
    lines.append("%s: %.1f m (%d boosts)" % [
      String(launch.get("player_id", "")),
      float(launch.get("distance", 0.0)),
      int(launch.get("boost_hits", 0))
    ])
  return "\n".join(lines)

func _winner_label(model) -> String:
  for player in model.players:
    if _player_id(player) == model.winner:
      return String(player.get("display_name", model.winner))
  return model.winner

func _player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)
