extends SceneTree
## Run through run_game_flow_tests.py: two real ENet peers in separate processes drive the level-flow
## system through the existing lobby, the existing PuzzleManager and the real exit interactables.
## Arguments after "--": <host|client> <port> <full|host_leaves>
##
## The peers keep step with each other through two "report" puzzles registered on both sides: each
## peer publishes a step number plus a few facts (room, transition ID, session, revision) as an
## ordinary confirmed puzzle action, and the other peer waits for it and compares. Nothing here adds
## an RPC to the game; the forged-RPC checks call the manager's real RPCs from the wrong side.

const RoomDef := preload("res://scripts/game_flow/room_definition.gd")
const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const FREQ := "puzzle_01_frequency"
const TEST_ROOMS := "res://resources/levels/test"
const ROOM_A_SCENE := "res://scenes/testing/transition_room_a.tscn"
const ROOM_B_SCENE := "res://scenes/testing/transition_room_b.tscn"
const ROOM_B_FUTURE_SCENE := "res://scenes/testing/transition_room_b_future.tscn"
const GENERATED_DIRECTORY := "res://.game_flow_test"


## Carries one peer's progress to the other as a normal confirmed puzzle action.
class ReportPuzzle extends "res://scripts/puzzles/puzzle_base.gd":
	var author: String

	func _init(who: String) -> void:
		author = who

	func get_initial_state() -> Dictionary:
		return {"step": 0, "reports": {}}

	func get_actions() -> Dictionary:
		return {"report": [author]}

	func validate_action(action: String, payload: Dictionary, actor_role: String, state: Dictionary) -> String:
		var reason := super(action, payload, actor_role, state)
		if reason.is_empty() and (payload.get("step") != state.step + 1 or not payload.get("data") is Dictionary):
			return "invalid_payload"
		return reason

	func apply_action(_action: String, payload: Dictionary, _actor_role: String, state: Dictionary) -> Dictionary:
		state.step += 1
		state.reports[state.step] = payload.data
		return change(state)


var role: String = ""
var port: int = 0
var scenario: String = "full"
var flow: Node
var puzzles: Node
var network: Node
var checks: int = 0
var failures: int = 0
var step: int = 0
var own_channel: String = ""
var partner_channel: String = ""
var session: int = 0
var peer_object_id: int = 0
var started: Array = []    # [from, to, transition ID]
var completed: Array = []  # room ID
var failed: Array = []     # reason
var rejected: Array = []   # [destination, reason]
var room_events: Array = []  # [room ID, screen black, input locked, controls enabled]
var requested: Array = []  # [from, to]
var link_completions: int = 0
var sessions_started: int = 0
var broken_scene: String = ""
## Set by run_game_flow_render.py: peers run with a real renderer and save what each player sees.
var shots_directory: String = ""


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED [%s]: %s" % [role, message])


func wait_for(predicate: Callable, message: String, seconds: float = 20.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message + " | phase=%d readiness=%s started=%d failed=%s state=%d in_game=%s" % [flow.get_phase(), str(flow.get_readiness()), started.size(), str(failed), network.state, network.in_game])
			return false
		await process_frame
	return true


func tick(frames: int = 4) -> void:
	for i in range(frames):
		await physics_frame
	await process_frame


func pause(seconds: float) -> void:
	await create_timer(seconds).timeout


func is_host() -> bool:
	return role == "host"


func shot(label: String) -> void:
	if shots_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots_directory.path_join("%s_%s.png" % [role, label]))


## Report this peer's facts and wait for the partner's report of the same step.
func barrier(data: Dictionary = {}) -> Dictionary:
	step += 1
	var my_step := step
	puzzles.submit_action(own_channel, "report", {"step": my_step, "data": data})
	if not await wait_for(func() -> bool: return puzzles.get_state(partner_channel).get("step", 0) >= my_step, "The partner never reached barrier %d" % my_step, 40.0):
		return {"timeout": true}
	return puzzles.get_state(partner_channel).reports.get(my_step, {})


func room_scene() -> Node:
	return current_scene


func count_nodes(type_name: String) -> int:
	return current_scene.find_children("*", type_name, true, false).size()


