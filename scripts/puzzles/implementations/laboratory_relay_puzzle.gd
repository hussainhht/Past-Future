extends "res://scripts/puzzles/implementations/power_switch_puzzle.gd"
## Reuse the existing switch rules for the lab's auxiliary receiver relay.
## The radio link is its prerequisite, never its consequence.

const ID := "laboratory_receiver_relay"


func get_prerequisites() -> PackedStringArray:
	return PackedStringArray(["puzzle_01_frequency"])
