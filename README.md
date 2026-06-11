# MOMGames

This repository contains two things:

- **`ios/`** — the current direction: a native SwiftUI **iMessage app** that lets
  two people play turn-based games inside a Messages conversation. Each turn
  rides inside the message bubble (`MSMessage.url`), so there is **no backend and
  no accounts**. Built only on Apple's `Messages` framework — no OpenBubbles /
  OpenPigeon code — so the repo keeps its own license. See `ios/README.md`.
- **`couch-classics/`** — the original Godot 4 prototype the game logic was ported
  from. Kept for reference. The PocketBase backend has been removed; the iMessage
  edition delivers turns peer-to-peer over Messages instead.

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
ios/                      Native iMessage app (current direction).
  project.yml             XcodeGen project definition.
  App/                    Minimal container app required by Apple.
  MessagesExtension/      The iMessage extension.
    Model/                MatchEnvelope, payload coder, game kinds.
    Games/                Pure Swift game rules (ported from GDScript).
    Views/                SwiftUI board + duel UIs.
couch-classics/           Original Godot 4 prototype (reference only).
  client/                 Godot 4 project.
  docs/                   Architecture, legal rules, game spec template.
```

## Run

```bash
just doctor
just test-engine
just run-client
```

Build the iMessage app (requires a Mac with Xcode and XcodeGen):

```bash
just ios-open
```

This generates `ios/MOMGames.xcodeproj` and opens it in Xcode. Set your signing
team, then run on a device or simulator and open MOM Games from the Messages app
drawer. Full details in `ios/README.md`.

## Build (Godot reference prototype)

Web export of the original Godot prototype:

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
- Three original hotseat proof games: Checkers, Archery Duel, and Artillery
  Duel. They run through the same JSON match engine and support turn switching,
  terminal detection, and JSON round-tripping.

## Reference Boundary

OpenPigeon was inspected only for high-level architecture patterns: self-contained
game folders, primary scenes/scripts, and compact serialized turn payloads. No
OpenPigeon source or assets were copied into this repository.

## Next Steps

1. Replace placeholder UI shapes with final original art, fonts, and audio.
2. Add authenticated PocketBase flows in the Godot shell.
3. Add a browser realtime bridge or polling adapter for web turn notifications.
4. Harden export presets with Android signing and iOS Xcode project settings.
