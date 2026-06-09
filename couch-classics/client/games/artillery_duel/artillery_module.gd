class_name ArtilleryModule
extends "res://core/game_module.gd"

const WORLD_WIDTH := 320.0
const GRAVITY := 9.8
const MIN_ANGLE := 20.0
const MAX_ANGLE := 80.0
const MIN_POWER := 28.0
const MAX_POWER := 72.0
const BLAST_RADIUS := 13.0
const STEP := 0.08

func init_state(players: Array = []) -> Dictionary:
  var terrain = _make_terrain()
  return {
    "players": players,
    "turn_number": 1,
    "winner": "",
    "world_width": WORLD_WIDTH,
    "gravity": GRAVITY,
    "wind": -2.0,
    "terrain": terrain,
    "tanks": {
      "p1": {"x": 36.0, "y": _terrain_at(terrain, 36.0), "side": "left"},
      "p2": {"x": 284.0, "y": _terrain_at(terrain, 284.0), "side": "right"}
    },
    "craters": [],
    "shots": [],
    "last_move": {}
  }

func is_valid_move(state: Dictionary, move: Dictionary) -> bool:
  var player_id = String(move.get("player_id", ""))
  if not _has_tank(state, player_id):
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
  var impact = _simulate(next, player_id, angle, power)
  var opponent_id = _opponent_id(next, player_id)
  var tanks: Dictionary = next.get("tanks", {})
  var opponent: Dictionary = tanks.get(opponent_id, {})
  var dx = float(impact.get("x", 0.0)) - float(opponent.get("x", 0.0))
  var dy = float(impact.get("y", 0.0)) - float(opponent.get("y", 0.0))
  var hit = sqrt(dx * dx + dy * dy) <= BLAST_RADIUS

  var shot = {
    "player_id": player_id,
    "angle": round(angle * 10.0) / 10.0,
    "power": round(power * 10.0) / 10.0,
    "wind": float(next.get("wind", 0.0)),
    "impact": impact,
    "hit": hit
  }
  next["last_move"] = shot
  var shots: Array = next.get("shots", [])
  shots.append(shot)
  next["shots"] = shots
  next["turn_number"] = int(next.get("turn_number", 1)) + 1

  if hit:
    next["winner"] = player_id
  else:
    _apply_crater(next, float(impact.get("x", 0.0)))
    next["wind"] = _next_wind(int(next["turn_number"]))
  return next

func is_terminal(state: Dictionary) -> bool:
  return String(state.get("winner", "")) != ""

func render(state: Dictionary) -> String:
  var last: Dictionary = state.get("last_move", {})
  if last.is_empty():
    return "No shells fired."
  var impact: Dictionary = last.get("impact", {})
  return "Impact at %.1f, %.1f." % [float(impact.get("x", 0.0)), float(impact.get("y", 0.0))]

func suggested_shot(state: Dictionary, player_id: String) -> Dictionary:
  var tanks: Dictionary = state.get("tanks", {})
  var opponent: Dictionary = tanks.get(_opponent_id(state, player_id), {})
  var best = {"angle": 45.0, "power": 52.0, "distance": INF}
  for angle in range(int(MIN_ANGLE), int(MAX_ANGLE) + 1):
    for power in range(int(MIN_POWER), int(MAX_POWER) + 1):
      var impact = _simulate(state, player_id, float(angle), float(power))
      var dx = float(impact.get("x", 0.0)) - float(opponent.get("x", 0.0))
      var dy = float(impact.get("y", 0.0)) - float(opponent.get("y", 0.0))
      var distance = sqrt(dx * dx + dy * dy)
      if distance < float(best["distance"]):
        best = {"angle": float(angle), "power": float(power), "distance": distance}
  return {"angle": best["angle"], "power": best["power"]}

func _simulate(state: Dictionary, player_id: String, angle: float, power: float) -> Dictionary:
  var terrain: Array = state.get("terrain", [])
  var tanks: Dictionary = state.get("tanks", {})
  var tank: Dictionary = tanks.get(player_id, {})
  var direction = 1.0 if String(tank.get("side", "left")) == "left" else -1.0
  var origin_x = float(tank.get("x", 0.0))
  var origin_y = float(tank.get("y", 0.0)) + 6.0
  var radians = deg_to_rad(angle)
  var vx = cos(radians) * power * direction
  var vy = sin(radians) * power
  var wind = float(state.get("wind", 0.0))

  var x = origin_x
  var y = origin_y
  var t = 0.0
  while t <= 12.0:
    x = origin_x + vx * t + 0.5 * wind * t * t
    y = origin_y + vy * t - 0.5 * GRAVITY * t * t
    if x < 0.0 or x > WORLD_WIDTH:
      return {"x": clamp(x, 0.0, WORLD_WIDTH), "y": max(0.0, y), "kind": "out"}
    if y <= _terrain_at(terrain, x):
      return {"x": round(x * 10.0) / 10.0, "y": round(_terrain_at(terrain, x) * 10.0) / 10.0, "kind": "terrain"}
    t += STEP
  return {"x": round(x * 10.0) / 10.0, "y": round(y * 10.0) / 10.0, "kind": "falloff"}

func _apply_crater(state: Dictionary, x: float) -> void:
  var terrain: Array = state.get("terrain", [])
  var center = int(round(clamp(x, 0.0, WORLD_WIDTH - 1.0)))
  for offset in range(-10, 11):
    var index = center + offset
    if index < 0 or index >= terrain.size():
      continue
    var depth = max(0.0, 9.0 - abs(float(offset)))
    terrain[index] = max(24.0, float(terrain[index]) - depth)
  state["terrain"] = terrain
  var craters: Array = state.get("craters", [])
  craters.append({"x": center, "radius": 10})
  state["craters"] = craters

func _make_terrain() -> Array:
  var terrain: Array = []
  for i in range(int(WORLD_WIDTH) + 1):
    var x = float(i)
    var height = 82.0 + 12.0 * sin(x / 37.0) + 6.0 * sin(x / 13.0)
    terrain.append(round(height * 10.0) / 10.0)
  return terrain

func _terrain_at(terrain: Array, x: float) -> float:
  if terrain.is_empty():
    return 80.0
  var index = int(round(clamp(x, 0.0, float(terrain.size() - 1))))
  return float(terrain[index])

func _has_tank(state: Dictionary, player_id: String) -> bool:
  var tanks: Dictionary = state.get("tanks", {})
  return tanks.has(player_id)

func _opponent_id(state: Dictionary, player_id: String) -> String:
  var players: Array = state.get("players", [])
  for player in players:
    var id = _player_id(player)
    if id != player_id:
      return id
  return ""

func _player_id(player: Variant) -> String:
  if typeof(player) == TYPE_DICTIONARY:
    return String(player.get("id", ""))
  return String(player)

func _next_wind(turn_number: int) -> float:
  var pattern = [-2.0, 3.0, 0.0, -4.0, 2.0, 1.0]
  return float(pattern[turn_number % pattern.size()])
