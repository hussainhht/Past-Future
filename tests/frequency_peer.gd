extends SceneTree
## Real ENet integration through the unchanged NetworkManager and PuzzleManager.
## Checkpoints use the existing test puzzle, never an extra RPC protocol.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Fixtures := preload("res://tests/puzzle_fixtures.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status

var network: Node
var puzzles: Node
var radio: Node
var presenter: Node3D
var rejected: Array = []
var completions: int = 0
var announcements: int = 0
var checks: int = 0
var failures: int = 0
var port: int


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func wait_for(predicate: Callable, message: String, seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func step() -> int:
	return puzzles.get_state("radio_checkpoint").get("step", 0)


func reach(value: int) -> void:
	check(puzzles.submit_action("radio_checkpoint", "reached", {"step": value}).status == Status.PENDING, "Client checkpoints go through host")


func _run() -> void:
	network = root.get_node("NetworkManager")
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	puzzles.register_puzzle(Rules.ID, Rules.new())
	puzzles.register_puzzle("radio_checkpoint", Fixtures.CheckpointPuzzle.new())
	puzzles.puzzle_completed.connect(func(id: String):
		if id == Rules.ID:
			completions += 1)
	puzzles.puzzle_state_changed.connect(func(id: String, _state: Dictionary, _revision: int):
		if id == Rules.ID:
			announcements += 1)
	puzzles.action_rejected.connect(func(id: String, action: String, reason: String, role: String):
		if id == Rules.ID:
			rejected.append([action, reason, role]))
	var args := OS.get_cmdline_user_args()
	port = args[1].to_int()
	radio = load("res://scenes/gameplay/radio/temporal_radio.tscn").instantiate()
	radio.player_role = "past" if args[0] == "host" else "future"
	root.add_child(radio)
	presenter = load("res://scenes/gameplay/frequency/temporal_link_indicator.tscn").instantiate()
	root.add_child(presenter)
	if args[0] == "host":
		await _host()
	else:
		await _client()
	network.leave_game()
	radio.free()
	presenter.free()
	await process_frame
	print("FREQUENCY %s: %s (%d checks)" % [args[0], "PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _host() -> void:
	check(network.host_game(port) == OK, "Host starts existing ENet lobby")
	print("RADIO_HOST_LISTENING")
	if not await wait_for(func() -> bool: return network.guest_ready, "Guest failed to ready"):
		return
	check(not puzzles.is_session_active(), "Lobby cannot change ownership")
	check(network.start_game(), "Host starts session")
	var session: int = puzzles.get_session_id()
	if not await wait_for(func() -> bool: return step() >= 1, "Guest validation/pickup checkpoint missing"):
		return
	check(rejected == [["tune_frequency", "role_not_allowed", "future"], ["acquire_radio", "radio_not_yours", "future"], ["acquire_radio", "invalid_payload", "future"]], "Real remote sender role defeats forged role and state payloads")
	var state: Dictionary = puzzles.get_state(Rules.ID)
	check(state.professor_radio and not state.student_radio and not state.frequency_calibrated, "Only genuine Future ownership was committed")
	check(puzzles.get_revision(Rules.ID) == 1, "Unauthorized attempts create no canonical revision")
	check(radio.request_acquisition().status == Status.CHANGED, "Host Student component requests its own radio")
	var revision: int = puzzles.get_revision(Rules.ID)
	check(puzzles.submit_action(Rules.ID, "tune_frequency", {"frequency": 66}).status == Status.NO_CHANGE, "Host wrong frequency cannot solve")
	check(puzzles.get_revision(Rules.ID) == revision and completions == 0, "Incorrect tuning creates neither completion nor revision")
	check(puzzles.submit_action(Rules.ID, "tune_frequency", {"frequency": 67}).status == Status.COMPLETED, "Host establishes link after all prerequisites")
	check(completions == 1 and radio.can_receive() and presenter.connected, "Host presentation follows confirmed state")
	check(puzzles.submit_action(Rules.ID, "tune_frequency", {"frequency": 67}).status == Status.NO_CHANGE, "Repeated host tuning is idempotent")
	if not await wait_for(func() -> bool: return step() >= 2, "Guest did not verify connected state and snapshot"):
		return
	check(puzzles.reset_puzzle(Rules.ID), "Host can explicitly reset the radio puzzle")
	if not await wait_for(func() -> bool: return step() >= 3, "Guest did not observe reset"):
		return
	puzzles.begin_session()
	check(puzzles.get_session_id() != session, "New session receives new identity")
	if not await wait_for(func() -> bool: return step() == 1, "Guest did not verify fresh session"):
		return
	if not await wait_for(func() -> bool: return not puzzles.is_session_active(), "Disconnect did not end host session"):
		return
	check(not puzzles.has_state(Rules.ID) and not radio.owns_radio and not presenter.connected, "Disconnect removes ownership and connection on host")
	check(puzzles.submit_action(Rules.ID, "acquire_radio", {"radio_role": "past"}).reason == "no_session", "No ownership action after session ends")


func _client() -> void:
	check(network.join_game("127.0.0.1", port) == OK, "Client joins through existing NetworkManager")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client failed to connect"):
		return
	check(not puzzles.is_authority() and not puzzles.is_session_active(), "Client cannot authorize itself in lobby")
	network.set_ready(true)
	if not await wait_for(func() -> bool: return puzzles.is_session_active(), "Initial authoritative snapshot missing"):
		return
	var session: int = puzzles.get_session_id()
	check(puzzles.get_state(Rules.ID) == Rules.new().get_initial_state(), "Initial snapshot has no radios or calibration")
	var revision: int = puzzles.get_revision(Rules.ID)
	# Both the separate actor argument and payload role lie about who sent this request.
	puzzles.submit_action(Rules.ID, "tune_frequency", {"frequency": 67}, "past")
	puzzles.submit_action(Rules.ID, "acquire_radio", {"radio_role": "past"}, "past")
	puzzles.submit_action(Rules.ID, "acquire_radio", {"radio_role": "future", "frequency_calibrated": true, "student_radio": true})
	if not await wait_for(func() -> bool: return rejected.size() >= 3, "Host rejection responses missing"):
		return
	check(puzzles.get_revision(Rules.ID) == revision and not radio.owns_radio, "Rejected spoofing never alters client replica")
	check(not puzzles.reset_puzzle(Rules.ID), "Client cannot reset authority")
	check(radio.request_acquisition().status == Status.PENDING, "Client pickup is a pending request")
	check(not radio.owns_radio and puzzles.get_revision(Rules.ID) == revision, "No optimistic client ownership")
	if not await wait_for(func() -> bool: return radio.owns_radio, "Confirmed Professor pickup missing"):
		return
	check(radio.signal_state == 1, "Client searches until host calibration")
	reach(1)
	if not await wait_for(func() -> bool: return radio.can_receive(), "Confirmed link missing on client"):
		return
	check(puzzles.get_state(Rules.ID) == {"student_radio": true, "professor_radio": true, "frequency_calibrated": true}, "Client receives all confirmed prerequisites")
	check(puzzles.get_revision(Rules.ID) == 4 and completions == 1 and presenter.connected, "Client applies canonical revision and completion exactly once")
	var before := announcements
	puzzles.request_sync()
	if not await wait_for(func() -> bool: return announcements > before, "Requested full snapshot missing"):
		return
	check(completions == 1 and radio.can_receive() and puzzles.get_revision(Rules.ID) == 4, "Resync restores state without replaying conversation trigger")
	# A newly loaded presentation room and radio both query the existing replica.
	presenter.free()
	presenter = load("res://scenes/gameplay/frequency/temporal_link_indicator.tscn").instantiate()
	root.add_child(presenter)
	check(presenter.connected and puzzles.get_session_id() == session, "New client room immediately reflects retained link")
	var later_radio: Node = load("res://scenes/gameplay/radio/temporal_radio.tscn").instantiate()
	later_radio.player_role = "future"
	root.add_child(later_radio)
	check(later_radio.owns_radio and later_radio.can_receive(), "New character radio rehydrates ownership and link")
	later_radio.free()
	reach(2)
	if not await wait_for(func() -> bool: return not radio.owns_radio, "Host reset did not reach client"):
		return
	check(not presenter.connected and radio.signal_state == 0, "Host reset updates client component and rift")
	reach(3)
	if not await wait_for(func() -> bool: return puzzles.get_session_id() != session, "New session snapshot missing"):
		return
	check(puzzles.get_state(Rules.ID) == Rules.new().get_initial_state() and puzzles.get_latest_revision() == 0, "Fresh session inherits no ownership or calibration")
	check(not puzzles._receive_update(session, Rules.ID, {"student_radio": true, "professor_radio": true, "frequency_calibrated": true}, true, 999, 0), "Old-session update cannot restore stale connection")
	check(not radio.can_receive() and completions == 1, "Stale updates and session start do not replay completion")
	reach(1)
	if not await wait_for(func() -> bool: return step() == 1, "New session checkpoint not confirmed"):
		return
	network.leave_game()
	check(not radio.owns_radio and not radio.can_receive(), "Leaving LAN starts clean offline radio state")
