extends "res://scripts/puzzles/puzzle_base.gd"
## Reactor rules. Only public facts enter PuzzleManager's replicated dictionary.
## Votes, deadlines and duplicate-request counters stay in the host's rules object.

const ID := "puzzle_03_final_fracture"
const CHALLENGE_SECONDS := 150.0
const SYNC_WINDOW := 5.0
const COIL_TARGET := [2, 0, 1]
const COMMANDS := {PAST: ["GROUND THE CORE", "CLAIM ORIGIN"], FUTURE: ["RELEASE THE ECHO", "PRESERVE ECHO"]}
const STATIONS := {
	"start": Vector3(0, 0, 4.5),
	"coil_0": Vector3(-6, 0, -2), "coil_1": Vector3(-6, 0, 0), "coil_2": Vector3(-6, 0, 2),
	"receiver": Vector3(6, 0, 3), "anchor": Vector3(6, 0, -3),
	"origin": Vector3(-3, 0, -3), "sync_past": Vector3(-2.5, 0, 0), "sync_future": Vector3(2.5, 0, 0),
	"terminal_past": Vector3(-3.5, 0, 3), "terminal_future": Vector3(3.5, 0, 3),
	"evidence_past": Vector3(-7, 0, 4.5), "warning": Vector3(-7, 0, -4.5),
	"evidence_future": Vector3(7, 0, 4.5), "routing": Vector3(7, 0, 0.5)
}

var challenge_seconds: float = CHALLENGE_SECONDS
var clock: Callable = func() -> float: return Time.get_ticks_usec() / 1000000.0
var proximity: Callable
var available: Callable
var _deadline: float = 0.0
var _sync_deadline: float = 0.0
var _meltdown_at: float = 0.0
var _choices: Dictionary = {}
var _sequences: Dictionary = {PAST: 0, FUTURE: 0}
# Shared across rules replacements, so returning from another room cannot reuse
# an attempt number from an earlier visit in the same process/session.
static var _attempt_serial: int = 0


func get_initial_state() -> Dictionary:
	_attempt_serial += 1
	_choices.clear()
	_sequences = {PAST: 0, FUTURE: 0}
	_deadline = 0.0
	_sync_deadline = 0.0
	_meltdown_at = 0.0
	return {"stage": "DISCOVERY", "attempt": _attempt_serial, "remaining": challenge_seconds,
		"meltdown_elapsed": 0.0,
		"coils": [0, 0, 0], "receiver": false, "anchor": false, "origin": false,
		"sync_past": false, "sync_future": false, "sync_remaining": 0.0,
		"locked_past": false, "locked_future": false, "ending": "", "solved": false,
		"notice": "Explore the records. The reactor is idle; there is no time limit yet."}


func get_actions() -> Dictionary:
	return {"start": [], "coil": [PAST], "receiver": [FUTURE], "anchor": [FUTURE],
		"origin": [PAST], "sync": [], "choose": [], "replay": [PAST]}


func station_for(action: String, payload: Dictionary, role: String) -> String:
	match action:
		"coil": return "coil_%s" % payload.get("index", -1)
		"sync": return "sync_" + role
		"choose": return "terminal_" + role
	return action


func validate_action(action: String, payload: Dictionary, role: String, state: Dictionary) -> String:
	var reason := super(action, payload, role, state)
	if not reason.is_empty(): return reason
	if available.is_valid() and not available.call(): return "partner_unavailable"
	if typeof(payload.get("attempt")) != TYPE_INT or payload.attempt != state.attempt: return "stale_attempt"
	if typeof(payload.get("seq")) != TYPE_INT or payload.seq <= int(_sequences[role]): return "duplicate_request"
	var keys := ["attempt", "seq"]
	if action == "coil": keys.append("index")
	if action == "choose": keys.append("command")
	if payload.size() != keys.size(): return "invalid_payload"
	for key in keys:
		if not payload.has(key): return "invalid_payload"
	if action == "coil" and (typeof(payload.index) != TYPE_INT or payload.index < 0 or payload.index > 2): return "invalid_coil"
	if action == "choose" and (not payload.command is String or not payload.command in COMMANDS[role]): return "invalid_command"
	if action == "replay":
		return "" if state.stage == "ENDING" else "wrong_stage"
	if state.stage in ["ENDING", "OVERLOAD"]: return "wrong_stage"
	if state.stage != "DISCOVERY" and clock.call() >= _deadline: return "expired"
	if proximity.is_valid() and not proximity.call(role, station_for(action, payload, role)): return "too_far"
	match action:
		"start":
			if state.stage != "DISCOVERY": return "already_started"
		"coil", "receiver":
			if state.stage != "STAGE_A": return "wrong_stage"
			if action == "receiver" and state.receiver: return "already_repaired"
		"anchor", "origin", "sync":
			if state.stage != "STAGE_B": return "wrong_stage"
			if action == "anchor" and state.anchor: return "already_repaired"
			if action == "origin" and not state.anchor: return "anchor_required"
			if action == "origin" and state.origin: return "already_stable"
			if action == "sync":
				if not state.anchor or not state.origin: return "calibration_required"
				if state["sync_" + role]: return "already_pressed"
		"choose":
			if state.stage != "STAGE_C": return "wrong_stage"
			if _choices.has(role): return "choice_locked"
	return ""


