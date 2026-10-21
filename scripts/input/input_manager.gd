class_name InputManager
extends Node
## Global Input & Gamepad Device Manager for Past-Future.
## Manages device detection (DualSense / Xbox / Generic / Keyboard), dynamic prompts,
## InputMap bindings, input context prioritization, and haptic feedback.

signal device_changed_signal(device_type: int, controller_type: int)
signal joy_connection_changed_signal(device_id: int, connected: bool)
signal haptic_triggered_signal(pattern: StringName, device_id: int)

enum DeviceType {
	KEYBOARD,
	CONTROLLER
}

enum ControllerType {
	GENERIC,
	DUALSENSE,
	XBOX
}

const DEADZONE_DEFAULT: float = 0.20
const STICK_NOISE_THRESHOLD: float = 0.35

static var instance: Node = null

## Current active input modality
static var active_device_type: DeviceType = DeviceType.KEYBOARD
static var active_controller_type: ControllerType = ControllerType.GENERIC
static var active_joypad_id: int = -1

## Haptic settings
static var haptics_enabled: bool = true

## Player device assignments for future local multiplayer / split-screen
static var _player_devices: Dictionary = {
	0: -1  # Player 0: -1 = any / primary
}


func _init() -> void:
	if instance == null:
		instance = self


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_standard_actions()
	_detect_initial_joypads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


static func ensure_initialized(parent: Node = null) -> Node:
	if instance == null:
		var script: GDScript = load("res://scripts/input/input_manager.gd")
		var node: Node = script.new()
		node.name = "InputManager"
		if parent != null and is_instance_valid(parent):
			parent.add_child(node, false, Node.INTERNAL_MODE_BACK)
		else:
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null and tree.root != null:
				if tree.root.has_node("GameFlowManager"):
					tree.root.get_node("GameFlowManager").add_child(node, false, Node.INTERNAL_MODE_BACK)
				else:
					tree.root.add_child(node, false, Node.INTERNAL_MODE_BACK)
		instance = node
	return instance


static func get_instance() -> Node:
	return ensure_initialized()


