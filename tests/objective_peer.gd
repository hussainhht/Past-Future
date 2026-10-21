extends SceneTree
## Run through run_objective_tests.py: two real ENet peers (host = Student / Past, guest = Professor /
## Future) in separate processes, each with its own ObjectiveManager, driven only by the real
## PuzzleManager (host-authoritative) and each peer's own local discoveries. The peers pace each other
## with the existing checkpoint fixture; every objective check is made on the peer that owns it.

const Fixtures := preload("res://tests/puzzle_fixtures.gd")
const Freq := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Corridor := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")

const F1 := "puzzle_01_frequency"
const M2 := "puzzle_02_maintenance"
const CHECK := "objective_checkpoint"

var network: Node
var puzzles: Node
var flow: Node
var objectives: Node
var journal: Node
var failures: int = 0
var checks: int = 0
var port: int = 0
var announced: Array[String] = []
var rooms: Array[Node] = []
var prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func poll(predicate: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func wait_for(predicate: Callable, message: String, timeout: float = 12.0) -> bool:
	var reached: bool = await poll(predicate, timeout)
	check(reached, message)
	return reached


func settle() -> void:
	for i in 5:
		await process_frame


func current_key(role: String = "") -> String:
	var definition: ObjectiveDefinition = objectives.get_current(role if not role.is_empty() else objectives.get_local_role())
	return "" if definition == null else definition.objective_id.trim_prefix(prefix)


func is_done(key: String) -> bool:
	return objectives.is_completed(prefix + key)


func told(key: String) -> int:
	return announced.count(prefix + key)


func enter_room(room_id: String) -> void:
	var node := Node.new()
	root.add_child(node)
	rooms.append(node)
	check(flow.attach_room(room_id, node), "Room %s attaches" % room_id)
	await settle()


func clear_rooms() -> void:
	for node in rooms:
		node.queue_free()
	rooms.clear()
	await settle()


func step() -> int:
	return puzzles.get_state(CHECK).get("step", 0)


func wait_step(value: int) -> bool:
	return await wait_for(func() -> bool: return step() >= value, "Never reached checkpoint %d" % value)


func reach(value: int) -> void:
	check(puzzles.submit_action(CHECK, "reached", {"step": value}).status == 4, "Checkpoint %d goes to the host" % value)


func _run() -> void:
	network = root.get_node("NetworkManager")
	puzzles = root.get_node("PuzzleManager")
	flow = root.get_node("GameFlowManager")
	objectives = root.get_node("ObjectiveManager")
	journal = root.get_node("JournalManager")
	puzzles.log_rejections = false
	flow.log_problems = false
	var arguments := OS.get_cmdline_user_args()
	port = int(arguments[1])
	puzzles.register_puzzle(CHECK, Fixtures.CheckpointPuzzle.new())
	objectives.objective_completed.connect(func(role: String, id: String) -> void: announced.append(id))
	match arguments[0]:
		"host":
			prefix = "student_"
			puzzles.register_puzzle(F1, Freq.new())
			puzzles.register_puzzle(M2, Corridor.new())
			await _host()
		"client":
			prefix = "professor_"
			await _client()
	network.leave_game()
	print("OBJECTIVES ", arguments[0], ": ", "PASS" if failures == 0 else "FAIL", " (%d checks, %d failures)" % [checks, failures])
	quit(0 if failures == 0 else 1)


## What a peer may and may not know, checked on that peer.
func check_isolation(own: String, other: String) -> void:
	check(objectives.get_local_role() == own, "This peer plays %s" % own)
	var asked_for_other: ObjectiveDefinition = objectives.get_current(other)
	check(asked_for_other == null or asked_for_other.role == own, "Asking for the other timeline's objective answers with this peer's own")
	for definition: ObjectiveDefinition in objectives.get_completed(other):
		check(definition.role == own, "The completed list never holds the other timeline's objectives")
	for entry: Dictionary in objectives.get_upcoming(other):
		check(not entry.has("definition") or entry.definition.role == own, "Upcoming never holds the other timeline's objectives")


func _host() -> void:
	check(network.host_game(port) == OK, "Host binds a port")
	print("HOST_LISTENING")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED and network.guest_ready, "Guest never became ready", 25.0):
		return
	check(network.start_game(), "Host starts the game")
	await enter_room("room_01")

	# --- Level 1 ------------------------------------------------------------------------------
	check(objectives.has_content() and current_key() == "l1_find_radio", "Student starts by finding the radio")
	check_isolation("past", "future")
	if not await wait_step(1):
		return
	puzzles.submit_action(F1, "acquire_radio", {"radio_role": "past"})
	await settle()
	check(is_done("l1_find_radio") and told("l1_find_radio") == 1 and current_key() == "l1_calibrate", "Student's radio completes the Student's objective, once")
	if not await wait_step(2):
		return
	# The Professor read the log on their own machine: the Student learns nothing from it.
	check(objectives.get_completed().size() == 1 and current_key() == "l1_calibrate", "The Professor's private discovery changes nothing for the Student")
	if not await wait_step(3):
		return
	check(puzzles.get_state(F1).professor_radio, "The Professor's radio arrived through the host")
	check(current_key() == "l1_calibrate" and objectives.get_completed().size() == 1, "...and the Student's list is still the Student's own")
	puzzles.submit_action(F1, "tune_frequency", {"frequency": 67})
	puzzles.submit_action(F1, "tune_amplitude", {"amplitude": 70})
	await settle()
	check(puzzles.is_solved(F1) and is_done("l1_calibrate") and told("l1_calibrate") == 1 and current_key() == "l1_exit", "The confirmed link completes the Student's calibration once")
	if not await wait_step(4):
		return

	# --- Level 2 ------------------------------------------------------------------------------
	await enter_room("room_02")
	check(is_done("l1_exit") and told("l1_exit") == 1 and current_key() == "l2_isolate_service", "Entering the corridor completes leaving the lab, once")
	if not await wait_step(5):
		return
	puzzles.submit_action(M2, "isolate_service")
	await settle()
	check(is_done("l2_isolate_service") and current_key() == "l2_restore_power", "Student isolates the service circuit")
	if not await wait_step(6):
		return
	if not await wait_for(func() -> bool: return puzzles.get_state(M2).battery_ready, "The Professor's charge never arrived"):
		return
	await settle()
	check(is_done("l2_restore_power") and told("l2_restore_power") == 1 and current_key() == "l2_preserve_parts", "...and completed the Student's next objective, once")
	if not await wait_step(7):
		return
	check(told("l2_restore_power") == 1, "A resync does not repeat the notice")
	check(objectives.get_completed().size() == 5, "Student history: radio, calibrate, exit, isolate, power (%d)" % objectives.get_completed().size())
	check_isolation("past", "future")

	# --- The guest leaves: the session ends and nothing carries over -----------------------------------
	await clear_rooms()
	if not await wait_for(func() -> bool: return network.state == network.State.HOSTING and not puzzles.is_session_active(), "Host session did not end when the guest left"):
		return
	check(objectives.get_completed().is_empty() and not objectives.has_content(), "A finished session leaves no objectives behind")
	check(network.host_game(port) == OK, "Host can host again")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED and network.guest_ready, "Guest could not rejoin", 25.0):
		return
	check(network.start_game(), "Host starts the second game")
	var before: int = announced.size()
	await enter_room("room_01")
	check(current_key() == "l1_find_radio" and objectives.get_completed().is_empty(), "A new game starts from the first objective")
	check(announced.size() == before, "Nothing is announced for a fresh start")
	if not await wait_step(1):
		return
	await create_timer(0.4).timeout


