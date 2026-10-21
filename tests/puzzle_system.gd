extends SceneTree
## Run: godot --headless --path . --script res://tests/puzzle_system.gd
## Offline checks of PuzzleManager and puzzle logic. Real RPC traffic between two processes is
## covered by tests/run_puzzle_tests.py.

# Autoload names do not exist yet while a --script file's preloads compile, so the manager and
# listener (which use NetworkManager / PuzzleManager) are loaded at runtime instead.
const PowerSwitch := preload("res://scripts/puzzles/implementations/power_switch_puzzle.gd")
const Fixtures := preload("res://tests/puzzle_fixtures.gd")
const Probe := Fixtures.Probe
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
const CAUSE_RESET := 1
const CAUSE_INITIAL := 2

var failures: int = 0
var checks: int = 0


## A world object that shows one puzzle differently per timeline, driven only by the listener.
class View extends Node:
	var puzzle_id: String
	var timeline: String
	var applied: Array = []
	var support_visible: bool = false  # what the Past player sees
	var bridge_visible: bool = false   # what the Future player sees

	func _init(id: String, view_timeline: String) -> void:
		puzzle_id = id
		timeline = view_timeline

	func _ready() -> void:
		var listener: Node = load("res://scripts/puzzles/puzzle_listener.gd").new()
		listener.puzzle_id = puzzle_id
		listener.state_applied.connect(_on_state_applied)
		add_child(listener)

	func _on_state_applied(state: Dictionary, _solved: bool) -> void:
		applied.append(state)
		if timeline == "past":
			support_visible = state.support_repaired
		else:
			bridge_visible = state.bridge_accessible


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


## A private manager so each test starts from a clean slate. It begins an offline session on entering the tree.
func fresh() -> Node:
	var manager: Node = load("res://scripts/puzzles/puzzle_manager.gd").new()
	manager.log_rejections = false
	root.add_child(manager)
	return manager


## Register puzzles, then start a clean session so every state sits at revision 0.
func setup(manager: Node, puzzles: Dictionary) -> void:
	for id in puzzles:
		manager.register_puzzle(id, puzzles[id])
	manager.begin_session()


func relay(host: Node, replica: Node, puzzle_id: String) -> bool:
	return replica._receive_update(host.get_session_id(), puzzle_id, host.get_state(puzzle_id), host.is_solved(puzzle_id), host.get_revision(puzzle_id), 0)


func _run() -> void:
	test_autoload_is_registered()
	test_registration()
	test_initial_state_and_copies()
	test_validation_and_authorization()
	test_secrets_payloads_and_prerequisites()
	test_completion_and_signals()
	test_temporal_causality_rules()
	test_misbehaving_puzzle_is_contained()
	test_reset()
	test_independent_puzzles()
	test_session_lifecycle()
	test_replica_sync()
	test_offline_local_actions()
	await test_presentation_views()
	await test_menu_starts_fresh_solo_session()
	print("PUZZLE SYSTEM: ", "PASS" if failures == 0 else "FAIL", " (", checks, " checks, ", failures, " failures)")
	quit(0 if failures == 0 else 1)


func test_autoload_is_registered() -> void:
	var autoload := root.get_node_or_null("PuzzleManager")
	check(autoload != null, "PuzzleManager must be an autoload")
	if autoload == null:
		return
	check(autoload.get_script().resource_path == "res://scripts/puzzles/puzzle_manager.gd", "The autoload must run puzzle_manager.gd")
	check(autoload.is_authority() and autoload.is_session_active(), "Without a network session the manager must act as its own authority")
	check(autoload.get_local_role() == "past", "Offline play defaults to the Past role")


