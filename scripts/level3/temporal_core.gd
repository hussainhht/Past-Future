extends Node3D
## Room C coordinator. Canonical state and RPCs belong to the existing PuzzleManager.
## Position messages carry no puzzle state, role, choice, or cross-machine timestamps.

const Rules := preload("res://scripts/level3/core_rules.gd")
const World := preload("res://scripts/level3/core_world.gd")
const UI := preload("res://scripts/level3/core_ui.gd")
const Sound := preload("res://scripts/level3/core_sound.gd")
const Story := preload("res://scripts/level3/core_story.gd")
const Inputs := preload("res://scripts/input/input_manager.gd")
const Devices := preload("res://scripts/level3/core_devices.gd")
const ReactorBridge := preload("res://scripts/level3/core_reactor_bridge.gd")

@export var pause_when_unfocused := true
@export var challenge_seconds: float = Rules.CHALLENGE_SECONDS
## Assign only a completed, verified module. Null keeps the stock assembly.
@export var reactor_visual_scene: PackedScene
var devices: Node
var reactor_bridge: Node
var player: CharacterBody3D
var role: String = "past"
var camera: Camera3D
var controller: Node
var worlds: Dictionary = {}
var state: Dictionary = {}
var rules: RefCounted
var ui: CanvasLayer
var sound: Node
var networked: bool = false
var disconnected: bool = false
var remote_ready: bool = false
var actors: Node3D
var camera_rig: Node3D
var prompt: CanvasLayer
var echo: CharacterBody3D
var environment: Environment
var key_light: DirectionalLight3D
var _seq: Dictionary = {"past": 0, "future": 0}
var _poses: Dictionary = {"past": Vector3(0, 0, 5.9), "future": Vector3(0, 0, 5.9)}
var _pose_at: float = 0.0
var _pose_budget: float = 0.0
var _sync_age: float = 0.0
var _refresh_age: float = 0.0
var _snapshot_at: float = 0.0
var _confirmed_sync_remaining: float = 0.0
var _shown_ending: String = ""
var _ending_tween: Tween
var _last_notice: String = ""
var _warned: bool = false
var _modal_kind: String = ""
var _configured: bool = false
var _last_attempt: int = -1
var _hello_age: float = 0.0
var settings_overlay: CanvasLayer
var pause_menu: CanvasLayer
var temporal_ghost: Node3D
var director: DialogueDirector
var radio: TemporalRadio
var radio_audio: Node
var _paused := false
var _simulation_time := 0.0



