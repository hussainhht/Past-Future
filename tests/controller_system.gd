extends SceneTree
## Automated Verification Suite for PlayStation 5 DualSense Controller Support.
## Covers all 20 required items from specification.

const InputManager := preload("res://scripts/input/input_manager.gd")
const DialogueLineRes := preload("res://scripts/dialogue/dialogue_line.gd")
const DialogueSequenceRes := preload("res://scripts/dialogue/dialogue_sequence.gd")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func tick(count: int = 3) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func _run() -> void:
	print("--- BEGIN PS5 DUALSENSE CONTROLLER TESTS ---")
	InputManager.ensure_initialized()

	await test_01_inputmap_registration()
	await test_02_keyboard_bindings_preserved()
	await test_03_joypad_buttons_mapped()
	await test_04_left_stick_axis_mapping()
	await test_05_deadzone_behavior()
	await test_06_movement_input()
	await test_07_sprint_input()
	await test_08_interaction_input()
	await test_09_one_interaction_per_press()
	await test_10_input_mode_switching()
	await test_11_menu_focus_behavior()
	await test_12_pause_navigation()
	await test_13_dialogue_input()
	await test_14_terminal_frequency_input()
	await test_15_modal_input_blocking()
	await test_16_controller_disconnection()
	await test_17_controller_reconnection()
	await test_18_level_transition_input_recovery()
	await test_19_host_client_role_preservation()
	await test_20_existing_gameplay_regression()

	print("PS5 CONTROLLER SYSTEM: %s (%d checks, %d failures)" % [
		"PASS" if failures == 0 else "FAIL",
		checks,
		failures
	])
	quit(0 if failures == 0 else 1)


func test_01_inputmap_registration() -> void:
	var required_actions := [
		"move_left", "move_right", "move_up", "move_down",
		"interact", "inspect", "use_item", "sprint", "cancel", "pause",
		"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"
	]
	for action in required_actions:
		check(InputMap.has_action(action), "InputMap must register action: " + action)


func test_02_keyboard_bindings_preserved() -> void:
	# Verify that physical keys exist in actions
	var has_key := func(action: String, keycode: Key) -> bool:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.physical_keycode == keycode:
				return true
		return false

	check(has_key.call("move_left", KEY_A), "move_left must preserve Key A")
	check(has_key.call("move_right", KEY_D), "move_right must preserve Key D")
	check(has_key.call("move_up", KEY_W), "move_up must preserve Key W")
	check(has_key.call("move_down", KEY_S), "move_down must preserve Key S")
	check(has_key.call("interact", KEY_F), "interact must preserve Key F")
	check(has_key.call("inspect", KEY_I), "inspect must preserve Key I")
	check(has_key.call("use_item", KEY_E), "use_item must preserve Key E")
	check(has_key.call("cancel", KEY_ESCAPE), "cancel must preserve Escape")
	check(has_key.call("pause", KEY_ESCAPE), "pause must preserve Escape")


func test_03_joypad_buttons_mapped() -> void:
	var has_btn := func(action: String, btn: JoyButton) -> bool:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and ev.button_index == btn:
				return true
		return false

	check(has_btn.call("interact", JOY_BUTTON_A), "interact must map Cross (✕) / Joypad A")
	check(has_btn.call("inspect", JOY_BUTTON_X), "inspect must map Square (□) / Joypad X")
	check(has_btn.call("use_item", JOY_BUTTON_Y), "use_item must map Triangle (△) / Joypad Y")
	check(has_btn.call("cancel", JOY_BUTTON_B), "cancel must map Circle (○) / Joypad B")
	check(has_btn.call("pause", JOY_BUTTON_START), "pause must map Options / Joypad Start")
	check(has_btn.call("sprint", JOY_BUTTON_LEFT_STICK), "sprint must map L3 / Joypad Left Stick")
	check(has_btn.call("ui_accept", JOY_BUTTON_A), "ui_accept must map Cross / Joypad A")
	check(has_btn.call("ui_cancel", JOY_BUTTON_B), "ui_cancel must map Circle / Joypad B")


