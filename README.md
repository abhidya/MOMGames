# MOMGames

This repository contains `couch-classics/`, a Godot 4 app for asynchronous
turn-based games with a PocketBase backend. The current slice is a mobile-first
hotseat shell with Checkers running through the shared JSON turn engine.

## Phase 0 Tooling

| Tool | Version detected | Status |
| --- | --- | --- |
| Godot | 4.6.3.stable.official.7d41c59c4 | installed |
| Godot export templates | 4.6.3.stable | installing/verified by `just doctor` |
| PocketBase | 0.39.3 | installed |
| Git | 2.50.1 (Apple Git-155) | present |
| just | 1.52.0 | installed |
| Make | GNU Make 3.81 | present fallback |
| Node | v25.6.1 | present, not required by this scaffold |

## Structure

```text
couch-classics/
  client/                 Godot 4 project.
    autoload/             App-wide singletons for state, backend, audio, theme.
    core/                 Generic match model, module interface, turn engine.
    games/                Self-contained game modules and screens.
    ui/                   Shared shell screens and flow host.
    assets/               Original placeholder assets only.
    theme/                Design tokens and app style helpers.
  backend/                PocketBase migrations, hooks, seed data.
  docs/                   Architecture, legal rules, game spec template.
  build/                  Local export output, ignored by Git.
```

## Run

```bash
just doctor
just test-engine
just run-client
```

Run the backend locally:

```bash
just run-backend
```

PocketBase starts at `http://127.0.0.1:8090`. The migration extends `users`
with `handle`/`display_name` fields and creates `matches`, `moves`, and
`notification_stubs`; a seed migration creates local users `alice@example.test`
and `bob@example.test` with password
`couchclassics123`.

## Build

Web export is the primary target:

```bash
just build-web
```

The output lands in `couch-classics/build/web/` and can be hosted on any static
host. The current recipe uses Godot's non-threaded web template, so it avoids
SharedArrayBuffer headers for local testing. Cloudflare Pages is the recommended
free hosting option.

Android and iOS are Phase 6 follow-ups. The `just build-android` and
`just build-ios` tasks intentionally fail with setup instructions until signing
and platform presets are configured.

Android debug APK, after Phase 6 setup:

```bash
just build-android
```

iOS export, after Phase 6 setup:

```bash
just build-ios
```

The iOS path intentionally stops at an Xcode-ready export. TestFlight requires
the Apple Developer Program, signing assets, a one-time beta review for the
first build, and rebuilds before the roughly 90 day beta expiration window.

## Current Vertical Slice

- Generic `MatchModel` with `id`, `game_id`, `players`, `current_turn`, opaque
  JSON `state`, `status`, `winner`, and `updated_at`.
- `GameModule` interface for game-specific state, validation, moves, terminal
  checks, rendering, and JSON serialization.
- Local hotseat mode with no backend dependency.
- Mobile portrait app shell: match list, new game flow, game host, settings
  stub, and polished theme tokens.
- Checkers implemented as the first proof of the engine. It supports normal
  diagonal moves, captures, kings, forced captures, turn switching, JSON
  round-tripping, and terminal detection.

## Reference Boundary

OpenPigeon was inspected only for high-level architecture patterns: self-contained
game folders, primary scenes/scripts, and compact serialized turn payloads. No
OpenPigeon source or assets were copied into this repository.

## Next Steps

1. Write specs for Archery Duel and Artillery Duel in `docs/` using
   `GAME_SPEC_TEMPLATE.md`, then get sign-off before implementation.
2. Replace placeholder UI shapes with final original art, fonts, and audio.
3. Add authenticated PocketBase flows in the Godot shell.
4. Add a browser realtime bridge or polling adapter for web turn notifications.
5. Harden export presets with Android signing and iOS Xcode project settings.