func verify_room(room_id: String, scene_path: String, label: String) -> void:
	check(flow.get_current_room_id() == room_id, "%s: current room is %s, got '%s'" % [label, room_id, flow.get_current_room_id()])
	check(current_scene.scene_file_path == scene_path, "%s: scene is %s, got %s" % [label, scene_path, current_scene.scene_file_path])
	check(not flow.is_transitioning() and not flow.is_input_locked() and not flow.overlay.is_covering(), "%s: nothing is locked, transitioning or black" % label)
	check(current_scene.player.controls_enabled, "%s: the player can move" % label)
	var expected_body := "student_3d_player.tscn" if is_host() else "professor_3d_player.tscn"
	check(current_scene.player.scene_file_path.ends_with(expected_body), "%s: this peer plays its own timeline's character" % label)
	check(count_nodes("CharacterBody3D") == 1 and count_nodes("TemporalRadio") == 1 and count_nodes("InteractionController") == 1, "%s: one character, one radio, one controller" % label)
	check(current_scene.find_children("StatusHUD", "CanvasLayer", true, false).size() == 1 and root.get_child_count() == 5, "%s: one HUD and no stray scenes" % label)
	check(network.in_game and network.state == network.State.CONNECTED and get_multiplayer().multiplayer_peer.get_instance_id() == peer_object_id, "%s: the same ENet connection is still in the game" % label)
	check(puzzles.get_session_id() == session and sessions_started == 1, "%s: still the same puzzle session, never restarted" % label)


func record() -> void:
	flow.transition_requested.connect(func(from: String, to: String) -> void: requested.append([from, to]))
	flow.transition_started.connect(func(from: String, to: String) -> void: started.append([from, to, flow.get_transition_id()]))
	flow.transition_completed.connect(func(id: String) -> void: completed.append(id))
	flow.transition_failed.connect(func(reason: String) -> void: failed.append(reason))
	flow.request_rejected.connect(func(destination: String, reason: String, _message: String) -> void: rejected.append([destination, reason]))
	flow.room_changed.connect(func(id: String) -> void:
		var controls: Variant = current_scene.player.controls_enabled if current_scene != null and current_scene.get("player") != null else null
		room_events.append([id, flow.overlay.is_fully_black(), flow.is_input_locked(), controls]))
	puzzles.puzzle_completed.connect(func(id: String) -> void:
		if id == FREQ:
			link_completions += 1)
	puzzles.session_started.connect(func() -> void: sessions_started += 1)


func write_broken_scene() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_DIRECTORY))
	broken_scene = "%s/broken_%s.tscn" % [GENERATED_DIRECTORY, role]
	var file := FileAccess.open(broken_scene, FileAccess.WRITE)
	file.store_string("[gd_scene format=3]\n\n[node name=\"Broken\" type=\"Node3D\"]\nposition = Vector3(1, 2\n")
	file.close()


func remove_broken_scene() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(broken_scene))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GENERATED_DIRECTORY))  # fails harmlessly while the other peer still uses it


func make_room(room_id: String, past_scene: String, future_scene: String) -> RoomDef:
	var definition := RoomDef.new()
	definition.room_id = room_id
	definition.past_scene = past_scene
	definition.future_scene = future_scene
	return definition


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	role = arguments[0]
	port = int(arguments[1])
	scenario = arguments[2] if arguments.size() > 2 else "full"
	flow = root.get_node("GameFlowManager")
	puzzles = root.get_node("PuzzleManager")
	network = root.get_node("NetworkManager")
	shots_directory = OS.get_environment("FLOW_SHOTS_DIR")
	if not shots_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(shots_directory)
	puzzles.log_rejections = false
	flow.log_problems = false
	flow.fade_out_seconds = 0.05
	flow.fade_in_seconds = 0.05
	own_channel = "host_report" if is_host() else "client_report"
	partner_channel = "client_report" if is_host() else "host_report"
	puzzles.register_puzzle("host_report", ReportPuzzle.new("past"))
	puzzles.register_puzzle("client_report", ReportPuzzle.new("future"))
	record()
	write_broken_scene()
	if is_host():
		await run_host()
	else:
		await run_client()
	if current_scene != null:
		current_scene.free()
	remove_broken_scene()
	network.leave_game()
	await pause(0.2)
	print("FLOW %s %s: %s (%d checks)" % [role, scenario, "PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func run_host() -> void:
	check(network.host_game(port) == OK, "The host binds the UDP port")
	print("FLOW_HOST_LISTENING")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "The guest never connected"):
		return
	if not await wait_for(func() -> bool: return network.guest_ready, "The guest never became ready"):
		return
	check(network.start_game(), "The host starts the game through the existing lobby")
	if scenario == "production":
		await scenario_production()
		return
	await enter_first_room()
	if scenario == "host_leaves":
		await scenario_host_leaves()
	else:
		await scenario_full()


func run_client() -> void:
	check(network.join_game("127.0.0.1", port) == OK, "The client opens a connection")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "The client never connected"):
		return
	network.set_ready(true)
	if not await wait_for(func() -> bool: return network.in_game, "The game never started for the client"):
		return
	if scenario == "production":
		await scenario_production()
		return
	await enter_first_room()
	if scenario == "host_leaves":
		await scenario_host_leaves()
	else:
		await scenario_full()


