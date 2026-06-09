extends Node

signal matches_changed
signal active_match_changed(match_model)
signal network_status_changed(message: String)

const MatchEngineScript := preload("res://core/match_engine.gd")
const MatchModelScript := preload("res://core/match_model.gd")
const CheckersModuleScript := preload("res://games/checkers/checkers_module.gd")
const ArcheryModuleScript := preload("res://games/archery_duel/archery_module.gd")
const ArtilleryModuleScript := preload("res://games/artillery_duel/artillery_module.gd")
const LaunchModuleScript := preload("res://games/launch_duel/launch_module.gd")

var engine = MatchEngineScript.new()
var modules: Dictionary = {}
var game_catalog: Array = []
var matches: Array = []
var active_match = null

func _ready() -> void:
  randomize()
  Net.auth_changed.connect(func(): network_status_changed.emit("Auth changed."))
  Net.backend_error.connect(func(message: String): network_status_changed.emit(message))
  register_module("checkers", CheckersModuleScript.new(), {
    "title": "Checkers",
    "tagline": "Classic diagonal tactics",
    "playable": true
  })
  register_module("archery_duel", ArcheryModuleScript.new(), {
    "title": "Archery Duel",
    "tagline": "Aim, power, and one clean shot",
    "playable": true
  })
  register_module("artillery_duel", ArtilleryModuleScript.new(), {
    "title": "Artillery Duel",
    "tagline": "Wind, terrain, and turn-based arcs",
    "playable": true
  })
  register_module("launch_duel", LaunchModuleScript.new(), {
    "title": "Launch Duel",
    "tagline": "Angle, bounce pads, and distance runs",
    "playable": true
  })

func register_module(game_id: String, module, meta: Dictionary) -> void:
  modules[game_id] = module
  var entry = meta.duplicate(true)
  entry["id"] = game_id
  game_catalog.append(entry)

func ensure_demo_match() -> void:
  if matches.is_empty():
    create_hotseat_match("checkers")

func create_hotseat_match(game_id: String):
  if not modules.has(game_id):
    push_error("No module registered for " + game_id)
    return null

  var players = [
    {"id": "p1", "display_name": "Player One"},
    {"id": "p2", "display_name": "Player Two"}
  ]
  var model = engine.create_match(game_id, players, modules[game_id])
  matches.push_front(model)
  active_match = model
  matches_changed.emit()
  active_match_changed.emit(model)
  return model

func login(identity: String, password: String) -> Dictionary:
  return await Net.login(identity, password)

func refresh_online_matches() -> Dictionary:
  if not Net.is_authenticated():
    return {"ok": false, "error": "Log in before loading online matches."}

  var result = await Net.list_matches()
  if bool(result.get("ok", false)):
    var online_matches: Array = result.get("matches", [])
    var local_matches: Array = []
    for model in matches:
      if _is_local_match(model):
        local_matches.append(model)
    matches = online_matches + local_matches
    if active_match != null and not _is_local_match(active_match):
      active_match = get_match(active_match.id)
      active_match_changed.emit(active_match)
    matches_changed.emit()
  return result

func create_online_match(game_id: String, opponent_handle: String) -> Dictionary:
  if not Net.is_authenticated():
    return {"ok": false, "error": "Log in before creating an online match."}
  if not modules.has(game_id):
    return {"ok": false, "error": "No module registered for " + game_id}

  var found = await Net.find_user_by_handle(opponent_handle)
  if not bool(found.get("ok", false)):
    return found

  var opponent: Dictionary = found.get("user", {})
  if String(opponent.get("id", "")) == Net.current_user_id():
    return {"ok": false, "error": "Pick a different friend handle."}

  var players = [Net.user_record.duplicate(true), opponent]
  var model = engine.create_match(game_id, players, modules[game_id])
  var created = await Net.create_match(model)
  if bool(created.get("ok", false)):
    active_match = created.get("match")
    _upsert_match(active_match)
    matches_changed.emit()
    active_match_changed.emit(active_match)
  return created

func set_active_match(match_id: String) -> void:
  active_match = get_match(match_id)
  active_match_changed.emit(active_match)

func get_match(match_id: String):
  for model in matches:
    if model.id == match_id:
      return model
  return null

func module_for(game_id: String):
  return modules.get(game_id)

func apply_hotseat_move(move: Dictionary) -> Dictionary:
  if active_match == null:
    return {"ok": false, "error": "No active match."}

  var module = module_for(active_match.game_id)
  if module == null:
    return {"ok": false, "error": "No module for active match."}

  var result = engine.apply_move(active_match, module, move)
  if bool(result.get("ok", false)):
    matches_changed.emit()
    active_match_changed.emit(active_match)
  return result

func apply_move(move: Dictionary) -> Dictionary:
  if active_match == null:
    return {"ok": false, "error": "No active match."}

  if _is_local_match(active_match):
    return apply_hotseat_move(move)

  var module = module_for(active_match.game_id)
  if module == null:
    return {"ok": false, "error": "No module for active match."}

  var snapshot: String = active_match.serialize_json()
  var result = engine.apply_move(active_match, module, move)
  if not bool(result.get("ok", false)):
    return result

  _upsert_match(active_match)
  matches_changed.emit()
  active_match_changed.emit(active_match)

  var submitted = await Net.submit_move(active_match, move)
  if bool(submitted.get("ok", false)):
    active_match = submitted.get("match")
    _upsert_match(active_match)
    matches_changed.emit()
    active_match_changed.emit(active_match)
    return {"ok": true, "match": active_match}

  active_match = MatchModelScript.deserialize_json(snapshot)
  _upsert_match(active_match)
  matches_changed.emit()
  active_match_changed.emit(active_match)
  return submitted

func current_player_name() -> String:
  if active_match == null:
    return ""
  for player in active_match.players:
    if MatchModelScript.player_id(player) == active_match.current_turn:
      return String(player.get("display_name", active_match.current_turn))
  return active_match.current_turn

func _is_local_match(model) -> bool:
  return model == null or String(model.id).begins_with("local-")

func _upsert_match(model) -> void:
  if model == null:
    return
  for i in range(matches.size()):
    if matches[i].id == model.id:
      matches[i] = model
      return
  matches.push_front(model)