func _ready() -> void:
	Inputs.ensure_initialized(self)
	networked = NetworkManager.in_game
	role = PuzzleManager.get_local_role()
	if not role in ["past", "future"]: role = "past"
	GameFlowManager.attach_room("room_03", self)
	var env_node := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("15212c") if role == "future" else Color("353832")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b7cad0")
	environment.ambient_light_energy = 0.75
	env_node.environment = environment
	add_child(env_node)
	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-40, -32, 0)
	key_light.light_energy = 1.05
	key_light.light_color = Color("b5d9ec") if role == "future" else Color("ffe2b8")
	add_child(key_light)
	for timeline in ["past", "future"]:
		var world := World.new()
		world.name = "Past" if timeline == "past" else "Future"
		world.position.x = 40.0 if timeline == "future" else 0.0
		add_child(world)
		world.build(timeline, operate)
		worlds[timeline] = world
		var spawn := Marker3D.new()
		spawn.name = timeline + "_entry"
		spawn.position = Vector3(0, 0, 5.9)
		spawn.add_to_group("spawn_point")
		world.add_child(spawn)
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	ui = UI.new()
	ui.name = "CoreHUD"
	add_child(ui)
	prompt = load("res://scenes/ui/interaction_prompt.tscn").instantiate()
	add_child(prompt)
	sound = Sound.new()
	sound.name = "CoreSound"
	add_child(sound)
	pause_menu = load("res://scenes/ui/pause_menu.tscn").instantiate()
	add_child(pause_menu)
	pause_menu.configure(self, sound.director, func() -> String: return role, set_paused, reset_solo_session, return_to_menu)
	settings_overlay = pause_menu.settings
	ui.pause_button.pressed.connect(set_paused.bind(true))
	ui.switch_button.pressed.connect(switch_role)
	ui.switch_button.visible = not networked
	director = DialogueDirector.new()
	director.name = "DialogueDirector"
	director.dialogue_box = load("res://scenes/dialogue/dialogue_box.tscn").instantiate()
	director.add_child(director.dialogue_box)
	add_child(director)
	director.set_local_timeline(role)
	director.gameplay_input_block_changed.connect(func(_blocked: bool) -> void: _sync_controls())
	director.dialogue_started.connect(func(_id: String) -> void: sound.play("signal"))
	radio = preload("res://scripts/gameplay/radio/temporal_radio.gd").new()
	add_child(radio)
	radio.set_player_role(role)
	radio_audio = preload("res://scripts/gameplay/radio/radio_audio.gd").new()
	radio_audio.audio_director = sound.director
	radio_audio.radio = radio
	add_child(radio_audio)
	_spawn_player()
	devices = Devices.new()
	devices.name = "CoreDevices"
	add_child(devices)
	devices.setup(self)
	reactor_bridge = ReactorBridge.new()
	add_child(reactor_bridge)
	if reactor_visual_scene == null: reactor_visual_scene = reactor_bridge.verified_scene()
	reactor_bridge.setup(worlds, reactor_visual_scene)
	reactor_bridge.sync_preferences(worlds, role)
	_register_evidence()
	rules = Rules.new()
	rules.challenge_seconds = challenge_seconds
	# WeakRef prevents persistent PuzzleManager rules from retaining a freed room.
	var weak: WeakRef = weakref(self)
	rules.clock = func() -> float:
		var room: Node = weak.get_ref()
		return room._clock() if room != null else 0.0
	rules.proximity = func(actor_role: String, station: String) -> bool:
		var room: Node = weak.get_ref()
		return room != null and room._near_station(actor_role, station)
	rules.available = func() -> bool:
		var room: Node = weak.get_ref()
		return room != null and room._can_operate()
	PuzzleManager.register_puzzle(Rules.ID, rules, true)
	PuzzleManager.puzzle_state_changed.connect(_on_state)
	PuzzleManager.action_rejected.connect(_on_rejected)
	NetworkManager.state_changed.connect(_on_connection)
	GameFlowManager.input_lock_changed.connect(_on_lock_changed)
	JournalManager.journal_opened.connect(func() -> void: sound.director.play_ui(&"document_open"); _sync_controls())
	JournalManager.journal_closed.connect(func() -> void: sound.director.play_ui(&"document_close"); _sync_controls())
	if PuzzleManager.is_authority():
		PuzzleManager.reset_puzzle(Rules.ID)
	else:
		PuzzleManager.request_sync()
	state = PuzzleManager.get_state(Rules.ID)
	if not state.is_empty(): _on_state(Rules.ID, state, PuzzleManager.get_revision(Rules.ID))
	_configured = true
	if not networked:
		temporal_ghost = load("res://scripts/world/temporal_ghost.gd").new()
		add_child(temporal_ghost)
		var roots: Array[Node3D] = [worlds.past, worlds.future]
		temporal_ghost.configure(self, roots, _temporal_ghost_context)
	sound.director.bind_ui(ui.root)
	_sync_controls()