func test_registration() -> void:
	var manager := fresh()
	var power := PowerSwitch.new()
	check(manager.register_puzzle("power", power) == OK, "Registration must succeed")
	check(manager.is_registered("power") and power.puzzle_id == "power", "Registered puzzles must know their ID")
	check(manager.get_puzzle_ids() == PackedStringArray(["power"]), "Registered IDs must be listed")
	check(manager.register_puzzle("power", power) == OK, "Registering the same instance twice must be a harmless no-op")
	var duplicate := PowerSwitch.new()
	check(manager.register_puzzle("power", duplicate) == ERR_ALREADY_EXISTS, "A different instance under a taken ID must be refused")
	check(duplicate.puzzle_id.is_empty() and power.puzzle_id == "power", "A refused duplicate must not disturb the original")
	check(manager.register_puzzle("power", duplicate, true) == OK, "replace = true must swap the logic")
	check(duplicate.puzzle_id == "power" and power.puzzle_id.is_empty(), "Replacement must hand the ID to the new logic only")
	check(manager.register_puzzle("", PowerSwitch.new()) == ERR_INVALID_PARAMETER, "An empty ID must be refused")
	check(manager.register_puzzle("no_logic", null) == ERR_INVALID_PARAMETER, "Missing logic must be refused")
	check(manager.register_puzzle("second_id", duplicate) == ERR_ALREADY_IN_USE, "One logic instance may serve only one ID")
	check(manager.register_puzzle("puzzle_99_never_planned", PowerSwitch.new()) == OK, "Any ID must be accepted without editing the manager")
	# Room unload: rules detach, progress stays.
	manager.begin_session()
	manager.submit_action("power", "activate_power")
	check(manager.unregister_puzzle("power") and not manager.is_registered("power"), "Unregistering must detach the logic")
	check(not manager.unregister_puzzle("power"), "Unregistering twice must report false")
	check(manager.is_solved("power") and manager.get_state("power").power_on, "Progress must survive an unregistered room")
	check(manager.submit_action("power", "activate_power").reason == "unknown_puzzle", "Actions need registered logic")
	manager.register_puzzle("power", PowerSwitch.new())
	check(manager.is_solved("power"), "Re-entering the room must pick the progress back up")


func test_initial_state_and_copies() -> void:
	var manager := fresh()
	var misbehaving := Fixtures.MisbehavingPuzzle.new()
	setup(manager, {"power": PowerSwitch.new(), "mis": misbehaving})
	check(manager.get_state("power") == {"solved": false, "power_on": false}, "Initial state must come from the puzzle")
	check(manager.get_revision("power") == 0 and not manager.is_solved("power"), "A new puzzle starts unsolved at revision 0")
	check(manager.get_state("ghost").is_empty() and not manager.has_state("ghost"), "Unknown puzzles have no state")
	var copy: Dictionary = manager.get_state("power")
	copy.power_on = true
	copy["injected"] = 1
	check(manager.get_state("power") == {"solved": false, "power_on": false}, "get_state must return a private copy")
	var nested: Dictionary = manager.get_state("mis")
	nested.list.append(99)
	check(manager.get_state("mis").list == [1, 2], "Nested arrays must be copied too")
	check(misbehaving.shared_state.list == [1, 2], "The manager must not edit a dictionary the puzzle keeps")
	var probe := Probe.new(manager)
	manager.submit_action("power", "activate_power")
	probe.changed[0][1].power_on = false
	check(manager.get_state("power").power_on, "Editing a signal's state must not touch canonical state")


func test_validation_and_authorization() -> void:
	var manager := fresh()
	setup(manager, {"power": PowerSwitch.new(), "bridge": Fixtures.BridgePuzzle.new()})
	var probe := Probe.new(manager)
	var result: Dictionary = manager.submit_action("power", "activate_power", {}, "future")
	check(result.status == Status.REJECTED and result.reason == "role_not_allowed", "The Future role must not throw the Past's switch")
	check(not manager.is_solved("power") and manager.get_revision("power") == 0, "A rejected action must change nothing")
	check(probe.rejected == [["power", "activate_power", "role_not_allowed", "future"]], "Rejections must be announced with their cause")
	result = manager.submit_action("power", "activate_power", {"solved": true, "power_on": true, "actor_role": "past"}, "future")
	check(result.status == Status.REJECTED and not manager.is_solved("power"), "Forged payload fields must not bypass the rules")
	result = manager.submit_action("bridge", "repair_support", {"solved": true, "crossed": true}, "past")
	check(result.status == Status.CHANGED and manager.get_state("bridge").crossed == false, "Payload keys must never become state")
	check(manager.submit_action("power", "explode").reason == "unknown_action", "Unknown actions must be rejected")
	check(manager.submit_action("ghost", "activate_power").reason == "unknown_puzzle", "Unknown puzzles must be rejected")
	check(manager.submit_action("power", "activate_power", {}, "admin").reason == "invalid_role", "Unknown roles must be rejected")
	check(manager._run_action("power", "activate_power", [1, 2], "past").reason == "invalid_payload", "Non-dictionary payloads must be rejected")
	# Actions before a session exists.
	manager._end_session()
	check(manager.submit_action("power", "activate_power").reason == "no_session", "Actions before initialization must be rejected")
	manager.begin_session()
	check(manager.submit_action("power", "activate_power").status == Status.COMPLETED, "Actions must work once a session begins")