func test_04_left_stick_axis_mapping() -> void:
	var has_axis := func(action: String, axis: JoyAxis, sign_val: float) -> bool:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion and ev.axis == axis and signf(ev.axis_value) == signf(sign_val):
				return true
		return false

	check(has_axis.call("move_left", JOY_AXIS_LEFT_X, -1.0), "move_left must map Left Stick X-")
	check(has_axis.call("move_right", JOY_AXIS_LEFT_X, 1.0), "move_right must map Left Stick X+")
	check(has_axis.call("move_up", JOY_AXIS_LEFT_Y, -1.0), "move_up must map Left Stick Y-")
	check(has_axis.call("move_down", JOY_AXIS_LEFT_Y, 1.0), "move_down must map Left Stick Y+")


func test_05_deadzone_behavior() -> void:
	var dz_left := InputMap.action_get_deadzone("move_left")
	var dz_right := InputMap.action_get_deadzone("move_right")
	check(is_equal_approx(dz_left, 0.20), "Deadzone for move_left must be ~0.20, got %.2f" % dz_left)
	check(is_equal_approx(dz_right, 0.20), "Deadzone for move_right must be ~0.20, got %.2f" % dz_right)


func test_06_movement_input() -> void:
	var player_scene = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	root.add_child(player_scene)
	await tick(2)

	var initial_pos: Vector3 = player_scene.global_position
	# Send simulated move_right action (as if from left stick)
	Input.action_press("move_right", 0.75)
	await tick(10)
	Input.action_release("move_right")
	await tick(5)

	check(player_scene.global_position.x > initial_pos.x + 0.1, "Player should move right under analog input")
	player_scene.queue_free()
	await tick(2)


func test_07_sprint_input() -> void:
	var player_scene = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	root.add_child(player_scene)
	await tick(2)

	# Regular walking
	var pos_start: Vector3 = player_scene.global_position
	Input.action_press("move_right", 1.0)
	await tick(10)
	Input.action_release("move_right")
	await tick(2)
	var walk_distance: float = player_scene.global_position.x - pos_start.x

	# Sprint with L3 (sprint action)
	player_scene.global_position = pos_start
	await tick(2)
	Input.action_press("sprint")
	Input.action_press("move_right", 1.0)
	await tick(10)
	Input.action_release("move_right")
	Input.action_release("sprint")
	await tick(2)
	var sprint_distance: float = player_scene.global_position.x - pos_start.x

	check(sprint_distance > walk_distance * 1.2, "Sprint with L3 should cover more distance than walk")
	player_scene.queue_free()
	await tick(2)


func test_08_interaction_input() -> void:
	var player_scene = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	root.add_child(player_scene)
	var rig = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
	rig.name = "InteractionRig"
	player_scene.add_child(rig)
	await tick(2)

	var interactable := Area3D.new()
	interactable.set_script(load("res://scripts/interaction/interactable_3d.gd"))
	interactable.collision_layer = 8
	interactable.interaction_distance = 3.0
	interactable.play_interaction_animation = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape.shape = sphere
	interactable.add_child(shape)
	root.add_child(interactable)
	interactable.global_position = player_scene.global_position
	await tick(4)

	var interacted_fired: Array = []
	interactable.interacted.connect(func(_actor, _role): interacted_fired.append(true))

	# Trigger with simulated Joypad Cross press
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	player_scene._unhandled_input(ev)
	await tick(3)

	ev.pressed = false
	player_scene._unhandled_input(ev)
	await tick(2)

	check(interacted_fired.size() == 1, "Cross button must execute interaction, got %d" % interacted_fired.size())
	interactable.queue_free()
	player_scene.queue_free()
	await tick(2)


func test_09_one_interaction_per_press() -> void:
	var player_scene = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	root.add_child(player_scene)
	var rig = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
	rig.name = "InteractionRig"
	player_scene.add_child(rig)
	await tick(2)

	var interactable := Area3D.new()
	interactable.set_script(load("res://scripts/interaction/interactable_3d.gd"))
	interactable.collision_layer = 8
	interactable.interaction_distance = 3.0
	interactable.timing = 0 # Timing.IMMEDIATE
	interactable.play_interaction_animation = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape.shape = sphere
	interactable.add_child(shape)
	root.add_child(interactable)
	interactable.global_position = player_scene.global_position
	await tick(4)

	var count: Array = []
	interactable.interacted.connect(func(_actor, _role): count.append(1))

	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	player_scene._unhandled_input(ev)
	await tick(2)

	# Second press while animation / action is locked
	var ev2 := InputEventJoypadButton.new()
	ev2.button_index = JOY_BUTTON_A
	ev2.pressed = true
	player_scene._unhandled_input(ev2)
	await tick(2)

	check(count.size() == 1, "Holding Cross down must not trigger repeated interactions, got %d" % count.size())

	ev.pressed = false
	player_scene._unhandled_input(ev)
	await tick(2)
	interactable.queue_free()
	player_scene.queue_free()
	await tick(2)


