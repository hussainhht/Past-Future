extends SceneTree
## First-time tutorial popup: real solo room, real input events. Uses a throwaway config file.
## Optional TUTORIAL_REVIEW_DIR saves a screenshot of the popup (needs a rendering driver).

const CONFIG := "user://tutorial_popup_test.cfg"

var room: Node3D
var popup: TutorialPopup
var journal: Node
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)


func tick(frames: int = 4) -> void:
	for i in range(frames):
		await physics_frame
	await process_frame


func wait_for(predicate: Callable, message: String, timeout: float = 20.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func capture(file_name: String) -> void:
	var directory := OS.get_environment("TUTORIAL_REVIEW_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(file_name + ".png")) == OK, "Capture " + file_name)


func _run() -> void:
	TutorialPopup.config_path = CONFIG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	root.get_node("PuzzleManager").log_rejections = false
	journal = root.get_node("JournalManager")
	var menu: Control = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.settings_path = "user://tutorial_popup_menu_settings.cfg"
	root.add_child(menu)
	current_scene = menu
	await tick()
	menu.get_node("%PlayButton").pressed.emit()
	menu.get_node("%PreviewButton").pressed.emit()
	if not await wait_for(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://scenes/world/spawn_area.tscn", "Solo menu failed to enter the laboratory"):
		quit(1)
		return
	room = current_scene
	room.pause_when_unfocused = false
	room._set_paused(false)
	popup = room.tutorial
	await tick()

	# 1. First-time player: nothing stored, so the room opens it by itself once the intro is done.
	check(popup != null and not popup.is_open(), "Popup exists and starts closed")
	check(not TutorialPopup.has_been_shown(), "No stored flag for a new player")
	room._show_first_time_tutorial()
	if not await wait_for(func() -> bool: return popup.is_open(), "Popup did not open for a first-time player"):
		quit(1)
		return
	await tick(8)

	# 2. Content for the Student, with the real bindings (keyboard).
	var text := popup.role_text()
	check("STUDENT — THE PAST" in text and "You can change the past." in text, "Student content shown")
	check(not ("PROFESSOR" in text), "No Professor content for the Student")
	check(popup.find_child("Title", true, false) == null, "No heading above the role card")
	check(popup.confirm_button.text == "GOT IT — LET'S PLAY", "Confirm button label")
	check(popup.control_texts() == ["W A S D", "F", "I", "Shift", "J", "Esc"], "Keyboard glyphs: " + str(popup.control_texts()))
	check(popup.confirm_button.has_focus(), "Confirm button has gamepad/keyboard focus")
	await capture("tutorial_student")

	# 3. Only the local player is locked; the session itself is not paused.
	check(not room.player.controls_enabled, "Local controls blocked while open")
	check(not paused, "SceneTree is not paused (partner keeps playing)")
	var start: Vector3 = room.player.global_position
	Input.action_press("move_right")
	await tick(10)
	Input.action_release("move_right")
	check(room.player.global_position.distance_to(start) < 0.01, "Player does not move while the tutorial is open")
	check(not room.pause_panel.visible, "Escape consumed: pause menu did not open under the tutorial")
	check(not room.gameplay.can_switch_role(), "Role switching blocked while open")

	# 4. Escape dismisses, remembers, and gives controls back.
	await key(KEY_ESCAPE)
	await wait_for(func() -> bool: return not popup.is_open(), "Escape did not close the tutorial")
	await tick()
	check(TutorialPopup.has_been_shown(), "Dismissal stored in the ConfigFile")
	check(room.player.controls_enabled and not room._paused and not room.pause_panel.visible, "Controls restored, game not paused, after Escape")
	Input.action_press("move_right")
	await tick(10)
	Input.action_release("move_right")
	check(room.player.global_position.distance_to(start) > 0.05, "Player moves again after closing")

	# 5. It does not come back by itself.
	room._show_first_time_tutorial()
	await create_timer(0.6).timeout
	check(not popup.is_open(), "Not shown again automatically")

	# 6. The pause menu reopens it; Back (Circle) returns to the pause menu without resuming or resetting.
	room._set_paused(true)
	check(room.get_node("%HowToPlayButton").visible, "Pause menu offers HOW TO PLAY")
	room.get_node("%HowToPlayButton").pressed.emit()
	await tick(4)
	check(popup.is_open() and popup.from_pause and not room.pause_panel.visible, "Pause menu opens the tutorial over a hidden pause panel")
	await pad(JOY_BUTTON_B)
	await wait_for(func() -> bool: return not popup.is_open(), "Controller back did not close the tutorial")
	await tick()
	check(room._paused and room.pause_panel.visible, "Back returns to the pause menu")
	check(room.get_node("%HowToPlayButton").has_focus(), "Focus returns to HOW TO PLAY")
	check(room.player.global_position.distance_to(start) > 0.05, "Reopening did not restart or move the level")
	room._set_paused(false)
	await tick()
	check(room.player.controls_enabled, "Resume works after the tutorial")

	# 7. Mouse/confirm button and the Professor's content, glyphs for PlayStation and Xbox.
	room._switch_preview_timeline()
	await tick(4)
	check(room.timeline == "Future", "Preview switched to the Professor")
	popup.open("future")
	await tick(4)
	text = popup.role_text()
	check("PROFESSOR — THE FUTURE" in text and "You can uncover the truth." in text and not ("STUDENT" in text), "Professor content shown")
	InputManager.set_device_type(InputManager.DeviceType.CONTROLLER, InputManager.ControllerType.DUALSENSE)
	check(popup.control_texts() == ["Left Stick", "✕", "□", "L3", "J", "Options"], "PlayStation glyphs: " + str(popup.control_texts()))
	InputManager.set_device_type(InputManager.DeviceType.CONTROLLER, InputManager.ControllerType.XBOX)
	check(popup.control_texts() == ["Left Stick", "A", "X", "LS", "J", "Menu"], "Xbox glyphs: " + str(popup.control_texts()))
	InputManager.set_device_type(InputManager.DeviceType.KEYBOARD)
	await capture("tutorial_professor")
	popup.confirm_button.pressed.emit()
	await wait_for(func() -> bool: return not popup.is_open(), "Confirm button did not close the tutorial")
	await tick()
	check(room.player.controls_enabled and not room._paused, "Controls restored after the confirm button")

	# 8. Other overlays still work: journal and pause.
	check(journal.can_open(), "Journal can open after the tutorial")
	await key(KEY_J)
	check(journal.is_open(), "Journal opens with J")
	await key(KEY_ESCAPE)
	await tick(2)
	check(not journal.is_open(), "Journal closes with Escape")
	await key(KEY_ESCAPE)
	check(room._paused, "Escape still opens the pause menu")
	room._set_paused(false)

	# 9. A silent close (transition, disconnect) does not count as having read it.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	popup.open("past")
	room.gameplay.close_overlays()
	check(not popup.is_open() and not TutorialPopup.has_been_shown(), "Room-initiated close is not remembered as read")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	print("TUTORIAL POPUP: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)
