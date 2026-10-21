extends SceneTree
## Production rooms, real input dispatch, shared overlays and timeline presentation.

var checks := 0
var failures := 0
var room
var pm: Node

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CAMPAIGN SYSTEMS: " + message)

func tick(count: int = 4) -> void:
	for index in count:
		await physics_frame
		await process_frame

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
		await tick(2)

func pause(value: bool) -> void:
	if room.has_method("_set_paused"): room._set_paused(value)
	else: room.set_paused(value)

func quiet() -> void:
	if room.has_method("_set_paused"): room.gameplay.director.stop_dialogue()
	else:
		room.director.stop_dialogue()
		if "_pending_lines" in room: room._pending_lines.clear()

func capture(name: String) -> void:
	var directory := OS.get_environment("UNIFIED_REVIEW_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "Screenshot " + name)

func role() -> String:
	return pm.get_local_role()

func run() -> void:
	root.get_node("CinematicTransitionManager").enabled = false
	pm = root.get_node("PuzzleManager")
	if "--countdown-only" in OS.get_cmdline_user_args():
		await countdown()
		finish()
		return
	var menu: Control = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await tick()
	check(menu.get_node_or_null("%LevelThreeMultiplayerButton") == null, "Level 3 multiplayer test launcher is removed")
	check(menu.get_node("%LevelThreeTestButton").visible and menu.get_node("%LevelThreeTestButton").text == "LEVEL 3 / SOLO TEST", "Level 3 has a clearly labelled solo-only test entry")
	await capture("main_menu_solo_only")
	menu.queue_free()
	await tick()
	var scenes := ["res://scenes/world/spawn_area.tscn", "res://scenes/world/maintenance_corridor.tscn", "res://scenes/rooms/temporal_core.tscn"]
	for index in scenes.size():
		pm.begin_session()
		room = load(scenes[index]).instantiate()
		if "pause_when_unfocused" in room: room.pause_when_unfocused = false
		if "tutorial_auto_show" in room: room.tutorial_auto_show = false
		root.add_child(room)
		current_scene = room
		await tick(8)
		quiet()
		pause(false)
		check(room.pause_menu.scene_file_path == "res://scenes/ui/pause_menu.tscn", "Level %d uses the laboratory's shared pause scene" % (index + 1))
		check(room.temporal_ghost != null, "TemporalGhost is initialized")
		check(room.temporal_ghost.find_children("*", "CollisionObject3D", true, false).is_empty(), "Ghost has no physical interaction or collision")
		var audio: AudioDirector = room.gameplay.audio if index == 0 else (room.audio if index == 1 else room.sound.director)
		var directors: Array = room.find_children("*", "Node", true, false).filter(func(node: Node) -> bool: return node is AudioDirector)
		check(directors.size() == 1, "One AudioDirector per active room")
		for dimensions in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540)]:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			root.content_scale_size = Vector2i.ZERO
			root.size = dimensions
			await tick()
			await capture("level%d_hud_%d" % [index + 1, dimensions.x])
			await key(KEY_ESCAPE)
			check(room.pause_menu.panel.visible and not room.player.controls_enabled, "Escape opens shared pause and blocks movement")
			check(room.pause_menu.button("ResumeButton").has_focus(), "Resume starts with keyboard/controller focus")
			check(not room.pause_menu.button("InterferenceButton").is_visible_in_tree(), "Diagnostic control is hidden")
			check(root.get_visible_rect().encloses(room.pause_menu._scroll.get_global_rect()), "Pause viewport fits " + str(dimensions))
			check(root.get_visible_rect().encloses(room.pause_menu.button("MenuButton").get_global_rect()), "All pause actions fit the minimum window")
			await capture("level%d_pause_%d" % [index + 1, dimensions.x])
			room.pause_menu.button("ResumeButton").pressed.emit()
			await tick()
			check(not room.is_gameplay_paused() and room.player.controls_enabled, "Resume restores gameplay")
		var ghost: Node3D = room.temporal_ghost
		for enabled in [true, false]:
			if ghost.enabled != enabled: await key(KEY_G)
			var switcher: Button = room.get_node("%TimelineButton") if index == 0 else (room.role_button if index == 1 else room.ui.switch_button)
			switcher.visible = enabled
			var before := role()
			await key(KEY_T)
			quiet()
			switcher.show()
			check(role() != before, "T switches solo role with ghost " + str(enabled))
			check(ghost.enabled == enabled, "T preserves G toggle preference")
			check(ghost._echo_role != role(), "Ghost represents the opposite role")
			if index == 2: check(room.ui.timer.is_visible_in_tree(), "Role switching preserves countdown visibility")
			check(audio.ambient_controller.get_current_ambience_id() == StringName("lab_ambience_" + role()), "Timeline ambience follows role")
			check(room.player.get_node_or_null("LocalAudioListener") != null, "Player-mounted listener receives footsteps")
			var steps := room.player.find_child("FootstepEmitter3D", true, false) as FootstepEmitter3D
			check(steps != null and steps.surface_event == StringName("footstep_future_concrete" if role() == "future" else "footstep_past_tile"), "Correct timeline footstep surface")
			await capture("level%d_%s_ghost_%s" % [index + 1, role(), str(enabled)])
		if not ghost.enabled: await key(KEY_G)
		if index == 2:
			room.player.position.x += 1.7
			await tick()
			await capture("level3_student_ghost")
			await key(KEY_T)
			await capture("level3_professor_ghost")
			check(ghost.visible and ghost.character.global_position.distance_to(room.worlds[role()].global_position + room._poses[ghost._echo_role]) < .01, "Offset timeline ghost maps to the active laboratory")
		pause(true)
		room.pause_menu.button("SettingsButton").pressed.emit()
		check(room.settings_overlay.visible and not room.player.controls_enabled, "Settings reuse shared overlay")
		await key(KEY_ESCAPE)
		check(not room.settings_overlay.visible and room.pause_menu.panel.visible, "Settings back returns to pause")
		room.pause_menu.button("HowToPlayButton").pressed.emit()
		check(room.pause_menu.tutorial.is_open(), "How To Play reuses tutorial")
		await key(KEY_ESCAPE)
		await create_timer(.4).timeout
		check(room.pause_menu.panel.visible and not room.player.controls_enabled, "Tutorial back stays paused")
		check(not room.pause_menu.button("CharacterButton").disabled, "Character studio is enabled inside pause")
		room.pause_menu.button("CharacterButton").grab_focus()
		await key(KEY_ENTER)
		var studio: Control = room._character_studio if index == 0 else room.pause_menu.studio
		check(is_instance_valid(studio) and not room.player.controls_enabled, "Character studio is available and blocks gameplay")
		studio.request_close()
		await tick()
		pause(false)
		if index == 2:
			var session: int = pm.get_session_id()
			pause(true)
			room.pause_menu.button("ResetSoloButton").pressed.emit()
			await scene_changed
			room = current_scene
			check(room.scene_file_path == scenes[0] and pm.get_session_id() != session, "Reset Solo Session starts a fresh campaign in the laboratory")
			check(pm.get_local_role() == "past", "Solo reset restores Student role")
		room.queue_free()
		await tick(8)
	finish()

