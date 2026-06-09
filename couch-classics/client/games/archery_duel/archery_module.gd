class_name ArcheryModule
extends "res://core/game_module.gd"

const GRAVITY := 9.8
const MIN_ANGLE := 15.0
const MAX_ANGLE := 75.0
const MIN_POWER := 18.0
const MAX_POWER := 42.0

func init_state(players: Array = []) -> Dictionary:
  return {
    "players": players,
    "turn_number": 1,
    "winner": "",
    "target_distance": 98.0,
    "hit_radius": 6.0,
    "wind": 0.0,
    "shots": [],
    "last_move": {}
  }

func is_valid_move(state: Dictionary, move: Dictionary) -> bool:
  var player_id = String(move.get("player_id", ""))
  if _side_for_player(state, player_id) == "":
    return false
  if not move.has("angle") or not move.has("power"):
    return false
  var angle = float(move["angle"])
  var power = float(move["power"])
  return angle >= MIN_ANGLE and angle <= MAX_ANGLE and power >= MIN_POWER and power <= MAX_POWER

func apply_move(state: Dictionary, move: Dictionary) -> Dictionary:
  var next = deserialize(serialize(state))
  var angle = float(move["angle"])
  var power = float(move["power"])
  var wind = float(next.get("wind", 0.0))
  var distance = _shot_distance(angle, power, wind)
  var target = float(next.get("target_distance", 98.0))
  var miss = distance - target
  var hit = abs(miss) <= float(next.get("hit_radius", 6.0))
  var shot = {
    "player_id": String(move.get("player_id", "")),
    "angle": round(angle * 10.0) / 10.0,
    "power": round(power * 10.0) / 10.0,
    "wind": wind,
    "distance": round(distance * 10.0) / 10.0,
    "miss": round(miss * 10.0) / 10.0,
    "hit": hit
  }

  next["last_move"] = shot
  var shots: Array = next.get("shots", [])
  shots.append(shot)
  next["shots"] = shots
  next["turn_number"] = int(next.get("turn_number", 1)) + 1
  if hit:
    next["winner"] = String(move.get("player_id", ""))
  else:
    next["wind"] = _next_wind(int(next["turn_number"]))
  return next

func is_terminal(state: Dictionary) -> bool:
  return String(state.get("winner", "")) != ""

func render(state: Dictionary) -> String:
  var last: Dictionary = state.get("last_move", {})
  if last.is_empty():
    return "No shots yet."
  return "Last shot landed %.1f m, miss %.1f m." % [float(last.get("distance", 0.0)), float(last.get("miss", 0.0))]

func suggested_shot(state: Dictionary) -> Dictionary:
  var angle = 45.0
  var wind = float(state.get("wind", 0.0))
  var target = float(state.get("target_distance", 98.0))
  var adjusted = max(1.0, target - wind * 4.0)
  var power = sqrt(adjusted * GRAVITY)
  return {"angle": angle, "power": clamp(power, MIN_POWER, MAX_POWER)}

func _shot_distance(angle: float, power: float, wind: float) -> float:
  var radians = deg_to_rad(angle)
  var base_range = (power * power * sin(2.0 * radians)) / GRAVITY
  return max(0.0, base_range + wind * 4.0)

func _next_wind(turn_number: int) -> float:
  var pattern = [-2.0, 1.5, 0.0, 2.5, -1.0, 3.0]
  return float(pattern[turn_number % pattern.size()])

func _side_for_player(state: Dictionary, player_id: String) -> String:
  var players: Array = state.get("players", [])
  if players.size() > 0 and _player_id(players[0]) == player_id:
    return "left"
  if players.size() > 1 and _player_id(players[1]) == player_id:
    return "right"
  return ""

func _player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)
