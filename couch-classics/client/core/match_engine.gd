class_name MatchEngine
extends RefCounted

const MatchModelScript := preload("res://core/match_model.gd")

func create_match(game_id: String, players: Array, module) -> RefCounted:
  var model = MatchModelScript.new()
  model.id = _new_match_id()
  model.game_id = game_id
  model.players = players
  model.current_turn = MatchModelScript.player_id(players[0]) if players.size() > 0 else ""
  model.state = module.init_state(players)
  model.status = "active"
  model.winner = ""
  model.updated_at = _now_iso()
  return model

func apply_move(model, module, move: Dictionary) -> Dictionary:
  if model.status != "active":
    return {"ok": false, "error": "Match is not active."}

  var player_id = String(move.get("player_id", ""))
  if player_id == "":
    return {"ok": false, "error": "Move is missing player_id."}

  if player_id != model.current_turn:
    return {"ok": false, "error": "It is not this player's turn."}

  var state = module.deserialize(module.serialize(model.state))
  if not module.is_valid_move(state, move):
    return {"ok": false, "error": "Illegal move."}

  state = module.apply_move(state, move)
  model.state = state
  model.updated_at = _now_iso()

  if module.is_terminal(state):
    model.status = "finished"
    model.winner = String(state.get("winner", ""))
  else:
    model.current_turn = _next_player_id(model.players, model.current_turn)

  return {"ok": true, "match": model}

func _next_player_id(players: Array, current_player_id: String) -> String:
  if players.is_empty():
    return ""

  for i in range(players.size()):
    if MatchModelScript.player_id(players[i]) == current_player_id:
      return MatchModelScript.player_id(players[(i + 1) % players.size()])

  return MatchModelScript.player_id(players[0])

func _new_match_id() -> String:
  var stamp = str(int(Time.get_unix_time_from_system() * 1000.0))
  return "local-" + stamp + "-" + str(randi() % 100000)

func _now_iso() -> String:
  return Time.get_datetime_string_from_system(false, true)
