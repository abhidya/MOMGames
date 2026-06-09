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
- `games/<game_id>/`: module, screen, and game-specific helpers.

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
next player. PocketBase realtime can subscribe to `matches` and `moves`; the
Godot web client still needs a browser SSE bridge or polling adapter before
network play is enabled in the shell.

## Export Strategy

Web is first. Godot 4 web exports require the Compatibility renderer and a host
that supports cross-origin isolation headers when threaded templates are used.
Android and iOS exports are configured as follow-on targets, with signing left
outside automation.