func test_secrets_payloads_and_prerequisites() -> void:
	var manager := fresh()
	setup(manager, {
		"bridge": Fixtures.BridgePuzzle.new(),
		"vault": Fixtures.VaultPuzzle.new(4821, PackedStringArray(["bridge"])),
	})
	var result: Dictionary = manager.submit_action("vault", "enter_code", {"code": 4821}, "future")
	check(result.reason == "prerequisite_not_met" and result.message == "bridge" and not manager.is_solved("vault"), "A puzzle must wait for its prerequisites")
	manager.submit_action("bridge", "repair_support", {}, "past")
	manager.submit_action("bridge", "cross_bridge", {}, "future")
	for bad in [{}, {"code": "4821"}, {"code": 4821.0}, {"code": null}]:
		check(manager.submit_action("vault", "enter_code", bad, "future").reason == "invalid_payload", "Malformed codes must be rejected: " + str(bad))
	result = manager.submit_action("vault", "enter_code", {"code": 1111}, "future")
	check(result.status == Status.CHANGED and manager.get_state("vault") == {"attempts": 1, "unlocked": false}, "A wrong code is a valid action that counts an attempt")
	check(not JSON.stringify(manager.get_state("vault")).contains("4821"), "The hidden answer must not appear in replicated state")
	result = manager.submit_action("vault", "enter_code", {"code": 4821}, "past")
	check(result.status == Status.COMPLETED and manager.is_solved("vault"), "The right code must solve the puzzle for either role")


func test_completion_and_signals() -> void:
	var manager := fresh()
	setup(manager, {"power": PowerSwitch.new()})
	var probe := Probe.new(manager)
	var result: Dictionary = manager.submit_action("power", "activate_power")
	check(result.status == Status.COMPLETED and result.revision == 1, "The solving action must report completion and its revision")
	check(manager.get_state("power") == {"solved": true, "power_on": true} and manager.is_solved("power"), "A valid Past action must switch the power on")
	check(probe.changed.size() == 1 and probe.changed[0][0] == "power" and probe.changed[0][2] == 1, "One accepted action must produce exactly one state signal")
	check(probe.completed == ["power"], "Completion must be announced once")
	result = manager.submit_action("power", "activate_power")
	check(result.status == Status.NO_CHANGE, "Repeating the action must be valid but change nothing")
	check(probe.changed.size() == 1 and probe.completed.size() == 1 and manager.get_revision("power") == 1, "Repeats must not duplicate signals or revisions")


func test_temporal_causality_rules() -> void:
	var manager := fresh()
	setup(manager, {"bridge": Fixtures.BridgePuzzle.new()})
	var probe := Probe.new(manager)
	check(manager.submit_action("bridge", "cross_bridge", {}, "future").reason == "bridge_not_accessible", "The Future cannot cross before the Past repairs the support")
	check(manager.submit_action("bridge", "repair_support", {}, "future").reason == "role_not_allowed", "Only the Past can repair the support")
	var result: Dictionary = manager.submit_action("bridge", "repair_support", {}, "past")
	check(result.status == Status.CHANGED, "Repairing the support changes state without completing the puzzle")
	var state: Dictionary = manager.get_state("bridge")
	check(state.support_repaired and state.bridge_accessible and manager.get_revision("bridge") == 1, "One transition must publish every linked change under one revision")
	check(probe.completed.is_empty(), "A partial step must not announce completion")
	check(manager.submit_action("bridge", "repair_support", {}, "past").status == Status.NO_CHANGE, "Repairing twice must change nothing")
	check(manager.submit_action("bridge", "cross_bridge", {}, "future").status == Status.COMPLETED, "The Future can cross once the Past has acted")
	check(manager.submit_action("bridge", "cross_bridge", {}, "future").status == Status.NO_CHANGE, "A change() that alters nothing must count as no change")
	check(probe.completed == ["bridge"], "Two roles cooperating must complete the puzzle exactly once")


