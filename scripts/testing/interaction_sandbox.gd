extends Node3D
## Test coordinator for the Interaction Sandbox.
## Demonstrates computers, readable documents, puzzle switches, dynamic doors, and temporal rifts.

const PowerSwitchPuzzle := preload("res://scripts/puzzles/implementations/power_switch_puzzle.gd")
const Interactable3D := preload("res://scripts/interaction/interactable_3d.gd")
const PuzzleInteractable3D := preload("res://scripts/interaction/puzzle_interactable_3d.gd")
const InteractionPrompt := preload("res://scripts/ui/interaction_prompt.gd")
const InteractionController := preload("res://scripts/interaction/interaction_controller.gd")

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var prompt: InteractionPrompt = $InteractionPrompt
@onready var log_label: Label = $HUD/Margin/VBox/LogPanel/LogLabel
@onready var timeline_label: Label = $HUD/Margin/VBox/Header/TimelineLabel

# Test Interactables
@onready var computer_interactable: Interactable3D = $World/Computer/Interactable3D
@onready var document_interactable: Interactable3D = $World/Document/Interactable3D
@onready var switch_interactable: PuzzleInteractable3D = $World/Switch/PuzzleInteractable3D
@onready var door_interactable: Interactable3D = $World/Door/Interactable3D
@onready var rift_interactable: Interactable3D = $World/TemporalRift/Interactable3D

# Visual references
@onready var switch_mesh: MeshInstance3D = $World/Switch/Visual
@onready var door_mesh: MeshInstance3D = $World/Door/Visual
@onready var door_collision: CollisionShape3D = $World/Door/StaticBody3D/CollisionShape3D

var current_timeline: String = "Past"
var door_opened: bool = false
var _controller: InteractionController = null
var _puzzle_manager: Node = null


func _get_pm() -> Node:
	if _puzzle_manager != null and is_instance_valid(_puzzle_manager):
		return _puzzle_manager
	if get_node_or_null("/root/PuzzleManager") != null:
		_puzzle_manager = get_node("/root/PuzzleManager")
	return _puzzle_manager


func _ready() -> void:
	var pm := _get_pm()
	# Register power switch puzzle in PuzzleManager if needed
	if pm != null and pm.has_method("is_registered"):
		if not pm.call("is_registered", "electricity_puzzle"):
			pm.call("register_puzzle", "electricity_puzzle", PowerSwitchPuzzle.new())
		if not pm.puzzle_state_changed.is_connected(_on_puzzle_state_changed):
			pm.puzzle_state_changed.connect(_on_puzzle_state_changed)

	# Configure Player & Rig
	player.view_camera = camera
	_controller = player.get_node_or_null("InteractionRig/InteractionController")
	if _controller != null:
		_controller.prompt_ui = prompt

	# Wire Object Behaviors
	computer_interactable.interacted.connect(_on_computer_interacted)
	document_interactable.interacted.connect(_on_document_interacted)
	switch_interactable.puzzle_action_accepted.connect(_on_switch_accepted)
	door_interactable.interacted.connect(_on_door_interacted)
	rift_interactable.interacted.connect(_on_rift_interacted)

	_apply_timeline(current_timeline)
	_log_event("Interaction Sandbox ready. Use WASD to move, F to interact, T to toggle timeline.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T:
			toggle_timeline()
		elif event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()


func toggle_timeline() -> void:
	var next_timeline := "Future" if current_timeline == "Past" else "Past"
	_apply_timeline(next_timeline)


func _apply_timeline(timeline: String) -> void:
	current_timeline = timeline
	timeline_label.text = "TIMELINE: " + current_timeline.to_upper()
	var color := Color("#e4bf7f") if current_timeline == "Past" else Color("#86c9d1")
	timeline_label.add_theme_color_override("font_color", color)
	player.body_color = color

	if _controller != null and _controller.detector != null:
		_controller.detector.set_current_role(current_timeline.to_lower())

	_log_event("Timeline switched to %s (%s interactables active)." % [current_timeline, "Past" if current_timeline == "Past" else "Future"])


func _log_event(message: String) -> void:
	log_label.text = message
	print("[SANDBOX] " + message)


func _on_computer_interacted(_actor: Node, _role: String) -> void:
	_log_event("[COMPUTER] Terminal access granted. Logs: Signal resonance stable at 432 Hz.")


func _on_document_interacted(_actor: Node, _role: String) -> void:
	_log_event("[DOCUMENT] Research Log #31: 'Temporal rifts appear when the core fracture is destabilized.'")


func _on_switch_accepted(puzzle_id: String, action: String) -> void:
	_log_event("[SWITCH] PuzzleManager accepted '%s' on '%s'! Power restored." % [action, puzzle_id])


func _on_puzzle_state_changed(puzzle_id: String, state: Dictionary, _revision: int) -> void:
	if puzzle_id == "electricity_puzzle":
		var power_on: bool = state.get("power_on", false)
		# Update switch visual
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.9, 0.3) if power_on else Color(0.9, 0.8, 0.2)
		mat.emission_enabled = power_on
		mat.emission = Color(0.2, 0.9, 0.3)
		switch_mesh.material_override = mat

		# Update door prompt dynamically
		if not door_opened:
			if power_on:
				door_interactable.set_interaction_name("Open Powered Door")
			else:
				door_interactable.set_interaction_name("Inspect Locked Door")


func _on_door_interacted(_actor: Node, _role: String) -> void:
	var pm := _get_pm()
	var power_on: bool = false
	if pm != null and pm.has_method("get_state"):
		var state: Dictionary = pm.call("get_state", "electricity_puzzle")
		power_on = state.get("power_on", false)
	
	if not power_on:
		_log_event("[DOOR] The electronic lock has no power. Activate the power switch first.")
	elif not door_opened:
		door_opened = true
		_log_event("[DOOR] Power verified! Opening security bulkhead.")
		door_interactable.set_interaction_enabled(false)
		# Animate door sliding up
		var tween := create_tween()
		tween.tween_property(door_mesh, "position:y", 3.0, 1.0)
		door_collision.disabled = true
	else:
		_log_event("[DOOR] Bulkhead is already open.")


func _on_rift_interacted(_actor: Node, _role: String) -> void:
	_log_event("[TEMPORAL RIFT] A faint whisper echoes from 31 years away: 'Do not trust the recording...'")


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	prompt.set_interaction_blocked(paused)
	_log_event("Game " + ("PAUSED" if paused else "RESUMED"))
