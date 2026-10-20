extends Node
## Presentation hook for one puzzle. Emits state_applied with the confirmed state when the
## node enters the scene and after every later change, so a door, light, or screen that
## loads after the puzzle changed still shows the right thing. Connect to state_applied
## and update visuals; never write to PuzzleManager from here.

signal state_applied(state: Dictionary, solved: bool)

@export var puzzle_id: String = ""


func _ready() -> void:
	PuzzleManager.puzzle_state_changed.connect(_on_puzzle_state_changed)
	refresh()


## Re-emit the current state, for example after toggling a visual's visibility.
func refresh() -> void:
	if PuzzleManager.has_state(puzzle_id):
		state_applied.emit(PuzzleManager.get_state(puzzle_id), PuzzleManager.is_solved(puzzle_id))


func _on_puzzle_state_changed(changed_id: String, state: Dictionary, _revision: int) -> void:
	if changed_id == puzzle_id:
		state_applied.emit(state, PuzzleManager.is_solved(puzzle_id))
