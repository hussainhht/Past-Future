extends "res://scripts/puzzles/puzzle_base.gd"
## Level 02's canonical progression. All choices, costs and recovery survive scene changes.

const ID := "puzzle_02_maintenance"
const DESTINATION := "res://scenes/world/maintenance_corridor.tscn"
var support_solution := {"circle": 3, "triangle": 2, "square": 1}
var access_code := "3142"


func get_initial_state() -> Dictionary:
	return {"arrived_past": false, "arrived_future": false, "service_isolated": false,
		"battery_ready": false, "priority": "shared", "briefed_past": false,
		"briefed_future": false, "bypass_past": false, "bypass_future": false,
		"supports": {"circle": 1, "triangle": 1, "square": 1}, "supports_secured": false,
		"archive_read": false, "recording": "pending", "core_authorized": false,
		"future_release_open": false, "anchor_past": false, "anchor_future": false}


func get_prerequisites() -> PackedStringArray:
	return PackedStringArray(["puzzle_01_frequency"])


func get_actions() -> Dictionary:
	return {"arrive": [], "read_reserve_note": [], "reserve_power": [], "repair_bypass": [],
		"isolate_service": [PAST], "charge_battery": [FUTURE], "set_support": [PAST],
		"apply_supports": [PAST], "read_archive": [FUTURE], "preserve_recording": [FUTURE],
		"extract_cell": [FUTURE], "authorize_core": [PAST], "release_door": [FUTURE],
		"arm_anchor": []}


static func bypass_ready(state: Dictionary) -> bool:
	return state.get("bypass_past", false) and state.get("bypass_future", false)


static func has_power(state: Dictionary, role: String) -> bool:
	if not state.get("battery_ready", false):
		return false
	if bypass_ready(state):
		return true
	if role == PAST and state.get("recording", "pending") == "erased":
		return false
	return state.get("priority", "shared") in ["shared", role]


static func both_arrived(state: Dictionary) -> bool:
	return state.get("arrived_past", false) and state.get("arrived_future", false)


func validate_action(action: String, payload: Dictionary, role: String, state: Dictionary) -> String:
	var reason := super(action, payload, role, state)
	if not reason.is_empty():
		return reason
	if action == "set_support":
		if payload.size() != 2 or payload.get("support") not in support_solution or typeof(payload.get("stage")) != TYPE_INT:
			return "invalid_support"
		if payload.stage < 1 or payload.stage > 3:
			return "invalid_stage"
	elif action == "authorize_core":
		if payload.size() != 1 or not payload.get("code") is String or payload.code.length() > 8:
			return "invalid_code"
	elif not payload.is_empty():
		return "invalid_payload"
	if action in ["arrive", "read_reserve_note"]:
		return ""
	if action == "isolate_service":
		return ""
	if not state.service_isolated:
		return "isolate_service_first"
	if action in ["repair_bypass", "charge_battery"]:
		return ""
	if action == "reserve_power":
		if not state.get("briefed_" + role, false):
			return "read_reserve_instructions"
		if state.priority != "shared" and state.priority != role:
			return "reserve_already_allocated"
		if state.core_authorized or state.future_release_open:
			return "distribution_locked"
		return ""
	if action in ["set_support", "apply_supports"]:
		if state.supports_secured:
			return "supports_locked"
		return "" if has_power(state, PAST) else "past_auxiliary_feed_offline"
	if not state.supports_secured:
		return "secure_crossing_first"
	if action == "read_archive":
		return "" if has_power(state, FUTURE) else "future_auxiliary_feed_offline"
	if action in ["preserve_recording", "extract_cell"]:
		if not state.archive_read:
			return "read_archive_first"
		if state.recording != "pending":
			return "recording_already_resolved"
		if action == "preserve_recording" and not bypass_ready(state):
			return "repair_both_bypass_ends"
		return ""
	if not state.archive_read or state.recording == "pending":
		return "resolve_archive_recording"
	if action == "authorize_core":
		return "" if has_power(state, PAST) else "past_auxiliary_feed_offline"
	if action == "release_door":
		if state.recording == "erased" or state.priority == FUTURE or state.core_authorized:
			return ""
		return "await_core_authorization"
	if action == "arm_anchor":
		if role == PAST and not state.core_authorized:
			return "authorize_core_first"
		if role == FUTURE and not state.future_release_open:
			return "release_door_first"
	return ""


func apply_action(action: String, payload: Dictionary, role: String, state: Dictionary) -> Dictionary:
	var key := ""
	match action:
		"arrive": key = "arrived_" + role
		"read_reserve_note": key = "briefed_" + role
		"isolate_service": key = "service_isolated"
		"charge_battery": key = "battery_ready"
		"repair_bypass": key = "bypass_" + role
		"read_archive": key = "archive_read"
		"arm_anchor": key = "anchor_" + role
		"release_door": key = "future_release_open"
		"reserve_power":
			if state.priority == role:
				return no_change("Local reserve is already engaged.")
			state.priority = role
			state.battery_ready = true
		"set_support":
			if state.supports[payload.support] == payload.stage:
				return no_change()
			state.supports[payload.support] = payload.stage
		"apply_supports":
			for support in support_solution:
				if state.supports[support] != support_solution[support]:
					return no_change("Unsafe load at %s. Check the Future diagnostic diagram." % support.to_upper())
			key = "supports_secured"
		"preserve_recording": state.recording = "preserved"
		"extract_cell": state.recording = "erased"
		"authorize_core":
			if payload.code != access_code:
				return no_change("Code refused. The service record is in the Future archive.")
			key = "core_authorized"
	if not key.is_empty():
		if state[key]:
			return no_change("Already confirmed.")
		state[key] = true
	return change(state)


func is_solved(state: Dictionary) -> bool:
	return state.get("anchor_past", false) and state.get("anchor_future", false)