## Registers or updates the required InputMap actions to ensure gamepad and keyboard parity.
static func setup_standard_actions() -> void:
	_ensure_action("move_left", [
		_create_key_event(KEY_A),
		_create_key_event(KEY_LEFT),
		_create_joy_axis_event(JOY_AXIS_LEFT_X, -1.0),
		_create_joy_button_event(JOY_BUTTON_DPAD_LEFT)
	], DEADZONE_DEFAULT)

	_ensure_action("move_right", [
		_create_key_event(KEY_D),
		_create_key_event(KEY_RIGHT),
		_create_joy_axis_event(JOY_AXIS_LEFT_X, 1.0),
		_create_joy_button_event(JOY_BUTTON_DPAD_RIGHT)
	], DEADZONE_DEFAULT)

	_ensure_action("move_up", [
		_create_key_event(KEY_W),
		_create_key_event(KEY_UP),
		_create_joy_axis_event(JOY_AXIS_LEFT_Y, -1.0),
		_create_joy_button_event(JOY_BUTTON_DPAD_UP)
	], DEADZONE_DEFAULT)

	_ensure_action("move_down", [
		_create_key_event(KEY_S),
		_create_key_event(KEY_DOWN),
		_create_joy_axis_event(JOY_AXIS_LEFT_Y, 1.0),
		_create_joy_button_event(JOY_BUTTON_DPAD_DOWN)
	], DEADZONE_DEFAULT)

	_ensure_action("interact", [
		_create_key_event(KEY_F),
		_create_joy_button_event(JOY_BUTTON_A) # Cross (✕) on PS5
	], DEADZONE_DEFAULT)

	_ensure_action("inspect", [
		_create_key_event(KEY_I),
		_create_joy_button_event(JOY_BUTTON_X) # Square (□) on PS5
	], DEADZONE_DEFAULT)

	_ensure_action("use_item", [
		_create_key_event(KEY_E),
		_create_joy_button_event(JOY_BUTTON_Y) # Triangle (△) on PS5
	], DEADZONE_DEFAULT)

	_ensure_action("sprint", [
		_create_key_event(KEY_SHIFT),
		_create_joy_button_event(JOY_BUTTON_LEFT_STICK) # L3 on PS5
	], DEADZONE_DEFAULT)
	_ensure_action("temporal_ghost", [
		_create_key_event(KEY_G),
		_create_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER)
	], DEADZONE_DEFAULT)

	_ensure_action("cancel", [
		_create_key_event(KEY_ESCAPE),
		_create_joy_button_event(JOY_BUTTON_B) # Circle (○) on PS5
	], DEADZONE_DEFAULT)

	_ensure_action("pause", [
		_create_key_event(KEY_ESCAPE),
		_create_joy_button_event(JOY_BUTTON_START) # Options on PS5
	], DEADZONE_DEFAULT)

	# Ensure ui_accept has Joypad Button A (Cross)
	_ensure_event_in_action("ui_accept", _create_joy_button_event(JOY_BUTTON_A))
	# Ensure ui_cancel has Joypad Button B (Circle)
	_ensure_event_in_action("ui_cancel", _create_joy_button_event(JOY_BUTTON_B))
	# Ensure ui navigation has D-Pad and Left Stick
	_ensure_event_in_action("ui_up", _create_joy_button_event(JOY_BUTTON_DPAD_UP))
	_ensure_event_in_action("ui_up", _create_joy_axis_event(JOY_AXIS_LEFT_Y, -1.0))
	_ensure_event_in_action("ui_down", _create_joy_button_event(JOY_BUTTON_DPAD_DOWN))
	_ensure_event_in_action("ui_down", _create_joy_axis_event(JOY_AXIS_LEFT_Y, 1.0))
	_ensure_event_in_action("ui_left", _create_joy_button_event(JOY_BUTTON_DPAD_LEFT))
	_ensure_event_in_action("ui_left", _create_joy_axis_event(JOY_AXIS_LEFT_X, -1.0))
	_ensure_event_in_action("ui_right", _create_joy_button_event(JOY_BUTTON_DPAD_RIGHT))
	_ensure_event_in_action("ui_right", _create_joy_axis_event(JOY_AXIS_LEFT_X, 1.0))


static func _ensure_action(action: StringName, default_events: Array, deadzone: float = DEADZONE_DEFAULT) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)

	for event: InputEvent in default_events:
		_ensure_event_in_action(action, event)


static func _ensure_event_in_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var existing := InputMap.action_get_events(action)
	for ex in existing:
		if _events_match(ex, event):
			return
	InputMap.action_add_event(action, event)


static func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode and a.keycode == b.keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


static func _create_key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


