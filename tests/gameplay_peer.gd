extends SceneTree
## Two actual menus -> ready lobby -> actual labs -> animated pickups -> confirmed
## calibration/dialogue -> room reload -> disconnect. Uses no test RPC protocol.

const Fixtures := preload("res://tests/puzzle_fixtures.gd")
const FREQUENCY := "puzzle_01_frequency"
const RELAY := "laboratory_receiver_relay"

var network: Node
var puzzles: Node
var room: Node3D
var game: Node3D
var menu: Control
var failures: int = 0
var checks: int = 0
var link_cues: int = 0
var completions: int = 0
var changes: int = 0
var refused: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func wait_for(predicate: Callable, message: String, seconds: float = 18.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func tick(count: int = 5) -> void:
	for i in range(count):
		await physics_frame
	await process_frame


func step() -> int:
	return puzzles.get_state("gameplay_checkpoint").get("step", 0)


func reach(value: int) -> void:
	check(puzzles.submit_action("gameplay_checkpoint", "reached", {"step": value}).status == 4, "Client checkpoint is requested through existing authority")


func in_lab() -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://scenes/world/spawn_area.tscn"


func use_object(position: Vector3, path: String) -> void:
	room.player.position = position
	room.player.velocity = Vector3.ZERO
	await tick()
	check(game.controller.get_current_interactable() == game.get_node(path), "Real lab detector selects " + path)
	check(game.controller.try_interact(), "Actual lab interaction executes " + path)


func finish_dialogue() -> void:
	for i in range(32):
		if not game.director.is_dialogue_active():
			return
		game.director.skip_typewriter()
		game.director.advance_dialogue()
		await process_frame
	check(false, "Director could not finish dialogue")


func enter_lab() -> bool:
	if not await wait_for(in_lab, "Menu did not enter actual lab on confirmed game start"):
		return false
	room = current_scene
	room.pause_when_unfocused = false
	room._set_paused(false)
	game = room.gameplay
	game.audio.sound_played.connect(func(id: StringName, _spatial: bool, _position: Vector3) -> void:
		if id == &"radio_connect":
			link_cues += 1)
	await tick()
	var expected: String = "past" if network.role == "past" else "future"
	check(game.audio.ambient_controller.get_current_ambience_id() == StringName("lab_ambience_" + expected), "Room ambience belongs to local network timeline")
	check(game.audio.music_controller.get_current_ambience_id() == StringName("music_" + expected), "Music belongs to local network timeline")
	check(room.player.get_node("FootstepEmitter3D").surface_event == (&"footstep_past_tile" if expected == "past" else &"footstep_future_concrete"), "Local character uses timeline footsteps")
	check(room.get_node("Actors").find_children("*", "CharacterBody3D", false, false).size() == 1, "Each process has exactly one independent local input character")
	check(not room.get_node("%TimelineButton").visible, "LAN roles cannot be switched locally")
	check(not room.get_node("%ResetSoloButton").visible, "LAN client/host do not expose a solo reset")
	return true


func _run() -> void:
	network = root.get_node("NetworkManager")
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	puzzles.register_puzzle("gameplay_checkpoint", Fixtures.CheckpointPuzzle.new())
	puzzles.puzzle_completed.connect(func(id: String):
		if id == FREQUENCY:
			completions += 1)
	puzzles.puzzle_state_changed.connect(func(id: String, _state: Dictionary, _revision: int):
		if id == FREQUENCY:
			changes += 1)
	puzzles.action_rejected.connect(func(id: String, _action: String, reason: String, role: String):
		if id == FREQUENCY:
			refused.append([reason, role]))
	var args := OS.get_cmdline_user_args()
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.lan_port = args[1].to_int()
	menu.settings_path = "user://gameplay_peer_settings.cfg"
	root.add_child(menu)
	current_scene = menu
	menu.get_node("%PlayButton").pressed.emit()
	if args[0] == "host":
		await host_game()
	else:
		await client_game()
	if in_lab():
		room.gameplay.shutdown()
		room.free()
	network.leave_game()
	await create_timer(0.15).timeout
	print("GAMEPLAY %s: %s (%d checks)" % [args[0], "PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func host_game() -> void:
	menu.get_node("%HostButton").pressed.emit()
	check(network.role == "past" and network.state == network.State.HOSTING, "Actual Host button opens Past ENet lobby")
	check(not puzzles.is_session_active(), "Lobby does not start a puzzle session")
	print("GAMEPLAY_HOST_LISTENING")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Guest did not join menu lobby"):
		return
	check(menu.get_node("%StartGameButton").disabled, "Host Start remains disabled before guest Ready")
	if not await wait_for(func() -> bool: return network.guest_ready, "Guest Ready button never confirmed"):
		return
	check(not menu.get_node("%StartGameButton").disabled, "Confirmed Ready enables actual Start button")
	menu.get_node("%StartGameButton").pressed.emit()
	if not await enter_lab():
		return
	check(room.timeline == "Past" and room.player.scene_file_path.ends_with("student_3d_player.tscn"), "Host spawns finished Student in Past")
	var start: Vector3 = room.player.position
	if not await wait_for(func() -> bool: return step() >= 1, "Future client did not complete ownership checks"):
		return
	check(room.player.position.distance_to(start) < 0.1, "Client movement never controls host character")
	check(refused.has(["role_not_allowed", "future"]), "Host authenticates remote Future role despite a forged Past argument")
	check(puzzles.get_state(FREQUENCY).professor_radio and not puzzles.get_state(FREQUENCY).student_radio, "Only confirmed client radio is owned before host pickup")
	await use_object(Vector3(-4.85, 0, 1.6), "../SignalLab/Layout/Interactive/PastRadio/Pickup")
	if not await wait_for(func() -> bool: return game.radio.owns_radio, "Host Student acquisition failed"):
		return
	await finish_dialogue()
	await use_object(Vector3(0, 0, -5.6), "../SignalLab/Layout/Interactive/ConsoleTerminal/Computer")
	if not await wait_for(func() -> bool: return game.terminal.visible, "Host terminal failed to open"):
		return
	var inspector = game.physical_devices.inspector
	check(inspector.adjust_dial(17) and puzzles.get_state(FREQUENCY).current_frequency == 67, "The physical frequency dial broadcasts immediately")
	if not await wait_for(func() -> bool: return step() >= 2, "Future receiver did not observe the live waveform"):
		return
	check(inspector.adjust_dial(35, "amplitude") and puzzles.is_solved(FREQUENCY), "The physical amplitude dial establishes the matched link")
	check(link_cues == 1, "Host hears one confirmed radio connection cue")
	check(game.terminal.status_label.text == "TEMPORAL RADIO LINK ESTABLISHED" and completions == 1, "Actual terminal displays confirmed outcome exactly once")
	game.terminal.close()
	check(game.director.get_current_sequence_id() == "laboratory.radio_link_established", "Host receives real radio DialogueSequence")
	await finish_dialogue()
	if not await wait_for(func() -> bool: return step() >= 3, "Guest did not verify radio/dialogue/snapshot"):
		return
	await use_object(Vector3(-9.9, 0, -2.5), "Props/ReceiverRelay")
	if not await wait_for(func() -> bool: return puzzles.is_solved(RELAY), "Confirmed receiver relay action missing"):
		return
	await finish_dialogue()
	if not await wait_for(func() -> bool: return step() >= 4, "Guest did not verify auxiliary puzzle and room reload"):
		return
	var session: int = puzzles.get_session_id()
	game.stop_audio()
	change_scene_to_file("res://scenes/world/spawn_area.tscn")
	await scene_changed
	if not await enter_lab():
		return
	check(game.radio.can_receive() and puzzles.get_session_id() == session and completions == 1, "Host actual-room reload retains link without replaying solve")
	check(not game.director.is_dialogue_active(), "Host room entry does not replay completed radio dialogue")
	room.get_node("%PauseButton").pressed.emit()
	check(room._paused and puzzles.is_session_active(), "Host pause keeps network and authoritative session alive")
	room.get_node("%MenuButton").pressed.emit()
	if not await wait_for(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", "Host could not return to menu"):
		return
	check(network.state == network.State.IDLE and not puzzles.is_solved(FREQUENCY), "Host menu return releases session and clears old progress")


func client_game() -> void:
	menu.get_node("%JoinButton").pressed.emit()
	menu.get_node("%HostAddress").text = "127.0.0.1"
	menu.get_node("%ConnectButton").pressed.emit()
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Actual Join button failed to connect"):
		return
	check(network.role == "future" and menu.get_node("%ReadyButton").visible, "Join assigns Professor and displays actual Ready UI")
	check(not network.start_game(), "Client cannot start the game")
	await create_timer(0.25).timeout  # let the host inspect its unready Start button
	menu.get_node("%ReadyButton").pressed.emit()
	if not await enter_lab():
		return
	check(room.timeline == "Future" and room.player.scene_file_path.ends_with("professor_3d_player.tscn"), "Guest spawns finished Professor in Future")
	check(game.controller.actor == room.player and game.radio.player_role == "future", "Guest rig and radio bind only to its own character")
	Input.action_press("move_right")
	await tick(12)
	Input.action_release("move_right")
	await tick()
	puzzles.submit_action(FREQUENCY, "tune_frequency", {"frequency": 67}, "past")
	if not await wait_for(func() -> bool: return refused.has(["role_not_allowed", "future"]), "Forged role request was not refused"):
		return
	check(not puzzles.is_solved(FREQUENCY), "Client cannot force temporal connection")
	await use_object(Vector3(-8.45, 0, 4.2), "../SignalLab/Layout/Interactive/FutureRadio/Pickup")
	check(not game.radio.owns_radio, "Animated remote acquisition does not grant ownership optimistically")
	if not await wait_for(func() -> bool: return game.radio.owns_radio, "Host did not confirm Future radio pickup"):
		return
	check(game.radio.signal_state == 1, "Guest HUD searches while waiting for host calibration")
	reach(1)
	if not await wait_for(func() -> bool: return puzzles.get_state(FREQUENCY).get("current_frequency") == 67, "Live frequency never reached Future"):
		return
	var console = room.lab.get_node("Layout/Interactive/ConsoleTerminal")
	check(console.waveform.show_target and console.waveform.state.current_frequency == 67 and console.waveform.state.current_amplitude == 35, "Future CRT updates while the Past is tuning, before completion")
	check(not game.radio.can_receive(), "Matching frequency still waits for the amplitude dial")
	reach(2)
	if not await wait_for(func() -> bool: return game.radio.can_receive(), "Host calibration did not reach actual Future lab"):
		return
	check(puzzles.get_state(FREQUENCY) == {"student_radio": true, "professor_radio": true, "frequency_calibrated": true, "current_frequency": 67, "current_amplitude": 70}, "Both actual labs share confirmed canonical prerequisites")
	check(game.director.get_current_sequence_id() == "laboratory.radio_link_established" and game.director.dialogue_box.radio_mode, "Guest sees actual radio dialogue after host-confirmed completion")
	check(game.get_node("GameplayHUD/RadioHUD").status_label.text == "CONNECTED", "Guest radio HUD displays connected state")
	await finish_dialogue()
	var before := changes
	var revision: int = puzzles.get_revision(FREQUENCY)
	puzzles.request_sync()
	if not await wait_for(func() -> bool: return changes > before, "Full gameplay snapshot missing"):
		return
	check(link_cues == 1, "Client snapshot does not replay connection audio")
	check(puzzles.get_revision(FREQUENCY) == revision and completions == 1 and not game.director.is_dialogue_active(), "Full snapshot retains revision without replaying radio dialogue")
	reach(3)
	if not await wait_for(func() -> bool: return puzzles.is_solved(RELAY), "Shared receiver relay completion missing"):
		return
	check(game.director.get_current_sequence_id() == "laboratory.receiver_online", "Guest receives later confirmed-puzzle radio conversation")
	await finish_dialogue()
	var session: int = puzzles.get_session_id()
	game.stop_audio()
	change_scene_to_file("res://scenes/world/spawn_area.tscn")
	await scene_changed
	if not await enter_lab():
		return
	check(game.radio.owns_radio and game.radio.can_receive() and puzzles.get_session_id() == session, "Guest actual-room reload retains radio and link")
	check(not game.director.is_dialogue_active(), "Guest room reload does not replay first conversation")
	check(link_cues == 1, "Room reload does not replay connection audio")
	reach(4)
	if not await wait_for(func() -> bool: return room._disconnected, "Partner departure did not reach actual gameplay"):
		return
	check(room.pause_panel.visible and not room.player.controls_enabled and not room.get_node("%ResumeButton").visible, "Disconnect shows actionable Return to Menu state and blocks local gameplay")
	check(not game.radio.can_receive() and not game.director.is_dialogue_active(), "Disconnect clears radio readiness and dialogue")
	room.get_node("%MenuButton").pressed.emit()
	if not await wait_for(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", "Disconnected guest could not return to menu"):
		return
	check(network.state == network.State.IDLE and get_nodes_in_group("dialogue_director").is_empty(), "Guest menu return releases connection and gameplay presenters")
