extends SceneTree
## Focused deterministic checks plus the actual room, UI, collision and ending presentations.

const Rules := preload("res://scripts/level3/core_rules.gd")
var checks: int = 0
var failures: int = 0
var test_time: float = 100.0
var pm: Node
var flow: Node
var room: Node3D
var rendered: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LEVEL3 FAILED: " + message)


func tick(frames: int = 3) -> void:
	for i in range(frames): await physics_frame
	await process_frame


func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await tick()
	if current_scene == null:
		await scene_changed
		await tick()


func move_to(station: String) -> void:
	room.player.position = room.worlds[room.role].position + Rules.STATIONS[station] + Vector3(0, 0, 1.0)
	room.player.velocity = Vector3.ZERO
	await tick()


func act(action: String, data: Dictionary = {}) -> Dictionary:
	return room.request_action(action, data)


func switch_role(role: String) -> void:
	if room.role != role: room.switch_debug_role()
	await tick()


func shot(label: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://docs/assets/screenshots/level3")
	check(image.save_png("res://docs/assets/screenshots/level3/" + label + ".png") == OK, "save " + label)


func solve_to_identity() -> void:
	await switch_role("past")
	await move_to("start")
	act("start")
	await move_to("coil_0")
	act("coil", {"index": 0})
	act("coil", {"index": 0})
	await move_to("coil_2")
	act("coil", {"index": 2})
	check(room.state.stage == "STAGE_A", "Past alone cannot restore power")
	await switch_role("future")
	await move_to("receiver")
	act("receiver")
	await tick()
	check(room.state.stage == "STAGE_B", "both roles restore power immediately")
	check(room.worlds.future.gate_shape.disabled, "Future conduit physically opens")
	await move_to("anchor")
	act("anchor")
	check(room.worlds.past.waveform.text != "", "Future repair exposes Past alignment")
	await switch_role("past")
	await move_to("origin")
	act("origin")
	await move_to("sync_past")
	act("sync")
	check(room.state.stage == "STAGE_B", "one switch cannot synchronize")
	await switch_role("future")
	await move_to("sync_future")
	act("sync")
	check(room.state.stage == "STAGE_C", "two switches within window unlock identity immediately")


func _run() -> void:
	root.size = Vector2i(1600, 900)
	pm = root.get_node("PuzzleManager")
	pm.log_rejections = false
	flow = root.get_node("GameFlowManager")
	rendered = "--render-review" in OS.get_cmdline_user_args()
	Engine.set_meta("development_tools_enabled", true)
	check(change_scene_to_file("res://scenes/menu/main_menu.tscn") == OK, "main menu loads")
	await scene_changed
	await tick()
	var direct: Button = current_scene.get_node("%LevelThreeTestButton")
	check(direct.is_visible_in_tree() and root.get_visible_rect().encloses(direct.get_global_rect()), "direct test button is visible on the main menu")
	await click(direct)
	if not current_scene is Node3D:
		check(false, "direct test button launches gameplay")
		quit(1)
		return
	room = current_scene
	check(room.scene_file_path == "res://scenes/rooms/temporal_core.tscn" and flow.get_current_room_id() == "room_03", "menu click enters the registered real Level 3")
	check(not room.networked and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "direct entry stays offline without ENet")
	check(room.role == "past" and room.worlds.past.visible and not room.worlds.future.visible, "fresh preview starts in Past")
	room.player.set_physics_process(false)
	room.rules.clock = func() -> float: return test_time
	check(room.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(room.camera.fov, 48.0), "existing perspective camera preserved")
	check(is_equal_approx(room.camera.rotation.x, -deg_to_rad(35.0)), "existing pitch preserved")
	check(room.state.remaining == 150.0 and room.state.stage == "DISCOVERY", "discovery begins at exactly 150 without running")
	test_time += 1000.0
	pm.refresh_puzzle(Rules.ID)
	check(room.state.stage == "DISCOVERY" and room.state.remaining == 150.0, "no discovery timeout")
	var pause := InputEventAction.new()
	pause.action = &"ui_cancel"
	pause.pressed = true
	root.push_input(pause)
	check(room.pause_menu.panel.visible and room._paused and not room.player.controls_enabled, "Escape opens the shared pause menu and stops player input")
	room._close()
	await shot("past_discovery")
	# Use the real interaction detector/controller and verify deliberate confirmation.
	await move_to("start")
	check(room.controller.get_current_interactable() != null, "physical proximity selects a station")
	check(room.controller.try_interact(), "real controller opens start confirmation")
	check(room.devices.inspector.active and room.state.stage == "DISCOVERY", "opening the physical console does not start timer")
	room._close()
	var revision: int = pm.get_revision(Rules.ID)
	room.player.position = Vector3(8, 0, 6)
	check(act("start").status == 0 and pm.get_revision(Rules.ID) == revision, "host refuses out-of-range request")
	await move_to("evidence_past")
	room.operate("evidence_past")
	check(root.get_node("JournalManager").is_unlocked("l3_authorization"), "evidence saved locally")
	check(not root.get_node("JournalManager").is_unlocked("l3_continuity"), "partner evidence not mirrored")
	await shot("private_evidence")
	room._close()
	await move_to("start")
	act("start")
	check(room.state.remaining == 150 and room.state.stage == "STAGE_A", "deliberate activation starts challenge")
	check(act("start").status == 0, "duplicate start refused")
	await move_to("coil_0")
	for i in range(3): act("coil", {"index": 0})
	check(room.state.coils[0] == 0, "wrong coil position cycles back reversibly")
	test_time += 140.0
	pm.refresh_puzzle(Rules.ID)
	check(is_equal_approx(room.state.remaining, 10.0), "host deadline drives countdown")
	var attempt: int = room.state.attempt
	test_time += 10.0
	pm.refresh_puzzle(Rules.ID)
	check(room.state.stage == "OVERLOAD" and room.state.remaining == 0, "exact expiry overloads, never negative")
	test_time += 3.0
	pm.refresh_puzzle(Rules.ID)
	check(room.state.stage == "OVERLOAD" and room.state.attempt == attempt, "timeout stays latched during destruction")
	await create_timer(5.3).timeout
	while flow.is_transitioning(): await process_frame
	check(flow.get_current_room_id() == "room_01", "timeout restarts the campaign in Room 1")
	check(not root.get_node("JournalManager").is_unlocked("l3_authorization"), "campaign restart clears discovered evidence")
	check(flow.start_room("room_03"), "return to isolated core for ending regression checks")
	room = current_scene
	room.player.set_physics_process(false)
	room.rules.clock = func() -> float: return test_time
	var stale: Dictionary = pm.submit_action(Rules.ID, "start", {"attempt": attempt, "seq": 9000}, "past")
	check(stale.status == 0, "old-attempt action refused")
	# One full solution, with an expired sync window and retry before the ending matrix.
	await solve_to_identity()
	check(not room.state.has("choices") and not str(room.state).contains("GROUND THE CORE"), "public state has no private commands")
	var matrix := [["GROUND THE CORE", "RELEASE THE ECHO", "trust"], ["CLAIM ORIGIN", "RELEASE THE ECHO", "student_override"], ["GROUND THE CORE", "PRESERVE ECHO", "professor_override"], ["CLAIM ORIGIN", "PRESERVE ECHO", "paradox"]]
	for row: Array in matrix:
		if room.state.stage != "STAGE_C": await solve_to_identity()
		await switch_role("past")
		await move_to("terminal_past")
		room.operate("terminal_past")
		check(room.devices.inspector.active, "role-specific physical terminal opens")
		room._confirm_command(row[0])
		check(not room.state.locked_past, "confirmation UI does not submit a vote")
		await shot("identity_terminal" if row[2] == "trust" else "identity_" + row[2])
		room._close()
		act("choose", {"command": row[0]})
		check(room.state.stage == "STAGE_C" and room.state.locked_past, "one private decision waits for partner")
		check(not str(room.state).contains(row[0]), "first private command absent from snapshot")
		check(act("choose", {"command": "CLAIM ORIGIN"}).status == 0, "cannot change a locked command")
		await switch_role("future")
		await move_to("terminal_future")
		check(act("choose", {"command": "GROUND THE CORE"}).status == 0, "other role command refused")
		act("choose", {"command": row[1]})
		check(room.state.ending == row[2] and pm.is_solved(Rules.ID), "correct ending: " + row[2])
		test_time += 200
		pm.refresh_puzzle(Rules.ID)
		check(room.state.stage == "ENDING", "late timeout cannot overwrite ending")
		if rendered:
			await create_timer(3.0).timeout
			await shot("ending_" + row[2])
		room._ending_tween.kill()
		room._show_conclusion()
		check(room.ui.visible_modal, "ending has usable navigation")
		# Exercise the actual navigation action while the offline preview views Future.
		room.replay_attempt()
		check(room.state.stage == "DISCOVERY" and room.state.remaining == 150, "replay resets only reactor")
	# Explicit timed sync retry on pure rules (same production implementation).
	var rules := Rules.new()
	rules.clock = func() -> float: return test_time
	var s := rules.get_initial_state()
	s.stage = "STAGE_B"
	s.anchor = true
	s.origin = true
	rules._deadline = test_time + 150
	s = rules.apply_action("sync", {"seq": 1}, "past", s).state
	test_time += 5.01
	s = rules.refresh_state(s).state
	check(not s.sync_past and not s.sync_future and s.stage == "STAGE_B", "missed sync window resets both switches")
	check(rules.validate_action("sync", {"attempt": s.attempt, "seq": 2}, "past", s) == "", "missed window is retryable")
	rules.clock = Callable()
	check(not room.accept_future_pose(Vector3(NAN, 0, 0)), "nonfinite position refused")
	check(not room.accept_future_pose(Vector3(7, 0, -6)), "teleport refused")
	await switch_role("past")
	await move_to("start")
	act("start")
	room.networked = true
	root.get_node("NetworkManager").in_game = false
	room._on_connection()
	var frozen: Dictionary = room.state.duplicate(true)
	await tick()
	check(room.disconnected and not room.player.controls_enabled and room.ui.visible_modal, "disconnect suspends gameplay with recovery action")
	check(room.state == frozen, "disconnect does not advance attempt")
	room.rules.clock = Callable()
	var session: int = pm.get_session_id()
	var old_attempt: int = room.state.attempt
	await click(room.ui.modal_box.find_children("*", "Button", true, false)[0])
	check(current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", "return button restores main menu")
	await click(current_scene.get_node("%LevelThreeTestButton"))
	room = current_scene
	check(pm.get_session_id() != session and room.state.attempt > old_attempt, "relaunch starts a new session and attempt")
	check(room.role == "past" and room.state.stage == "DISCOVERY" and room.state.remaining == 150.0, "relaunch resets role and leaves the 150-second clock idle")
	check(room.state.coils == [0, 0, 0] and not room.state.receiver and not room.state.anchor and not room.state.origin and not room.state.sync_past and not room.state.sync_future, "relaunch resets real puzzles and temporary interactions")
	check(not room.state.locked_past and not room.state.locked_future and room.state.ending.is_empty() and not room.disconnected and not room.ui.visible_modal, "relaunch clears decisions, ending and modal state")
	check(not root.get_node("JournalManager").is_unlocked("l3_authorization"), "new test session clears prior evidence")
	room.queue_free()
	await tick()
	await create_timer(.2).timeout
	print("LEVEL3 CORE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
