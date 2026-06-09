extends Node

signal match_record_changed(record: Dictionary)
signal backend_error(message: String)
signal auth_changed

var base_url := "http://127.0.0.1:8090"
var auth_token := ""
var user_record: Dictionary = {}
var realtime_enabled := false

func configure(url: String, token: String = "") -> void:
  base_url = url.trim_suffix("/")
  auth_token = token

func is_authenticated() -> bool:
  return auth_token != ""

func current_user_id() -> String:
  return String(user_record.get("id", ""))

func current_user_label() -> String:
  return String(user_record.get("display_name", user_record.get("handle", current_user_id())))

func login(identity: String, password: String) -> Dictionary:
  var result = await _request(HTTPClient.METHOD_POST, "/api/collections/users/auth-with-password", {
    "identity": identity,
    "password": password
  })
  if bool(result.get("ok", false)):
    var data: Dictionary = result.get("data", {})
    auth_token = String(data.get("token", ""))
    user_record = _normalize_user(data.get("record", {}))
    auth_changed.emit()
  return result

func logout() -> void:
  auth_token = ""
  user_record = {}
  auth_changed.emit()

func find_user_by_handle(handle: String) -> Dictionary:
  var cleaned := handle.strip_edges().trim_prefix("@")
  if cleaned == "":
    return {"ok": false, "error": "Enter a friend handle."}

  var filter := "handle = '" + cleaned.replace("'", "\\'") + "'"
  var path := "/api/collections/users/records?perPage=1&filter=" + filter.uri_encode()
  var result = await _request(HTTPClient.METHOD_GET, path)
  if not bool(result.get("ok", false)):
    return result

  var data: Dictionary = result.get("data", {})
  var items: Array = data.get("items", [])
  if items.is_empty():
    return {"ok": false, "error": "No user found for @" + cleaned + "."}

  return {"ok": true, "user": _normalize_user(items[0])}

func create_match_payload(match_model) -> Dictionary:
  return {
    "game_id": match_model.game_id,
    "players": _player_ids(match_model.players),
    "created_by": current_user_id(),
    "current_turn": match_model.current_turn,
    "state": match_model.state,
    "status": match_model.status
  }

func submit_move_payload(match_model, move: Dictionary) -> Dictionary:
  var payload := {
    "match": match_model.id,
    "player": String(move.get("player_id", "")),
    "turn_number": max(1, int(match_model.state.get("turn_number", 1)) - 1),
    "move": move,
    "resulting_state": match_model.state,
    "next_turn": match_model.current_turn,
    "status_after": match_model.status
  }
  if match_model.winner != "":
    payload["winner"] = match_model.winner
  return payload

func create_match(match_model) -> Dictionary:
  var result = await _request(
    HTTPClient.METHOD_POST,
    "/api/collections/matches/records?expand=players,current_turn,winner,created_by",
    create_match_payload(match_model)
  )
  if bool(result.get("ok", false)):
    var record: Dictionary = result.get("data", {})
    match_record_changed.emit(record)
    return {"ok": true, "record": record, "match": match_model_from_record(record)}
  return result

func list_matches() -> Dictionary:
  var result = await _request(
    HTTPClient.METHOD_GET,
    "/api/collections/matches/records?perPage=50&expand=players,current_turn,winner,created_by"
  )
  if not bool(result.get("ok", false)):
    return result

  var data: Dictionary = result.get("data", {})
  var models: Array = []
  for record in data.get("items", []):
    models.append(match_model_from_record(record))
  return {"ok": true, "matches": models}

func fetch_match(match_id: String) -> Dictionary:
  var result = await _request(
    HTTPClient.METHOD_GET,
    "/api/collections/matches/records/" + match_id.uri_encode() + "?expand=players,current_turn,winner,created_by"
  )
  if bool(result.get("ok", false)):
    var record: Dictionary = result.get("data", {})
    match_record_changed.emit(record)
    return {"ok": true, "record": record, "match": match_model_from_record(record)}
  return result