func enter_first_room() -> void:
	flow.load_room_directory(TEST_ROOMS)
	check(flow.start_room("test_room_a"), "Both peers enter Test Room A")
	if not await wait_for(func() -> bool: return puzzles.is_session_active(), "The puzzle session never became active"):
		return
	session = puzzles.get_session_id()
	peer_object_id = get_multiplayer().multiplayer_peer.get_instance_id()
	await tick(6)
	room_events.clear()


func establish_link() -> bool:
	current_scene.dev_establish_link()
	return await wait_for(func() -> bool: return current_scene.radio.can_receive(), "The radio link never came up")


# --- The full scenario ---------------------------------------------------------------------

func scenario_full() -> void:
	var timeline := "past" if is_host() else "future"
	var expected_state := {"student_radio": true, "professor_radio": true, "frequency_calibrated": true}

	# 1. Both players start in Room A with their own timeline; invalid and forged requests go nowhere.
	var partner := await barrier({"session": session})
	check(partner.get("session") == session, "Both peers share one session ID")
	verify_room("test_room_a", ROOM_A_SCENE, "start")
	check(current_scene.role == timeline, "Each peer keeps its authenticated timeline")
	var marker: Marker3D = current_scene.get_node("Spawns/%s_entry" % timeline)
	check(current_scene.player.global_position.is_equal_approx(marker.global_position) and absf(current_scene.player.global_position.y) < 0.001, "The character spawns at its timeline's entry with its root at Y = 0")
	if is_host():
		partner = await barrier()
		check(flow.get_phase() == flow.Phase.IDLE and flow.get_readiness().destination == "" and started.is_empty() and failed.is_empty(), "The host ignored every forged or invalid message from the client")
		check(not puzzles.is_solved(FREQ) and puzzles.get_session_id() == session, "Nothing changed on the host")
	else:
		check(flow.request_transition("test_room_b") == "puzzle_incomplete", "The client is told the exit is locked")
		flow._rpc_set_ready.rpc_id(1, session, "test_room_b", true)
		flow._rpc_set_ready.rpc_id(1, session, "no_such_room", true)
		flow._rpc_set_ready.rpc_id(1, session, "res://scenes/testing/transition_room_b.tscn", true)
		flow._rpc_set_ready.rpc_id(1, session + 1, "test_room_b", true)
		flow._rpc_begin.rpc_id(1, session, 99, "test_room_a", "test_room_b")
		flow._rpc_commit.rpc_id(1, session, 1)
		flow._rpc_abort.rpc_id(1, session, 1, "forged")
		await wait_for(func() -> bool: return rejected.size() >= 4, "The host did not answer the client's requests")
		await pause(0.5)
		check(rejected == [["test_room_b", "puzzle_incomplete"], ["test_room_b", "puzzle_incomplete"], ["no_such_room", "unknown_room"], ["res://scenes/testing/transition_room_b.tscn", "unknown_room"]], "The host rejects locked, unknown and path-like rooms with a reason (and ignores a wrong session), got %s" % str(rejected))
		check(flow.get_phase() == flow.Phase.IDLE and started.is_empty(), "The client did not start anything on its own")
		check(flow.overlay.notice_panel.visible, "The client was shown why its requests were refused")
		await pause(3.8)
		check(not flow.overlay.notice_panel.visible, "The refusal notice disappears again by itself")
		partner = await barrier()
	rejected.clear()

	# 2. Establish the 67 MHz temporal link in Room A through the real puzzle actions.
	if not await establish_link():
		return
	var revision: int = puzzles.get_revision(FREQ)
	check(puzzles.get_state(FREQ) == expected_state and link_completions == 1, "The link is established exactly once")
	partner = await barrier({"revision": revision, "session": session})
	check(partner.revision == revision and partner.session == session, "Both peers hold the same link revision and session")

	# 3. Only one player is ready: nothing happens, both can see who is waiting, and it can be cancelled.
	if is_host():
		check(flow.request_transition("test_room_b") == "", "The Student marks ready")
		check(flow.get_readiness() == {"destination": "test_room_b", "past": true, "future": false}, "The host tracks that only the Student is ready")
		check(flow.overlay.is_readiness_visible(), "The host sees the readiness panel")
		await tick(3)
		await shot("ready_waiting")
		partner = await barrier()
		check(flow.get_phase() == flow.Phase.IDLE and started.is_empty(), "The transition waits for the Professor")
		flow.cancel_transition_request()
		check(flow.get_readiness().destination == "" and not flow.overlay.is_readiness_visible(), "Readiness can be cancelled before the commit")
		partner = await barrier()
	else:
		await wait_for(func() -> bool: return flow.get_readiness().destination == "test_room_b" and flow.get_readiness().past, "The Professor never saw the Student become ready")
		check(flow.get_readiness().future == false and not flow.is_local_ready("test_room_b") and flow.overlay.is_readiness_visible(), "The Professor sees the Student ready and themself waiting")
		check(requested == [["test_room_a", "test_room_b"]], "The Professor is told a departure was requested")
		await tick(3)
		await shot("ready_waiting")
		await pause(0.7)
		check(flow.get_phase() == flow.Phase.IDLE and started.is_empty(), "No transition starts while one player waits")
		partner = await barrier()
		await wait_for(func() -> bool: return flow.get_readiness().destination == "", "The cancellation never reached the Professor")
		check(not flow.overlay.is_readiness_visible(), "The Professor's panel closes")
		partner = await barrier()

	# 4. Both ready: the host authorises, both peers load their own timeline's scene, then commit.
	if is_host():
		check(flow.request_transition("test_room_b") == "", "The Student marks ready again")
		partner = await barrier()
	else:
		partner = await barrier()
		await wait_for(func() -> bool: return flow.get_readiness().past, "The Professor never saw the Student ready (step 4)")
		check(flow.request_transition("test_room_b") == "", "The Professor marks ready")
	if not await wait_for(func() -> bool: return completed.size() == 1, "The first transition never completed", 30.0):
		return
	check(started == [["test_room_a", "test_room_b", 1]], "Both peers started the same transition 1: A -> B, got %s" % str(started))
	check(failed.is_empty() and completed == ["test_room_b"], "It completed exactly once and never failed")
	check(room_events.size() == 1 and room_events[0] == ["test_room_b", true, true, false], "The new room appeared behind black with controls locked, got %s" % str(room_events))
	verify_room("test_room_b", ROOM_B_SCENE if is_host() else ROOM_B_FUTURE_SCENE, "after the first transition")
	check(puzzles.get_state(FREQ) == expected_state and puzzles.get_revision(FREQ) == revision, "The Lost Frequency state and revision are exactly as before")
	check(link_completions == 1, "The link completion was not replayed in the new room")
	check(current_scene.radio.owns_radio and current_scene.radio.can_receive(), "The re-created radio is connected in Room B")
	check(current_scene.link_label.text.contains("ESTABLISHED"), "Room B shows the link as established")
	await tick(10)
	await shot("room_b")
	var before: Vector3 = current_scene.player.global_position
	Input.action_press("move_right")
	await tick(20)
	Input.action_release("move_right")
	await tick(4)
	check(current_scene.player.global_position.x > before.x + 0.3, "The character moves after the transition")
	partner = await barrier({"room": flow.get_current_room_id(), "tid": started[0][2], "revision": puzzles.get_revision(FREQ), "session": puzzles.get_session_id()})
	check(partner.room == flow.get_current_room_id() and partner.tid == started[0][2] and partner.revision == revision and partner.session == session, "Both peers agree on room, transition ID, revision and session")

	# 5. Duplicate, stale and foreign-session messages are ignored in both directions.
	var starts := started.size()
	if is_host():
		var guest: int = network.guest_id
		flow._rpc_begin.rpc_id(guest, session, 1, "test_room_b", "test_room_a")
		flow._rpc_begin.rpc_id(guest, session + 1, 2, "test_room_b", "test_room_a")
		flow._rpc_commit.rpc_id(guest, session, 1)
		flow._rpc_abort.rpc_id(guest, session, 1, "stale")
		await pause(0.6)
		partner = await barrier()
		check(flow.get_phase() == flow.Phase.IDLE and failed.is_empty(), "The host is untouched by the client's duplicates")
	else:
		flow._rpc_loaded.rpc_id(1, session, 1)
		flow._rpc_loaded.rpc_id(1, session, 1)
		flow._rpc_loaded.rpc_id(1, session, 999)
		flow._rpc_load_failed.rpc_id(1, session, 1, "stale")
		flow._rpc_finished.rpc_id(1, session, 77)
		await pause(0.6)
		partner = await barrier()
		check(flow.get_phase() == flow.Phase.IDLE and started.size() == starts and failed.is_empty() and flow.get_current_room_id() == "test_room_b", "The client ignored stale and wrong-session messages from the host")
	verify_room("test_room_b", ROOM_B_SCENE if is_host() else ROOM_B_FUTURE_SCENE, "after stale messages")

	# 6. The return exit: ready, walk away to cancel, then go back to Room A through the real interaction.
	var exit: Area3D = current_scene.get_node("Exits/Exit")
	check(exit.get_destination() == "test_room_a", "Room B's exit leads back to Room A")
	current_scene.player.global_position = exit.global_position
	await tick(6)
	check(current_scene.controller.get_current_interactable() == exit, "The existing detector selects the exit")
	partner = await barrier()
	if is_host():
		check(current_scene.controller.try_interact(), "The Student uses the exit")
		check(flow.is_local_ready("test_room_a") and exit.get_interaction_prompt() == "Cancel (waiting for your partner)", "The prompt now offers to cancel")
		partner = await barrier()
		current_scene.player.global_position = Vector3.ZERO  # leave the exit zone
		await tick(4)
		check(flow.get_readiness().destination == "" and exit.get_interaction_prompt() == "Return to Previous Area", "Walking out of the exit zone withdraws readiness")
		partner = await barrier()
		current_scene.player.global_position = exit.global_position
		await tick(6)
		check(current_scene.controller.try_interact(), "The Student is ready again")
		partner = await barrier()
	else:
		# Each wait comes before the barrier, so the host holds its state until this peer has seen it.
		await wait_for(func() -> bool: return flow.get_readiness().past, "The Professor never saw the Student ready (step 6, first)")
		partner = await barrier()
		await wait_for(func() -> bool: return flow.get_readiness().destination == "", "The Professor never saw the cancellation")
		partner = await barrier()
		await wait_for(func() -> bool: return flow.get_readiness().past, "The Professor never saw the Student ready again")
		partner = await barrier()
		check(current_scene.controller.try_interact(), "The Professor uses the exit")
	if not await wait_for(func() -> bool: return completed.size() == 2, "The return transition never completed", 30.0):
		return
	check(started[1] == ["test_room_b", "test_room_a", 2], "The return is transition 2: B -> A, got %s" % str(started[1]))
	verify_room("test_room_a", ROOM_A_SCENE, "after returning")
	check(current_scene.radio.can_receive() and link_completions == 1 and puzzles.get_revision(FREQ) == revision, "The link survived the round trip without a second completion")
	partner = await barrier({"room": flow.get_current_room_id(), "tid": started[1][2]})
	check(partner.room == "test_room_a" and partner.tid == 2, "Both peers are back in Room A after transition 2")

	# 7. Repeated trips: no duplicate characters, HUDs or scenes, and a busy transition refuses more requests.
	var baseline := 0
	for trip in range(6):
		var target := "test_room_b" if flow.get_current_room_id() == "test_room_a" else "test_room_a"
		var done := completed.size()
		var slow := trip == 2
		if slow:
			flow.fade_out_seconds = 0.7
		if is_host():
			check(flow.request_transition(target) == "", "Trip %d: the Student is ready" % trip)
			partner = await barrier()
		else:
			partner = await barrier()
			await wait_for(func() -> bool: return flow.get_readiness().past, "Trip %d: no sign of the Student" % trip)
			check(flow.request_transition(target) == "", "Trip %d: the Professor is ready" % trip)
		if slow:
			await wait_for(func() -> bool: return flow.is_transitioning(), "Trip %d never started" % trip)
			check(flow.request_transition(target) == "busy", "Trip %d: a request during a transition is refused" % trip)
			if not is_host():
				flow._rpc_set_ready.rpc_id(1, session, target, true)
				await wait_for(func() -> bool: return rejected.has([target, "busy"]), "The host did not refuse a request during a transition")
		if not await wait_for(func() -> bool: return completed.size() == done + 1, "Trip %d never completed" % trip, 30.0):
			return
		if slow:
			flow.fade_out_seconds = 0.05
		await tick(2)
		verify_room(target, ROOM_A_SCENE if target == "test_room_a" else (ROOM_B_SCENE if is_host() else ROOM_B_FUTURE_SCENE), "trip %d" % trip)
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if trip == 0:
			baseline = nodes
		check(absi(nodes - baseline) < 80, "Trip %d does not accumulate nodes (%d vs %d)" % [trip, nodes, baseline])
		partner = await barrier({"room": flow.get_current_room_id(), "tid": started.back()[2]})
		check(partner.room == target and partner.tid == started.back()[2], "Trip %d: both peers agree on room and ID" % trip)
	check(started.size() == 8 and completed.size() == 8 and failed.is_empty(), "Eight transitions started and completed, none failed")
	for index in range(started.size()):
		check(started[index][2] == index + 1, "Transition IDs only ever rise (got %s)" % str(started[index]))
	check(puzzles.get_revision(FREQ) == revision and link_completions == 1 and current_scene.radio.can_receive(), "The link is untouched after repeated trips")
	rejected.clear()

	# 8. Load problems on either side restore the previous room and never touch progress.
	await scenario_failures(revision, expected_state)


