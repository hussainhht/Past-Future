extends SceneTree
## Real presentation stress checks: simultaneous messages, dialogue, thoughts, resize and equipment.
const WorldText = preload("res://scripts/ui/world_text_layout.gd")
var room
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func tick(frames: int = 8) -> void:
	for index in frames: await process_frame
func capture(name: String) -> void:
	var directory := OS.get_environment("TEXT_LAYOUT_REVIEW_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await create_timer(.4).timeout
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "Capture " + name)
func separate(a: Control, b: Control, message: String) -> void:
	check(not a.get_global_rect().intersects(b.get_global_rect()), message)
func check_inspection(inspector: Node, ui: LabUI, name: String) -> void:
	var panel: Rect2 = inspector._record_panel.get_global_rect()
	check(root.get_visible_rect().encloses(panel), name + ": record stays on screen")
	check(inspector._record_layer.visible and inspector._record_layer.layer > 0, name + ": record renders in front of scene geometry")
	check(not panel.intersects(inspector.equipment_screen_rect()), name + ": record never covers the equipment")
	check(inspector._equipment_rect.encloses(inspector.equipment_screen_rect()), name + ": complete equipment fits its reserved view")
	check(not panel.intersects(ui._sidebar.get_global_rect()), name + ": record stays clear of player help")
	check(not panel.intersects(ui._observation_panel.get_global_rect()), name + ": record stays clear of character thoughts")
	separate(inspector._record_title, inspector._record_scroll, name + ": title and scrollable text stay separate")
	for control: Dictionary in inspector.controls.values():
		var point: Vector2 = room.camera.unproject_position(control.visual.global_position)
		check(not panel.has_point(point) and inspector._equipment_rect.has_point(point), name + ": physical control remains visible outside the record")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.gui_disable_input = true
	room = load("res://scenes/world/maintenance_corridor.tscn").instantiate()
	room.pause_when_unfocused = false
	root.add_child(room)
	current_scene = room
	room.set_process_input(false)
	room.ui.inspector.set_process_input(false)
	await tick()
	room.director.stop_dialogue()
	room._pending_lines.clear()
	for dimensions in [Vector2i(1600,900), Vector2i(1280,720), Vector2i(960,540)]:
		root.size = dimensions
		if room.role != "past": room.switch_role()
		room.director.stop_dialogue()
		room._pending_lines.clear()
		await tick()
		var ui = room.ui
		ui.set_guidance("Check the service labels and compare the load readings before committing the support plan. ".repeat(5))
		ui.toast("Auxiliary voltage dropped. Repair both connections before attempting another transfer. ".repeat(3), 30)
		ui.banner("A LONG STATUS UPDATE THAT NEEDS MULTIPLE LINES", "The emergency distribution system has accepted the latest confirmed setting. ".repeat(2), 30)
		ui.observe("Student", "The instructions mention a separate return line. I should check that before touching the switch. ".repeat(3))
		var sequence := DialogueSequence.new()
		sequence.sequence_id = "layout_%d" % dimensions.x
		sequence.playback_mode = DialogueSequence.PlaybackMode.NON_BLOCKING
		var line := DialogueLine.new()
		line.speaker_name = "Professor"
		line.text = "The ceiling has moved. I can see the old support markings again, but the archive door is still sealed. ".repeat(6)
		sequence.lines.assign([line])
		check(room.director.play_dialogue(sequence), "Start real dialogue during a pending thought")
		room.director.dialogue_box.reveal_all()
		await tick(20)
		check(not ui._observation_panel.visible and ui._observation_remaining > 7.0, "Thought waits without expiring while dialogue owns the subtitle area")
		separate(ui._guide, ui._toast, "Guide and feedback stack without intersection")
		separate(ui._toast, ui._banner, "Feedback and banner stack without intersection")
		var panel: Control = room.director.dialogue_box.get_node("%DialoguePanel")
		separate(panel, ui._sidebar, "Dialogue is outside the message column")
		check(panel.get_global_rect().position.y >= 145.0, "Long dialogue stays below the header")
		check(panel.get_global_rect().end.y <= dimensions.y - 145.0, "Dialogue leaves space for interaction and footer")
		check(root.get_visible_rect().encloses(ui._sidebar.get_global_rect()), "Message column stays on screen after resize")
		var flow_overlay = root.get_node("GameFlowManager").overlay
		flow_overlay.show_readiness("Maintenance Corridor", true, false)
		flow_overlay.show_notice("Finish the conversation before leaving.")
		await tick(3)
		check(not flow_overlay.message_rect().intersects(ui._sidebar.get_global_rect()), "Incoming level-flow notice stays separate from room guidance")
		check(root.get_visible_rect().encloses(ui._sidebar.get_global_rect()), "Readiness and refusal notices leave a bounded scrollable guide")
		flow_overlay.hide_notice()
		flow_overlay.hide_readiness()
		await tick(3)
		await capture("dialogue_%d" % dimensions.x)
		root.gui_disable_input = false
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = panel.get_global_rect().position + Vector2(90,90)
		click.pressed = true
		Input.parse_input_event(click)
		await tick(2)
		click = click.duplicate()
		click.pressed = false
		Input.parse_input_event(click)
		await tick(2)
		check(not room.director.is_dialogue_active(), "Clicking the scrolled dialogue still advances the conversation")
		root.gui_disable_input = true
		room.director.stop_dialogue()
		await create_timer(.3).timeout
		await tick()
		check(ui._observation_panel.visible, "Deferred thought resumes after dialogue fades away")
		separate(ui._observation_panel, ui._sidebar, "Thought stays clear of the right-side messages")
		room.set_paused(true)
		check(not ui._sidebar.visible and not ui._observation_panel.visible, "Pause suppresses background text")
		room.set_paused(false)
		room._show_device("Service")
		ui.set_guidance("Inspect the physical isolator before operating it.")
		await create_timer(.4).timeout
		await tick()
		check(not room.prompt.root_control.visible, "World interaction prompt cannot linger over the equipment close-up")
		check(ui._sidebar.scroll_vertical == 0, "New equipment instructions start at the top of the message column")
		check_inspection(ui.inspector, ui, "Service %d" % dimensions.x)
		await capture("device_%d" % dimensions.x)
		ui.close_modal()
		var puzzles := root.get_node("PuzzleManager")
		puzzles.submit_action("puzzle_02_maintenance", "isolate_service", {}, "past")
		puzzles.submit_action("puzzle_02_maintenance", "charge_battery", {}, "future")
		# Inspect every station in both roles, including the diagnostic shown in the reported image.
		for role in ["past", "future"]:
			if room.role != role: room.switch_role()
			room.director.stop_dialogue()
			room._pending_lines.clear()
			for id in room.devices:
				if not room.devices[id].is_timeline_allowed(role): continue
				room._show_device(id)
				await create_timer(.32).timeout
				await tick(2)
				check_inspection(ui.inspector, ui, "%s %s %d" % [role, id, dimensions.x])
				if id == "Diagnostic": await capture("diagnostic_%d" % dimensions.x)
				room.set_paused(true)
				await tick(2)
				check(not ui.inspector._record_layer.visible, "Paused inspection hides the record")
				room.set_paused(false)
				ui.close_modal()
				check(not ui.inspector._record_layer.visible, "Closing inspection hides the record")
		room.player.position = Vector3(0,0,2.6)
		room.get_node("CameraRig").snap_to_target()
		await tick()
		var visible_labels: Array[Label3D] = []
		for label in room._floating_labels:
			if label.is_visible_in_tree(): visible_labels.append(label)
		for a in visible_labels.size():
			for b in range(a+1, visible_labels.size()):
				check(not WorldText.screen_rect(visible_labels[a], room.camera).intersects(WorldText.screen_rect(visible_labels[b], room.camera)), "Floating captions remain disjoint")
	room.queue_free()
	await tick(3)
	# The laboratory also reserves the radio HUD's row above the message column.
	root.size = Vector2i(960,540)
	room = load("res://scenes/world/spawn_area.tscn").instantiate()
	room.pause_when_unfocused = false
	room.level_travel_enabled = false
	root.add_child(room)
	current_scene = room
	await tick()
	room._set_paused(false)
	var lab_ui = room.lab.ui
	separate(room.gameplay.get_node("GameplayHUD/RadioHUD"), lab_ui._sidebar, "Laboratory radio status and guide use separate rows")
	room.gameplay.director.stop_dialogue()
	for dimensions in [Vector2i(1600,900), Vector2i(1280,720), Vector2i(960,540)]:
		root.size = dimensions
		await tick()
		for role in ["past", "future"]:
			room.timeline = "Past" if role == "past" else "Future"
			room._apply_timeline()
			room.gameplay.director.stop_dialogue()
			var devices = room.gameplay.physical_devices
			if role == "past": devices.open_frequency(room.player, role)
			else: devices.open_log("RECOVERED RECORD\n" + "A retained calibration entry at 67 MHz. ".repeat(20), room.player, role)
			await create_timer(.35).timeout
			await tick()
			check_inspection(devices.inspector, lab_ui, "Laboratory %s %d" % [role, dimensions.x])
			await capture("console_%s_%d" % [role, dimensions.x])
			if role == "future" and dimensions.x == 960:
				var inspector = devices.inspector
				root.gui_disable_input = false
				inspector.set_process_input(true)
				var revision: int = root.get_node("PuzzleManager").get_revision("puzzle_01_frequency")
				var wheel := InputEventMouseButton.new()
				wheel.position = inspector._record_scroll.get_global_rect().get_center()
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				root.push_input(wheel, true)
				await tick()
				check(inspector._record_scroll.scroll_vertical > 0, "Mouse wheel scrolls the long record in the foreground card")
				check(root.get_node("PuzzleManager").get_revision("puzzle_01_frequency") == revision, "Scrolling a record cannot operate the device")
				root.gui_disable_input = true
				inspector.set_process_input(false)
				root.size = Vector2i(1280,720)
				await tick()
				check_inspection(inspector, lab_ui, "Laboratory live resize")
			devices.inspector.close()
	room.queue_free()
	await tick(3)
	# Allow the audio thread to release the final room's imported OGG playbacks.
	await create_timer(.2).timeout
	print("TEXT LAYOUT: %s (%d checks; %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
