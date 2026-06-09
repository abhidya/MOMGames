extends SceneTree

func _init() -> void:
  call_deferred("_run")

func _run() -> void:
  await process_frame

  var base_url := OS.get_environment("COUCH_CLASSICS_PB_URL")
  if base_url == "":
    base_url = "http://127.0.0.1:8099"
  var net = root.get_node("/root/Net")
  var game_state = root.get_node("/root/GameState")
  net.configure(base_url)

  var login = await game_state.login("alice@example.test", "couchclassics123")
  if not _expect(bool(login.get("ok", false)), "alice can log in"):
    return
  if not _expect(net.current_user_id() != "", "alice auth record is stored"):
    return

  var created = await game_state.create_online_match("archery_duel", "bob")
  if not _expect(bool(created.get("ok", false)), "alice can create online match with bob"):
    return
  var model = created.get("match")
  if not _expect(model != null and not String(model.id).begins_with("local-"), "online match uses backend id"):
    return

  var module = game_state.module_for("archery_duel")
  var suggestion: Dictionary = module.suggested_shot(model.state)
  var moved = await game_state.apply_move({
    "player_id": model.current_turn,
    "angle": suggestion["angle"],
    "power": suggestion["power"]
  })
  if not _expect(bool(moved.get("ok", false)), "online move submits"):
    return
  if not _expect(game_state.active_match.status == "finished", "winning online move updates match status"):
    return
  if not _expect(game_state.active_match.winner == net.current_user_id(), "winning online move records winner"):
    return

  var refreshed = await game_state.refresh_online_matches()
  if not _expect(bool(refreshed.get("ok", false)), "online matches refresh: " + String(refreshed.get("error", "unknown"))):
    return
  if not _expect(game_state.get_match(game_state.active_match.id) != null, "refreshed list keeps online match"):
    return

  print("network_turn_smoke: ok")
  quit(0)

func _expect(condition: bool, message: String) -> bool:
  if condition:
    return true
  push_error("network_turn_smoke failed: " + message)
  quit(1)
  return false
