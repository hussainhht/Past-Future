extends "res://scripts/interaction/interactable_3d.gd"
## World acquisition endpoint. Hides the replaceable mesh only after host confirmation.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")

signal acquisition_submitted(result: Dictionary)
signal radio_acquired(role: String)

@export_enum("past", "future") var radio_role: String = "past"
@export var placeholder: Node3D


func _ready() -> void:
	super._ready()
	allowed_timeline = TimelineRestriction.PAST if radio_role == "past" else TimelineRestriction.FUTURE
	interaction_name = "Acquire Handheld Radio"
	play_interaction_animation = false
	PuzzleManager.puzzle_state_changed.connect(_on_state_changed)
	PuzzleManager.session_ended.connect(refresh)
	refresh()


func _execute_interaction(_actor: Node, role: String) -> void:
	var result := PuzzleManager.submit_action(Rules.ID, "acquire_radio", {"radio_role": radio_role}, role)
	acquisition_submitted.emit(result)


func refresh() -> void:
	var owned: bool = PuzzleManager.get_state(Rules.ID).get(Rules.ownership_key(radio_role), false) == true
	set_interaction_enabled(not owned)
	if is_instance_valid(placeholder):
		placeholder.visible = not owned


func _on_state_changed(puzzle_id: String, state: Dictionary, _revision: int) -> void:
	if puzzle_id != Rules.ID:
		return
	var newly_owned: bool = interaction_enabled and state.get(Rules.ownership_key(radio_role), false) == true
	refresh()
	if newly_owned:
		radio_acquired.emit(radio_role)