func make_failure_rooms() -> void:
	var a: RoomDef = flow.get_room("test_room_a")
	var b_past := ROOM_B_SCENE
	var b_future := ROOM_B_FUTURE_SCENE
	var never_ready := "res://tests/fixtures/never_ready_room.tscn"
	var rooms := [
		make_room("bad_load_room", b_past, broken_scene if not is_host() else b_future),
		make_room("missing_client_room", b_past, "res://scenes/testing/nope.tscn" if not is_host() else b_future),
		make_room("host_broken_room", broken_scene if is_host() else b_past, b_future),
		make_room("slow_room", b_past, never_ready),
	]
	if is_host():
		rooms.append(make_room("host_only_room", b_past, b_future))
	var exits := PackedStringArray()
	for definition in rooms:
		check(flow.register_room(definition), "Failure room %s registers" % definition.room_id)
		exits.append(definition.room_id)
	if not is_host():
		exits.append("host_only_room")  # listed as an exit, but this peer has no such room
	a.allowed_exits = exits
	a.require_both_ready = false  # the host's own readiness is enough, so each case starts by itself


func scenario_failures(revision: int, expected_state: Dictionary) -> void:
	make_failure_rooms()
	var partner := await barrier()
	var cases := [
		["bad_load_room", "partner_load_failed", 20.0],
		["missing_client_room", "partner_load_failed", 20.0],
		["host_broken_room", "scene_load_failed", 20.0],
		["host_only_room", "partner_load_failed", 20.0],
		["slow_room", "timeout", 2.0],
	]
	for case in cases:
		var room_id: String = case[0]
		var reason: String = case[1]
		flow.transition_timeout_seconds = case[2]
		var failures_before := failed.size()
		var completed_before := completed.size()
		var started_before := started.size()
		# The guest never even starts a transition into a room it does not have.
		var unaware := not is_host() and room_id == "host_only_room"
		if is_host():
			check(flow.request_transition(room_id) == "", "%s: the host starts it" % room_id)
		if not unaware and not await wait_for(func() -> bool: return failed.size() > failures_before, "%s: no failure was reported" % room_id, 30.0):
			return
		partner = await barrier()
		if unaware:
			check(failed.size() == failures_before and started.size() == started_before, "%s: the guest was never put into a transition" % room_id)
		else:
			check(failed.size() == failures_before + 1 and failed.back() == reason, "%s: failed with %s, got %s" % [room_id, reason, str(failed)])
		check(completed.size() == completed_before, "%s: never reported success" % room_id)
		verify_room("test_room_a", ROOM_A_SCENE, "after %s" % room_id)
		check(puzzles.get_state(FREQ) == expected_state and puzzles.get_revision(FREQ) == revision and current_scene.radio.can_receive(), "%s: puzzle progress and the radio link are untouched" % room_id)
		check(flow.get_block_reason("test_room_b") == "" or not is_host(), "%s: the host may start another transition" % room_id)
		partner = await barrier()
	flow.transition_timeout_seconds = 20.0
	flow.get_room("test_room_a").require_both_ready = true

	# 9. The Professor drops out while a transition is being prepared.
	await scenario_disconnect_in_preparation()


