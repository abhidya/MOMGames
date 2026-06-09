extends Control

const CheckersScreenScene := preload("res://games/checkers/checkers_screen.tscn")
const ArcheryScreenScene := preload("res://games/archery_duel/archery_screen.tscn")
const ArtilleryScreenScene := preload("res://games/artillery_duel/artillery_screen.tscn")
const LaunchScreenScene := preload("res://games/launch_duel/launch_screen.tscn")

var body: VBoxContainer
var title_label: Label
var subtitle_label: Label
var feedback_label: Label
var selected_game_id := "checkers"

func _ready() -> void:
  _build_shell()
  GameState.matches_changed.connect(_show_match_list)
  GameState.network_status_changed.connect(func(message: String): _set_feedback(message, true))
  GameState.ensure_demo_match()
  _show_match_list()

func _build_shell() -> void:
  var background := ColorRect.new()
  background.color = ThemeTokens.MINT
  background.set_anchors_preset(Control.PRESET_FULL_RECT)
  add_child(background)

  var safe := MarginContainer.new()
  safe.set_anchors_preset(Control.PRESET_FULL_RECT)
  safe.add_theme_constant_override("margin_left", 18)
  safe.add_theme_constant_override("margin_right", 18)
  safe.add_theme_constant_override("margin_top", 22)
  safe.add_theme_constant_override("margin_bottom", 18)
  add_child(safe)

  var stack := VBoxContainer.new()
  stack.add_theme_constant_override("separation", ThemeTokens.SPACE_3)
  safe.add_child(stack)

  var header := PanelContainer.new()
  header.add_theme_stylebox_override("panel", ThemeTokens.panel_style(ThemeTokens.PANEL, Color("#cfc3ae"), 22))
  stack.add_child(header)

  var header_box := VBoxContainer.new()
  header_box.add_theme_constant_override("separation", 2)
  header.add_child(header_box)

  title_label = Label.new()
  title_label.text = "Couch Classics"
  title_label.add_theme_font_size_override("font_size", 34)
  title_label.add_theme_color_override("font_color", ThemeTokens.INK)
  header_box.add_child(title_label)

  subtitle_label = Label.new()
  subtitle_label.text = "Async turns, local hotseat ready"
  subtitle_label.add_theme_font_size_override("font_size", 15)
  subtitle_label.add_theme_color_override("font_color", ThemeTokens.SLATE)
  header_box.add_child(subtitle_label)

  feedback_label = Label.new()
  feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  feedback_label.add_theme_font_size_override("font_size", 13)
  feedback_label.add_theme_color_override("font_color", ThemeTokens.SLATE)
  stack.add_child(feedback_label)

  body = VBoxContainer.new()
  body.size_flags_vertical = Control.SIZE_EXPAND_FILL
  body.add_theme_constant_override("separation", ThemeTokens.SPACE_3)
  stack.add_child(body)

func _clear_body() -> void:
  for child in body.get_children():
    child.queue_free()

func _show_match_list() -> void:
  if body == null:
    return
  _clear_body()
  subtitle_label.text = "Your active turns"

  var actions := HBoxContainer.new()
  actions.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  body.add_child(actions)

  var new_game := Button.new()
  new_game.text = "New Game"
  new_game.custom_minimum_size = Vector2(140, 46)
  new_game.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.GOLD))
  new_game.pressed.connect(_show_new_game)
  actions.add_child(new_game)

  var settings := Button.new()
  settings.text = "Settings"
  settings.custom_minimum_size = Vector2(120, 46)
  settings.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.PAPER))
  settings.pressed.connect(_show_settings)
  actions.add_child(settings)

  if Net.is_authenticated():
    var refresh := Button.new()
    refresh.text = "Refresh"
    refresh.custom_minimum_size = Vector2(110, 46)
    refresh.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.BLUE))
    refresh.pressed.connect(_refresh_online_matches)
    actions.add_child(refresh)

  for model in GameState.matches:
    body.add_child(_match_card(model))

