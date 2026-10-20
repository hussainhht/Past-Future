extends SceneTree
## Launch the real menu, then drive the actual lab using its interaction/controller APIs.
## Optional GAMEPLAY_REVIEW_DIR captures the real integrated screens with a renderer.

const FREQUENCY := "puzzle_01_frequency"
const RELAY := "laboratory_receiver_relay"

var room: Node3D
var game: Node3D
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func tick(frames: int = 4) -> void:
	for i in range(frames):
		await physics_frame
	await process_frame


func wait_for(predicate: Callable, message: String, timeout: float = 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func press(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func capture(name: String) -> void:
	var directory := OS.get_environment("GAMEPLAY_REVIEW_DIR")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await create_timer(0.22).timeout  # inspect the settled native UI fade, not its first frame
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "Capture " + name)


func finish_dialogue() -> void:
	for i in range(32):
		if not game.director.is_dialogue_active():
			return
		game.director.skip_typewriter()
		game.director.advance_dialogue()
		await process_frame
	check(false, "Dialogue failed to finish through the public director API")


func approach(position: Vector3, expected: Node) -> void:
	room.player.global_position = position
	room.player.velocity = Vector3.ZERO
	await tick(6)
	check(game.controller.get_current_interactable() == expected, "Existing detector selects " + str(expected.name))
	await press(KEY_F)


func _run() -> void:
	var puzzles: Node = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	var menu: Control = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.settings_path = "user://gameplay_integration_settings.cfg"
	root.add_child(menu)
	current_scene = menu
	await tick()
	menu.get_node("%PlayButton").pressed.emit()
	check(menu.get_node("Overlay").visible and "SOLO TEST" in menu.get_node("%PreviewButton").text, "Existing Play page offers a clearly labelled Solo Test")
	await capture("01_main_menu_play")
	menu.get_node("%PreviewButton").pressed.emit()
	if not await wait_for(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://scenes/world/spawn_area.tscn", "Solo menu failed to enter actual laboratory"):
		quit(1)
		return
	room = current_scene
	room.pause_when_unfocused = false
	room._set_paused(false)
	game = room.gameplay
	await tick()
	check(room.timeline == "Past" and game.configured, "Solo starts as Student in real Past environment")
	check(room.player.scene_file_path.ends_with("student_3d_player.tscn"), "Student uses the finished animated character")
	check(room.get_node("Actors/Console/Visual").get_child_count() > 0, "Existing modelled console is reused")
	check(room.get_node("Actors").find_children("*", "CharacterBody3D", false, false).size() == 1, "Exactly one locally controlled character")
	check(room.player.find_children("InteractionRig", "Node3D", false, false).size() == 1, "One interaction rig per player")
	check(get_nodes_in_group("dialogue_director").size() == 1, "One actual DialogueDirector without duplicate dialogue widgets")
	check(game.director is DialogueDirector and game.director.dialogue_box is DialogueBox, "Integrated dialogue uses actual director and box APIs")
	check(not game.radio.owns_radio and game.get_node("GameplayHUD/RadioHUD").frequency_label.text == "-- MHz", "Unacquired radio hides calibration clue")
	var original: Vector3 = room.player.position
	var camera_start: Vector3 = room.camera.global_position
	Input.action_press("move_right")
	await tick(20)
	Input.action_release("move_right")
	await tick(8)
	check(room.player.position.x > original.x + 0.4, "Normal gameplay movement works from the menu")
	check(room.camera.global_position.x > camera_start.x + 0.2, "Existing camera follows gameplay movement")
	room.respawn()
	await capture("02_past_lab")
	var relay_revision: int = puzzles.get_revision(RELAY)
	await approach(Vector3(-9.9, 0, -2.5), game.get_node("Props/ReceiverRelay"))
	if not await wait_for(func() -> bool: return not room.player.is_action_active(), "Relay interaction failed to return control"):
		quit(1)
		return
	check(not puzzles.is_solved(RELAY) and puzzles.get_revision(RELAY) == relay_revision, "Auxiliary relay cannot bypass the required radio link")
	check("needs an established temporal radio link" in game.objective.text, "Premature relay use gives actionable gameplay feedback")
	var student_pickup: Node = game.get_node("Props/StudentRadio")
	await approach(Vector3(-5.4, 0, 1.6), student_pickup)
	check(room.player.is_action_active() and not game.radio.owns_radio, "Pickup animation precedes ownership grant")
	check(not game.controller.try_interact(), "Second interaction is refused during pickup animation")
	if not await wait_for(func() -> bool: return game.radio.owns_radio, "Student radio pickup failed"):
		quit(1)
		return
	check(puzzles.get_state(FREQUENCY).student_radio and not puzzles.get_state(FREQUENCY).professor_radio, "Student pickup changes only Student ownership")
	check(not student_pickup.placeholder.visible, "Confirmed pickup removes world radio")
	check(room.player.skeleton.get_node("HeldRadioSocket/PlaceholderRadio").visible, "Owned radio is attached to actual hand socket")
	check(not room.player._held_document.visible, "Held radio does not display the character's demonstration paper")
	check(game.director.get_current_sequence_id() == "opening_past", "Actual DialogueTrigger starts Past-specific discovery sequence")
	await finish_dialogue()
	await capture("08_held_student_radio")
	await approach(Vector3(0, 0, -2.8), game.get_node("Props/MainComputer"))
	if not await wait_for(func() -> bool: return game.terminal.visible, "Main console did not open terminal after animation"):
		quit(1)
		return
	check(not room.player.controls_enabled and not game.controller.is_interaction_available(), "Console modal owns movement and interaction input")
	var revision: int = puzzles.get_revision(FREQUENCY)
	game.terminal.frequency_input.text = "66"
	game.terminal._validate_text("66")
	check(game.terminal.submit_frequency().status == 1 and "SIGNAL NOT FOUND" in game.terminal.feedback_label.text, "Incorrect frequency produces normal retry feedback in real lab")
	check(puzzles.get_revision(FREQUENCY) == revision, "Incorrect attempt creates no authoritative revision")
	await capture("03_terminal_retry")
	game.terminal.frequency_input.text = "67"
	game.terminal._validate_text("67")
	check(game.terminal.submit_frequency().status == 2 and not puzzles.is_solved(FREQUENCY), "Calibration waits for missing Professor radio")
	await press(KEY_ESCAPE)
	check(not game.terminal.visible and not room._paused and room.player.controls_enabled, "Escape closes terminal without opening pause or leaving movement locked")
	var radio_instance: int = game.radio.get_instance_id()
	await press(KEY_T)
	await tick()
	check(room.timeline == "Future" and room.player.scene_file_path.ends_with("professor_3d_player.tscn"), "Solo switches to real Professor model and Future environment")
	check(game.radio.get_instance_id() == radio_instance and game.radio.get_parent() == room.player, "Role switch rebinds the existing radio component without resetting state")
	check(room.get_node("CameraRig").target == room.player and game.controller.actor == room.player, "Camera and interaction controller follow the new local character")
	check(not student_pickup.visible and game.get_node("Props/ProfessorRadio").visible, "Role-specific world radios use the corresponding timeline")
	await capture("04_future_lab")
	await approach(Vector3(5.4, 0, 1.6), game.get_node("Props/ProfessorRadio"))
	if not await wait_for(func() -> bool: return puzzles.is_solved(FREQUENCY), "Final radio did not establish temporal connection"):
		quit(1)
		return
	check(game.radio.can_receive() and game.get_node("GameplayHUD/RadioHUD").status_label.text == "CONNECTED", "Confirmed link updates actual radio HUD")
	check(game.get_node("Props/TemporalRift").connected, "Actual laboratory rift reflects connection")
	check("TEMPORAL RADIO LINK ESTABLISHED" in game.objective.text, "Gameplay displays required success text")
	check(game.director.get_current_sequence_id() == "laboratory.radio_link_established", "Confirmed solve starts real sequence-based radio conversation")
	check(game.director.dialogue_box.radio_mode and "67 MHz" in game.director.dialogue_box.channel_label.text, "Actual DialogueBox shows radio frequency and channel status")
	check(game.director.dialogue_box.get_speaker_text() == "The Student", "Radio sequence begins with correct Student speaker")
	check(not room.player.controls_enabled, "Blocking radio conversation owns gameplay input")
	await capture("05_radio_dialogue")
	room._set_paused(true)
	var line_index: int = game.director.get_current_line_index()
	await press(KEY_F)
	await tick(4)
	check(room.pause_panel.visible and game.director.get_current_line_index() == line_index, "Pause panel blocks dialogue advance")
	check(room.get_node("PauseLayer").layer > game.director.dialogue_box.layer, "Pause renders above dialogue and modals")
	await capture("06_pause")
	room.get_node("%ResumeButton").pressed.emit()
	check(not room._paused and not room.player.controls_enabled, "Resume retains active dialogue input lock")
	revision = puzzles.get_revision(FREQUENCY)
	game.radio.interfere(0.08)
	check(not game.radio.can_receive() and "INTERFERENCE" in game.director.dialogue_box.channel_label.text, "Interference updates actual dialogue status")
	await create_timer(0.18).timeout
	check(game.radio.can_receive() and puzzles.get_revision(FREQUENCY) == revision, "Signal recovers without changing persistent puzzle state")
	check(game.radio.transmitting, "Radio signal animation resumes after interference")
	game.director.skip_typewriter()
	game.director.advance_dialogue()
	check(game.director.dialogue_box.get_speaker_text() == "The Professor", "Actual director alternates Student and Professor")
	await finish_dialogue()
	check(room.player.controls_enabled and game.adapter.active_sequence_id.is_empty(), "Dialogue completion restores controls and adapter lifetime")
	await approach(Vector3(6.7, 0, 1.6), game.get_node("Props/ResearchLog"))
	if not await wait_for(func() -> bool: return game.reader.visible, "Future research reader failed"):
		quit(1)
		return
	check("67 MHz" in game.reader.document_label.text and not room.player.controls_enabled, "Research log is readable in actual Future lab with safe modal input")
	await capture("07_research_log")
	await press(KEY_ESCAPE)
	check(not game.reader.visible and game.director.get_current_sequence_id() == "future_discovery", "Future-specific actual dialogue resumes after document closes")
	await finish_dialogue()
	await press(KEY_T)
	await tick()
	check(room.timeline == "Past" and game.radio.owns_radio and game.radio.can_receive(), "Returning to Student preserves both acquisitions and calibrated link")
	await approach(Vector3(-9.9, 0, -2.5), game.get_node("Props/ReceiverRelay"))
	if not await wait_for(func() -> bool: return puzzles.is_solved(RELAY), "Receiver relay puzzle failed"):
		quit(1)
		return
	check(game.director.get_current_sequence_id() == "laboratory.receiver_online", "Confirmed auxiliary puzzle completion triggers real radio dialogue")
	await finish_dialogue()
	var radio_revision: int = puzzles.get_revision(FREQUENCY)
	await approach(Vector3(-3, 0, -3.3), game.get_node("Props/RadioCheck"))
	check(game.director.get_current_sequence_id() == "laboratory.radio_check", "Persistent receiver interaction requests another real radio conversation")
	await finish_dialogue()
	check(puzzles.get_revision(FREQUENCY) == radio_revision, "Later radio conversation leaves authoritative progress unchanged")
	var session: int = puzzles.get_session_id()
	revision = puzzles.get_revision(FREQUENCY)
	# Reload the actual gameplay scene, not a mock presentation node or sandbox.
	game.stop_audio()
	check(change_scene_to_file("res://scenes/world/spawn_area.tscn") == OK, "Real gameplay room reload begins")
	await scene_changed
	room = current_scene
	room.pause_when_unfocused = false
	room._set_paused(false)
	game = room.gameplay
	await tick()
	check(puzzles.get_session_id() == session and puzzles.get_revision(FREQUENCY) == revision and game.radio.can_receive(), "Actual scene transition preserves ownership, calibration, session and revision")
	check(not game.director.is_dialogue_active() and game.adapter.active_sequence_id.is_empty(), "New room does not replay connection conversation")
	check(room.player.skeleton.get_node("HeldRadioSocket/PlaceholderRadio").visible, "New character presentation recovers held radio from confirmed state")
	await approach(Vector3(0, 0, -2.8), game.get_node("Props/MainComputer"))
	if not await wait_for(func() -> bool: return game.terminal.visible, "Recreated lab terminal failed to open"):
		quit(1)
		return
	check(game.terminal.status_label.text == "TEMPORAL RADIO LINK ESTABLISHED" and game.terminal.frequency_input.text == "67", "Reopened actual console restores the calibrated connection")
	await capture("09_connected_terminal")
	await press(KEY_ESCAPE)
	room._set_paused(true)
	room.get_node("%ResetSoloButton").pressed.emit()
	check(puzzles.get_session_id() != session and not puzzles.is_solved(FREQUENCY) and not puzzles.is_solved(RELAY), "Explicit solo reset clears puzzles under a new session")
	check(room.timeline == "Past" and not game.radio.owns_radio and room.player.controls_enabled, "Reset restores Student gameplay without stale locks")
	check(game.get_node("Props/StudentRadio").placeholder.visible and game.director.get_played_ids().is_empty(), "Reset restores pickups and clears dialogue history")
	room._set_paused(true)
	room.get_node("%MenuButton").pressed.emit()
	if not await wait_for(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", "Return to Menu failed"):
		quit(1)
		return
	check(get_nodes_in_group("dialogue_director").is_empty() and root.get_node("NetworkManager").state == 0, "Returning to menu releases dialogue and network session resources")
	current_scene.get_node("%PlayButton").pressed.emit()
	current_scene.get_node("%PreviewButton").pressed.emit()
	await scene_changed
	room = current_scene
	room.pause_when_unfocused = false
	await tick()
	check(room.timeline == "Past" and not room.gameplay.radio.owns_radio and not puzzles.is_solved(FREQUENCY), "Next menu-launched game starts with fresh radio state")
	room._return_to_menu()
	await scene_changed
	await create_timer(0.15).timeout
	print("GAMEPLAY SOLO: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
