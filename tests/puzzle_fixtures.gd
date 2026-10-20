extends RefCounted
## Puzzles used only by the puzzle tests. They live outside PuzzleManager to show that new
## mechanics need no change to the core.

const Base := preload("res://scripts/puzzles/puzzle_base.gd")


## Temporal causality: one Past action produces a Past consequence and a Future consequence.
class BridgePuzzle extends "res://scripts/puzzles/puzzle_base.gd":
	func get_initial_state() -> Dictionary:
		return {"support_repaired": false, "bridge_accessible": false, "crossed": false}

	func get_actions() -> Dictionary:
		return {"repair_support": [PAST], "cross_bridge": [FUTURE]}

	func validate_action(action: String, payload: Dictionary, actor_role: String, state: Dictionary) -> String:
		var reason := super(action, payload, actor_role, state)
		if reason.is_empty() and action == "cross_bridge" and not state.bridge_accessible:
			return "bridge_not_accessible"
		return reason

	func apply_action(action: String, _payload: Dictionary, _actor_role: String, state: Dictionary) -> Dictionary:
		if action == "repair_support":
			if state.support_repaired:
				return no_change("already repaired")
			state.support_repaired = true
			state.bridge_accessible = true
		else:
			state.crossed = true
		return change(state)

	func is_solved(state: Dictionary) -> bool:
		return state.crossed


## Hidden answer, payload validation, either-role action, and a prerequisite on another puzzle.
class VaultPuzzle extends "res://scripts/puzzles/puzzle_base.gd":
	var _code: int  # host-only secret: never part of the replicated state
	var requires: PackedStringArray

	func _init(code: int, required_puzzles: PackedStringArray = PackedStringArray()) -> void:
		_code = code
		requires = required_puzzles

	func get_initial_state() -> Dictionary:
		return {"attempts": 0, "unlocked": false}

	func get_actions() -> Dictionary:
		return {"enter_code": []}

	func get_prerequisites() -> PackedStringArray:
		return requires

	func validate_action(action: String, payload: Dictionary, actor_role: String, state: Dictionary) -> String:
		var reason := super(action, payload, actor_role, state)
		if reason.is_empty() and not (payload.get("code") is int):
			return "invalid_payload"
		return reason

	func apply_action(_action: String, payload: Dictionary, _actor_role: String, state: Dictionary) -> Dictionary:
		if state.unlocked:
			return no_change("already unlocked")
		if payload.code == _code:
			state.unlocked = true
		else:
			state.attempts += 1
		return change(state)

	func is_solved(state: Dictionary) -> bool:
		return state.unlocked


## Everything a buggy puzzle could do wrong. The manager must contain all of it.
class MisbehavingPuzzle extends "res://scripts/puzzles/puzzle_base.gd":
	var shared_state := {"list": [1, 2], "solved": false}

	func get_initial_state() -> Dictionary:
		return shared_state  # hands out the same dictionary every time

	func get_actions() -> Dictionary:
		return {"no_state": [], "unknown_status": [], "same_state": [], "mutate_then_decline": []}

	func apply_action(action: String, _payload: Dictionary, _actor_role: String, state: Dictionary) -> Dictionary:
		match action:
			"no_state":
				return {"status": Status.CHANGED}  # forgot to say what the new state is
			"unknown_status":
				return {"status": 99}
			"same_state":
				return change(state)
			_:
				state.list.append(3)
				state.solved = true
				return no_change()


## The two-process test uses this to tell the other peer how far it has got.
class CheckpointPuzzle extends "res://scripts/puzzles/puzzle_base.gd":
	func get_initial_state() -> Dictionary:
		return {"step": 0}

	func get_actions() -> Dictionary:
		return {"reached": [FUTURE]}

	func validate_action(action: String, payload: Dictionary, actor_role: String, state: Dictionary) -> String:
		var reason := super(action, payload, actor_role, state)
		if reason.is_empty() and payload.get("step") != state.step + 1:
			return "invalid_payload"
		return reason

	func apply_action(_action: String, _payload: Dictionary, _actor_role: String, state: Dictionary) -> Dictionary:
		state.step += 1
		return change(state)


## Records every signal so tests can count exactly what listeners would see.
class Probe:
	var changed: Array = []
	var completed: Array = []
	var resets: Array = []
	var rejected: Array = []
	var started: int = 0
	var ended: int = 0

	func _init(manager: Node) -> void:
		manager.puzzle_state_changed.connect(func(id: String, state: Dictionary, revision: int) -> void: changed.append([id, state, revision]))
		manager.puzzle_completed.connect(func(id: String) -> void: completed.append(id))
		manager.puzzle_reset.connect(func(id: String) -> void: resets.append(id))
		manager.action_rejected.connect(func(id: String, action: String, reason: String, role: String) -> void: rejected.append([id, action, reason, role]))
		manager.session_started.connect(func() -> void: started += 1)
		manager.session_ended.connect(func() -> void: ended += 1)