func _spawn_player() -> void:
	if is_instance_valid(player):
		_poses[role] = local_position()
		actors.remove_child(player)
		player.queue_free()
	var packed: PackedScene = load("res://scenes/characters/%s_3d_player.tscn" % ("professor" if role == "future" else "student"))
	player = packed.instantiate()
	player.name = "Player"
	player.demonstration_items_enabled = false
	actors.add_child(player)
	player.position = worlds[role].position + _poses[role]
	if is_instance_valid(camera_rig):
		remove_child(camera_rig)
		camera_rig.queue_free()
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://scripts/world/follow_camera.gd"))
	camera_rig.set("target_path", NodePath("../Actors/Player"))
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera_rig.add_child(camera)
	add_child(camera_rig)
	player.view_camera = camera
	var rig: Node3D = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
	player.add_child(rig)
	controller = rig.get_node("InteractionController")
	controller.detector.set_current_role(role)
	controller.prompt_ui = prompt
	var footsteps: Node = load("res://scenes/audio/footstep_emitter_3d.tscn").instantiate()
	player.add_child(footsteps)
	footsteps.set_timeline(StringName(role))
	var listener := AudioListener3D.new()
	listener.name = "LocalAudioListener"
	listener.position.y = 1.4
	player.add_child(listener)
	listener.make_current()
	sound.set_role(role)
	for timeline in worlds:
		worlds[timeline].visible = timeline == role


func switch_role() -> void:
	if networked or NetworkManager.state != NetworkManager.State.IDLE or is_gameplay_paused() or player.is_action_active(): return
	if ui.visible_modal or devices.inspector.active or JournalManager.is_open() or state.get("stage") == "ENDING": return
	_poses[role] = local_position()
	role = "future" if role == "past" else "past"
	PuzzleManager.offline_role = role
	# _spawn_player must save the old player's position under its original role.
	actors.remove_child(player)
	player.queue_free()
	player = null
	_spawn_player()
	devices.refresh()
	reactor_bridge.sync_preferences(worlds, role)
	key_light.light_color = Color("b5d9ec") if role == "future" else Color("ffe2b8")
	environment.background_color = Color("15212c") if role == "future" else Color("353832")
	JournalManager.state_changed.emit()
	director.set_local_timeline(role)
	radio.set_player_role(role)
	if temporal_ghost != null: temporal_ghost.refresh()
	ui.status.text = "Professor / Future" if role == "future" else "Student / Past"
	_sync_controls()


func local_position() -> Vector3:
	return player.global_position - worlds[role].global_position


func _register_evidence() -> void:
	for id: String in Story.EVIDENCE:
		var data: Array = Story.EVIDENCE[id]
		var entry := JournalEntry.new()
		entry.entry_id = data[0]
		entry.title = data[1]
		entry.body = data[2]
		entry.subtitle = "Room C / private evidence"
		entry.category = JournalEntry.Category.CLUES
		entry.timeline = JournalEntry.Timeline.PAST if id in ["evidence_past", "warning"] else JournalEntry.Timeline.FUTURE
		JournalManager.register_entry(entry)


func operate(id: String) -> void:
	if not _configured or is_gameplay_paused() or state.is_empty(): return
	if not worlds[role].stations.has(id) or not _near_station(role, id): return
	if Story.EVIDENCE.has(id):
		var data: Array = Story.EVIDENCE[id]
		if id == "routing" and not state.receiver:
			_show("ROUTING DIAGRAM / NO SIGNAL", "The receiver battery is dead. Restore the nearby receiver to recover its readings.", [{"label": "CLOSE", "callback": _close}])
			return
		JournalManager.unlock_entry(data[0])
		_show(data[1], data[2], [{"label": "CLOSE / SAVED TO YOUR JOURNAL", "callback": _close}])
	elif devices.is_device(id): devices.open(id)


func confirm_arming() -> void:
	_modal_kind = "start"
	_show("ARM TEMPORAL CORE?", "This confirmed operation starts the shared 150-second reactor challenge.\n\nBoth timelines must restore power, align the core, engage phase switches within five seconds, then lock private identity commands.\n\nSolo pause suspends the clock. In LAN play the shared clock continues through menus. Journals and devices keep the challenge running.", [
		{"label": "KEEP INVESTIGATING", "callback": _close},
		{"label": "CONFIRM / ARM REACTOR", "callback": func() -> void: _close(); request_action("start")}])