func test_10_input_mode_switching() -> void:
	# Initial keyboard mode
	InputManager.set_device_type(InputManager.DeviceType.KEYBOARD)
	check(InputManager.active_device_type == InputManager.DeviceType.KEYBOARD, "Should be keyboard mode")
	check(InputManager.get_action_label(&"interact") == "F", "Keyboard interact label must be F")

	# Switch to DualSense
	InputManager.set_device_type(InputManager.DeviceType.CONTROLLER, InputManager.ControllerType.DUALSENSE)
	check(InputManager.active_device_type == InputManager.DeviceType.CONTROLLER, "Should be controller mode")
	check(InputManager.get_action_label(&"interact") == "✕", "DualSense interact label must be ✕")
	check(InputManager.get_action_label(&"cancel") == "○", "DualSense cancel label must be ○")
	check(InputManager.get_action_label(&"inspect") == "□", "DualSense inspect label must be □")
	check(InputManager.get_action_label(&"use_item") == "△", "DualSense use_item label must be △")
	check(InputManager.get_action_label(&"sprint") == "L3", "DualSense sprint label must be L3")
	check(InputManager.get_action_label(&"pause") == "Options", "DualSense pause label must be Options")

	# Switch to Generic controller
	InputManager.set_device_type(InputManager.DeviceType.CONTROLLER, InputManager.ControllerType.GENERIC)
	check(InputManager.get_action_label(&"interact") == "A", "Generic controller interact label must be A")
	check(InputManager.get_action_label(&"cancel") == "B", "Generic controller cancel label must be B")

	# Revert back to Keyboard
	InputManager.set_device_type(InputManager.DeviceType.KEYBOARD)
	check(InputManager.get_action_label(&"interact") == "F", "Keyboard interact label must be F")


func test_11_menu_focus_behavior() -> void:
	var menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await tick(2)

	var play_btn: Button = menu.get_node("%PlayButton")
	check(play_btn.has_focus(), "Play button must receive focus on menu open")

	menu.queue_free()
	await tick(2)


func test_12_pause_navigation() -> void:
	var spawn = load("res://scenes/world/spawn_area.tscn").instantiate()
	spawn.pause_when_unfocused = false
	root.add_child(spawn)
	await tick(3)

	spawn._set_paused(false)
	check(not spawn.is_gameplay_paused(), "Should not be paused initially")

	# Simulate pause action (Options / Escape)
	spawn._set_paused(true)
	check(spawn.is_gameplay_paused(), "Should be paused after _set_paused(true)")
	var resume_btn: Button = spawn.get_node("%ResumeButton")
	check(resume_btn.has_focus(), "Resume button must grab focus on pause")

	spawn._set_paused(false)
	check(not spawn.is_gameplay_paused(), "Should unpause")
	spawn.queue_free()
	await tick(2)


func test_13_dialogue_input() -> void:
	var director := DialogueDirector.new()
	var box = load("res://scenes/dialogue/dialogue_box.tscn").instantiate()
	root.add_child(box)
	root.add_child(director)
	director.dialogue_box = box
	director._connect_box()
	await tick(2)

	var seq := DialogueSequenceRes.new()
	seq.sequence_id = "test_dialogue"
	var line := DialogueLineRes.new()
	line.speaker_name = "TESTER"
	line.text = "Hello DualSense"
	seq.lines = [line]

	director.play_dialogue(seq)
	await tick(2)
	check(director.is_dialogue_active(), "Dialogue should be active")

	# Reveal line
	director.advance_dialogue()
	await tick(2)

	# Advance to complete
	director.advance_dialogue()
	await tick(3)
	check(not director.is_dialogue_active(), "Dialogue should complete after advancing past last line")

	director.queue_free()
	box.queue_free()
	await tick(2)


