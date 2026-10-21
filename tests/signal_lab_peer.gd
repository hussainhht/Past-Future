extends SceneTree
## Run through run_signal_lab_tests.py: two real ENet peers in separate processes play Puzzle 01
## (the frequency puzzle) in the Signal Laboratory. The host is the Past (Student radio, calibration
## computer, authority), the client is the Future (recovered log, Professor radio). Each peer drives
## its own player through the real interaction rig and the puzzle's own screens; the peers pace each
## other only through confirmed puzzle state.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
const SPAWN_AREA := "res://scenes/world/spawn_area.tscn"

var network: Node
var puzzles: Node
var failures: int = 0
var port: int = 0
var states: Array[Dictionary] = []
var completions: int = 0
var rejections: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func wait_for(predicate: Callable, message: String, timeout: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func state() -> Dictionary:
	return puzzles.get_state(Rules.ID)


func lab():
	return current_scene.lab if is_instance_valid(current_scene) and current_scene.has_node("SignalLab") else null


func _run() -> void:
	network = root.get_node("NetworkManager")
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	puzzles.puzzle_state_changed.connect(func(id: String, s: Dictionary, _revision: int) -> void:
		if id == Rules.ID:
			states.append(s)
	)
	puzzles.puzzle_completed.connect(func(id: String) -> void:
		if id == Rules.ID:
			completions += 1
	)
	puzzles.action_rejected.connect(func(id: String, action: String, reason: String, _role: String) -> void:
		rejections.append([id, action, reason])
	)
	network.game_started.connect(func() -> void: change_scene_to_file.call_deferred(SPAWN_AREA))
	var arguments := OS.get_cmdline_user_args()
	port = int(arguments[1])
	match arguments[0]:
		"host":
			await _host()
		"client":
			await _client()
	network.leave_game()
	await create_timer(1.5).timeout  # let the last one-shot sounds finish before the engine shuts down
	print("SIGNAL LAB ", arguments[0], ": ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


## Wait for the room, and for this peer's copy of the puzzle state.
func _enter_room() -> bool:
	if not await wait_for(func() -> bool: return lab() != null and lab().is_node_ready(), "The spawn area with the Signal Laboratory never loaded"):
		return false
	if not await wait_for(func() -> bool: return puzzles.has_state(Rules.ID), "Lost Frequency state never reached this peer"):
		return false
	current_scene._set_paused(false)
	# This suite checks room synchronization; gameplay_peer.gd covers narrative playback.
	current_scene.gameplay.get_node("StudentDiscovery").enabled = false
	current_scene.gameplay.get_node("FutureDiscovery").enabled = false
	current_scene.gameplay.adapter.link_sequence_id = &""
	await create_timer(0.3).timeout
	return true


func _stand(at: Vector3) -> Interactable3D:
	var player: CharacterBody3D = current_scene.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	for index in 8:
		await physics_frame
	var controller = current_scene.interaction
	controller.detector.refresh_target()
	return controller.get_current_interactable()


func _use(at: Vector3, expected: String) -> bool:
	var target := await _stand(at)
	var name: String = "" if target == null else (target.get_parent().name if target.name == "Pickup" else target.name)
	check(name == expected, "Expected to use %s, found %s" % [expected, name])
	if name != expected or not current_scene.interaction.try_interact():
		return false
	# Merged gameplay commits device interactions after the character animation.
	return await wait_for(func() -> bool: return not current_scene.player.is_action_active(), "Device animation did not finish")


func _host() -> void:
	check(network.host_game(port) == OK, "Host should bind a UDP port")
	print("HOST_LISTENING")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED and network.guest_ready, "Guest never connected and readied", 25.0):
		return
	check(network.start_game(), "Host should start the game")
	if not await _enter_room():
		return
	var room = lab()
	check(current_scene.timeline == "Past" and not room.future, "The host must see the Past laboratory")
	check(puzzles.is_authority(), "The host must be the puzzle authority")

	# The Student takes the radio from the science bench, then calibrates at the console.
	await _use(Vector3(-4.85, 0, 1.6), "PastRadio")
	await wait_for(func() -> bool: return state().get("student_radio", false), "The host's radio pickup was never confirmed")
	check(await _use(Vector3(0, 0, -5.6), "Computer") and room.terminal.visible, "The calibration terminal must open on the host")
	if not await wait_for(func() -> bool: return Rules.radios_ready(state()), "Both radios required before live tuning"):
		return
	check(room.terminal.submit_frequency(66).status == Status.CHANGED, "An unmatched frequency is broadcast live")
	check(room.terminal.submit_frequency(67).status == Status.CHANGED, "Frequency matches while amplitude still differs")
	check(room.terminal.submit_amplitude(70).status == Status.COMPLETED, "Both settings calibrate the array")
	room.terminal.close()
	check(rejections.any(func(entry: Array) -> bool: return entry[1] == "tune_frequency" and entry[2] == "role_not_allowed"), "A tune request from the Future must be rejected on the host")

	# The Professor's radio completes the link; the host sees one completion and the door opening.
	if not await wait_for(func() -> bool: return puzzles.is_solved(Rules.ID), "The link was never established", 30.0):
		return
	check(completions == 1, "The host must see the completion exactly once")
	await wait_for(func() -> bool: return room.door.is_open, "The host's door never opened", 6.0)
	check("TEMPORAL RADIO LINK ESTABLISHED" in room.ui.banner_text(), "The host must see the link banner")
	# Give the client time to verify its side before the session ends.
	await wait_for(func() -> bool: return network.state != network.State.CONNECTED, "The client never finished", 30.0)


func _client() -> void:
	check(network.join_game("127.0.0.1", port) == OK, "Join should initialize")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client never joined", 20.0):
		return
	network.set_ready(true)
	if not await _enter_room():
		return
	var room = lab()
	check(current_scene.timeline == "Future" and room.future, "The client must see the Future laboratory")
	check(not puzzles.is_authority(), "The client must not be the authority")

	# The Future cannot calibrate; the host must refuse even a forged request.
	check(puzzles.submit_action(Rules.ID, "tune_frequency", {"frequency": 67}).status == Status.PENDING, "The client's request must go to the host")
	await wait_for(func() -> bool: return rejections.size() > 0, "The host never answered the forged calibration")
	check(rejections.size() > 0 and rejections[0][2] == "role_not_allowed", "The host must reject a calibration from the Future")

	# Read the recovered log at the damaged console.
	check(await _use(Vector3(0, 0, -5.6), "RecoveredLog") and room.reader.visible, "The recovered log must open on the client")
	check("67 MHz" in room.reader.document_label.text, "The log must show the frequency to the Future player")
	room.reader.close()

	# Both pickups precede live tuning.
	await _use(Vector3(-8.45, 0, 4.2), "FutureRadio")
	if not await wait_for(func() -> bool: return puzzles.is_solved(Rules.ID), "The client's radio never completed the link"):
		return
	check(completions == 1, "The client must see the completion exactly once")
	check("TEMPORAL RADIO LINK ESTABLISHED" in room.ui.banner_text(), "The client must see the link banner")
	await wait_for(func() -> bool: return room.door.is_open, "The client's door never opened", 6.0)
	check(room.get_node("Layout/Interactive/DoorKeypad").display.text == "OPEN", "The client's keypad must report the open door")
	check(room.get_node("Layout/Interactive/ConsoleTerminal").readout.text == "TEMPORAL LINK", "The client's console must confirm the link")
	check(current_scene.radio.has_established_link(), "The client's TemporalRadio must report the link")