func _match_card(model) -> Control:
  var card := PanelContainer.new()
  card.add_theme_stylebox_override("panel", ThemeTokens.panel_style(ThemeTokens.PANEL, Color("#d7ccb8"), 18))

  var box := VBoxContainer.new()
  box.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  card.add_child(box)

  var name := Label.new()
  name.text = _game_title(model.game_id)
  name.add_theme_font_size_override("font_size", 24)
  name.add_theme_color_override("font_color", ThemeTokens.INK)
  box.add_child(name)

  var status := Label.new()
  status.add_theme_font_size_override("font_size", 15)
  status.add_theme_color_override("font_color", ThemeTokens.SLATE)
  status.text = _match_status(model)
  box.add_child(status)

  var open := Button.new()
  open.text = "Open Match"
  open.custom_minimum_size = Vector2(160, 44)
  open.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.BLUE))
  open.pressed.connect(func():
    GameState.set_active_match(model.id)
    _show_game(model)
  )
  box.add_child(open)
  return card

func _show_new_game() -> void:
  _clear_body()
  subtitle_label.text = "Pick a game and invite a friend"

  var invite := LineEdit.new()
  invite.placeholder_text = "Friend handle for online match (blank = hotseat)"
  invite.editable = Net.is_authenticated()
  invite.custom_minimum_size = Vector2(0, 46)
  body.add_child(invite)

  for game in GameState.game_catalog:
    var row := PanelContainer.new()
    row.add_theme_stylebox_override("panel", ThemeTokens.panel_style(ThemeTokens.PANEL, Color("#d7ccb8"), 18))
    body.add_child(row)

    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
    row.add_child(h)

    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(copy)

    var title := Label.new()
    title.text = String(game["title"])
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", ThemeTokens.INK)
    copy.add_child(title)

    var tagline := Label.new()
    tagline.text = String(game["tagline"])
    tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tagline.add_theme_color_override("font_color", ThemeTokens.SLATE)
    copy.add_child(tagline)

    var button := Button.new()
    button.custom_minimum_size = Vector2(92, 44)
    if bool(game["playable"]):
      button.text = "Start"
      button.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.GOLD))
      var playable_id = String(game["id"])
      button.pressed.connect(_start_game.bind(playable_id, invite))
    else:
      button.text = "Soon"
      button.disabled = true
      button.add_theme_stylebox_override("disabled", ThemeTokens.muted_button_style())
    h.add_child(button)

  var back := Button.new()
  back.text = "Back to Matches"
  back.custom_minimum_size = Vector2(0, 46)
  back.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.PAPER))
  back.pressed.connect(_show_match_list)
  body.add_child(back)

func _show_game(model) -> void:
  _clear_body()
  subtitle_label.text = "Hotseat mode" if _is_local_match(model) else "Online match"
  if model == null:
    _show_match_list()
    return

  if model.game_id == "checkers":
    var screen := CheckersScreenScene.instantiate()
    screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
    screen.back_requested.connect(_show_match_list)
    body.add_child(screen)
  elif model.game_id == "archery_duel":
    var screen := ArcheryScreenScene.instantiate()
    screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
    screen.back_requested.connect(_show_match_list)
    body.add_child(screen)
  elif model.game_id == "artillery_duel":
    var screen := ArtilleryScreenScene.instantiate()
    screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
    screen.back_requested.connect(_show_match_list)
    body.add_child(screen)
  elif model.game_id == "launch_duel":
    var screen := LaunchScreenScene.instantiate()
    screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
    screen.back_requested.connect(_show_match_list)
    body.add_child(screen)

