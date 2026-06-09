extends SceneTree

const MatchEngineScript := preload("res://core/match_engine.gd")
const MatchModelScript := preload("res://core/match_model.gd")
const CheckersModuleScript := preload("res://games/checkers/checkers_module.gd")

func _init() -> void:
  var engine = MatchEngineScript.new()
  var module = CheckersModuleScript.new()
  var players = [
    {"id": "p1", "display_name": "Player One"},
    {"id": "p2", "display_name": "Player Two"}
  ]
  var model = engine.create_match("checkers", players, module)

  _expect(model.current_turn == "p1", "player one starts")
  _expect(model.state["board"][5][0] == "r", "red piece seeded")
  _expect(model.state["board"][2][1] == "b", "black piece seeded")

  var move_one = {"player_id": "p1", "from": [5, 0], "to": [4, 1]}
  var result = engine.apply_move(model, module, move_one)
  _expect(bool(result.get("ok", false)), "first move accepted")
  _expect(model.current_turn == "p2", "turn flips after move")
  _expect(model.state["board"][4][1] == "r", "piece moved")

  var repeat_turn = engine.apply_move(model, module, {"player_id": "p1", "from": [5, 2], "to": [4, 3]})
  _expect(not bool(repeat_turn.get("ok", false)), "same player cannot move twice")

  var payload = model.serialize_json()
  var restored = MatchModelScript.deserialize_json(payload)
  _expect(restored.game_id == "checkers", "match survives JSON round trip")
  _expect(restored.state["board"][4][1] == "r", "state survives JSON round trip")

  print("checkers_engine_smoke: ok")
  quit(0)

func _expect(condition: bool, message: String) -> void:
  if condition:
    return
  push_error("checkers_engine_smoke failed: " + message)
  quit(1)
