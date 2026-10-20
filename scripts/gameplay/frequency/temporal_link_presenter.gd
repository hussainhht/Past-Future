extends Node3D
## Rift/indicator appearance, derived from confirmed state. Never a communication device.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
signal link_applied(connected: bool)

@export var indicator: MeshInstance3D
@export var light: OmniLight3D
var connected: bool = false
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.emission_enabled = true
	if indicator != null:
		indicator.material_override = _material
	PuzzleManager.puzzle_state_changed.connect(_on_state_changed)
	PuzzleManager.session_ended.connect(refresh)
	refresh()


func refresh() -> void:
	connected = Rules.link_established(PuzzleManager.get_state(Rules.ID))
	var color := Color("86c9d1") if connected else Color("8057b5")
	_material.albedo_color = color
	_material.emission = color * 0.4
	if light != null:
		light.light_color = color
	link_applied.emit(connected)


func _on_state_changed(puzzle_id: String, _state: Dictionary, _revision: int) -> void:
	if puzzle_id == Rules.ID:
		refresh()
