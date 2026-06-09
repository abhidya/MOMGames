# Game Spec Template

Copy this file before implementing a new game. Get sign-off on the spec before
writing game logic.

## Game Name

Use a generic original name.

## Player Count

Usually two players for this app.

## State Shape

List every field stored in the JSON state blob.

```json
{
  "example": true
}
```

## Move Shape

List every field accepted by `is_valid_move()` and `apply_move()`.

```json
{
  "player_id": "p1",
  "action": "example"
}
```

## Turn Rules

Describe who may act, how turns advance, and whether a move can create extra
actions.

## Win Condition

Describe terminal states and how `winner` is set.

## Rendering Plan

Describe how the screen maps state to controls or visuals.

## Backend Notes

Describe any replay or move-audit requirements beyond the standard match blob.

## Legal Notes

Confirm original name, original assets, and no copied source.
