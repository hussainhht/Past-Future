extends Node3D
## Standalone PS5 DualSense & Gamepad Verification Sandbox.
## Tests analog movement, deadzones, sprint (L3), interaction (Cross),
## inspect (Square), use item (Triangle), back/cancel (Circle), pause (Options),
## dynamic prompts, focus navigation, dialogue advancement, frequency terminal input,
## and connection/disconnection events using real project components.

const InputManager := preload("res://scripts/input/input_manager.gd")
const DialogueLineRes := preload("res://scripts/dialogue/dialogue_line.gd")
const DialogueSequenceRes := preload("res://scripts/dialogue/dialogue_sequence.gd")

@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var prompt_ui: InteractionPrompt = $HUD/InteractionPrompt
@onready var terminal_ui: Control = $HUD/FrequencyTerminalUI
@onready var dialogue_director: DialogueDirector = $DialogueDirector
@onready var dialogue_box: DialogueBox = $HUD/DialogueBox
@onready var pause_panel: ColorRect = %PausePanel

# Diagnostics labels
@onready var device_label: Label = %DeviceLabel
@onready var controller_label: Label = %ControllerLabel
@onready var stick_label: Label = %StickLabel
@onready var sprint_label: Label = %SprintLabel
@onready var last_action_label: Label = %LastActionLabel
@onready var connection_banner: Label = %ConnectionBanner

var _paused: bool = false
var _test_sequence: DialogueSequenceRes


func _ready() -> void:
	InputManager.ensure_initialized(self)
	InputManager.get_instance().device_changed_signal.connect(_on_device_changed)
	InputManager.get_instance().joy_connection_changed_signal.connect(_on_joy_connection_changed)
	InputManager.get_instance().haptic_triggered_signal.connect(_on_haptic_triggered)

	player.view_camera = camera
	$CameraRig.target = player

	# Wire buttons
	%ResumeButton.pressed.connect(_set_paused.bind(false))
	%TriggerDialogueBtn.pressed.connect(_trigger_sample_dialogue)
	%OpenTerminalBtn.pressed.connect(_open_terminal)
	%TestHapticBtn.pressed.connect(func(): InputManager.trigger_haptic(&"puzzle_complete"))

	# Create a sample dialogue sequence for testing controller dialogue advance
	_create_sample_dialogue()

	# Wire dialogue director to dialogue box
	dialogue_director.dialogue_box = dialogue_box
	dialogue_director._connect_box()
	dialogue_director.gameplay_input_block_changed.connect(_on_dialogue_block_changed)

	# Wire terminal modal
	terminal_ui.modal_changed.connect(_on_modal_changed)

	_update_diagnostics()
	%ConnectionBanner.text = "DualSense Controller Sandbox Ready. Move left stick or use WASD."


func _process(_delta: float) -> void:
	_update_diagnostics()


func _input(event: InputEvent) -> void:
	if terminal_ui.visible and not _paused:
		return

	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if not terminal_ui.visible and not dialogue_director.is_dialogue_active():
			_set_paused(not _paused)
			get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	_paused = paused
	player.controls_enabled = not paused
	pause_panel.visible = paused
	if paused:
		%ResumeButton.grab_focus()


func _on_device_changed(_device_type: int, _controller_type: int) -> void:
	_update_diagnostics()


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	var pad_name := Input.get_joy_name(device_id)
	var status_text := "CONNECTED" if connected else "DISCONNECTED"
	connection_banner.text = "Gamepad %d (%s) %s" % [device_id, pad_name, status_text]
	_update_diagnostics()


func _on_haptic_triggered(pattern: StringName, device_id: int) -> void:
	last_action_label.text = "Haptic Rumble: %s (Device %d)" % [pattern, device_id]


func _update_diagnostics() -> void:
	if not is_instance_valid(device_label):
		return

	var is_controller := InputManager.active_device_type == InputManager.DeviceType.CONTROLLER
	device_label.text = "Active Device: %s" % ("CONTROLLER" if is_controller else "KEYBOARD & MOUSE")

	var type_str := "GENERIC"
	if InputManager.active_controller_type == InputManager.ControllerType.DUALSENSE:
		type_str = "SONY PS5 DUALSENSE"
	elif InputManager.active_controller_type == InputManager.ControllerType.XBOX:
		type_str = "XBOX"
	controller_label.text = "Controller Type: %s (ID: %d)" % [type_str, InputManager.active_joypad_id]

	var stick_x := Input.get_axis("move_left", "move_right")
	var stick_y := Input.get_axis("move_up", "move_down")
	var stick_vec := Vector2(stick_x, stick_y)
	stick_label.text = "Left Stick: (%.2f, %.2f) | Mag: %.2f" % [stick_x, stick_y, stick_vec.length()]

	var is_sprinting := Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	sprint_label.text = "Sprint Active (L3 / Shift): %s" % ("YES" if is_sprinting else "NO")


func _create_sample_dialogue() -> void:
	_test_sequence = DialogueSequenceRes.new()
	_test_sequence.sequence_id = "sandbox_test"
	_test_sequence.allow_skip = true

	var line1 := DialogueLineRes.new()
	line1.speaker_name = "DR. A. VANCE"
	line1.text = "Testing dual-frequency relay... Press Cross (✕) or Enter to reveal, then advance."
	line1.timeline = DialogueLineRes.Timeline.PAST

	var line2 := DialogueLineRes.new()
	line2.speaker_name = "THE PROFESSOR"
	line2.text = "Transmission received clearly across 31 years. Controller navigation verified."
	line2.timeline = DialogueLineRes.Timeline.FUTURE

	_test_sequence.lines = [line1, line2]


func _trigger_sample_dialogue() -> void:
	if dialogue_director.is_dialogue_active():
		return
	dialogue_director.play_dialogue(_test_sequence)


func _open_terminal() -> void:
	terminal_ui.open_for(player, "past")


func _on_modal_changed(opened: bool) -> void:
	player.controls_enabled = not opened
	prompt_ui.set_interaction_blocked(opened)


func _on_dialogue_block_changed(blocked: bool) -> void:
	player.controls_enabled = not blocked
	prompt_ui.set_interaction_blocked(blocked)