func scenario_disconnect_in_preparation() -> void:
	flow.fade_out_seconds = 1.5  # keep the transition in its preparation phase while the connection drops
	var failures_before := failed.size()
	var completed_before := completed.size()
	var starts_before := started.size()
	if is_host():
		check(flow.request_transition("test_room_b") == "", "The Student is ready for the last transition")
		await barrier()
		if not await wait_for(func() -> bool: return failed.size() > failures_before, "The host never noticed the guest leaving", 30.0):
			return
		check(failed.back() == "peer_disconnected", "The host reports peer_disconnected, got %s" % failed.back())
		check(completed.size() == completed_before, "The host never reports the transition as completed")
		await tick(4)
		check(flow.get_current_room_id() == "test_room_a" and current_scene.scene_file_path == ROOM_A_SCENE, "The host is back in a playable Room A")
		check(not flow.is_transitioning() and not flow.is_input_locked() and not flow.overlay.is_covering() and current_scene.player.controls_enabled, "Nothing stays locked or black on the host")
		check(flow.get_readiness().destination == "", "The readiness panel does not wait for someone who left")
		check(network.state == network.State.HOSTING and flow.request_transition("test_room_b") == "no_partner", "With nobody connected the host is told there is no partner")
	else:
		await barrier()
		await wait_for(func() -> bool: return flow.get_readiness().past, "The Professor never saw the Student ready (disconnect finale)")
		flow.transition_started.connect(func(_from: String, _to: String) -> void: network.leave_game(), CONNECT_ONE_SHOT)
		check(flow.request_transition("test_room_b") == "", "The Professor marks ready, then loses the connection mid-preparation")
		if not await wait_for(func() -> bool: return failed.size() > failures_before, "The client never recovered", 30.0):
			return
		check(failed.back() == "host_disconnected", "The client reports host_disconnected, got %s" % failed.back())
		check(completed.size() == completed_before and started.size() == starts_before + 1, "The aborted transition never completes")
		await tick(4)
		check(flow.get_current_room_id() == "test_room_a" and current_scene.scene_file_path == ROOM_A_SCENE, "The client is back in a playable Room A")
		check(not flow.is_transitioning() and not flow.is_input_locked() and not flow.overlay.is_covering() and current_scene.player.controls_enabled, "Nothing stays locked or black on the client")
		check(network.state == network.State.IDLE, "The client left the session")