func countdown() -> void:
	pm.begin_session()
	room = load("res://scenes/rooms/temporal_core.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await tick(8)
	room.request_action("start")
	check(room.state.stage == "STAGE_A" and room.state.remaining == 150.0, "Real challenge starts at 150 seconds")
	var attempt: int = room.state.attempt
	pause(true)
	var frozen: float = room._clock()
	await create_timer(1.25).timeout
	check(is_equal_approx(room._clock(), frozen) and room.state.remaining == 150.0, "Solo pause freezes canonical challenge clock")
	pause(false)
	await key(KEY_T)
	check(room.state.attempt == attempt and room.state.stage == "STAGE_A", "T preserves live attempt")
	var start := Time.get_ticks_msec()
	await create_timer(150.5).timeout
	check(room.state.stage == "OVERLOAD", "Full 150-second sequence reaches overload")
	check(Time.get_ticks_msec() - start >= 150000, "Full countdown was executed in real time")
	await create_timer(3.2).timeout
	check(room.state.stage == "DISCOVERY" and room.state.attempt > attempt, "Three-second overload recovers to a new attempt")
	check(room.temporal_ghost != null and room.player.controls_enabled, "Retry restores shared systems and controls")
	room.queue_free()
	await tick(8)

func finish() -> void:
	print("CAMPAIGN SYSTEMS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
