extends SceneTree
## Run through run_puzzle_tests.py: two real ENet peers in separate processes exercise PuzzleManager's RPCs.
## The peers pace each other with the "checkpoint" puzzle: the client reports progress as confirmed
## actions, and the host waits for them, so the test needs no timers beyond flush delays.

const Fixtures := preload("res://tests/puzzle_fixtures.gd")
const PowerSwitch := preload("res://scripts/puzzles/implementations/power_switch_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
const INITIAL_POWER := {"solved": false, "power_on": false}

var network: Node
var puzzles: Node
var probe
var failures: int = 0
var port: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func poll(predicate: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func wait_for(predicate: Callable, message: String, timeout: float = 10.0) -> bool:
	var reached: bool = await poll(predicate, timeout)
	check(reached, message)
	return reached


func _run() -> void:
	network = root.get_node("NetworkManager")
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	probe = Fixtures.Probe.new(puzzles)
	var arguments := OS.get_cmdline_user_args()
	port = int(arguments[1])
	puzzles.register_puzzle("power_switch", PowerSwitch.new())
	puzzles.register_puzzle("checkpoint", Fixtures.CheckpointPuzzle.new())
	match arguments[0]:
		"host":
			await _host()
		"client":
			await _client()
	network.leave_game()
	print("PUZZLE ", arguments[0], ": ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func checkpoint_step() -> int:
	return puzzles.get_state("checkpoint").get("step", 0)


func wait_step(step: int) -> bool:
	return await wait_for(func() -> bool: return checkpoint_step() >= step, "Never reached checkpoint %d" % step)


## Client: tell the host how far we got, as a normal confirmed puzzle action.
func reach(step: int) -> void:
	check(puzzles.submit_action("checkpoint", "reached", {"step": step}).status == Status.PENDING, "Checkpoint request must go to the host")


func _host() -> void:
	check(network.host_game(port) == OK, "Host should bind a UDP port")
	print("HOST_LISTENING")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Guest never connected", 20.0):
		return
	check(not puzzles.is_session_active(), "No puzzle session may exist in the lobby")
	check(puzzles.submit_action("power_switch", "activate_power").reason == "no_session", "Actions before the game starts must be refused")
	probe.rejected.clear()
	if not await wait_for(func() -> bool: return network.guest_ready, "Guest never became ready"):
		return
	check(network.start_game(), "Host should start the game")
	var first_session: int = puzzles.get_session_id()
	check(puzzles.is_session_active() and puzzles.is_authority() and puzzles.get_local_role() == "past", "Starting the game must begin the host's session as the Past")
	check(puzzles.get_state("power_switch") == INITIAL_POWER, "A new session must start from initial state")

	# The client's wrong requests and forged RPCs arrive first; its checkpoint comes last.
	if not await wait_step(1):
		return
	var reasons := []
	for entry in probe.rejected:
		reasons.append(entry[2])
	check(reasons == ["role_not_allowed", "role_not_allowed", "unknown_puzzle", "unknown_action"], "Host must reject each bad client request with its reason, got %s" % str(reasons))
	check(probe.rejected[0] == ["power_switch", "activate_power", "role_not_allowed", "future"], "The host must derive the Future role from the connection")
	check(puzzles.get_state("power_switch") == INITIAL_POWER and puzzles.get_revision("power_switch") == 0, "Rejected requests must not touch canonical state")
	check(puzzles.get_latest_revision() == 1 and puzzles.get_session_id() == first_session, "Forged state pushes from the client must not be accepted")
	check(probe.completed.is_empty(), "Nothing has been solved yet")

	# The Past solves it; the client must see it exactly once.
	var result: Dictionary = puzzles.submit_action("power_switch", "activate_power")
	check(result.status == Status.COMPLETED and result.revision == 2, "The host's own action must be applied once, with the next revision")
	check(puzzles.submit_action("power_switch", "activate_power").status == Status.NO_CHANGE, "A repeated action must change nothing")
	check(probe.completed == ["power_switch"] and probe.changed.size() >= 2, "The host must announce the completion once")
	if not await wait_step(2):
		return

	# Reset, then solve again.
	check(puzzles.reset_puzzle("power_switch") and probe.resets == ["power_switch"], "The host must be able to reset a puzzle")
	if not await wait_step(3):
		return
	check(puzzles.submit_action("power_switch", "activate_power").status == Status.COMPLETED, "A reset puzzle can be solved again")
	if not await wait_step(4):
		return

	# A room that registers its puzzle after the session began still reaches the client.
	check(puzzles.register_puzzle("late_puzzle", PowerSwitch.new()) == OK, "Late registration must work")
	if not await wait_step(5):
		return

	# The client leaves: the session must end cleanly.
	if not await wait_for(func() -> bool: return network.state == network.State.HOSTING and not puzzles.is_session_active(), "Host session did not end when the guest left"):
		return
	check(probe.ended >= 1, "Ending the session must be announced")
	check(puzzles.submit_action("power_switch", "activate_power").reason == "no_session", "No actions may run after the guest disconnected")
	check(not puzzles.has_state("power_switch"), "A finished session must not leave state behind")

	# Fresh session on a fresh connection.
	check(network.host_game(port) == OK, "Host should be able to host again")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED and network.guest_ready, "Guest could not rejoin", 25.0):
		return
	check(not puzzles.is_session_active(), "The lobby has no session")
	check(network.start_game(), "Host should start the second game")
	check(puzzles.get_session_id() != first_session and puzzles.get_session_id() != 0, "A second game must be a new session")
	check(puzzles.get_state("power_switch") == INITIAL_POWER and puzzles.get_revision("power_switch") == 0 and puzzles.get_latest_revision() == 0, "A second game must start from initial state")
	check(puzzles.get_state("late_puzzle") == INITIAL_POWER, "Registered puzzles must be recreated for the new session")
	if not await wait_step(1):
		return
	await create_timer(0.5).timeout


func _client() -> void:
	network.connect_timeout_seconds = 4.0
	check(network.join_game("127.0.0.1", port) == OK, "Join should initialize")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client never connected", 20.0):
		return
	check(not puzzles.is_authority() and not puzzles.is_session_active(), "A client has no session until the host sends a snapshot")
	check(puzzles.submit_action("power_switch", "activate_power").reason == "no_session", "A client must not send requests before its snapshot")
	probe.rejected.clear()
	network.set_ready(true)

	# The host's snapshot starts the client's session.
	if not await wait_for(func() -> bool: return puzzles.is_session_active(), "Initial snapshot never arrived"):
		return
	var first_session: int = puzzles.get_session_id()
	check(probe.started == 1 and puzzles.get_local_role() == "future", "The snapshot must start the session once")
	check(puzzles.get_state("power_switch") == INITIAL_POWER and not puzzles.is_solved("power_switch"), "The snapshot must carry the initial state")
	check(puzzles.has_state("checkpoint"), "The snapshot must carry every registered puzzle")

	# The Future may not throw the Past's switch, however the request is dressed up.
	var result: Dictionary = puzzles.submit_action("power_switch", "activate_power")
	check(result.status == Status.PENDING and not puzzles.is_solved("power_switch"), "A client request must wait for the host, not apply optimistically")
	puzzles.submit_action("power_switch", "activate_power", {"solved": true, "power_on": true, "actor_role": "past"}, "past")
	puzzles.submit_action("ghost_puzzle", "anything")
	puzzles.submit_action("power_switch", "explode")
	if not await wait_for(func() -> bool: return probe.rejected.size() >= 4, "The host never answered the rejected requests"):
		return
	check(probe.rejected[0] == ["power_switch", "activate_power", "role_not_allowed", "future"], "The client must be told why its request failed")
	check(not puzzles.is_solved("power_switch"), "Rejected requests must leave the client's state alone")
	# Clients cannot push state at the host either: these must be dropped by the engine and by the handlers.
	puzzles._rpc_apply_update.rpc_id(1, first_session, "power_switch", {"solved": true, "power_on": true}, true, 999, 0)
	puzzles._rpc_apply_snapshot.rpc_id(1, first_session, 999, {"power_switch": {"state": {"solved": true, "power_on": true}, "solved": true, "revision": 999}}, 0)
	reach(1)

	# The host's confirmed solve arrives once.
	if not await wait_for(func() -> bool: return puzzles.is_solved("power_switch"), "The confirmed solve never reached the client"):
		return
	check(puzzles.get_state("power_switch") == {"solved": true, "power_on": true}, "The client must hold the host's confirmed state")
	check(probe.completed == ["power_switch"], "The client must announce the completion exactly once")
	check(puzzles.get_latest_revision() == puzzles.get_revision("power_switch") and puzzles.get_revision("power_switch") == 2, "The client must record the host's revision")
	var announcements: int = probe.changed.size()
	puzzles.request_sync()
	if not await wait_for(func() -> bool: return probe.changed.size() >= announcements + 2, "The requested snapshot never arrived"):
		return
	check(puzzles.is_solved("power_switch") and probe.completed.size() == 1 and puzzles.get_session_id() == first_session, "A resync must restore state without replaying the completion")
	reach(2)

	if not await wait_for(func() -> bool: return not puzzles.is_solved("power_switch"), "The host's reset never reached the client"):
		return
	check(probe.resets == ["power_switch"] and puzzles.get_state("power_switch") == INITIAL_POWER, "The reset must reach the client")
	reach(3)
	if not await wait_for(func() -> bool: return probe.completed.size() == 2, "The second solve never reached the client"):
		return
	reach(4)

	if not await wait_for(func() -> bool: return puzzles.has_state("late_puzzle"), "A late-registered puzzle never reached the client"):
		return
	check(puzzles.get_state("late_puzzle") == INITIAL_POWER and not puzzles.is_registered("late_puzzle"), "A client needs no logic to display a puzzle's state")
	reach(5)
	if not await wait_step(5):
		return
	await create_timer(0.3).timeout

	# Leaving the game drops back to an independent offline session.
	network.leave_game()
	check(puzzles.is_session_active() and puzzles.is_authority() and puzzles.get_session_id() != first_session, "Leaving must start a fresh offline session")
	check(puzzles.get_state("power_switch") == INITIAL_POWER and not puzzles.has_state("late_puzzle"), "Offline play must not inherit the finished game")

	# Rejoin the restarted host: a new session must replace the old one completely.
	await create_timer(1.0).timeout
	var joined := false
	for attempt in range(6):
		network.join_game("127.0.0.1", port)
		await poll(func() -> bool: return network.state != network.State.CONNECTING, 8.0)
		if network.state == network.State.CONNECTED:
			joined = true
			break
		await create_timer(0.5).timeout
	check(joined, "Client could not rejoin the restarted host")
	if not joined:
		return
	check(not puzzles.is_session_active(), "A rejoining client must wait for the new host's snapshot")
	network.set_ready(true)
	if not await wait_for(func() -> bool: return puzzles.is_session_active(), "Second snapshot never arrived"):
		return
	check(puzzles.get_session_id() != first_session, "The second game must be a new session")
	check(puzzles.get_state("power_switch") == INITIAL_POWER and puzzles.get_latest_revision() == 0, "The new session must not carry old progress")
	check(not puzzles._receive_update(first_session, "power_switch", {"solved": true, "power_on": true}, true, 999, 0), "An update from the first game must be ignored")
	check(not puzzles.is_solved("power_switch"), "Old-session updates must not corrupt the new session")
	reach(1)
	if not await wait_step(1):
		return
	await create_timer(0.3).timeout