# --- Host leaves mid-transition ------------------------------------------------------------

func scenario_host_leaves() -> void:
	flow.fade_out_seconds = 1.5
	var partner := await barrier({"session": session})
	check(partner.session == session, "Both peers share one session")
	if not await establish_link():
		return
	partner = await barrier()
	var failures_before := failed.size()
	if is_host():
		flow.transition_started.connect(func(_from: String, _to: String) -> void:
			await create_timer(0.3).timeout  # let the begin message reach the guest first
			network.leave_game(), CONNECT_ONE_SHOT)
		check(flow.request_transition("test_room_b") == "", "The Student is ready")
		partner = await barrier()
		if not await wait_for(func() -> bool: return failed.size() > failures_before, "The host never recovered", 30.0):
			return
		check(failed.back() == "peer_disconnected" or failed.back() == "session_ended", "The host recovers after dropping the session, got %s" % failed.back())
		await tick(4)
		check(flow.get_current_room_id() == "test_room_a" and not flow.is_transitioning() and not flow.is_input_locked() and not flow.overlay.is_covering(), "The host is back in a playable Room A")
	else:
		partner = await barrier()
		await wait_for(func() -> bool: return flow.get_readiness().past, "The Professor never saw the Student ready (host_leaves)")
		check(flow.request_transition("test_room_b") == "", "The Professor is ready")
		if not await wait_for(func() -> bool: return failed.size() > failures_before, "The client never recovered after the host left", 30.0):
			return
		check(failed.back() == "host_disconnected", "The client reports host_disconnected, got %s" % failed.back())
		await tick(4)
		check(flow.get_current_room_id() == "test_room_a" and current_scene.scene_file_path == ROOM_A_SCENE, "The client stays in a playable Room A")
		check(not flow.is_transitioning() and not flow.is_input_locked() and not flow.overlay.is_covering() and current_scene.player.controls_enabled, "Nothing stays locked or black")
		check(network.state == network.State.IDLE and flow.request_transition("test_room_b") != "", "The session is over; the client cannot start transitions")