func _show_terminal() -> void:
	_modal_kind = "terminal"
	var text := "TWO VERSIONS. ONE IDENTITY. ONE SURVIVOR.\n\n"
	if role == "past":
		text += "GROUND THE CORE uses the stable continuity protocol. You survive, the world is stabilized, and the current Professor and his memories dissolve.\n\nCLAIM ORIGIN forcibly redirects ownership to your younger identity. If the Professor releases, his timeline is erased. This repeats the forbidden protocol behind the catastrophe."
	else:
		text += "RELEASE THE ECHO lets the stable protocol preserve the Student and save the world. Your current echo and memories end.\n\nPRESERVE ECHO forcibly anchors you outside linear causality. If the Student grounds the core, he disappears and a changed future survives."
	text += "\n\nConflicting private overrides cause a temporal paradox. Your exact command stays private until resolution."
	var options: Array = [{"label": "CLOSE TERMINAL", "callback": _close}]
	for command: String in Rules.COMMANDS[role]:
		options.append({"label": command, "callback": _confirm_command.bind(command)})
	_show("ORIGIN TERMINAL" if role == "past" else "CONTINUITY TERMINAL", text, options)


func _confirm_command(command: String) -> void:
	_modal_kind = "terminal"
	_show("LOCK PRIVATE MACHINE COMMAND?", command + "\n\nThis command cannot be changed during this attempt. Your partner sees only that you have locked in. The host resolves both commands together.", [
		{"label": "BACK TO TERMINAL", "callback": _show_terminal},
		{"label": "CONFIRM / " + command, "callback": func() -> void: _close(); request_action("choose", {"command": command})}])


func request_action(action: String, data: Dictionary = {}) -> Dictionary:
	if state.is_empty() or disconnected: return {}
	_seq[role] += 1
	var payload := data.duplicate(true)
	payload.attempt = state.attempt
	payload.seq = _seq[role]
	return PuzzleManager.submit_action(Rules.ID, action, payload, role)


func _near_station(actor_role: String, station: String) -> bool:
	if not Rules.STATIONS.has(station): return false
	var at: Vector3 = local_position() if actor_role == role else _poses[actor_role]
	if networked and actor_role == "future" and actor_role != role and _now() - _pose_at > 1.5: return false
	return at.distance_to(Rules.STATIONS[station]) <= 1.85


func _can_operate() -> bool:
	return _configured and not disconnected and (networked or not _paused) and not GameFlowManager.is_input_locked() and (not networked or (NetworkManager.in_game and remote_ready))


func _process(delta: float) -> void:
	if not _configured: return
	if networked or not _paused: _simulation_time += delta
	_sync_controls()
	_refresh_age += delta
	if PuzzleManager.is_authority() and not disconnected and not GameFlowManager.is_input_locked() and _refresh_age >= 0.2:
		_refresh_age = 0.0
		PuzzleManager.refresh_puzzle(Rules.ID)
	if state.is_empty(): return
	var predicted: float = state.remaining
	if state.stage in ["STAGE_A", "STAGE_B", "STAGE_C"] and not disconnected:
		predicted = maxf(0.0, predicted - (_clock() - _snapshot_at))
	var sync_left: float = state.sync_remaining
	if state.stage == "STAGE_B" and (state.sync_past or state.sync_future):
		# Display-only interpolation. The host remains the sole deadline owner.
		sync_left = maxf(0.0, _confirmed_sync_remaining - (_clock() - _snapshot_at))
	ui.render(state, role, predicted, sync_left)
	ui.set_radio_status(radio)
	if predicted <= 10 and state.stage in ["STAGE_A", "STAGE_B", "STAGE_C"] and not _warned:
		_warned = true
		sound.play("warning")
	if networked and not disconnected and NetworkManager.in_game:
		_sync_age += delta
		_hello_age += delta
		if role == "future" and _hello_age > 0.5:
			_hello_age = 0.0
			_hello.rpc_id(1, state.attempt)
		if role == "future" and _sync_age >= 0.05:
			_sync_age = 0.0
			_report_pose.rpc_id(1, state.attempt, local_position())


