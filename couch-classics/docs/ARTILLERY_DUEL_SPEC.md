# Artillery Duel Spec

## Name

Artillery Duel

## State Shape

```json
{
  "players": [{"id": "p1", "display_name": "Player One"}],
  "turn_number": 1,
  "winner": "",
  "world_width": 320,
  "gravity": 9.8,
  "wind": -2.0,
  "terrain": [96, 95, 94],
  "tanks": {
    "p1": {"x": 36, "y": 88, "side": "left"},
    "p2": {"x": 284, "y": 88, "side": "right"}
  },
  "craters": [],
  "shots": [],
  "last_move": {}
}
```

## Move Shape

```json
{
  "player_id": "p1",
  "angle": 42,
  "power": 54
}
```

## Turn Rules

Players alternate projectile shots. Each shot starts at the active tank, applies
wind and gravity, and marches along a deterministic sampled path. Legal moves
use `angle` from 20 to 80 degrees and `power` from 28 to 72.

## Win Condition

The active player wins when the projectile lands within the blast radius of the
opponent tank. Terrain impacts create a crater in the serialized state and pass
the turn.

## Rendering Plan

The first screen uses original flat controls and a text terrain readout. Sliders
control angle and power; quick-shot buttons make the hotseat loop playable
without guessing.

## Backend Notes

The standard match blob and append-only move history are enough.

## Legal Notes

Original name, rules, code, and placeholder UI only.