func test_misbehaving_puzzle_is_contained() -> void:
	var manager := fresh()
	var misbehaving := Fixtures.MisbehavingPuzzle.new()
	setup(manager, {"mis": misbehaving})
	var probe := Probe.new(manager)
	check(manager.submit_action("mis", "no_state").reason == "invalid_result", "A change without a state must be rejected")
	check(manager.submit_action("mis", "unknown_status").reason == "invalid_result", "An unknown result status must be rejected")
	check(manager.submit_action("mis", "same_state").status == Status.NO_CHANGE, "Returning the old state must count as no change")
	check(manager.submit_action("mis", "mutate_then_decline").status == Status.NO_CHANGE, "A puzzle that declines must not leak edits")
	check(manager.get_state("mis") == {"list": [1, 2], "solved": false} and not manager.is_solved("mis"), "Edits to the working copy must never reach canonical state")
	check(manager.get_revision("mis") == 0 and probe.changed.is_empty(), "None of that may produce a revision or a signal")


func test_reset() -> void:
	var manager := fresh()
	setup(manager, {"power": PowerSwitch.new(), "bridge": Fixtures.BridgePuzzle.new()})
	var probe := Probe.new(manager)
	manager.submit_action("power", "activate_power")
	manager.submit_action("bridge", "repair_support", {}, "past")
	var solved_revision: int = manager.get_revision("power")
	check(manager.reset_puzzle("power"), "Resetting a registered puzzle must succeed")
	check(manager.get_state("power") == {"solved": false, "power_on": false} and not manager.is_solved("power"), "Reset must restore the initial state")
	check(manager.get_revision("power") > solved_revision, "Reset is a confirmed change and needs a newer revision")
	check(probe.resets == ["power"] and manager.get_state("bridge").support_repaired, "Resetting one puzzle must leave the others alone")
	manager.submit_action("power", "activate_power")
	check(probe.completed == ["power", "power"], "Solving again after a reset is a new completion")
	check(not manager.reset_puzzle("ghost"), "Resetting an unknown puzzle must report false")
	probe.resets.clear()
	var before: int = manager.get_latest_revision()
	check(manager.reset_all(), "reset_all must succeed")
	check(not manager.is_solved("power") and not manager.get_state("bridge").support_repaired, "reset_all must restore every puzzle")
	check(manager.get_revision("power") == manager.get_revision("bridge") and manager.get_revision("power") > before, "reset_all publishes everything under one new revision")
	check(probe.resets.size() == 2 and "power" in probe.resets and "bridge" in probe.resets, "Each puzzle must announce its reset")
	manager.unregister_puzzle("bridge")
	manager.reset_all()
	check(not manager.has_state("bridge"), "reset_all must drop state that no registered puzzle can recreate")


func test_independent_puzzles() -> void:
	var manager := fresh()
	setup(manager, {
		"power": PowerSwitch.new(),
		"bridge": Fixtures.BridgePuzzle.new(),
		"vault": Fixtures.VaultPuzzle.new(7),
	})
	manager.submit_action("power", "activate_power")
	check(manager.is_solved("power") and not manager.is_solved("bridge") and not manager.is_solved("vault"), "Solving one puzzle must not solve others")
	var power_revision: int = manager.get_revision("power")
	manager.submit_action("vault", "enter_code", {"code": 1}, "past")
	check(manager.get_revision("power") == power_revision and manager.get_revision("vault") > power_revision, "Each puzzle keeps its own revision")
	check(manager.get_state("bridge") == {"support_repaired": false, "bridge_accessible": false, "crossed": false}, "Puzzles must not share state keys")
	check(manager.get_state("vault") == {"attempts": 1, "unlocked": false}, "Different puzzles may have completely different state shapes")


