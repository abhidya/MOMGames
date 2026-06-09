# Archery Duel Spec

## Name

Archery Duel

## State Shape

```json
{
  "players": [{"id": "p1", "display_name": "Player One"}],
  "turn_number": 1,
  "winner": "",
  "target_distance": 98.0,
  "hit_radius": 6.0,
  "wind": 0.0,
  "shots": [],
  "last_move": {}
}
```

## Move Shape

```json
{
  "player_id": "p1",
  "angle": 45,
  "power": 31
}
```

## Turn Rules

Players alternate single shots. A move is legal when it belongs to the current
turn owner and uses `angle` from 15 to 75 degrees and `power` from 18 to 42.
Wind changes deterministically after every miss so a whole match remains
replayable from JSON.

## Win Condition

The active player wins immediately when the calculated arrow landing point is
within `hit_radius` of `target_distance`.

## Rendering Plan

The screen shows the current archer, target distance, wind, angle/power sliders,
quick-shot buttons, and a shot history. Placeholder visuals are original styled
controls, not external art.

## Backend Notes

The standard match blob and append-only move history are enough.

## Legal Notes

Original name, rules, code, and placeholder UI only.