func _on_state(id: String, confirmed: Dictionary, _revision: int) -> void:
	if id != Rules.ID: return
	var previous := state
	var previous_stage: String = state.get("stage", "")
	state = confirmed.duplicate(true)
	_confirmed_sync_remaining = float(state.sync_remaining)
	if state.stage == "STAGE_B" and (state.sync_past or state.sync_future) and state.sync_remaining <= 0:
		_confirmed_sync_remaining = Rules.SYNC_WINDOW
	_snapshot_at = _clock()
	if _last_attempt != state.attempt:
		sound.reactor_ambience.stop_ambience(0.0)
		if devices != null: devices.close()
		_last_attempt = state.attempt
		_seq = {"past": 0, "future": 0}
		_warned = false
		_shown_ending = ""
		if _ending_tween != null and _ending_tween.is_valid(): _ending_tween.kill()
		if is_instance_valid(echo): echo.queue_free(); echo = null
		if is_instance_valid(player): player.visible = true; _fade_character(player, 0.0)
		if ui != null:
			ui.ending_caption.text = ""
			ui.close_panel()
		# On overload the rebuilt Future gate closes; move players out of its north pocket.
		_poses = {"past": Vector3(0, 0, 5.9), "future": Vector3(0, 0, 5.9)}
		_pose_at = _now()
		_pose_budget = 0.0
		if is_instance_valid(player):
			player.position = worlds[role].position + _poses[role]
			player.velocity = Vector3.ZERO
			camera_rig.snap_to_target()
	for world: Node in worlds.values(): world.apply_state(state)
	if devices != null: devices.refresh()
	if (_modal_kind == "start" and state.stage != "DISCOVERY") or (_modal_kind == "terminal" and (state.stage != "STAGE_C" or state["locked_" + role])):
		_close()
	if reactor_bridge != null: reactor_bridge.apply_state(state, challenge_seconds)
	if not previous.is_empty() and previous.get("attempt") == state.attempt:
		if previous.coils != state.coils: sound.director.play_sfx(&"switch_electrical")
		var events := {"receiver": &"equipment_activate", "anchor": &"computer_calibrate", "origin": &"rift_stabilize", "sync_past": &"switch_toggle", "sync_future": &"switch_toggle", "locked_past": &"computer_success", "locked_future": &"computer_success"}
		for key: String in events:
			if previous.get(key) != state.get(key) and state.get(key): sound.director.play_sfx(events[key])
		if previous.get("sync_past", false) and not state.sync_past and state.stage == "STAGE_B":
			sound.get_node("AudioSystem").play_sfx(&"interaction_denied")
		elif previous.get("sync_future", false) and not state.sync_future and state.stage == "STAGE_B":
			sound.get_node("AudioSystem").play_sfx(&"interaction_denied")
	if state.notice != _last_notice:
		_last_notice = state.notice
		ui.status.text = state.notice
	if previous_stage != state.stage:
		if state.stage in ["STAGE_A", "STAGE_C"]: _play_radio_notice(state.notice)
		if state.stage == "STAGE_A": sound.play("activate")
		elif state.stage in ["STAGE_B", "STAGE_C"]: sound.play("phase")
		elif state.stage == "OVERLOAD":
			devices.close()
			set_paused(false)
			director.stop_dialogue()
			settings_overlay.hide()
			ui.close_panel()
			JournalManager.close_journal()
			sound.play("overload")
	if state.stage == "ENDING" and state.ending != _shown_ending: _play_ending()
	_sync_controls()


