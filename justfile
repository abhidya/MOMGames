set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

godot := env_var_or_default("GODOT_BIN", "godot")
client := "couch-classics/client"
ios := "ios"

default:
  @just --list

doctor:
  @printf "%-14s %-28s %s\n" "tool" "version" "status"
  @printf "%-14s %-28s %s\n" "Godot" "$({{godot}} --version 2>/dev/null || echo missing)" "$(command -v {{godot}} >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "XcodeGen" "$(xcodegen --version 2>/dev/null || echo missing)" "$(command -v xcodegen >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "Git" "$(git --version 2>/dev/null || echo missing)" "$(command -v git >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "just" "$(just --version 2>/dev/null || echo missing)" "$(command -v just >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "Make" "$(make --version 2>/dev/null | head -1 || echo missing)" "$(command -v make >/dev/null && echo present || echo missing)"
  @printf "%-14s %-28s %s\n" "Node" "$(node --version 2>/dev/null || echo skipped)" "$(command -v node >/dev/null && echo present || echo skipped)"
  @test -d "$HOME/Library/Application Support/Godot/export_templates/4.6.3.stable" && printf "%-14s %-28s %s\n" "Templates" "4.6.3.stable" "present" || printf "%-14s %-28s %s\n" "Templates" "4.6.3.stable" "missing"

run-client:
  {{godot}} --path {{client}}

test-engine:
  {{godot}} --headless --path {{client}} --script tests/checkers_engine_smoke.gd
  {{godot}} --headless --path {{client}} --script tests/full_engine_smoke.gd

# iMessage app (native SwiftUI). Requires a Mac with Xcode + XcodeGen.
ios-generate:
  cd {{ios}} && xcodegen generate

ios-open: ios-generate
  open {{ios}}/MOMGames.xcodeproj

build-web:
  rm -rf couch-classics/build/web/*
  mkdir -p couch-classics/build/web
  {{godot}} --headless --path {{client}} --export-pack "Web" ../build/web/index.pck
  unzip -oq "$HOME/Library/Application Support/Godot/export_templates/4.6.3.stable/web_nothreads_release.zip" -d couch-classics/build/web
  mv couch-classics/build/web/godot.js couch-classics/build/web/index.js
  mv couch-classics/build/web/godot.wasm couch-classics/build/web/index.wasm
  mv couch-classics/build/web/godot.audio.worklet.js couch-classics/build/web/index.audio.worklet.js
  mv couch-classics/build/web/godot.audio.position.worklet.js couch-classics/build/web/index.audio.position.worklet.js
  cp couch-classics/client/web_shell.html couch-classics/build/web/index.html

build-android:
  rm -rf couch-classics/build/android/*
  mkdir -p couch-classics/build/android
  GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/Library/Application Support/Godot/keystores/debug.keystore}" \
  GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}" \
  GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}" \
  {{godot}} --headless --path {{client}} --export-debug "Android" ../build/android/couch-classics-debug.apk

build-ios:
  rm -rf couch-classics/build/ios/export
  rm -f couch-classics/build/ios/couch-classics-xcode.zip
  mkdir -p couch-classics/build/ios
  mkdir -p couch-classics/build/ios/export
  {{godot}} --headless --path {{client}} --export-release "iOS" ../build/ios/export/couch-classics.zip
  cd couch-classics/build/ios/export && zip -qry ../couch-classics-xcode.zip .
