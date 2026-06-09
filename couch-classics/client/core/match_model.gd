class_name MatchModel
extends RefCounted

var id: String = ""
var game_id: String = ""
var players: Array = []
var current_turn: String = ""
var state: Dictionary = {}
var status: String = "waiting"
var winner: String = ""
var updated_at: String = ""

static func player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)

func to_dict() -> Dictionary:
  return {
    "id": id,
    "game_id": game_id,
    "players": players,
    "current_turn": current_turn,
    "state": state,
    "status": status,
    "winner": winner,
    "updated_at": updated_at
  }

func serialize_json() -> String:
  return JSON.stringify(to_dict())

static func from_dict(data: Dictionary):
  var model = load("res://core/match_model.gd").new()
  model.id = String(data.get("id", ""))
  model.game_id = String(data.get("game_id", ""))
  model.players = data.get("players", [])
  model.current_turn = String(data.get("current_turn", ""))
  var raw_state: Variant = data.get("state", {})
  model.state = raw_state if typeof(raw_state) == TYPE_DICTIONARY else {}
  model.status = String(data.get("status", "waiting"))
  model.winner = String(data.get("winner", ""))
  model.updated_at = String(data.get("updated_at", ""))
  return model

static func deserialize_json(payload: String):
  var parsed: Variant = JSON.parse_string(payload)
  if typeof(parsed) != TYPE_DICTIONARY:
    return load("res://core/match_model.gd").new()
  return from_dict(parsed)