func _client() -> void:
	network.connect_timeout_seconds = 4.0
	check(network.join_game("127.0.0.1", port) == OK, "Join initializes")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client never connected", 20.0):
		return
	network.set_ready(true)
	if not await wait_for(func() -> bool: return puzzles.is_session_active(), "The host's snapshot never arrived", 20.0):
		return
	await enter_room("room_01")

	# --- Level 1 ------------------------------------------------------------------------------
	check(objectives.has_content() and current_key() == "l1_find_radio", "Professor starts by finding the radio")
	check_isolation("future", "past")
	check(announced.is_empty(), "Nothing is announced for arriving")
	reach(1)
	if not await wait_for(func() -> bool: return puzzles.get_state(F1).get("student_radio", false), "The Student's radio never reached the Professor"):
		return
	check(current_key() == "l1_find_radio" and objectives.get_completed().is_empty() and announced.is_empty(), "The Student's pickup does not complete anything for the Professor")
	journal.unlock_entry("future_frequency_log")  # reading the console log: a local discovery
	await settle()
	check(is_done("l1_terminal") and told("l1_terminal") == 1, "The Professor's own discovery completes the Professor's terminal objective")
	check(current_key() == "l1_find_radio", "...without skipping the radio they still need")
	reach(2)
	puzzles.submit_action(F1, "acquire_radio", {"radio_role": "future"})
	if not await wait_for(func() -> bool: return is_done("l1_find_radio"), "The confirmed radio never completed the objective"):
		return
	check(told("l1_find_radio") == 1 and current_key() == "l1_guide", "The Professor's radio completes once and moves on")
	reach(3)
	if not await wait_for(func() -> bool: return puzzles.is_solved(F1), "The confirmed link never reached the Professor"):
		return
	await settle()
	check(is_done("l1_guide") and told("l1_guide") == 1 and current_key() == "l1_exit", "The host's confirmed link completes the Professor's guiding objective, once")
	reach(4)

	# --- Level 2 ------------------------------------------------------------------------------
	await enter_room("room_02")
	check(is_done("l1_exit") and told("l1_exit") == 1 and current_key() == "l2_charge_cell", "Professor enters the corridor with their own first task")
	reach(5)
	if not await wait_for(func() -> bool: return puzzles.get_state(M2).get("service_isolated", false), "The Student's isolation never reached the Professor"):
		return
	await settle()
	check(current_key() == "l2_charge_cell" and not is_done("l2_charge_cell") and objectives.get_completed().size() == 4, "The Student's isolation completes nothing for the Professor (%d done)" % objectives.get_completed().size())
	reach(6)
	puzzles.submit_action(M2, "charge_battery")
	if not await wait_for(func() -> bool: return is_done("l2_charge_cell"), "The confirmed charge never completed the Professor's objective"):
		return
	check(told("l2_charge_cell") == 1 and current_key() == "l2_inspect_archive", "Professor charges the cell and moves on, once")
	var completed: int = objectives.get_completed().size()
	var heard: int = announced.size()
	reach(7)
	var revision: int = puzzles.get_revision(M2)
	puzzles.request_sync()
	await create_timer(0.6).timeout
	check(puzzles.get_revision(M2) == revision and objectives.get_completed().size() == completed, "A resync restores state without changing history")
	check(announced.size() == heard, "...and announces nothing")
	check_isolation("future", "past")

	# --- Leave, rejoin: a new session, a new campaign -------------------------------------------------
	await clear_rooms()
	network.leave_game()
	check(objectives.get_completed().is_empty() and not objectives.has_content(), "Leaving the game clears the Professor's objectives")
	await create_timer(1.0).timeout
	var joined := false
	for attempt in 6:
		network.join_game("127.0.0.1", port)
		await poll(func() -> bool: return network.state != network.State.CONNECTING, 8.0)
		if network.state == network.State.CONNECTED:
			joined = true
			break
		await create_timer(0.5).timeout
	check(joined, "Client rejoins the restarted host")
	if not joined:
		return
	network.set_ready(true)
	if not await wait_for(func() -> bool: return puzzles.is_session_active(), "Second snapshot never arrived", 20.0):
		return
	var before: int = announced.size()
	await enter_room("room_01")
	check(current_key() == "l1_find_radio" and objectives.get_completed().is_empty(), "The Professor's second game starts from the first objective")
	check(announced.size() == before, "Nothing is announced for a fresh start")
	reach(1)
	if not await wait_step(1):
		return
	await create_timer(0.3).timeout
