extends Node

var muted := false

func play_ui_tick() -> void:
  if muted:
    return
  # Placeholder for original UI audio.
  pass

func set_muted(value: bool) -> void:
  muted = value
