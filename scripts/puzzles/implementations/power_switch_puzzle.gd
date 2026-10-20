extends "res://scripts/puzzles/puzzle_base.gd"
## Reference implementation: copy this file to start a new puzzle.
## The Past player throws a switch; the Future player cannot. One accepted action
## changes the state, solves the puzzle, and nothing here knows about networking.


func get_initial_state() -> Dictionary:
	return {"solved": false, "power_on": false}


func get_actions() -> Dictionary:
	return {"activate_power": [PAST]}


func apply_action(_action: String, _payload: Dictionary, _actor_role: String, state: Dictionary) -> Dictionary:
	if state.power_on:
		return no_change("power is already on")
	state.power_on = true
	state.solved = true
	return change(state)