func _show_settings() -> void:
  _clear_body()
  subtitle_label.text = "Account and backend"

  var card := PanelContainer.new()
  card.add_theme_stylebox_override("panel", ThemeTokens.panel_style())
  body.add_child(card)

  var box := VBoxContainer.new()
  box.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  card.add_child(box)

  var backend := Label.new()
  backend.text = "Backend: " + Net.base_url
  backend.add_theme_color_override("font_color", ThemeTokens.INK)
  box.add_child(backend)

  var auth := Label.new()
  auth.text = "Signed in as " + Net.current_user_label() if Net.is_authenticated() else "Not signed in"
  auth.add_theme_color_override("font_color", ThemeTokens.SLATE)
  box.add_child(auth)

  var login_row := HBoxContainer.new()
  login_row.add_theme_constant_override("separation", ThemeTokens.SPACE_2)
  box.add_child(login_row)

  var alice := Button.new()
  alice.text = "Alice"
  alice.custom_minimum_size = Vector2(88, 42)
  alice.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.GOLD))
  alice.pressed.connect(_login_dev.bind("alice@example.test"))
  login_row.add_child(alice)

  var bob := Button.new()
  bob.text = "Bob"
  bob.custom_minimum_size = Vector2(88, 42)
  bob.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.GOLD))
  bob.pressed.connect(_login_dev.bind("bob@example.test"))
  login_row.add_child(bob)

  var logout := Button.new()
  logout.text = "Logout"
  logout.custom_minimum_size = Vector2(96, 42)
  logout.disabled = not Net.is_authenticated()
  logout.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.PAPER))
  logout.pressed.connect(func():
    Net.logout()
    _set_feedback("Signed out.")
    _show_settings()
  )
  login_row.add_child(logout)

  var refresh := Button.new()
  refresh.text = "Load Online Matches"
  refresh.custom_minimum_size = Vector2(0, 44)
  refresh.disabled = not Net.is_authenticated()
  refresh.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.BLUE))
  refresh.pressed.connect(_refresh_online_matches)
  box.add_child(refresh)

  var note := Label.new()
  note.text = "Use Alice/Bob for local PocketBase testing. Enter the other handle when starting a new game to create an online match."
  note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  note.add_theme_color_override("font_color", ThemeTokens.SLATE)
  box.add_child(note)

  var back := Button.new()
  back.text = "Back"
  back.custom_minimum_size = Vector2(0, 46)
  back.add_theme_stylebox_override("normal", ThemeTokens.button_style(ThemeTokens.PAPER))
  back.pressed.connect(_show_match_list)
  body.add_child(back)

func _game_title(game_id: String) -> String:
  for game in GameState.game_catalog:
    if String(game["id"]) == game_id:
      return String(game["title"])
  return game_id

func _match_status(model) -> String:
  if model.status == "finished":
    return "Finished. Winner: " + _winner_label(model)
  return "Turn: " + _player_label(model, model.current_turn) + " | Move " + str(model.state.get("turn_number", 1))

func _player_label(model, player_id: String) -> String:
  for player in model.players:
    if _player_id(player) == player_id:
      return String(player.get("display_name", player_id))
  return player_id

func _winner_label(model) -> String:
  return _player_label(model, model.winner)

func _player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)

func _start_game(game_id: String, invite: LineEdit) -> void:
  var handle := invite.text.strip_edges()
  if Net.is_authenticated() and handle != "":
    _set_feedback("Creating online match...")
    var result = await GameState.create_online_match(game_id, handle)
    if bool(result.get("ok", false)):
      _set_feedback("Online match ready.")
      _show_game(result.get("match"))
    else:
      _set_feedback(String(result.get("error", "Online match failed.")), true)
    return

  var model = GameState.create_hotseat_match(game_id)
  _set_feedback("Started local hotseat match.")
  _show_game(model)

func _login_dev(identity: String) -> void:
  _set_feedback("Signing in...")
  var result = await GameState.login(identity, "couchclassics123")
  if bool(result.get("ok", false)):
    _set_feedback("Signed in as " + Net.current_user_label() + ".")
  else:
    _set_feedback(String(result.get("error", "Sign in failed.")), true)
  _show_settings()

func _refresh_online_matches() -> void:
  _set_feedback("Loading online matches...")
  var result = await GameState.refresh_online_matches()
  if bool(result.get("ok", false)):
    _set_feedback("Online matches loaded.")
    _show_match_list()
  else:
    _set_feedback(String(result.get("error", "Could not load online matches.")), true)

func _set_feedback(message: String, is_error: bool = false) -> void:
  if feedback_label == null:
    return
  feedback_label.text = message
  feedback_label.add_theme_color_override("font_color", ThemeTokens.CORAL if is_error else ThemeTokens.SLATE)

func _is_local_match(model) -> bool:
  return model == null or String(model.id).begins_with("local-")
