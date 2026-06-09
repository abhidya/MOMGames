# Couch Classics

Couch Classics is a Godot 4 app for asynchronous two-player games. A whole game
state serializes into one JSON blob; each move validates against that blob,
produces a new blob, and can be sent later through PocketBase.

## Folders

- `client/`: Godot project and all original app code.
- `client/autoload/`: global state, backend client stub, audio stub, and theme
  tokens.
- `client/core/`: game-agnostic match model, module contract, and turn engine.
- `client/games/`: one self-contained folder per game.
- `client/ui/`: mobile portrait shell screens and routing host.
- `client/assets/`: original placeholder assets.
- `client/theme/`: design token helpers.
- `backend/`: PocketBase migrations, hooks, seed users, and local data.
- `docs/`: architecture, legal rules, and game-spec template.
- `build/`: ignored local exports.

## Commands

Run from the repository root:

```bash
just doctor
just test-engine
just run-client
just run-backend
just build-web
```

## Backend Dev Accounts

The seed migration creates:

- `alice@example.test` / `couchclassics123` with handle `alice`
- `bob@example.test` / `couchclassics123` with handle `bob`

These are local development users only.