func _on_rejected(id: String, _action: String, reason: String, actor_role: String) -> void:
	if id == Rules.ID and actor_role == role:
		var messages := {"too_far": "Move closer to the hardware and try again.", "partner_unavailable": "Waiting for both timelines to finish loading.", "stale_attempt": "That operation belongs to an earlier attempt.", "duplicate_request": "That operation was already received.", "wrong_stage": "That device is not enabled in this reactor phase.", "choice_locked": "Your private command is already locked.", "anchor_required": "The Professor must calibrate the Signal Anchor first."}
		devices.reject()
		ui.show_error(messages.get(reason, "Operation refused: " + reason.replace("_", " ")))
		sound.get_node("AudioSystem").play_sfx(&"interaction_denied")


func _play_ending() -> void:
	devices.close()
	set_paused(false)
	director.stop_dialogue()
	settings_overlay.hide()
	_shown_ending = state.ending
	JournalManager.close_journal()
	ui.close_panel()
	var data: Dictionary = Story.ENDINGS[state.ending]
	sound.play(state.ending)
	ui.ending_caption.modulate = data.color
	ui.ending_caption.text = data.title
	var other := "past" if role == "future" else "future"
	var packed: PackedScene = load("res://scenes/characters/%s_3d_player.tscn" % ("professor" if other == "future" else "student"))
	echo = packed.instantiate()
	echo.name = "IdentityEcho"
	echo.demonstration_items_enabled = false
	actors.add_child(echo)
	echo.controls_enabled = false
	echo.set_physics_process(false)
	echo.collision_layer = 0
	echo.position = worlds[role].position + Vector3(1.8, 0, 2)
	player.position = worlds[role].position + Vector3(-1.8, 0, 2)
	camera_rig.snap_to_target()
	var erased: CharacterBody3D = player if data.erased == role else echo
	_ending_tween = create_tween()
	_ending_tween.tween_interval(0.6)
	_ending_tween.tween_callback(func() -> void: ui.ending_caption.text = data.lines[0])
	_ending_tween.tween_method(func(v: float) -> void:
		_fade_character(erased, v)
		if data.erased == "both": _fade_character(player, v), 0.0, 1.0, 2.0)
	_ending_tween.tween_callback(func() -> void:
		erased.visible = false
		if data.erased == "both": player.visible = false
		ui.ending_caption.text = data.lines[1])
	_ending_tween.tween_interval(2.0)
	_ending_tween.tween_callback(func() -> void:
		if state.ending != "paradox":
			ui.ending_caption.text = "UNREGISTERED SIGNAL / SOURCE TIME: ???"
			sound.play("signal")
		else:
			player.visible = true
			_fade_character(player, 0.0)
			player.position = worlds[role].position + Vector3(0, 0, 5.9)
			camera_rig.snap_to_target()
			ui.ending_caption.text = "ITERATION 02 DETECTED")
	_ending_tween.tween_interval(2.0)
	_ending_tween.tween_callback(_show_conclusion)


func _fade_character(body: Node, amount: float) -> void:
	if not is_instance_valid(body): return
	for mesh in body.find_children("*", "MeshInstance3D", true, false): mesh.transparency = amount


func _show_conclusion() -> void:
	if state.stage != "ENDING": return
	var data: Dictionary = Story.ENDINGS[state.ending]
	var options: Array = [{"label": "RETURN TO MAIN MENU", "callback": return_to_menu}]
	if not networked or role == "past":
		options.push_front({"label": "REPLAY ROOM C", "callback": replay_attempt})
	var suffix := "\n\nUNREGISTERED SIGNAL / SOURCE TIME: ???" if state.ending != "paradox" else "\n\nITERATION 02 DETECTED"
	if networked and role == "future": suffix += "\nThe Student can restart this room for both players."
	_show(data.title + " / END OF CHAPTER 0", "\n\n".join(data.lines) + suffix, options)


func replay_attempt() -> void:
	if networked:
		if role == "past": request_action("replay")
		return
	# Offline preview is its own authority even when inspecting the Professor's view.
	# This local administration path has no RPC and never changes live role assignment.
	_seq.past += 1
	PuzzleManager.submit_action(Rules.ID, "replay", {"attempt": state.attempt, "seq": _seq.past}, "past")