func test_session_lifecycle() -> void:
	var manager := fresh()
	setup(manager, {"power": PowerSwitch.new()})
	var probe := Probe.new(manager)
	var first_session: int = manager.get_session_id()
	check(first_session != 0 and manager.is_session_active(), "A session must be running")
	manager.submit_action("power", "activate_power")
	manager.begin_session()
	check(manager.get_session_id() != first_session, "A new session needs a new ID")
	check(not manager.is_solved("power") and manager.get_revision("power") == 0 and manager.get_latest_revision() == 0, "A new session must start from initial state and revision 0")
	check(probe.started == 1 and probe.changed.size() == 2, "World objects must be told to re-apply state when a session begins")
	manager._end_session()
	check(not manager.is_session_active() and manager.get_session_id() == 0 and not manager.has_state("power"), "Ending a session must drop its state")
	check(probe.ended == 1, "Ending a session must be announced")
	check(not manager.reset_puzzle("power") and not manager.reset_all(), "Nothing can be reset without a session")
	check(manager.submit_action("power", "activate_power").reason == "no_session", "Actions must be refused between sessions")
	manager.begin_session()
	check(manager.submit_action("power", "activate_power").status == Status.COMPLETED, "A fresh session must accept actions again")


## The client side without a network: feed a second manager only what the host confirmed.
func test_replica_sync() -> void:
	var host := fresh()
	setup(host, {"power": PowerSwitch.new(), "bridge": Fixtures.BridgePuzzle.new()})
	var replica := fresh()
	var probe := Probe.new(replica)
	host.submit_action("bridge", "repair_support", {}, "past")
	var session: int = host.get_session_id()
	check(replica._receive_snapshot(session, host.get_latest_revision(), host._snapshot(), CAUSE_INITIAL), "A snapshot must be accepted")
	check(replica.is_session_active() and replica.get_session_id() == session, "A snapshot must start the client's session")
	check(replica.get_state("bridge") == host.get_state("bridge") and replica.get_state("power") == host.get_state("power"), "A snapshot must restore every puzzle")
	check(probe.started == 1 and probe.changed.size() == 2 and probe.completed.is_empty(), "A snapshot restores state without replaying completions")
	host.submit_action("power", "activate_power")
	check(relay(host, replica, "power"), "A newer revision must be applied")
	check(replica.is_solved("power") and probe.completed == ["power"], "The client must announce the completion once")
	check(replica.get_revision("power") == host.get_revision("power"), "The client must record the host's revision")
	var revision: int = host.get_revision("power")
	var stale := {"solved": false, "power_on": false}
	check(not replica._receive_update(session, "power", stale, false, revision, 0), "A duplicate revision must be ignored")
	check(not replica._receive_update(session, "power", stale, false, revision - 1, 0), "An older revision must be ignored")
	check(replica.is_solved("power") and probe.changed.size() == 3 and probe.completed.size() == 1, "Stale updates must change and announce nothing")
	check(not replica._receive_update(session + 1, "power", stale, false, revision + 10, 0), "An update from another session must be ignored")
	check(replica._receive_update(session, "power", stale, false, revision + 1, CAUSE_RESET), "A newer revision must win, even when it undoes progress")
	check(not replica.is_solved("power") and probe.resets == ["power"], "A confirmed reset must reach the client")
	check(not replica._receive_snapshot(session, revision - 5, host._snapshot(), CAUSE_INITIAL) and not replica.is_solved("power"), "A snapshot older than the client's state must be ignored")
	# Host restarts the session: the client must follow, and the old session must be dead to it.
	host.begin_session()
	var new_session: int = host.get_session_id()
	check(replica._receive_snapshot(new_session, 0, host._snapshot(), CAUSE_INITIAL), "A new session's snapshot must win even with a lower revision")
	check(replica.get_session_id() == new_session and replica.get_latest_revision() == 0 and probe.started == 2, "The client must adopt the new session")
	check(not replica._receive_update(session, "power", {"solved": true, "power_on": true}, true, 99, 0), "Updates from a finished session must not reach the new one")
	check(not replica.is_solved("power") and not replica.get_state("bridge").support_repaired, "The new session's state must be untouched by the old one")
	# Remote entry points refuse callers they cannot identify (no real peer behind these direct calls).
	host._rpc_request_action(host.get_session_id(), "power", "activate_power", {})
	check(not host.is_solved("power"), "A request without a verified remote peer must be ignored")
	replica._rpc_apply_update(new_session, "power", {"solved": true, "power_on": true}, true, 99, 0)
	replica._rpc_apply_snapshot(new_session, 99, {"power": {"state": {"solved": true}, "solved": true, "revision": 99}}, 0)
	check(not replica.is_solved("power"), "Only the host's connection may deliver state")


