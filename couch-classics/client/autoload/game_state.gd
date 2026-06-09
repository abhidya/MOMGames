extends Node

signal matches_changed
signal active_match_changed(match_model)

const MatchEngineScript := preload("res://core/match_engine.gd")
const MatchModelScript := preload("res://core/match_model.gd")
const CheckersModuleScript := preload("res://games/checkers/checkers_module.gd")
const ArcheryModuleScript := preload("res://games/archery_duel/archery_module.gd")
const ArtilleryModuleScript := preload("res://games/artillery_duel/artillery_module.gd")

var engine = MatchEngineScript.new()
var modules: Dictionary = {}
var game_catalog: Array = []
var matches: Array = []
var active_match = null

func _ready() -> void:
  randomize()
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

func current_player_name() -> String:
  if active_match == null:
    return ""
  for player in active_match.players:
    if MatchModelScript.player_id(player) == active_match.current_turn:
      return String(player.get("display_name", active_match.current_turn))
  return active_match.current_turn