func _show(title: String, body: String, options: Array) -> void:
	if devices != null: devices.close()
	if settings_overlay != null: settings_overlay.hide()
	ui.show_panel(title, body, options)
	_sync_controls()


func _close() -> void:
	if _paused: set_paused(false)
	if devices != null: devices.close()
	settings_overlay.hide()
	ui.close_panel()
	_modal_kind = ""
	_sync_controls()


func _unhandled_input(event: InputEvent) -> void:
	if pause_menu.handle_input(event): return
	if event.is_echo() or JournalManager.is_open(): return
	if event.is_action_pressed("switch_role"):
		switch_role()
		get_viewport().set_input_as_handled()
		return
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")): return
	get_viewport().set_input_as_handled()
	if disconnected: return
	if state.get("stage") == "ENDING": _show_conclusion(); return
	if ui.visible_modal: _close(); return
	set_paused(not _paused)


func set_paused(value: bool) -> void:
	if disconnected and not value: return
	if value and devices != null and devices.inspector.active: devices.close()
	if _paused != value: sound.director.play_ui(&"ui_pause" if value else &"ui_unpause")
	_paused = value
	pause_menu.present(value)
	_sync_controls()


func reset_solo_session() -> void:
	if networked: return
	set_paused(false)
	PuzzleManager.begin_session()
	PuzzleManager.offline_role = "past"
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/spawn_area.tscn")


# Compatibility for the existing isolated reactor test scenes.
func switch_debug_role() -> void:
	switch_role()


func _temporal_ghost_context() -> Dictionary:
	return {"role": role, "player": player, "timeline_roots": worlds,
		"past_position": worlds[role].global_position + (local_position() if role == "past" else _poses.past),
		"future_position": worlds[role].global_position + (local_position() if role == "future" else _poses.future),
		"inspecting": devices.inspector.active, "blocked": is_gameplay_paused()}


func _play_radio_notice(message: String) -> void:
	if not message.begins_with("Professor:"): return
	var sequence := DialogueSequence.new()
	sequence.sequence_id = "core.%d.%s" % [state.attempt, state.stage]
	sequence.playback_mode = DialogueSequence.PlaybackMode.NON_BLOCKING
	sequence.auto_advance = true
	sequence.auto_advance_delay = 2.0
	var line := DialogueLine.new()
	line.speaker_id = "professor"
	line.speaker_name = "Professor"
	line.timeline = DialogueLine.Timeline.FUTURE
	line.text = message.trim_prefix("Professor: ")
	sequence.lines.append(line)
	director.play_dialogue(sequence)


func _clock() -> float:
	return _now() if networked else _simulation_time


func is_gameplay_paused() -> bool:
	return _paused or disconnected or not _configured or director.is_gameplay_input_blocked() or ui.visible_modal or (devices != null and devices.inspector.active) or JournalManager.is_open() or GameFlowManager.is_input_locked() or state.get("stage", "DISCOVERY") in ["ENDING", "OVERLOAD"]


func _sync_controls() -> void:
	if not is_instance_valid(player) or controller == null: return
	var blocked := is_gameplay_paused() or state.is_empty()
	if devices != null:
		devices.inspector.suspended = _paused or disconnected or GameFlowManager.is_input_locked() or JournalManager.is_open() or ui.visible_modal
		ui.device_panel.visible = devices.inspector.active and not devices.inspector.suspended
	ui.switch_button.disabled = blocked
	ui.journal_button.disabled = blocked
	ui.set_overlay_blocked(blocked)
	if radio_audio != null: radio_audio.set_suspended(blocked)
	director.process_mode = Node.PROCESS_MODE_DISABLED if _paused else Node.PROCESS_MODE_INHERIT
	director.dialogue_box.visible = not _paused
	player.controls_enabled = not blocked
	if blocked: player.velocity = Vector3.ZERO
	controller.set_interaction_blocked(blocked)
	prompt.set_interaction_blocked(blocked)


