extends Node
## Place in each participating room on both peers. Never starts or resets a session.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")

signal temporal_radio_link_established

@export_range(1, 999, 1) var target_frequency: int = Rules.DEFAULT_FREQUENCY
@export_range(1, 100, 1) var target_amplitude: int = Rules.DEFAULT_AMPLITUDE


func _ready() -> void:
	if not PuzzleManager.is_registered(Rules.ID):
		var rules := Rules.new()
		rules.target_frequency = target_frequency
		rules.target_amplitude = target_amplitude
		PuzzleManager.register_puzzle(Rules.ID, rules)
	PuzzleManager.puzzle_completed.connect(_on_completed)


func is_temporal_link_established() -> bool:
	return Rules.link_established(PuzzleManager.get_state(Rules.ID))


func _on_completed(puzzle_id: String) -> void:
	if puzzle_id == Rules.ID:
		temporal_radio_link_established.emit()
