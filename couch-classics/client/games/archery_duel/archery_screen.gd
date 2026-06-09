extends Control

signal back_requested

var status_label: Label
var detail_label: Label
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
  title.text = "Archery Duel"
  title.add_theme_font_size_override("font_size", 28)
  title.add_theme_color_override("font_color", ThemeTokens.INK)
  copy.add_child(title)

  status_label = Label.new()
  status_label.add_theme_color_override("font_color", ThemeTokens.SLATE)
  copy.add_child(status_label)

  var field := PanelContainer.new()
  field.add_theme_stylebox_override("panel", ThemeTokens.panel_style(Color("#e8f4df"), ThemeTokens.GREEN, 22))
  outer.add_child(field)

  detail_label = Label.new()
  detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  detail_label.add_theme_font_size_override("font_size", 17)
  detail_label.add_theme_color_override("font_color", ThemeTokens.INK)
  field.add_child(detail_label)

  var angle_controls := _add_slider(outer, "Angle", 15, 75, 45)
  angle_slider = angle_controls["slider"]
  angle_value = angle_controls["value"]

  var power_controls := _add_slider(outer, "Power", 18, 42, 31)
  power_slider = power_controls["slider"]
  power_value = power_controls["value"]

  angle_slider.value_changed.connect(func(_value): _render_controls())
  power_slider.value_changed.connect(func(_value): _render_controls())

  var actions := HBoxContainer.new()
  actions.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  outer.add_child(actions)

  var suggest := Button.new()
  suggest.text = "Line Up"
  suggest.custom_minimum_size = Vector2(108, 46)
  suggest.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.BLUE))
  suggest.pressed.connect(func():
    _sync_suggestion()
    _render()
  )
  actions.add_child(suggest)

  var fire := Button.new()
  fire.text = "Fire"
  fire.custom_minimum_size = Vector2(108, 46)
  fire.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.GOLD))
  fire.pressed.connect(_fire)
  actions.add_child(fire)

  history_label = Label.new()
  history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  history_label.add_theme_color_override("font_color", ThemeTokens.SLATE)
  outer.add_child(history_label)

func _add_slider(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, default_value: float) -> Dictionary:
  var panel := PanelContainer.new()
  panel.name = label_text + "Panel"
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
  var module = GameState.module_for("archery_duel")
  if module == null:
    return
  var suggestion: Dictionary = module.suggested_shot(model.state)
  if angle_slider != null:
    angle_slider.value = float(suggestion.get("angle", 45.0))
  if power_slider != null:
    power_slider.value = round(float(suggestion.get("power", 31.0)))

func _fire() -> void:
  var model = GameState.active_match
  if model == null:
    return
  var result = await GameState.apply_move({
    "player_id": model.current_turn,
    "angle": angle_slider.value,
    "power": power_slider.value
  })
  if not bool(result.get("ok", false)):
    detail_label.text = String(result.get("error", "Shot failed."))
  _sync_suggestion()
  _render()

func _render() -> void:
  var model = GameState.active_match
  if model == null or status_label == null:
    return
  if model.status == "finished":
    status_label.text = _winner_label(model) + " landed the winning shot."
  else:
    status_label.text = GameState.current_player_name() + " at the line."

  var state: Dictionary = model.state
  var last: Dictionary = state.get("last_move", {})
  var last_text = "No arrows loosed yet."
  if not last.is_empty():
    last_text = "Last arrow: %.1f m (%+.1f m), wind %.1f." % [
      float(last.get("distance", 0.0)),
      float(last.get("miss", 0.0)),
      float(last.get("wind", 0.0))
    ]
  detail_label.text = "Target %.1f m | Hit window %.1f m | Wind %+.1f\n%s" % [
    float(state.get("target_distance", 0.0)),
    float(state.get("hit_radius", 0.0)),
    float(state.get("wind", 0.0)),
    last_text
  ]
  history_label.text = _history_text(state.get("shots", []))
  _render_controls()

func _render_controls() -> void:
  if angle_value != null:
    angle_value.text = str(int(angle_slider.value)) + " deg"
  if power_value != null:
    power_value.text = str(int(power_slider.value))

func _history_text(shots: Array) -> String:
  if shots.is_empty():
    return "Shot history will appear here."
  var lines: Array = []
  for i in range(max(0, shots.size() - 4), shots.size()):
    var shot: Dictionary = shots[i]
    lines.append("%s: %.1f m%s" % [
      String(shot.get("player_id", "")),
      float(shot.get("distance", 0.0)),
      " hit" if bool(shot.get("hit", false)) else ""
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
