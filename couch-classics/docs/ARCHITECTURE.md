# Architecture

## Goal

Couch Classics is built around asynchronous turns. The client can run a full
game locally, serialize the whole match state to JSON, and later send that state
through PocketBase so another device can continue the match.

## Client

The Godot project is intentionally split into generic engine code and isolated
game modules:

- `autoload/GameState`: owns local matches, registered modules, selected match,
  and hotseat move application.
- `autoload/Net`: keeps PocketBase endpoint/auth state and exposes the backend
  methods the shell will call when network play is enabled.
- `autoload/ThemeTokens`: central palette, spacing, and reusable style boxes.
- `core/MatchModel`: plain match data with JSON round-trip helpers.
- `core/GameModule`: interface every game implements.
- `core/MatchEngine`: validates turn ownership, calls the active module, flips
  turns, and updates status/winner.
- `games/<game_id>/`: module, screen, and game-specific helpers. Checkers,
  Archery Duel, Artillery Duel, and Launch Duel are currently playable in
  hotseat mode.

## Match State

`MatchModel.state` is opaque to the engine. The game module owns the schema and
must make it fully JSON-serializable. This keeps backend sync simple: the backend
stores the latest canonical blob, while `moves` records keep the audit trail.

## Game Module Contract

Every game module implements:

- `init_state(players)`
- `is_valid_move(state, move)`
- `apply_move(state, move)`
- `is_terminal(state)`
- `render(state)`
- `serialize(state)`
- `deserialize(payload)`

The engine treats modules as pure state transformers. Screens turn player input
into `move` dictionaries and let the engine decide whether the move is legal.

## Backend

PocketBase provides:

- `users`: auth records with local `handle` and `display_name` fields.
- `matches`: canonical match record with `game_id`, `players`, `current_turn`,
  `state`, `status`, `winner`, and invite metadata.
- `moves`: append-only turn history with the submitted move and resulting state.
- `notification_stubs`: local records representing future push notifications.

The `moves` hook updates the parent match and writes a notification stub for the
next player. Direct client updates to `matches` are locked; clients append moves
and then refetch the match record updated by the hook.

The Godot client currently uses REST calls for auth, match listing, match
creation, and move submission. Realtime is still represented as a seam:
PocketBase can subscribe to `matches` and `moves`, but the Godot web client will
need a browser SSE bridge, polling adapter, or native plugin before passive turn
notifications update the open screen automatically.

## Export Strategy

Web is first. The project uses the Compatibility renderer and the no-threaded
web template so the generated `build/web/` folder can be served by a simple
static host without cross-origin isolation headers.

Android exports produce a local signed debug APK at
`build/android/couch-classics-debug.apk`. The release signing key is intentionally
not stored in the repository.

iOS exports produce a zipped Xcode project at
`build/ios/couch-classics-xcode.zip`. The preset uses a placeholder Apple Team
ID only to make project-file export deterministic; real TestFlight signing still
requires Apple Developer credentials in Xcode.