func scenario_production() -> void:
	check(flow.has_room("room_02"), "Room 02 is registered without loading the sandbox registry")
	check(flow.start_room("room_01"), "The production Signal Laboratory starts")
	await tick(8)
	var lab: Node3D = current_scene
	lab.pause_when_unfocused = false
	lab._set_paused(false)
	if not await wait_for(func() -> bool: return puzzles.is_session_active(), "Production puzzle session did not arrive"):
		return
	session = puzzles.get_session_id()
	peer_object_id = get_multiplayer().multiplayer_peer.get_instance_id()
	await barrier()
	check(flow.get_block_reason("room_02") == "puzzle_incomplete", "The production exit retains the Lost Frequency prerequisite")
	lab.gameplay.radio.request_acquisition()
	await barrier()
	if not await wait_for(func() -> bool: return puzzles.get_state(FREQ).get("student_radio", false) and puzzles.get_state(FREQ).get("professor_radio", false), "Radio acquisition was not confirmed on both peers"):
		return
	if is_host():
		puzzles.submit_action(FREQ, "tune_frequency", {"frequency": 67})
	if not await wait_for(func() -> bool: return puzzles.is_solved(FREQ), "Production calibration failed"):
		return
	await tick(4)
	for i in 32:
		if not lab.gameplay.director.is_dialogue_active():
			break
		lab.gameplay.director.skip_typewriter()
		lab.gameplay.director.advance_dialogue()
		await process_frame
	await barrier()
	var revision: int = puzzles.get_revision(FREQ)
	var state: Dictionary = puzzles.get_state(FREQ)
	check(flow.get_current_room_id() == "room_01" and not flow.is_transitioning(), "Puzzle completion alone does not trigger departure")
	var exit: Area3D = lab.gameplay.get_node("Props/LevelExit")
	lab.player.global_position = exit.global_position
	await tick(6)
	check(lab.gameplay.controller.get_current_interactable() == exit, "The production corridor exit is selected")
	if is_host():
		check(lab.gameplay.controller.try_interact(), "Student readies using the production exit")
	await barrier()
	check(not flow.is_transitioning() and flow.get_current_room_id() == "room_01", "One ready player does not move either peer")
	await barrier()
	if not is_host():
		check(lab.gameplay.controller.try_interact(), "Professor readies using the production exit")
	if not await wait_for(func() -> bool: return flow.get_current_room_id() == "room_02" and not flow.is_transitioning(), "Production Room 02 transition timed out"):
		return
	await tick(4)
	var room: Node3D = current_scene
	var timeline := "past" if is_host() else "future"
	check(room.scene_file_path == "res://scenes/world/maintenance_corridor.tscn" and room.role == timeline, "Production Maintenance Gallery configures the local timeline")
	room.pause_when_unfocused = false
	room.director.stop_dialogue()
	room._pending_lines.clear()
	check(room.player.scene_file_path.ends_with("student_3d_player.tscn" if is_host() else "professor_3d_player.tscn"), "Correct production character spawned")
	var marker: Marker3D = flow.find_spawn_point(flow.get_entry_spawn_id(timeline))
	check(room.player.global_position.distance_to(marker.global_position) < 0.1 and room.player.is_on_floor(), "Correct grounded timeline marker used")
	check(count_nodes("CharacterBody3D") == 1 and count_nodes("Camera3D") == 1 and count_nodes("TemporalRadio") == 1 and count_nodes("InteractionController") == 1, "No duplicate players, cameras, radios or interaction rigs")
	check("67 MHz" in room.radio_label.text and count_nodes("AudioDirector") == 1, "The gallery owns one radio status display and one audio director")
	check(not flow.is_input_locked() and not flow.overlay.is_covering() and room.player.controls_enabled, "Fade clears and movement controls unlock")
	check(room.radio.can_receive() and room.radio.owns_radio and room.radio.get_calibrated_frequency() == 67, "Established radio state restores in the gallery")
	var before: Vector3 = room.player.position
	var camera_before: Vector3 = room.camera.global_position
	Input.action_press("move_right")
	await tick(16)
	Input.action_release("move_right")
	await tick(5)
	check(room.player.position.x > before.x + 0.2 and room.camera.global_position.x > camera_before.x + 0.1, "Normal movement and the existing follow camera work")
	check(network.in_game and network.state == network.State.CONNECTED and get_multiplayer().multiplayer_peer.get_instance_id() == peer_object_id, "The same ENet connection survives")
	check(puzzles.get_session_id() == session and puzzles.get_revision(FREQ) == revision and puzzles.get_state(FREQ) == state and link_completions == 1 and sessions_started == 1, "Puzzle session, state, revision and one completion survive unchanged")
	await shot("room_02_gallery")
	await barrier({"room": flow.get_current_room_id(), "revision": revision})
