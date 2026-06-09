class_name GameModule
extends RefCounted

func init_state(_players: Array = []) -> Dictionary:
  return {}

func apply_move(state: Dictionary, _move: Dictionary) -> Dictionary:
  return deserialize(serialize(state))

func is_valid_move(_state: Dictionary, _move: Dictionary) -> bool:
  return false

func is_terminal(state: Dictionary) -> bool:
  return String(state.get("winner", "")) != ""

func render(state: Dictionary) -> String:
  return JSON.stringify(state)

func serialize(state: Dictionary) -> String:
  return JSON.stringify(state)

func deserialize(payload: String) -> Dictionary:
  var parsed: Variant = JSON.parse_string(payload)
  if typeof(parsed) == TYPE_DICTIONARY:
    return parsed
  return {}
