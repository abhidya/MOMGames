class_name LaunchModule
extends "res://core/game_module.gd"

const GRAVITY := 9.8
const WORLD_WIDTH := 560.0
const MIN_ANGLE := 15.0
const MAX_ANGLE := 70.0
const MIN_POWER := 20.0
const MAX_POWER := 72.0
const ROUNDS_TO_WIN := 3

func init_state(players: Array = []) -> Dictionary:
  return {
    "players": players,
    "turn_number": 1,
    "rounds_to_win": ROUNDS_TO_WIN,
    "winner": "",
    "wind": 1.5,
    "launches": [],
    "scores": _empty_scores(players),
    "field": _make_field(),
    "last_move": {}
  }

func is_valid_move(state: Dictionary, move: Dictionary) -> bool:
  var player_id = String(move.get("player_id", ""))
  if not _has_player(state, player_id):
    return false
  if not move.has("angle") or not move.has("power"):
    return false
  var angle = float(move["angle"])
  var power = float(move["power"])
  return angle >= MIN_ANGLE and angle <= MAX_ANGLE and power >= MIN_POWER and power <= MAX_POWER

func apply_move(state: Dictionary, move: Dictionary) -> Dictionary:
  var next = deserialize(serialize(state))
  var player_id = String(move.get("player_id", ""))
  var angle = float(move["angle"])
  var power = float(move["power"])
  var result = _simulate(next, angle, power)
  result["player_id"] = player_id
  result["angle"] = round(angle * 10.0) / 10.0
  result["power"] = round(power * 10.0) / 10.0
  result["wind"] = float(next.get("wind", 0.0))

  var launches: Array = next.get("launches", [])
  launches.append(result)
  next["launches"] = launches
  next["last_move"] = result
  next["turn_number"] = int(next.get("turn_number", 1)) + 1

  var scores: Dictionary = next.get("scores", {})
  scores[player_id] = float(scores.get(player_id, 0.0)) + float(result.get("distance", 0.0))
  next["scores"] = scores

  if _all_launches_taken(next):
    next["winner"] = _leader_id(next)
  else:
    next["wind"] = _next_wind(int(next["turn_number"]))
  return next

func is_terminal(state: Dictionary) -> bool:
  return String(state.get("winner", "")) != ""

func render(state: Dictionary) -> String:
  var last: Dictionary = state.get("last_move", {})
  if last.is_empty():
    return "No launches yet."
  return "Last launch traveled %.1f m." % float(last.get("distance", 0.0))

func suggested_launch(state: Dictionary) -> Dictionary:
  var best := {"angle": 38.0, "power": 52.0, "distance": -1.0}
  for angle in range(int(MIN_ANGLE), int(MAX_ANGLE) + 1):
    for power in range(int(MIN_POWER), int(MAX_POWER) + 1):
      var result = _simulate(state, float(angle), float(power))
      var distance = float(result.get("distance", 0.0))
      if distance > float(best["distance"]):
        best = {"angle": float(angle), "power": float(power), "distance": distance}
  return {"angle": best["angle"], "power": best["power"]}

func _simulate(state: Dictionary, angle: float, power: float) -> Dictionary:
  var radians = deg_to_rad(angle)
  var wind = float(state.get("wind", 0.0))
  var vx = cos(radians) * power + wind * 0.35
  var vy = sin(radians) * power
  var x = 0.0
  var y = 10.0
  var distance = 0.0
  var bounces = 0
  var boost_hits = 0
  var drag_hits = 0
  var event_log: Array = []
  var step = 0.12
  var elapsed = 0.0

  while elapsed < 18.0 and x < WORLD_WIDTH and abs(vx) > 1.0:
    x += vx * step
    vy -= GRAVITY * step
    y += vy * step
    distance = max(distance, x)

    if y <= 0.0:
      var zone = _zone_at(state, x)
      if zone == "boost":
        vx *= 1.18
        vy = abs(vy) * 0.62 + 14.0
        boost_hits += 1
        event_log.append("boost %.0f" % x)
      elif zone == "drag":
        vx *= 0.58
        vy = abs(vy) * 0.28
        drag_hits += 1
        event_log.append("drag %.0f" % x)
      else:
        vx *= 0.74
        vy = abs(vy) * 0.46
      bounces += 1
      y = 0.0

    elapsed += step

  var rounded_distance = round(clamp(distance, 0.0, WORLD_WIDTH) * 10.0) / 10.0
  return {
    "distance": rounded_distance,
    "bounces": bounces,
    "boost_hits": boost_hits,
    "drag_hits": drag_hits,
    "events": event_log
  }

func _zone_at(state: Dictionary, x: float) -> String:
  var field: Array = state.get("field", [])
  for zone in field:
    var item: Dictionary = zone
    var left = float(item.get("x", 0.0))
    var right = left + float(item.get("width", 0.0))
    if x >= left and x <= right:
      return String(item.get("kind", ""))
  return ""

func _make_field() -> Array:
  return [
    {"kind": "boost", "x": 88.0, "width": 22.0},
    {"kind": "drag", "x": 158.0, "width": 18.0},
    {"kind": "boost", "x": 230.0, "width": 24.0},
    {"kind": "drag", "x": 325.0, "width": 20.0},
    {"kind": "boost", "x": 405.0, "width": 26.0}
  ]

func _empty_scores(players: Array) -> Dictionary:
  var scores := {}
  for player in players:
    scores[_player_id(player)] = 0.0
  return scores

func _all_launches_taken(state: Dictionary) -> bool:
  var players: Array = state.get("players", [])
  var launches: Array = state.get("launches", [])
  return players.size() > 0 and launches.size() >= players.size() * int(state.get("rounds_to_win", ROUNDS_TO_WIN))

func _leader_id(state: Dictionary) -> String:
  var scores: Dictionary = state.get("scores", {})
  var best_id := ""
  var best_score := -1.0
  for player in state.get("players", []):
    var id = _player_id(player)
    var score = float(scores.get(id, 0.0))
    if score > best_score:
      best_score = score
      best_id = id
  return best_id

func _has_player(state: Dictionary, player_id: String) -> bool:
  for player in state.get("players", []):
    if _player_id(player) == player_id:
      return true
  return false

func _player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)

func _next_wind(turn_number: int) -> float:
  var pattern = [1.5, -2.0, 0.0, 3.0, -1.0, 2.5]
  return float(pattern[turn_number % pattern.size()])
