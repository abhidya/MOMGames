extends Node

signal match_record_changed(record: Dictionary)
signal backend_error(message: String)

var base_url := "http://127.0.0.1:8090"
var auth_token := ""
var realtime_enabled := false

func configure(url: String, token: String = "") -> void:
  base_url = url.trim_suffix("/")
  auth_token = token

func is_authenticated() -> bool:
  return auth_token != ""

func create_match_payload(match_model) -> Dictionary:
  return {
    "game_id": match_model.game_id,
    "players": match_model.players,
    "current_turn": match_model.current_turn,
    "state": match_model.state,
    "status": match_model.status,
    "winner": match_model.winner
  }

func submit_move_payload(match_model, move: Dictionary) -> Dictionary:
  return {
    "match": match_model.id,
    "player": String(move.get("player_id", "")),
    "turn_number": int(match_model.state.get("turn_number", 0)),
    "move": move,
    "resulting_state": match_model.state,
    "next_turn": match_model.current_turn,
    "winner": match_model.winner,
    "status_after": match_model.status
  }

func subscribe_to_match(_match_id: String) -> void:
  realtime_enabled = true
  # Godot has no built-in SSE client. Web builds should add a JavaScriptBridge
  # adapter here, while native builds can use polling or a small SSE plugin.

func push_notification_stub(user_id: String, match_id: String) -> void:
  print("Notification stub queued for ", user_id, " in match ", match_id)
