# Checkers Spec

## Name

Checkers

## State Shape

```json
{
  "board": [["", "b", "", "b", "", "b", "", "b"]],
  "players": [{"id": "p1", "display_name": "Player One"}],
  "turn_number": 1,
  "winner": "",
  "last_move": {},
  "rules": {"forced_capture": true, "multi_jump": false}
}
```

## Move Shape

```json
{
  "player_id": "p1",
  "from": [5, 0],
  "to": [4, 1]
}
```

## Turn Rules

Player one controls red pieces and moves first. Player two controls black
pieces. Men move diagonally forward. Kings move diagonally in either direction.
Captures are mandatory when available. This vertical slice resolves one capture
per turn; multi-jump chaining is intentionally deferred.

## Win Condition

A player wins when the opponent has no pieces or no legal move after the turn.

## Rendering Plan

The first screen uses original styled UI controls rather than imported sprites.
Each square is a fixed button; pieces are represented by color and letter labels.
