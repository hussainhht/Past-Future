extends SceneTree
## Authoritative rules exercised through the actual PuzzleManager, no shadow implementation.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
const INITIAL := {"student_radio": false, "professor_radio": false, "frequency_calibrated": false}

var manager: Node
var checks: int = 0
var failures: int = 0
var completions: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func act(action: String, payload: Dictionary, role: String = "past") -> Dictionary:
	return manager.submit_action(Rules.ID, action, payload, role)


func _run() -> void:
	manager = root.get_node("PuzzleManager")
	manager.log_rejections = false
	check(manager.register_puzzle(Rules.ID, Rules.new()) == OK, "Register the frequency rules")
	manager.begin_session()
	manager.puzzle_completed.connect(func(id: String):
		if id == Rules.ID:
			completions += 1)
	check(manager.get_state(Rules.ID) == INITIAL, "Exactly three initial prerequisite flags")
	check(not manager.is_solved(Rules.ID), "Initially disconnected")
	check(act("tune_frequency", {"frequency": 67}).reason == "student_radio_required", "Student must acquire a radio before calibrating")
	check(act("acquire_radio", {"radio_role": "future"}).reason == "radio_not_yours", "Student cannot take Professor ownership")
	check(act("acquire_radio", {"radio_role": "past"}, "future").reason == "radio_not_yours", "Professor cannot take Student ownership")
	check(act("acquire_radio", {"radio_role": 1}).reason == "invalid_payload", "Radio role requires a string")
	check(act("acquire_radio", {}).reason == "invalid_payload", "Missing pickup role is rejected")
	check(act("acquire_radio", {"radio_role": "past", "frequency_calibrated": true}).reason == "invalid_payload", "Pickup cannot smuggle authoritative fields")
	check(act("explode", {}).reason == "unknown_action", "Reject unsupported actions")
	check(act("acquire_radio", {"radio_role": "past"}, "intruder").reason == "invalid_role", "Reject unknown actors")
	check(manager.get_revision(Rules.ID) == 0, "Rejections create no revisions")
	check(act("acquire_radio", {"radio_role": "past"}).status == Status.CHANGED, "Student acquires radio")
	check(manager.get_state(Rules.ID).student_radio and not manager.get_state(Rules.ID).professor_radio, "Ownership is per role")
	check(act("acquire_radio", {"radio_role": "past"}).status == Status.NO_CHANGE, "Duplicate acquisition is idempotent")
	check(manager.get_revision(Rules.ID) == 1, "One pickup, one revision")
	for invalid in [null, "67", 67.0, true, [], {}, "67.0"]:
		check(act("tune_frequency", {"frequency": invalid}).reason == "invalid_frequency", "Reject frequency type %s" % str(invalid))
	for invalid in [-1, 0, 1000, 999999]:
		check(act("tune_frequency", {"frequency": invalid}).reason == "frequency_out_of_range", "Reject out-of-range frequency")
	check(act("tune_frequency", {}).reason == "invalid_frequency", "Frequency is required")
	check(act("tune_frequency", {"frequency": 67, "solved": true}).reason == "invalid_frequency", "No extra authoritative payload fields")
	check(act("tune_frequency", {"frequency": 67}, "future").reason == "role_not_allowed", "Future cannot tune")
	for wrong in [1, 66, 68, 999]:
		var result := act("tune_frequency", {"frequency": wrong})
		check(result.status == Status.NO_CHANGE and result.message == "SIGNAL NOT FOUND", "Wrong frequency is normal retry feedback")
	check(manager.get_revision(Rules.ID) == 1 and completions == 0, "Bad attempts never mutate or complete")
	check(act("tune_frequency", {"frequency": 67}).status == Status.CHANGED, "Calibration can wait for the second radio")
	check(manager.get_state(Rules.ID).frequency_calibrated and not manager.is_solved(Rules.ID), "Missing Professor radio prevents connection")
	check(act("acquire_radio", {"radio_role": "future"}, "future").status == Status.COMPLETED, "Final radio establishes connection")
	check(manager.is_solved(Rules.ID) and Rules.link_established(manager.get_state(Rules.ID)), "Connection is derived from every prerequisite")
	check(completions == 1 and manager.get_revision(Rules.ID) == 3, "One completion and three authoritative transitions")
	check(act("tune_frequency", {"frequency": 67}).status == Status.NO_CHANGE, "Repeated tuning does not complete again")
	check(act("tune_frequency", {"frequency": 80}).status == Status.NO_CHANGE, "Locked calibration cannot be undone by wrong tuning")
	check(act("acquire_radio", {"radio_role": "future"}, "future").status == Status.NO_CHANGE, "Repeated completed pickup is a no-op")
	check(completions == 1 and manager.get_revision(Rules.ID) == 3, "Repeats produce no extra revisions or events")
	var copy: Dictionary = manager.get_state(Rules.ID)
	copy.student_radio = false
	check(manager.get_state(Rules.ID).student_radio, "Caller cannot mutate ownership by changing a returned copy")
	var session: int = manager.get_session_id()
	check(manager.unregister_puzzle(Rules.ID), "Room may detach rules")
	check(manager.get_state(Rules.ID).frequency_calibrated, "Room unload keeps calibration")
	check(manager.register_puzzle(Rules.ID, Rules.new()) == OK, "Another room registers rules")
	check(manager.is_solved(Rules.ID) and manager.get_session_id() == session, "Another room keeps the connection and session")
	check(manager.reset_puzzle(Rules.ID), "Host/offline may explicitly reset")
	check(manager.get_state(Rules.ID) == INITIAL, "Reset clears both radios and calibration")
	act("acquire_radio", {"radio_role": "past"})
	act("acquire_radio", {"radio_role": "future"}, "future")
	check(not manager.is_solved(Rules.ID), "Two radios alone do not connect")
	check(act("tune_frequency", {"frequency": 67}).status == Status.COMPLETED, "Normal pickup then calibration order works")
	check(completions == 2, "Reset permits exactly one new completion")
	manager.begin_session()
	check(manager.get_session_id() != session and manager.get_state(Rules.ID) == INITIAL, "New session resets all radio progress")
	check(completions == 2, "Session snapshots never replay completion")
	# A target belongs to puzzle configuration, never to PuzzleManager or replicated state.
	var alternate := Rules.new()
	alternate.target_frequency = 81
	manager.register_puzzle("alternate_frequency", alternate)
	manager.submit_action("alternate_frequency", "acquire_radio", {"radio_role": "past"}, "past")
	check(manager.submit_action("alternate_frequency", "tune_frequency", {"frequency": 67}, "past").status == Status.NO_CHANGE, "Default is not hardcoded in the manager")
	check(manager.submit_action("alternate_frequency", "tune_frequency", {"frequency": 81}, "past").status == Status.CHANGED, "Configurable target is honored")
	check(manager.get_state("alternate_frequency").size() == 3, "Answer and derived connection are not redundant replicated state")
	print("FREQUENCY RULES: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
