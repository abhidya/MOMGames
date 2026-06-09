# Couch Classics Backend

PocketBase stores canonical match state and move history.

Run from the repository root:

```bash
just run-backend
```

Collections:

- `users`: auth collection with `handle` and `display_name`.
- `matches`: current match state and turn owner.
- `moves`: append-only move audit trail.
- `notification_stubs`: local placeholder for future push notifications.

PocketBase realtime supports collection subscriptions over Server-Sent Events.
The Godot shell currently runs hotseat locally; network match wiring is the next
client milestone.
