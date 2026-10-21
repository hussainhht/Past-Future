class_name LabDevice
extends TimelineProp
## Base for the Signal Laboratory's interactive devices (door, keypad, breaker, console...).
##
## A device is a TimelineProp, so it follows the room's timeline, and it shows the confirmed state
## of Puzzle 01 (the frequency puzzle, "puzzle_01_frequency") through its child PuzzleListener.
## Devices never decide anything: puzzle actions go through the frequency puzzle's own components
## and PuzzleManager, and devices redraw themselves in _show_state() whenever the confirmed state or
## the timeline changes. Sounds come from the scene's AudioDirector (group "lab_audio").

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const PUZZLE_ID := Rules.ID

## Last confirmed puzzle state ({} until the puzzle is registered).
var state: Dictionary = {}
var solved: bool = false


func _ready() -> void:
	super()
	var listener := get_node_or_null("PuzzleListener")
	if listener != null:
		listener.state_applied.connect(_on_state_applied)
		listener.refresh()
	for interactable in find_children("*", "Area3D", true, false):
		if interactable.has_signal("interacted"):
			interactable.interacted.connect(_on_interacted.bind(interactable))
	_show_state(false)


func _apply() -> void:
	super()
	if is_node_ready():
		_show_state(false)


func _on_state_applied(new_state: Dictionary, is_solved: bool) -> void:
	var previous := state
	state = new_state
	solved = is_solved
	_state_changed(previous)
	_show_state(true)


## Override: react to a confirmed change (play a sound, start an animation). previous may be {}.
func _state_changed(_previous: Dictionary) -> void:
	pass


## Override: redraw indicators, prompts and screens. animate is false for timeline switches and loads.
func _show_state(_animate: bool) -> void:
	pass


## Override: an Interactable3D under this device was used.
func _on_interacted(_actor: Node, _role: String, _interactable: Node) -> void:
	pass


## True once both radios are owned and the array is calibrated: the temporal radio link.
func linked() -> bool:
	return Rules.link_established(state)


func ui() -> LabUI:
	return get_tree().get_first_node_in_group("lab_ui") as LabUI


## Play an AudioDirector catalog sound at a point on this device (local offset).
func sfx(sound: StringName, offset: Vector3 = Vector3.ZERO) -> void:
	var audio := get_tree().get_first_node_in_group("lab_audio")
	if audio != null:
		audio.play_world_sfx(sound, global_transform * offset)


func toast(text: String) -> void:
	var lab_ui := ui()
	if lab_ui != null:
		lab_ui.observe("Professor" if future else "Student", text)


## Give one mesh a palette slot regardless of what it was imported with.
func paint(mesh: MeshInstance3D, slot: String) -> void:
	if mesh == null or mesh.mesh == null:
		return
	var material := EnvPalette.material(slot, future)
	for surface in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(surface, material)


func find_mesh(node_name: String) -> MeshInstance3D:
	return find_child(node_name, true, false) as MeshInstance3D