static func _create_joy_button_event(btn: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = btn
	event.pressed = true
	return event


static func _create_joy_axis_event(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event


func _detect_initial_joypads() -> void:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		active_joypad_id = pads[0]
		_update_controller_type(active_joypad_id)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if active_joypad_id < 0:
			active_joypad_id = device
		_update_controller_type(device)
	else:
		if active_joypad_id == device:
			var remaining := Input.get_connected_joypads()
			if not remaining.is_empty():
				active_joypad_id = remaining[0]
				_update_controller_type(active_joypad_id)
			else:
				active_joypad_id = -1
				set_device_type(DeviceType.KEYBOARD)
	joy_connection_changed_signal.emit(device, connected)


static func _update_controller_type(device: int) -> void:
	if device < 0:
		active_controller_type = ControllerType.GENERIC
		return
	var joy_name := Input.get_joy_name(device).to_lower()
	var guid := Input.get_joy_guid(device).to_lower()
	# Check for Sony / DualSense / PS5 identifiers
	if "dualsense" in joy_name or "ps5" in joy_name or "playstation" in joy_name or "sony" in joy_name or "054c" in guid or "wireless controller" in joy_name:
		active_controller_type = ControllerType.DUALSENSE
	elif "xbox" in joy_name or "x-box" in joy_name or "microsoft" in joy_name or "045e" in guid:
		active_controller_type = ControllerType.XBOX
	else:
		active_controller_type = ControllerType.GENERIC


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		set_device_type(DeviceType.KEYBOARD)
	elif event is InputEventJoypadButton:
		active_joypad_id = event.device
		_update_controller_type(event.device)
		set_device_type(DeviceType.CONTROLLER, active_controller_type)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > STICK_NOISE_THRESHOLD:
			active_joypad_id = event.device
			_update_controller_type(event.device)
			set_device_type(DeviceType.CONTROLLER, active_controller_type)


static func set_device_type(new_type: DeviceType, ctrl_type: ControllerType = ControllerType.GENERIC) -> void:
	var changed := (active_device_type != new_type) or (active_controller_type != ctrl_type)
	active_device_type = new_type
	if new_type == DeviceType.CONTROLLER:
		active_controller_type = ctrl_type
	if changed and instance != null:
		instance.device_changed_signal.emit(active_device_type, active_controller_type)


## Returns a player-facing symbol or label for an action based on active device.
static func get_action_label(action: StringName) -> String:
	var is_controller := active_device_type == DeviceType.CONTROLLER
	var is_dualsense := active_controller_type == ControllerType.DUALSENSE

	match action:
		&"interact":
			if is_controller:
				return "✕" if is_dualsense else "A"
			return "F"
		&"inspect":
			if is_controller:
				return "□" if is_dualsense else "X"
			return "I"
		&"use_item":
			if is_controller:
				return "△" if is_dualsense else "Y"
			return "E"
		&"sprint":
			if is_controller:
				return "L3" if is_dualsense else "LS"
			return "Shift"
		&"cancel":
			if is_controller:
				return "○" if is_dualsense else "B"
			return "Esc"
		&"temporal_ghost":
			return ("R1" if is_dualsense else "RB") if is_controller else "G"
		&"move":
			return "Left Stick" if is_controller else "W A S D"
		&"journal":
			return "J"  # Keyboard only: the journal has no gamepad binding in project.godot.
		&"pause":
			if is_controller:
				return "Options" if is_dualsense else "Menu"
			return "Esc"
		&"ui_accept":
			if is_controller:
				return "✕" if is_dualsense else "A"
			return "Enter"
		&"ui_cancel":
			if is_controller:
				return "○" if is_dualsense else "B"
			return "Esc"
		_:
			return ""


## Trigger low-intensity haptic vibration safely on the active controller.
static func trigger_haptic(pattern: StringName = &"interaction", device_id: int = -1) -> void:
	if not haptics_enabled:
		return
	var dev: int = device_id if device_id >= 0 else active_joypad_id
	if dev < 0:
		return
	match pattern:
		&"interaction":
			Input.start_joy_vibration(dev, 0.15, 0.0, 0.1)
		&"radio_connect":
			Input.start_joy_vibration(dev, 0.35, 0.5, 0.4)
		&"puzzle_complete":
			Input.start_joy_vibration(dev, 0.4, 0.65, 0.5)
		&"narrative_event":
			Input.start_joy_vibration(dev, 0.25, 0.35, 0.3)
		_:
			Input.start_joy_vibration(dev, 0.2, 0.2, 0.15)
	if instance != null:
		instance.haptic_triggered_signal.emit(pattern, dev)


## Future split-screen device assignment methods
static func set_player_device(player_index: int, joypad_id: int) -> void:
	_player_devices[player_index] = joypad_id


static func get_player_device(player_index: int = 0) -> int:
	return _player_devices.get(player_index, -1)


static func is_event_for_player(event: InputEvent, player_index: int = 0) -> bool:
	var assigned_device: int = get_player_device(player_index)
	if assigned_device == -1:
		# Any device controls primary player
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device == assigned_device
	return player_index == 0
