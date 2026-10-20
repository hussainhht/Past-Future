extends Node3D
## Fixture: a room that never finishes initialising, to exercise the transition timeout and rollback.


func is_game_flow_ready() -> bool:
	return false
