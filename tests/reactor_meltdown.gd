extends SceneTree
## Small real-scene smoke test, also used by the two-process ENet runner.
const Rules := preload("res://scripts/level3/core_rules.gd")
const Instability := preload("res://scripts/level3/reactor_instability_controller.gd")
const Frequency := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Corridor := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
var pm: Node
var flow: Node
var net: Node
var host := true
var offline := true
var rendered := false
var checks := 0
var failures := 0
var explosions := 0
var shots: Dictionary = {}
var _round := 0
var future_review := false


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MELTDOWN FAILED: " + label)


func wait_for(condition: Callable, label: String, seconds: float = 18.0) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < until: await process_frame
	check(condition.call(), label)
	if not condition.call(): quit(1)


func screenshot(label: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	var directory := "res://docs/assets/screenshots/meltdown"
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory + "/" + ("future_" if future_review else "") + label + ".png")


func _capture_stages(room: Node) -> void:
	if not rendered or _round > 0: return
	var t: float = room.explosion.elapsed
	for entry in [[0.35, "containment"], [1.05, "explosion"], [2.3, "destruction"], [4.5, "collapse"]]:
		if t >= entry[0] and not shots.has(entry[1]):
			shots[entry[1]] = true
			screenshot(entry[1])


func _run() -> void:
	root.size = Vector2i(1280, 720)
	pm = root.get_node("PuzzleManager")
	flow = root.get_node("GameFlowManager")
	net = root.get_node("NetworkManager")
	pm.log_rejections = false
	var args := OS.get_cmdline_user_args()
	rendered = "--render-review" in args
	future_review = "--future-review" in args
	offline = args.is_empty() or args[0].begins_with("--")
	host = offline or args[0] == "host"
	for remaining in [150.0, 60.0, 30.0, 10.0]:
		check(Instability.urgency(remaining) < Instability.urgency(remaining - 0.01), "monotonic urgency at %.0f" % remaining)
		check(absf(Instability.urgency(remaining + 0.01) - Instability.urgency(remaining - 0.01)) < 0.002, "smooth threshold %.0f" % remaining)
	if offline:
		check(flow.start_room("room_03"), "load core")
	else:
		net.game_started.connect(func() -> void: flow.start_room.call_deferred("room_03"))
		if host:
			check(net.host_game(int(args[1])) == OK, "host ENet")
			print("MELTDOWN_HOST_LISTENING")
			await wait_for(func() -> bool: return net.guest_ready, "guest ready")
			check(net.start_game(), "start session")
		else:
			check(net.join_game("127.0.0.1", int(args[1])) == OK, "join ENet")
			await wait_for(func() -> bool: return net.state == net.State.CONNECTED, "lobby connected")
			net.set_ready(true)
	for round_index in range(2):
		_round = round_index
		root.get_node("CinematicTransitionManager").reduced_motion_override = round_index == 1
		await wait_for(func() -> bool: return flow.get_current_room_id() == "room_03" and not flow.is_transitioning() and current_scene.is_game_flow_ready(), "core loaded")
		var room: Node = current_scene
		if future_review and offline and room.role != "future": room.switch_role()
		room.pause_when_unfocused = false
		room.player.set_physics_process(false)
		if not offline: await wait_for(func() -> bool: return room.remote_ready, "role handshake")
		var session: int = pm.get_session_id()
		var peer := root.multiplayer.multiplayer_peer
		var timeline: String = pm.get_local_role()
		room.explosion.finished.connect(func() -> void: explosions += 1)
		room.explosion.explosion_audio_cue_requested.connect(func(cue: StringName) -> void:
			if cue == &"impact": print("MELTDOWN_IMPACT ", timeline, " ", round_index))
		root.get_node("JournalManager").unlock_entry("l3_authorization" if timeline == "past" else "l3_continuity")
		if rendered and round_index == 0:
			for row in [[150.0, "stable"], [45.0, "unstable"], [18.0, "critical"], [2.0, "imminent"]]:
				room.explosion.set_process(false)
				for frame in range(80):
					room.explosion._controllers[timeline].update_presentation(1.0/60, row[0], true, -1)
					room.reactor_bridge.modules[timeline]._update_visuals(1.0/60)
				await screenshot(row[1])
			room.explosion.set_process(true)
		if host:
			# Seed real earlier-room progress before failure; all must be cleared.
			pm.register_puzzle(Frequency.ID, Frequency.new(), true)
			pm.register_puzzle(Corridor.ID, Corridor.new(), true)
			pm.submit_action(Frequency.ID, "acquire_radio", {"radio_role": "past"}, "past")
			if offline: pm.submit_action(Frequency.ID, "acquire_radio", {"radio_role": "future"}, "future")
			var prior: Dictionary = pm.get_state(Corridor.ID)
			prior.service_isolated = true
			prior.battery_ready = true
			prior.archive_read = true
			pm._commit_record(Corridor.ID, pm._logic[Corridor.ID], prior, pm.Cause.ACTION)
			room.player.position = room.worlds[timeline].position + Rules.STATIONS.start + Vector3(0, 0, 1)
			room.request_action("start")
			check(room.state.stage == "STAGE_A", "armed deliberately")
			room.rules._deadline = room._clock() + 0.5
			await create_timer(0.15).timeout
			room.set_paused(true)
			if offline: room.set_paused(false)
		else:
			await wait_for(func() -> bool: return room.state.stage == "STAGE_A", "host armed event")
			room.set_paused(true)
		await wait_for(func() -> bool: return room._meltdown_started, "one authorized meltdown")
		check(not room.player.controls_enabled and not room.devices.inspector.active and not room._paused, "menus close and input locks")
		check(pm.submit_action(Rules.ID, "start", {"attempt": room.state.attempt, "seq": 999}).get("status") in [0, 4], "cinematic blocks actions or sends host-validated request")
		room._start_meltdown()
		check(room.explosion.active, "duplicate begin harmless")
		if round_index == 1:
			check(room.explosion._reduced and room.camera.h_offset == 0.0 and room.camera.v_offset == 0.0, "reduced motion disables shake")
		while flow.get_current_room_id() == "room_03" and not flow.is_transitioning():
			_capture_stages(room)
			await process_frame
		await wait_for(func() -> bool: return flow.get_current_room_id() == "room_01" and not flow.is_transitioning(), "coordinated Room 1 restart")
		check(explosions == round_index + 1, "one complete cinematic per failure")
		check(pm.get_session_id() != session, "new gameplay session")
		check(root.multiplayer.multiplayer_peer == peer, "same ENet peer")
		check(pm.get_local_role() == timeline, "role preserved")
		check(not pm.is_solved(Frequency.ID) and pm.get_state(Frequency.ID) == Frequency.new().get_initial_state(), "frequency and radio reset")
		check(pm.get_state(Corridor.ID) == Corridor.new().get_initial_state(), "all corridor and storage flags reset")
		check(pm.get_state(Rules.ID).stage == "DISCOVERY" and pm.get_state(Rules.ID).remaining == 150.0, "reactor fresh and idle")
		check(root.get_node("JournalManager").get_unlocked_entries().is_empty(), "journal cleared")
		check(not pm.gameplay_suspended and current_scene.player.controls_enabled, "opening controls restored")
		check(current_scene.player.global_position.distance_to(current_scene.get_node("SpawnPoint").global_position) < 0.5, "original spawn restored")
		check(not current_scene.radio.owns_radio and not current_scene.radio.has_established_link(), "physical radio acquisition available again")
		check(not is_instance_valid(room), "old room and all VFX freed")
		if rendered: await screenshot("restart_room1")
		print("MELTDOWN_RESTART ", timeline, " ", round_index)
		if round_index == 0:
			if host:
				await create_timer(0.3).timeout
				# Exercise the same transition protocol to the next isolated test setup.
				flow._start_authorized("room_03")
		else:
			await create_timer(0.2).timeout
	print("MELTDOWN %s: %s (%d checks)" % ["solo" if offline else ("host" if host else "client"), "PASS" if failures == 0 else "FAIL", checks])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
