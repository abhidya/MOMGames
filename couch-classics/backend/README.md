# Couch Classics Backend

PocketBase stores canonical match state and move history.

Run from the repository root:

```bash
just run-backend
just test-backend
just test-network
```

Collections:

- `users`: auth collection with `handle` and `display_name`.
- `matches`: current match state and turn owner.
- `moves`: append-only move audit trail.
- `notification_stubs`: local placeholder for future push notifications.

Clients create `matches`, append `moves`, and then refetch the hook-updated
match. Direct match updates are locked to superusers/server hooks.

PocketBase realtime supports collection subscriptions over Server-Sent Events.
The current Godot shell uses REST refresh/submission; realtime push into open
screens is the next networking milestone.