func submit_move(match_model, move: Dictionary) -> Dictionary:
  var result = await _request(
    HTTPClient.METHOD_POST,
    "/api/collections/moves/records",
    submit_move_payload(match_model, move)
  )
  if not bool(result.get("ok", false)):
    return result
  return await fetch_match(match_model.id)

func match_model_from_record(record: Dictionary):
  var MatchModelScript = load("res://core/match_model.gd")
  var players := _expanded_players(record)
  return MatchModelScript.from_dict({
    "id": String(record.get("id", "")),
    "game_id": String(record.get("game_id", "")),
    "players": players,
    "current_turn": _relation_id(record.get("current_turn", "")),
    "state": record.get("state", {}),
    "status": String(record.get("status", "waiting")),
    "winner": _relation_id(record.get("winner", "")),
    "updated_at": String(record.get("updated", record.get("updated_at", "")))
  })

func subscribe_to_match(_match_id: String) -> void:
  realtime_enabled = true
  # Godot has no built-in SSE client. Web builds should add a JavaScriptBridge
  # adapter here, while native builds can use polling or a small SSE plugin.

func push_notification_stub(user_id: String, match_id: String) -> void:
  print("Notification stub queued for ", user_id, " in match ", match_id)

func _request(method: int, path: String, body: Variant = null) -> Dictionary:
  var request := HTTPRequest.new()
  add_child(request)

  var headers := PackedStringArray(["Accept: application/json"])
  var payload := ""
  if body != null:
    headers.append("Content-Type: application/json")
    payload = JSON.stringify(body)
  if auth_token != "":
    headers.append("Authorization: " + auth_token)

  var error := request.request(base_url + path, headers, method, payload)
  if error != OK:
    request.queue_free()
    var message := "Backend request failed to start."
    backend_error.emit(message)
    return {"ok": false, "error": message}

  var completed: Array = await request.request_completed
  request.queue_free()

  var result_code := int(completed[0])
  var response_code := int(completed[1])
  var response_body: PackedByteArray = completed[3]
  var text := response_body.get_string_from_utf8()
  var parsed: Variant = JSON.parse_string(text) if text != "" else {}
  var data: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

  if result_code != HTTPRequest.RESULT_SUCCESS:
    var transport_message := "Backend transport error " + str(result_code) + "."
    backend_error.emit(transport_message)
    return {"ok": false, "status": response_code, "error": transport_message, "data": data}

  if response_code < 200 or response_code >= 300:
    var api_message := String(data.get("message", "Backend returned HTTP " + str(response_code) + "."))
    backend_error.emit(api_message)
    return {"ok": false, "status": response_code, "error": api_message, "data": data}

  return {"ok": true, "status": response_code, "data": data}

func _normalize_user(raw: Variant) -> Dictionary:
  if typeof(raw) != TYPE_DICTIONARY:
    return {}
  return {
    "id": String(raw.get("id", "")),
    "handle": String(raw.get("handle", "")),
    "display_name": String(raw.get("display_name", raw.get("email", raw.get("id", "")))),
    "email": String(raw.get("email", ""))
  }

func _expanded_players(record: Dictionary) -> Array:
  var relation_ids: Array = record.get("players", [])
  var expanded: Variant = record.get("expand", {})
  var expanded_players: Array = []
  if typeof(expanded) == TYPE_DICTIONARY:
    expanded_players = expanded.get("players", [])

  var players: Array = []
  for id in relation_ids:
    var player_id := String(id)
    var player: Dictionary = {}
    for candidate in expanded_players:
      if typeof(candidate) == TYPE_DICTIONARY and String(candidate.get("id", "")) == player_id:
        player = _normalize_user(candidate)
        break
    if player.is_empty():
      player = {"id": player_id, "handle": player_id, "display_name": player_id}
    players.append(player)
  return players

func _player_ids(players: Array) -> Array:
  var ids: Array = []
  for player in players:
    if typeof(player) == TYPE_DICTIONARY:
      ids.append(String(player.get("id", "")))
    else:
      ids.append(String(player))
  return ids

func _relation_id(value: Variant) -> String:
  if typeof(value) == TYPE_DICTIONARY:
    return String(value.get("id", ""))
  return String(value)