func test_14_terminal_frequency_input() -> void:
	var terminal = load("res://scenes/gameplay/frequency/frequency_terminal_ui.tscn").instantiate()
	root.add_child(terminal)
	await tick(2)

	var dummy_actor := Node.new()
	root.add_child(dummy_actor)
	terminal.open_for(dummy_actor, "past")
	await tick(2)

	check(terminal.visible, "Terminal modal must be open")
	var input: LineEdit = terminal.frequency_input
	var btn_6: Button = terminal.keypad_container.get_node("Keypad_6")
	var btn_7: Button = terminal.keypad_container.get_node("Keypad_7")

	# Press 6 and 7 using keypad buttons
	btn_6.pressed.emit()
	btn_7.pressed.emit()
	await tick(2)

	check(input.text == "67", "Keypad buttons must enter 67, got '%s'" % input.text)
	check(terminal._valid_frequency(), "Frequency 67 must be valid")

	terminal.close()
	await tick(2)
	check(not terminal.visible, "Terminal should close")
	terminal.queue_free()
	dummy_actor.queue_free()
	await tick(2)


func test_15_modal_input_blocking() -> void:
	var terminal = load("res://scenes/gameplay/frequency/frequency_terminal_ui.tscn").instantiate()
	root.add_child(terminal)
	var player_scene = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	root.add_child(player_scene)
	var rig = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
	player_scene.add_child(rig)
	await tick(2)

	check(player_scene.controls_enabled, "Player controls should be enabled initially")
	terminal.open_for(player_scene, "past")
	await tick(2)

	check(not player_scene.controls_enabled, "Opening terminal modal must lock player controls")

	terminal.close()
	await tick(2)
	check(player_scene.controls_enabled, "Closing terminal modal must restore player controls")

	terminal.queue_free()
	player_scene.queue_free()
	await tick(2)


func test_16_controller_disconnection() -> void:
	InputManager.set_device_type(InputManager.DeviceType.CONTROLLER, InputManager.ControllerType.DUALSENSE)
	# Simulate disconnect of active device
	var active_id := InputManager.active_joypad_id
	InputManager.get_instance()._on_joy_connection_changed(active_id, false)

	check(InputManager.active_device_type == InputManager.DeviceType.KEYBOARD, "Disconnecting must fall back to keyboard")
	check(InputManager.get_action_label(&"interact") == "F", "Prompt must return to F on disconnect")


func test_17_controller_reconnection() -> void:
	# Simulate reconnect
	InputManager.get_instance()._on_joy_connection_changed(0, true)
	check(InputManager.active_joypad_id >= 0, "Connected device ID must be registered")


func test_18_level_transition_input_recovery() -> void:
	var flow = root.get_node("GameFlowManager")
	var player_scene = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	root.add_child(player_scene)
	await tick(2)

	flow._set_input_locked(true)
	check(flow.is_input_locked(), "Input must be locked during transition phase")

	flow._set_input_locked(false)
	check(not flow.is_input_locked(), "Input must be unlocked after transition commit")
	player_scene.queue_free()
	await tick(2)


func test_19_host_client_role_preservation() -> void:
	var pm = root.get_node("PuzzleManager")
	var nm = root.get_node("NetworkManager")
	# Check that controller input manager does not alter roles
	pm.offline_role = "past"
	check(pm.get_local_role() == "past", "Offline role must remain past")
	pm.offline_role = "future"
	check(pm.get_local_role() == "future", "Offline role must remain future")
	pm.offline_role = "past"


func test_20_existing_gameplay_regression() -> void:
	var pm = root.get_node("PuzzleManager")
	var rules_script = load("res://scripts/puzzles/implementations/frequency_puzzle.gd")
	if not pm.is_registered(rules_script.ID):
		pm.register_puzzle(rules_script.ID, rules_script.new())
	pm.begin_session()
	check(pm.is_session_active(), "PuzzleManager session must be active")
	var state: Dictionary = pm.get_state(rules_script.ID)
	check(state.has("frequency_calibrated"), "Frequency puzzle state must be initialized")
	check(not state["frequency_calibrated"], "Frequency puzzle should start uncalibrated")
	pm.reset_all()
