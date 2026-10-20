extends RefCounted
## Rules for one puzzle. PuzzleManager owns state, validation order, and networking;
## an implementation only answers "may this role do this?" and "what is the new state?".
## Extend it with: extends "res://scripts/puzzles/puzzle_base.gd"
##
## Hidden answers (target codes, solutions) belong in member variables of the implementation.
## The state dictionary is replicated to both players; members stay on the host.

## Puzzles produce REJECTED, NO_CHANGE and CHANGED. PuzzleManager upgrades CHANGED to
## COMPLETED when the action solved the puzzle, and answers remote requests with PENDING.
enum Status { REJECTED, NO_CHANGE, CHANGED, COMPLETED, PENDING }

const PAST := "past"
const FUTURE := "future"

## Assigned by PuzzleManager.register_puzzle(). Handy for prerequisite lookups.
var puzzle_id: String = ""


## State the puzzle starts in and returns to on reset. Called on the host only, so
## this is also the place to roll a random secret.
func get_initial_state() -> Dictionary:
	return {"solved": false}


## Every action this puzzle understands, mapped to the roles allowed to perform it.
## An empty role list means either timeline may.
func get_actions() -> Dictionary:
	return {}


## Puzzle IDs that must be solved before this puzzle accepts any action.
func get_prerequisites() -> PackedStringArray:
	return PackedStringArray()


## Return "" when the request is acceptable, otherwise a short reason code such as "invalid_payload".
## The default checks that the action exists and the role may use it. Override, call super() first,
## then check the payload and state. Never trust the payload: it came from a player.
func validate_action(action: String, _payload: Dictionary, actor_role: String, _state: Dictionary) -> String:
	var actions := get_actions()
	if not actions.has(action):
		return "unknown_action"
	var roles: Array = actions[action]
	if not roles.is_empty() and not roles.has(actor_role):
		return "role_not_allowed"
	return ""


## Run a validated action. `state` is a private copy: edit it and return change(state),
## or return no_change() / reject(). Only the returned state is ever kept.
func apply_action(_action: String, _payload: Dictionary, _actor_role: String, _state: Dictionary) -> Dictionary:
	return reject("not_implemented", "%s does not override apply_action()" % puzzle_id)


## Completion condition, derived from state alone. The default reads state.solved.
func is_solved(state: Dictionary) -> bool:
	return state.get("solved", false) == true


static func reject(reason: String, message: String = "") -> Dictionary:
	return {"status": Status.REJECTED, "reason": reason, "message": message}


static func no_change(message: String = "") -> Dictionary:
	return {"status": Status.NO_CHANGE, "message": message}


static func change(new_state: Dictionary) -> Dictionary:
	return {"status": Status.CHANGED, "state": new_state}