func _on_lock_changed(_locked: bool) -> void:
	_sync_controls()


func game_flow_suspend() -> void:
	set_paused(false)
	director.stop_dialogue()
	settings_overlay.hide()
	_close()
	JournalManager.close_journal()


func is_game_flow_ready() -> bool:
	return _configured and not state.is_empty() and is_instance_valid(player) and camera.current


func _on_connection() -> void:
	if networked and not NetworkManager.in_game:
		disconnected = true
		remote_ready = false
		JournalManager.close_journal()
		_show("CONNECTION LOST / REACTOR SUSPENDED", "The other timeline disconnected. This attempt cannot continue. Return to the menu and create a new session to reconnect.", [{"label": "RETURN TO MAIN MENU", "callback": return_to_menu}])
		_sync_controls()


func return_to_menu() -> void:
	JournalManager.close_journal()
	NetworkManager.leave_game()
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


@rpc("any_peer", "call_remote", "reliable")
func _hello(attempt: int) -> void:
	if not _valid_guest() or attempt != state.get("attempt"): return
	remote_ready = true
	devices.refresh()
	_ack_hello.rpc_id(NetworkManager.guest_id, attempt)


@rpc("authority", "call_remote", "reliable")
func _ack_hello(attempt: int) -> void:
	if networked and multiplayer.get_remote_sender_id() == 1 and attempt == state.get("attempt"):
		remote_ready = true
		devices.refresh()


func _valid_guest() -> bool:
	return networked and not disconnected and NetworkManager.in_game and PuzzleManager.is_authority() and multiplayer.get_remote_sender_id() == NetworkManager.guest_id and NetworkManager.guest_id > 1


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _report_pose(attempt: int, at: Vector3) -> void:
	if not _valid_guest() or attempt != state.get("attempt"): return
	if not accept_future_pose(at) and not state.stage in ["ENDING", "OVERLOAD"]:
		_correct_pose.rpc_id(NetworkManager.guest_id, attempt, _poses.future)


@rpc("authority", "call_remote", "reliable")
func _correct_pose(attempt: int, at: Vector3) -> void:
	if not networked or disconnected or multiplayer.get_remote_sender_id() != 1 or attempt != state.get("attempt"): return
	if role == "future" and local_position().distance_to(at) > 0.35:
		player.position = worlds.future.global_position + at
		player.velocity = Vector3.ZERO


## Bounded movement envelope + swept footprint collision in the actual Future world.
## Host uses this position, never a position attached to a puzzle request.
func accept_future_pose(at: Vector3) -> bool:
	if not at.is_finite() or absf(at.x) > 8.8 or absf(at.z) > 6.9 or absf(at.y) > 0.3: return false
	var now := _now()
	var elapsed := clampf(now - _pose_at, 0.0, 0.5)
	_pose_budget = minf(_pose_budget + elapsed * 5.0, 1.4)
	_pose_at = now
	var previous: Vector3 = _poses.future
	var distance := previous.distance_to(at)
	if distance > _pose_budget + 0.03: return false
	var motion := at - previous
	if motion.length() > 0.001:
		var query := PhysicsShapeQueryParameters3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.26
		cylinder.height = 0.32
		query.shape = cylinder
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, worlds.future.global_position + previous + Vector3(0, 0.23, 0))
		query.motion = motion
		var fractions := get_world_3d().direct_space_state.cast_motion(query)
		if fractions[0] < 0.98: return false
	_pose_budget = maxf(0.0, _pose_budget - distance)
	_poses.future = at
	return true


func _exit_tree() -> void:
	if is_instance_valid(director): director.stop_dialogue()
	if _ending_tween != null and _ending_tween.is_valid(): _ending_tween.kill()


func _notification(what: int) -> void:
	if not is_node_ready() or not _configured: return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		set_paused(true)
		pause_menu.label("PauseTitle").text = "Leave this timeline?"
		pause_menu.button("QuitGameButton").show()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_when_unfocused:
		set_paused(true)
