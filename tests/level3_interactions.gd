extends SceneTree
## Interaction audit through the production detector, physical inspector, native
## focus buttons and PuzzleManager. --render-review also saves real room views.
const Rules := preload("res://scripts/level3/core_rules.gd")
const Inputs := preload("res://scripts/input/input_manager.gd")
var room: Node3D
var pm: Node
var checks := 0
var failures := 0
var now := 100.0
var rendered := false


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LEVEL3 INTERACTION FAILED: " + message)


func tick(count: int = 4) -> void:
	for i in count: await physics_frame
	await process_frame


func shot(label: String) -> void:
	if not rendered: return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/assets/screenshots/level3")
	root.get_texture().get_image().save_png("res://docs/assets/screenshots/level3/interaction_" + label + ".png")


func switch(role: String) -> void:
	room._close()
	if room.role != role: room.switch_debug_role()
	room.player.set_physics_process(false)
	await tick()


func open(id: String) -> void:
	room._close()
	room.player.position = room.worlds[room.role].position + Rules.STATIONS[id] + Vector3(0, 0, 0.8)
	room.camera_rig.snap_to_target()
	await tick()
	var target: Node = room.controller.get_current_interactable()
	check(target != null and target.name == id, id + " is physically approachable and targeted")
	check(room.controller.try_interact(), id + " opens through InteractionController")
	check(room.devices.inspector.active and not room.player.controls_enabled, id + " opens an inspection and locks movement")
	check(room.devices.active_id == id and room.ui.device_panel.visible, id + " shows its actual controls")


func press(caption: String) -> void:
	check(room.devices.inspector.press_control(caption), "physical control responds: " + caption)
	await tick(8)


func accept(button: Button, joy: bool = false) -> void:
	button.grab_focus()
	for down in [true, false]:
		var event: InputEvent
		if joy:
			var pad := InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_A
			pad.pressed = down
			event = pad
		else:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_ENTER
			key.keycode = KEY_ENTER
			key.pressed = down
			event = key
		root.push_input(event, true)
		await tick(2)


func cancel() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	root.push_input(event, true)
	await tick()
	check(not room.devices.inspector.active and not room.ui.visible_modal and room.player.controls_enabled, "Cancel returns to gameplay without opening pause")
	check(room.player.visible and room.camera_rig.is_processing() and is_equal_approx(room.camera.fov, 48.0), "Cancel restores actor and camera")


func arm() -> void:
	await switch("past")
	await open("start")
	await press("ARM REACTOR...")
	check(room.ui.visible_modal and room.state.stage == "DISCOVERY", "ARM requires separate confirmation")
	var options: Array[Node] = room.ui.modal_box.find_children("*", "Button", true, false)
	check(options[0].has_focus(), "safe cancel has initial confirmation focus")
	await accept(options[1])
	check(room.state.stage == "STAGE_A" and room.state.remaining == 150.0, "confirmed ARM starts the real 150-second host deadline")


func power() -> void:
	await open("coil_0")
	await press("SET POSITION 2")
	check(room.state.coils[0] == 2 and room.devices.pending.is_empty(), "selector reaches stop 2 through confirmed cycle actions")
	check(not room.devices.inspector.press_control("SET POSITION 2"), "current stop cannot issue redundant actions")
	await shot("coil")
	await open("coil_1")
	await press("SET POSITION 2")
	await press("SET POSITION 0")
	check(room.state.coils[1] == 0, "incorrect coil setting is reversible")
	await open("coil_2")
	# Native focus activation uses the same physical action as mouse picking.
	await accept(room.ui.device_buttons["SET POSITION 1"], true)
	await tick(8)
	check(room.state.coils == [2, 0, 1] and room.state.stage == "STAGE_A", "Xbox / DualSense accept operates a real relay; receiver still required")
	await switch("future")
	await open("receiver")
	await press("RECONNECT BATTERY")
	check(room.state.receiver and room.state.stage == "STAGE_B", "battery reconnect updates canonical power state")
	check(room.devices.readouts["future/receiver"].text == "CONNECTED", "battery readout uses confirmed state")
	check(not room.devices.inspector.press_control("RECONNECT BATTERY"), "latched battery cannot submit twice")
	await cancel()


