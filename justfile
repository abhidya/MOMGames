set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

godot := env_var_or_default("GODOT_BIN", "godot")
client := "couch-classics/client"
backend := "couch-classics/backend"

default:
  @just --list

doctor:
  @printf "%-14s %-28s %s\n" "tool" "version" "status"
  @printf "%-14s %-28s %s\n" "Godot" "$({{godot}} --version 2>/dev/null || echo missing)" "$(command -v {{godot}} >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "PocketBase" "$(pocketbase --version 2>/dev/null || echo missing)" "$(command -v pocketbase >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "Git" "$(git --version 2>/dev/null || echo missing)" "$(command -v git >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "just" "$(just --version 2>/dev/null || echo missing)" "$(command -v just >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "Make" "$(make --version 2>/dev/null | head -1 || echo missing)" "$(command -v make >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "Node" "$(node --version 2>/dev/null || echo skipped)" "$(command -v node >/dev/null && echo present || echo skipped)"
  @test -d "$HOME/Library/Application Support/Godot/export_templates/4.6.3.stable" && printf "%-14s %-28s %s\n" "Templates" "4.6.3.stable" "present" || printf "%-14s %-28s %s\n" "Templates" "4.6.3.stable" "missing"

run-client:
  {{godot}} --path {{client}}

test-engine:
  {{godot}} --headless --path {{client}} --script tests/checkers_engine_smoke.gd

run-backend:
  cd {{backend}} && pocketbase serve --http 127.0.0.1:8090 --dir pb_data --hooksDir pb_hooks --migrationsDir pb_migrations

migrate-backend:
  cd {{backend}} && pocketbase migrate up --dir pb_data --migrationsDir pb_migrations

seed-backend:
  cd {{backend}} && pocketbase migrate up --dir pb_data --migrationsDir pb_migrations

build-web:
  mkdir -p couch-classics/build/web
  mkdir -p couch-classics/client/exported/web
  {{godot}} --headless --path {{client}} --export-pack "Web" exported/web/index.pck
  rm -rf couch-classics/build/web/*
  unzip -oq "$HOME/Library/Application Support/Godot/export_templates/4.6.3.stable/web_nothreads_release.zip" -d couch-classics/build/web
  mv couch-classics/build/web/godot.js couch-classics/build/web/index.js
  mv couch-classics/build/web/godot.wasm couch-classics/build/web/index.wasm
  mv couch-classics/build/web/godot.audio.worklet.js couch-classics/build/web/index.audio.worklet.js
  mv couch-classics/build/web/godot.audio.position.worklet.js couch-classics/build/web/index.audio.position.worklet.js
  cp couch-classics/client/exported/web/index.pck couch-classics/build/web/index.pck
  cp couch-classics/client/web_shell.html couch-classics/build/web/index.html

build-android:
  @echo "Android export is a Phase 6 task: add Android SDK/signing settings and an Android export preset first."
  @exit 1

build-ios:
  @echo "iOS export is a Phase 6 task: add Apple signing settings and an iOS export preset first."
  @exit 1
