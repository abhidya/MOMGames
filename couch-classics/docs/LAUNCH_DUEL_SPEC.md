# Launch Duel Spec

## Intent

Original two-player distance-launch duel inspired by the broad launch-and-bounce
arcade genre. No copied title, characters, art, text, code, or level layout.

## State Shape

- `players`: two player records.
- `turn_number`: starts at 1.
- `rounds_to_win`: launches each player receives.
- `wind`: deterministic per-turn modifier.
- `field`: JSON array of boost/drag zones.
- `launches`: append-only launch results.
- `scores`: player id to cumulative distance.
- `winner`: empty until all launches are taken.

## Move Shape

```json
{
  "player_id": "p1",
  "angle": 38,
  "power": 52
}
```

## Win Condition

After each player has taken three launches, the player with the highest
cumulative distance wins.

## Notes

This is designed as a clean-room game module. It uses deterministic simulation
so one JSON blob fully describes the match for asynchronous play.
