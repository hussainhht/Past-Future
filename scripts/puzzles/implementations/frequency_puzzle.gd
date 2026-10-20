extends "res://scripts/puzzles/puzzle_base.gd"
## Rules only. PuzzleManager owns all commits, role assignment, RPCs and persistence.

const ID := "puzzle_01_frequency"
const DEFAULT_FREQUENCY := 67
const MIN_FREQUENCY := 1
const MAX_FREQUENCY := 999

var target_frequency: int = DEFAULT_FREQUENCY


func get_initial_state() -> Dictionary:
	return {"student_radio": false, "professor_radio": false, "frequency_calibrated": false}


func get_actions() -> Dictionary:
	return {"acquire_radio": [PAST, FUTURE], "tune_frequency": [PAST]}


func validate_action(action: String, payload: Dictionary, actor_role: String, state: Dictionary) -> String:
	var reason := super(action, payload, actor_role, state)
	if not reason.is_empty():
		return reason
	if action == "acquire_radio":
		if payload.size() != 1 or not (payload.get("radio_role") is String):
			return "invalid_payload"
		if payload.radio_role != actor_role:
			return "radio_not_yours"
	else:
		if payload.size() != 1 or typeof(payload.get("frequency")) != TYPE_INT:
			return "invalid_frequency"
		if payload.frequency < MIN_FREQUENCY or payload.frequency > MAX_FREQUENCY:
			return "frequency_out_of_range"
		if not state.get("student_radio", false):
			return "student_radio_required"
	return ""


func apply_action(action: String, payload: Dictionary, actor_role: String, state: Dictionary) -> Dictionary:
	if action == "acquire_radio":
		var key := ownership_key(actor_role)
		if state.get(key, false):
			return no_change("Radio already acquired.")
		state[key] = true
	else:
		if state.frequency_calibrated:
			return no_change("Frequency already locked.")
		if payload.frequency != target_frequency:
			return no_change("SIGNAL NOT FOUND")
		state.frequency_calibrated = true
	return change(state)


func is_solved(state: Dictionary) -> bool:
	return link_established(state)


static func ownership_key(role: String) -> String:
	return "student_radio" if role == PAST else "professor_radio"


static func link_established(state: Dictionary) -> bool:
	return state.get("student_radio", false) == true and state.get("professor_radio", false) == true and state.get("frequency_calibrated", false) == true