func align(miss_window: bool = false) -> void:
	await switch("past")
	await open("origin")
	check(not room.devices.inspector.press_control("STABILIZE ORIGIN CORE"), "Origin control waits for Professor calibration")
	await switch("future")
	await open("anchor")
	await press("CALIBRATE SIGNAL ANCHOR")
	check(room.state.anchor and not room.worlds.past.waveform.text.is_empty(), "Professor calibration exposes Past waveform")
	await switch("past")
	await open("origin")
	await press("STABILIZE ORIGIN CORE")
	check(room.state.origin, "Student stabilization latches canonical contact")
	await open("sync_past")
	await press("ENGAGE PHASE SWITCH")
	check(room.state.sync_past and room.state.stage == "STAGE_B", "one phase switch starts a window without completing it")
	if miss_window:
		now += 5.01
		pm.refresh_puzzle(Rules.ID)
		await tick()
		check(not room.state.sync_past and not room.state.sync_future, "late synchronization resets both physical switches")
		check(not room.ui.device_buttons["ENGAGE PHASE SWITCH"].disabled, "expired window makes physical switch retryable")
		await press("ENGAGE PHASE SWITCH")
	await switch("future")
	await open("sync_future")
	await press("ENGAGE PHASE SWITCH")
	check(room.state.stage == "STAGE_C", "two physical switches unlock identity through server rules")
	await cancel()


func choose(role: String, command: String) -> void:
	await switch(role)
	await open("terminal_" + role)
	await shot("terminal_" + role)
	await press(command)
	check(room.ui.visible_modal and not room.state["locked_" + role], "terminal selection previews a private command without locking it")
	var buttons: Array[Node] = room.ui.modal_box.find_children("*", "Button", true, false)
	check(buttons[0].has_focus(), "terminal confirmation defaults to BACK")
	await accept(buttons[1], true)
	check(room.state["locked_" + role], "controller confirmation locks the host-validated private command")


func _run() -> void:
	root.size = Vector2i(1600, 900)
	pm = root.get_node("PuzzleManager")
	pm.log_rejections = false
	rendered = "--render-review" in OS.get_cmdline_user_args()
	root.get_node("GameFlowManager").start_room("room_03")
	await tick()
	room = current_scene
	room.player.set_physics_process(false)
	room.rules.clock = func() -> float: return now
	await shot("discovery")
	for role in ["past", "future"]:
		await switch(role)
		for id: String in room.worlds[role].stations:
			if not room.devices.is_device(id): continue
			await open(id)
			if id != "start":
				for caption: String in room.devices.inspector.controls:
					check(not room.devices.inspector.press_control(caption), "premature control is disabled: " + id)
			await cancel()
	# Deliberate arming and real mouse ray picking; cancel it before the main flow.
	await switch("past")
	await open("start")
	await create_timer(0.35).timeout
	var control: Node3D = room.devices.bindings["past/start"]["ARM REACTOR..."]
	var point: Vector2 = room.camera.unproject_position(control.global_position)
	await physics_frame
	check(room.devices.inspector.control_at(point) == "ARM REACTOR...", "camera framing exposes ray-pickable physical ARM button")
	for down in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.pressed = down
		root.push_input(mouse, true)
		await process_frame
	check(room.ui.visible_modal and room.state.stage == "DISCOVERY", "real mouse click opens explicit arming confirmation")
	await cancel()
	var matrix := [["GROUND THE CORE", "RELEASE THE ECHO", "trust"], ["CLAIM ORIGIN", "RELEASE THE ECHO", "student_override"], ["GROUND THE CORE", "PRESERVE ECHO", "professor_override"], ["CLAIM ORIGIN", "PRESERVE ECHO", "paradox"]]
	for row: Array in matrix:
		await arm()
		await power()
		await align(row[2] == "trust")
		await choose("past", row[0])
		check(not str(room.state).contains(row[0]), "confirmed snapshots do not expose private command")
		await choose("future", row[1])
		check(room.state.stage == "ENDING" and room.state.ending == row[2], "physical flow preserves ending " + row[2])
		check(not room.devices.inspector.active, "ending exits inspection cleanly")
		room._ending_tween.kill()
		room._show_conclusion()
		room.replay_attempt()
		await tick()
		check(room.state.stage == "DISCOVERY", "replay restores all physical controls")
	await arm()
	await open("coil_0")
	now += 150.0
	pm.refresh_puzzle(Rules.ID)
	check(room.state.stage == "OVERLOAD" and not room.devices.inspector.active, "timeout closes inspection and overloads through host deadline")
	now += 3.0
	pm.refresh_puzzle(Rules.ID)
	await tick()
	check(room.state.stage == "DISCOVERY" and room.state.coils == [0, 0, 0] and room.player.controls_enabled, "timeout retry restores room and controls")
	room.rules.clock = Callable()
	print("LEVEL3 INTERACTIONS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
