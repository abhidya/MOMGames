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
  {{godot}} --headless --path {{client}} --export-release "Web" ../build/web/index.html

build-android:
  mkdir -p couch-classics/build/android
  {{godot}} --headless --path {{client}} --export-debug "Android" ../build/android/couch-classics.apk

build-ios:
  mkdir -p couch-classics/build/ios
  {{godot}} --headless --path {{client}} --export-release "iOS" ../build/ios
