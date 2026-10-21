extends "res://scripts/puzzles/puzzle_base.gd"
## Rules only. PuzzleManager owns all commits, role assignment, RPCs and persistence.

const ID := "puzzle_01_frequency"
const DEFAULT_FREQUENCY := 67
const MIN_FREQUENCY := 1
const MAX_FREQUENCY := 999
const DEFAULT_AMPLITUDE := 70
const MIN_AMPLITUDE := 1
const MAX_AMPLITUDE := 100
const INITIAL_FREQUENCY := 50
const INITIAL_AMPLITUDE := 35

var target_frequency: int = DEFAULT_FREQUENCY
var target_amplitude: int = DEFAULT_AMPLITUDE


func get_initial_state() -> Dictionary:
	return {"student_radio": false, "professor_radio": false, "frequency_calibrated": false,
		"current_frequency": INITIAL_FREQUENCY, "current_amplitude": INITIAL_AMPLITUDE}


func get_actions() -> Dictionary:
	return {"acquire_radio": [PAST, FUTURE], "tune_frequency": [PAST], "tune_amplitude": [PAST]}


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
		var parameter := "frequency" if action == "tune_frequency" else "amplitude"
		if payload.size() != 1 or typeof(payload.get(parameter)) != TYPE_INT:
			return "invalid_" + parameter
		var maximum := MAX_FREQUENCY if parameter == "frequency" else MAX_AMPLITUDE
		if payload[parameter] < 1 or payload[parameter] > maximum:
			return parameter + "_out_of_range"
		if not state.get("student_radio", false):
			return "student_radio_required"
		if not state.get("professor_radio", false):
			return "professor_radio_required"
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
		var parameter := "frequency" if action == "tune_frequency" else "amplitude"
		var key := "current_" + parameter
		if state.get(key) == payload[parameter]:
			return no_change("Dial unchanged.")
		state[key] = payload[parameter]
		state.frequency_calibrated = state.current_frequency == target_frequency and state.current_amplitude == target_amplitude
	return change(state)


func is_solved(state: Dictionary) -> bool:
	return link_established(state)


static func ownership_key(role: String) -> String:
	return "student_radio" if role == PAST else "professor_radio"


static func link_established(state: Dictionary) -> bool:
	return radios_ready(state) and state.get("frequency_calibrated", false) == true


static func radios_ready(state: Dictionary) -> bool:
	return state.get("student_radio", false) == true and state.get("professor_radio", false) == true
