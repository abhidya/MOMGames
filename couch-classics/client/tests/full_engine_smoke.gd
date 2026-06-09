extends SceneTree

const MatchEngineScript := preload("res://core/match_engine.gd")
const MatchModelScript := preload("res://core/match_model.gd")
const CheckersModuleScript := preload("res://games/checkers/checkers_module.gd")
const ArcheryModuleScript := preload("res://games/archery_duel/archery_module.gd")
const ArtilleryModuleScript := preload("res://games/artillery_duel/artillery_module.gd")
const LaunchModuleScript := preload("res://games/launch_duel/launch_module.gd")

var players = [
  {"id": "p1", "display_name": "Player One"},
  {"id": "p2", "display_name": "Player Two"}
]

func _init() -> void:
  _test_checkers()
  _test_archery()
  _test_artillery()
  _test_launch()
  print("full_engine_smoke: ok")
  quit(0)

func _test_checkers() -> void:
  var engine = MatchEngineScript.new()
  var module = CheckersModuleScript.new()
  var model = engine.create_match("checkers", players, module)
  var result = engine.apply_move(model, module, {"player_id": "p1", "from": [5, 0], "to": [4, 1]})
  _expect(bool(result.get("ok", false)), "checkers accepts first legal move")
  _expect(model.current_turn == "p2", "checkers turn flips")
  _round_trip(model, "checkers")

func _test_archery() -> void:
  var engine = MatchEngineScript.new()
  var module = ArcheryModuleScript.new()
  var model = engine.create_match("archery_duel", players, module)
  var suggestion: Dictionary = module.suggested_shot(model.state)
  var result = engine.apply_move(model, module, {
    "player_id": "p1",
    "angle": suggestion["angle"],
    "power": suggestion["power"]
  })
  _expect(bool(result.get("ok", false)), "archery accepts suggested shot")
  _expect(model.status == "finished", "archery suggested shot can finish")
  _expect(model.winner == "p1", "archery records winner")
  _round_trip(model, "archery_duel")

func _test_artillery() -> void:
  var engine = MatchEngineScript.new()
  var module = ArtilleryModuleScript.new()
  var model = engine.create_match("artillery_duel", players, module)
  var suggestion: Dictionary = module.suggested_shot(model.state, "p1")
  var result = engine.apply_move(model, module, {
    "player_id": "p1",
    "angle": suggestion["angle"],
    "power": suggestion["power"]
  })
  _expect(bool(result.get("ok", false)), "artillery accepts suggested shot")
  _expect(model.state.get("last_move", {}).has("impact"), "artillery records impact")
  _expect(model.state.get("shots", []).size() == 1, "artillery records shot history")
  _expect(model.status == "finished", "artillery suggested shot can finish")
  _expect(model.winner == "p1", "artillery records winner")
  _round_trip(model, "artillery_duel")

func _test_launch() -> void:
  var engine = MatchEngineScript.new()
  var module = LaunchModuleScript.new()
  var model = engine.create_match("launch_duel", players, module)
  while model.status != "finished":
    var suggestion: Dictionary = module.suggested_launch(model.state)
    var result = engine.apply_move(model, module, {
      "player_id": model.current_turn,
      "angle": suggestion["angle"],
      "power": suggestion["power"]
    })
    _expect(bool(result.get("ok", false)), "launch accepts suggested move")

  _expect(model.state.get("launches", []).size() == players.size() * 3, "launch records all rounds")
  _expect(model.state.get("last_move", {}).has("distance"), "launch records distance")
  _expect(model.winner != "", "launch records winner")
  _round_trip(model, "launch_duel")

func _round_trip(model, game_id: String) -> void:
  var restored = MatchModelScript.deserialize_json(model.serialize_json())
  _expect(restored.game_id == game_id, game_id + " round trip keeps game id")
  _expect(restored.state.has("turn_number"), game_id + " round trip keeps state")

func _expect(condition: bool, message: String) -> void:
  if condition:
    return
  push_error("full_engine_smoke failed: " + message)
  quit(1)