func test_offline_local_actions() -> void:
	var manager := fresh()
	setup(manager, {"power": PowerSwitch.new(), "bridge": Fixtures.BridgePuzzle.new()})
	check(manager.is_authority() and manager.get_local_role() == "past", "Offline play is its own authority as the Past")
	manager.offline_role = "future"
	check(manager.get_local_role() == "future", "Solo preview can switch the local timeline")
	check(manager.submit_action("power", "activate_power").reason == "role_not_allowed", "The offline role must drive local authorization")
	manager.offline_role = "past"
	# Split-screen: two local players share one state; the input router names the acting role per call.
	check(manager.submit_action("bridge", "repair_support", {}, "past").status == Status.CHANGED, "Local Past player acts")
	check(manager.submit_action("bridge", "cross_bridge", {}, "future").status == Status.COMPLETED, "Local Future player acts on the same state")
	check(manager.submit_action("bridge", "cross_bridge", {}, "nonsense").reason == "invalid_role", "A local caller still cannot invent a role")
	check(manager.submit_action("power", "activate_power").status == Status.COMPLETED, "Offline actions must complete without any network")


func test_presentation_views() -> void:
	var manager: Node = root.get_node("PuzzleManager")
	manager.log_rejections = false
	manager.register_puzzle("bridge_view_test", Fixtures.BridgePuzzle.new())
	manager.begin_session()
	var past_view := View.new("bridge_view_test", "past")
	var future_view := View.new("bridge_view_test", "future")
	root.add_child(past_view)
	root.add_child(future_view)
	check(past_view.applied.size() == 1 and future_view.applied.size() == 1, "Views must apply the current state as they enter the scene")
	check(not past_view.support_visible and not future_view.bridge_visible, "Nothing is repaired yet")
	manager.submit_action("bridge_view_test", "repair_support", {}, "past")
	check(past_view.support_visible and not past_view.bridge_visible, "The Past shows the repaired support")
	check(future_view.bridge_visible and not future_view.support_visible, "The Future shows the rebuilt bridge")
	check(past_view.applied.back() == future_view.applied.back() and manager.get_state("bridge_view_test") == past_view.applied.back(), "Both timelines must derive from one canonical state")
	var late_view := View.new("bridge_view_test", "future")
	root.add_child(late_view)
	check(late_view.bridge_visible, "A room entered later must show the current state without waiting for a signal")
	past_view.queue_free()
	await process_frame
	var applied_before := future_view.applied.size()
	manager.submit_action("bridge_view_test", "cross_bridge", {}, "future")
	check(future_view.applied.size() == applied_before + 1, "Updates must still reach views after another view unloads")
	check(manager.is_solved("bridge_view_test"), "Puzzle progress must not depend on any view existing")
	var ghost_view := View.new("never_registered", "past")
	root.add_child(ghost_view)
	check(ghost_view.applied.is_empty(), "A view for an unknown puzzle must wait quietly")
	for view in [future_view, late_view, ghost_view]:
		view.queue_free()
	manager.unregister_puzzle("bridge_view_test")


func test_menu_starts_fresh_solo_session() -> void:
	var manager: Node = root.get_node("PuzzleManager")
	manager.register_puzzle("menu_test_power", PowerSwitch.new())
	manager.submit_action("menu_test_power", "activate_power")
	check(manager.is_solved("menu_test_power"), "Test setup: puzzle should be solved")
	var session: int = manager.get_session_id()
	var menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.settings_path = OS.get_temp_dir().path_join("past-future-puzzle-test-%d.cfg" % OS.get_process_id())
	root.add_child(menu)
	current_scene = menu
	menu._preview_spawn_area()
	check(manager.get_session_id() != session and not manager.is_solved("menu_test_power"), "Starting a solo preview must start a fresh puzzle session")
	await create_timer(0.5).timeout
	check(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/world/spawn_area.tscn", "The laboratory must still open from the menu")
	manager.unregister_puzzle("menu_test_power")
	# The menu now launches an audio-enabled playable lab. End that owned session
	# through its normal lifecycle instead of quitting with live ambience.
	current_scene._return_to_menu()
	await scene_changed
	await create_timer(0.15).timeout