func apply_action(action: String, payload: Dictionary, role: String, state: Dictionary) -> Dictionary:
	_sequences[role] = payload.seq
	match action:
		"start":
			_deadline = float(clock.call()) + challenge_seconds
			state.stage = "STAGE_A"
			state.notice = "Professor: We have two and a half minutes. Keep the connection alive."
		"coil":
			state.coils[payload.index] = (int(state.coils[payload.index]) + 1) % 3
			state.notice = "Relay %d now reads %d. Adjustments are reversible." % [payload.index + 1, state.coils[payload.index]]
		"receiver":
			state.receiver = true
			state.notice = "Receiver restored. Professor: I can read the routing diagram now."
		"anchor":
			state.anchor = true
			state.notice = "Signal Anchor calibrated. The Past waveform is now visible."
		"origin":
			state.origin = true
			state.notice = "Origin stabilized. Both phase switches are ready. Press within five seconds."
		"sync":
			if _sync_deadline == 0.0: _sync_deadline = float(clock.call()) + SYNC_WINDOW
			state["sync_" + role] = true
			state.notice = "One phase switch held. Waiting for the other timeline."
			if state.sync_past and state.sync_future:
				state.stage = "STAGE_C"
				state.sync_remaining = 0.0
				state.notice = "Professor: I didn't tell you everything. I didn't think you would help me if you knew."
		"choose":
			_choices[role] = payload.command
			state["locked_" + role] = true
			state.notice = "An identity command is locked. Waiting for the other terminal."
			if _choices.size() == 2:
				state.ending = ending_for(_choices[PAST], _choices[FUTURE])
				state.stage = "ENDING"
				state.solved = true
				_deadline = 0.0
		"replay":
			return change(get_initial_state())
	if state.stage == "STAGE_A" and state.receiver and state.coils == COIL_TARGET:
		state.stage = "STAGE_B"
		state.notice = "Power restored across 31 years. Student: The broken conduit is rebuilding."
	return change(state)


## Invoked through PuzzleManager's host-only refresh hook, also before every action.
func refresh_state(state: Dictionary) -> Dictionary:
	if not clock.is_valid(): return no_change()
	var now: float = clock.call()
	if state.stage == "OVERLOAD":
		# Latched failure: only GameFlowManager may start the next campaign.
		state.meltdown_elapsed = clampf(now - _meltdown_at, 0.0, 5.0)
		return change(state)
	if not state.stage in ["STAGE_A", "STAGE_B", "STAGE_C"]: return no_change()
	state.remaining = maxf(0.0, _deadline - now)
	if state.remaining <= 0.0:
		state.stage = "OVERLOAD"
		state.notice = "CONTAINMENT LOST / Both timelines are collapsing."
		_meltdown_at = now
		state.meltdown_elapsed = 0.0
		_choices.clear()
		return change(state)
	if state.stage == "STAGE_B" and _sync_deadline > 0.0:
		state.sync_remaining = maxf(0.0, _sync_deadline - now)
		if now >= _sync_deadline:
			state.sync_past = false
			state.sync_future = false
			_sync_deadline = 0.0
			state.notice = "Phase window missed. Both switches reset; try together again."
	return change(state)


static func ending_for(student: String, professor: String) -> String:
	if student == "CLAIM ORIGIN":
		return "paradox" if professor == "PRESERVE ECHO" else "student_override"
	return "professor_override" if professor == "PRESERVE ECHO" else "trust"
