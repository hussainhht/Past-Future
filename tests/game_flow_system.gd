extends SceneTree
## Offline checks for the level-flow system: RoomDefinition rules, the registry, a full solo
## transition with its signals and input lock, the real exit interactable, repeated transitions,
## and every failure path that does not need a second peer. Run:
##   godot --headless --path . --script res://tests/game_flow_system.gd
## The two-process checks live in game_flow_peer.gd (run_game_flow_tests.py).

const RoomDef := preload("res://scripts/game_flow/room_definition.gd")
const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const FREQ := "puzzle_01_frequency"
const TEST_ROOMS := "res://resources/levels/test"
const ROOM_A_SCENE := "res://scenes/testing/transition_room_a.tscn"
const ROOM_B_SCENE := "res://scenes/testing/transition_room_b.tscn"
const ROOM_B_FUTURE_SCENE := "res://scenes/testing/transition_room_b_future.tscn"
const ROOM_02_SCENE := "res://scenes/world/maintenance_corridor.tscn"
const LAB_SCENE := "res://scenes/world/spawn_area.tscn"
## Written by the test and removed afterwards. A dot-prefixed folder is invisible to the editor,
## so the deliberately unparsable scene never shows up as an import error.
const GENERATED_DIRECTORY := "res://.game_flow_test"
const BROKEN_LOAD_SCENE := GENERATED_DIRECTORY + "/broken_load_room.tscn"

var flow: Node
var puzzles: Node
var network: Node
var checks: int = 0
var failures: int = 0
var events: Array = []
var completions: int = 0
var sessions_started: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)


func wait_for(predicate: Callable, message: String, seconds: float = 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func tick(frames: int = 4) -> void:
	for i in range(frames):
		await physics_frame
	await process_frame


func idle() -> bool:
	return not flow.is_transitioning()


func names() -> Array:
	return events.map(func(entry: Array) -> String: return entry[0])


func index_of(event_name: String) -> int:
	return names().find(event_name)


func make_room(room_id: String, shared: String = ROOM_B_SCENE, next_room: String = "") -> RoomDef:
	var definition := RoomDef.new()
	definition.room_id = room_id
	definition.shared_scene = shared
	definition.next_room_id = next_room
	return definition


## A fresh solo run in Test Room A as the given timeline.
func fresh_solo(role: String = "past") -> void:
	puzzles.offline_role = role
	puzzles.begin_session()
	check(flow.start_room("test_room_a"), "start_room enters Test Room A")
	await tick()


func establish_link() -> void:
	current_scene.dev_establish_link()
	await tick(2)


func move_to_idle(message: String) -> bool:
	return await wait_for(idle, message)


func record_signals() -> void:
	events.clear()
	flow.transition_requested.connect(func(from: String, to: String) -> void: events.append(["transition_requested", from, to]))
	flow.transition_started.connect(func(from: String, to: String) -> void: events.append(["transition_started", from, to]))
	flow.room_loading.connect(func(id: String) -> void: events.append(["room_loading", id, flow.overlay.is_fully_black()]))
	flow.room_unloading.connect(func(id: String) -> void: events.append(["room_unloading", id]))
	flow.room_changed.connect(func(id: String) -> void:
		# current_scene is still null while a directly opened scene runs its own _ready().
		var controls: Variant = null
		if current_scene != null and current_scene.get("player") != null:
			controls = current_scene.player.controls_enabled
		events.append(["room_changed", id, flow.overlay.is_fully_black(), flow.is_input_locked(), controls]))
	flow.transition_completed.connect(func(id: String) -> void: events.append(["transition_completed", id]))
	flow.transition_failed.connect(func(reason: String) -> void: events.append(["transition_failed", reason]))
	flow.request_rejected.connect(func(destination: String, reason: String, message: String) -> void: events.append(["request_rejected", destination, reason, message]))
	flow.phase_changed.connect(func(phase: int) -> void: events.append(["phase", phase]))
	flow.input_lock_changed.connect(func(locked: bool) -> void: events.append(["lock", locked]))
	flow.transition_progress_changed.connect(func(progress: float) -> void: events.append(["progress", progress]))


func count_nodes(type_name: String) -> int:
	return current_scene.find_children("*", type_name, true, false).size()


func _run() -> void:
	flow = root.get_node("GameFlowManager")
	puzzles = root.get_node("PuzzleManager")
	network = root.get_node("NetworkManager")
	puzzles.log_rejections = false
	flow.log_problems = false
	flow.fade_out_seconds = 0.05
	flow.fade_in_seconds = 0.05
	puzzles.puzzle_completed.connect(func(id: String) -> void:
		if id == FREQ:
			completions += 1)
	puzzles.session_started.connect(func() -> void: sessions_started += 1)
	record_signals()
	await test_definitions()
	await test_registry()
	await test_solo_flow()
	await test_timeline_scenes()
	await test_exit_interaction()
	await test_repeated_transitions()
	await test_rules_and_blockers()
	await test_lock_enforcement()
	await test_signal_laboratory()
	await test_sandbox_entry_points()
	await test_failures()
	if current_scene != null:
		current_scene.free()
	await process_frame
	await create_timer(.2).timeout
	print("GAME FLOW SYSTEM: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


# --- RoomDefinition ------------------------------------------------------------------------

func test_definitions() -> void:
	var shared := make_room("shared_room", ROOM_A_SCENE, "next")
	check(shared.validate().is_empty(), "A shared-scene definition is valid")
	check(shared.get_scene_path("past") == ROOM_A_SCENE and shared.get_scene_path("future") == ROOM_A_SCENE, "A shared scene serves both timelines")
	var split := make_room("split_room", "", "next")
	split.past_scene = ROOM_B_SCENE
	split.future_scene = ROOM_B_FUTURE_SCENE
	check(split.validate().is_empty(), "A definition with one scene per timeline is valid")
	check(split.get_scene_path("past") == ROOM_B_SCENE and split.get_scene_path("future") == ROOM_B_FUTURE_SCENE, "Each timeline gets its own scene")
	var mixed := make_room("mixed_room", ROOM_A_SCENE, "next")
	mixed.future_scene = ROOM_B_FUTURE_SCENE
	check(mixed.get_scene_path("past") == ROOM_A_SCENE and mixed.get_scene_path("future") == ROOM_B_FUTURE_SCENE, "A timeline scene overrides the shared one")
	check(split.get_spawn_id("past") == &"past_entry" and split.get_spawn_id("future") == &"future_entry", "Default spawn IDs are past_entry and future_entry")
	var gated := make_room("gated_room", ROOM_A_SCENE, "next")
	gated.allowed_exits = PackedStringArray(["back", "next", ""])
	gated.required_puzzles = PackedStringArray([FREQ])
	check(gated.validate().is_empty(), "A gated definition with an exit is valid")
	check(gated.get_destinations() == PackedStringArray(["next", "back"]), "Destinations list the main exit once, then the extras")
	check(gated.get_required_puzzles("next") == PackedStringArray([FREQ]) and gated.get_required_puzzles("back").is_empty(), "Only the main exit is gated")
	for problem in [
		["no ID", make_room("", ROOM_A_SCENE)],
		["padded ID", make_room(" room", ROOM_A_SCENE)],
		["no scene", make_room("no_scene", "")],
		["user:// scene", make_room("user_scene", "user://x.tscn")],
		["wrong extension", make_room("wrong_ext", "res://project.godot")],
		["self-loop", make_room("loop", ROOM_A_SCENE, "loop")],
	]:
		check(not problem[1].validate().is_empty(), "Invalid definition is reported: " + problem[0])
	var no_exit := make_room("gate_without_exit", ROOM_A_SCENE)
	no_exit.required_puzzles = PackedStringArray([FREQ])
	check(not no_exit.validate().is_empty(), "Puzzle requirements need an exit to gate")
	var missing := make_room("ghost", "res://scenes/testing/does_not_exist.tscn")
	check(missing.validate().is_empty() and missing.missing_scenes() == PackedStringArray(["res://scenes/testing/does_not_exist.tscn"]), "A missing file is reported separately from structural problems")


# --- Registry ------------------------------------------------------------------------------

func test_registry() -> void:
	check(flow.get_room_ids().is_empty() or not flow.has_room("test_room_a"), "Test rooms are not part of the production registry")
	check(flow.load_room_directory(TEST_ROOMS) == 2, "load_room_directory registers both sandbox rooms")
	check(flow.has_room("test_room_a") and flow.has_room("test_room_b"), "Both rooms are known by ID")
	check(flow.get_room_display_name("test_room_b") == "Maintenance Corridor (sandbox)", "Display names come from the definition")
	check(flow.load_room_directory(TEST_ROOMS) == 2, "Registering the same resources again is harmless")
	check(not flow.register_room(null), "A null definition is refused")
	check(not flow.register_room(make_room("", ROOM_A_SCENE)), "A definition without an ID is refused")
	check(not flow.register_room(make_room("no_scene", "")), "A definition without a scene is refused")
	var duplicate := make_room("test_room_a", ROOM_B_SCENE)
	check(not flow.register_room(duplicate), "A different resource with an existing ID is refused")
	check(flow.get_room("test_room_a").shared_scene == ROOM_A_SCENE, "The refused duplicate did not replace the room")
	var extra := make_room("registry_extra", ROOM_B_SCENE)
	check(flow.register_room(extra) and flow.register_room(extra), "Registering one resource twice succeeds")
	var replacement := make_room("registry_extra", ROOM_A_SCENE)
	check(flow.register_room(replacement, true) and flow.get_room("registry_extra") == replacement, "replace = true swaps a definition")
	check(flow.unregister_room("registry_extra") and not flow.has_room("registry_extra"), "A room that is not in use can be unregistered")
	check(not flow.unregister_room("registry_extra"), "Unregistering an unknown room reports false")
	check(flow.get_current_room_id() == "" and not flow.is_transitioning(), "No room is current before a session enters one")
	check(not flow.start_room("not_a_room"), "start_room refuses an unknown ID")


# --- Full solo transition ------------------------------------------------------------------

func test_solo_flow() -> void:
	await fresh_solo("past")
	var session: int = puzzles.get_session_id()
	var started_before := sessions_started
	events.clear()
	var room := current_scene
	check(flow.get_current_room_id() == "test_room_a" and room.scene_file_path == ROOM_A_SCENE, "Room A is the current room and scene")
	check(room.player.scene_file_path.ends_with("student_3d_player.tscn"), "The Past timeline plays the Student")
	var spawn: Marker3D = room.get_node("Spawns/past_entry")
	check(room.player.global_position.is_equal_approx(spawn.global_position) and absf(room.player.global_position.y) < 0.001, "The player enters at past_entry with its root on the ground (Y = 0)")
	check(flow.get_entry_spawn_id() == &"past_entry" and flow.find_spawn_point(&"past_entry") == spawn, "The manager resolves the entry spawn by ID, not by path")
	check(flow.find_spawn_point(&"no_such_marker") == null, "An unknown spawn ID resolves to nothing")
	check(not flow.can_enter_room("test_room_b") and flow.get_block_reason("test_room_b") == "puzzle_incomplete", "Leaving is refused while the radio link is not established")
	check(flow.get_missing_puzzles("test_room_b") == PackedStringArray([FREQ]), "The missing puzzle is named")
	check(flow.request_transition("test_room_b") == "puzzle_incomplete", "request_transition returns the reason")
	var rejected: Array = events.filter(func(entry: Array) -> bool: return entry[0] == "request_rejected")
	check(rejected.size() == 1 and rejected[0][3] == "Establish the temporal radio link first (F9 in this sandbox).", "The room's own locked message is shown")
	check(not flow.is_transitioning() and index_of("transition_started") == -1, "A refused request starts nothing")
	check(flow.request_transition("nowhere") == "unknown_room" and flow.request_transition("test_room_a") == "not_adjacent", "Unknown rooms and non-neighbours are refused")
	await establish_link()
	check(completions == 1 and room.radio.can_receive(), "The Lost Frequency link is established once, through real puzzle actions")
	var revision: int = puzzles.get_revision(FREQ)
	var state: Dictionary = puzzles.get_state(FREQ)
	check(flow.can_enter_room("test_room_b"), "With the puzzle solved the exit is allowed")
	events.clear()
	check(flow.request_transition("test_room_b") == "", "Offline, one ready player is enough: no second peer is awaited")
	check(flow.is_transitioning() and flow.is_input_locked(), "Input is locked as soon as the transition starts")
	check(room.player.controls_enabled == false, "The old character stops responding to input")
	check(flow.request_transition("test_room_b") == "busy", "A second request during the transition is refused")
	check(flow.begin_transition("test_room_b") == "busy", "A forced second start is refused too")
	check(await move_to_idle("Solo transition did not finish"), "The transition finishes")
	var order := ["transition_requested", "transition_started", "room_loading", "room_unloading", "room_changed", "transition_completed"]
	var last := -1
	for event_name in order:
		var position := index_of(event_name)
		check(position > last, "Signal order: %s comes after the previous one" % event_name)
		last = maxi(position, last)
	check(names().count("transition_started") == 1 and names().count("transition_completed") == 1, "Each lifecycle signal fires exactly once")
	var phases: Array = events.filter(func(entry: Array) -> bool: return entry[0] == "phase").map(func(entry: Array) -> int: return entry[1])
	check(phases == [1, 2, 3, 4, 0], "Phases run FADING_OUT, LOADING, WAITING_FOR_PEERS, FADING_IN, IDLE; got %s" % str(phases))
	var loading: Array = events[index_of("room_loading")]
	check(loading[1] == "test_room_b" and loading[2] == true, "Loading starts only once the screen is fully black")
	var changed: Array = events[index_of("room_changed")]
	check(changed[1] == "test_room_b" and changed[2] == true and changed[3] == true and changed[4] == false, "The new room appears hidden behind black with controls locked, before the commit")
	check(events.filter(func(entry: Array) -> bool: return entry[0] == "lock").map(func(entry: Array) -> bool: return entry[1]) == [true, false], "The input lock is taken once and released once")
	var progress: Array = events.filter(func(entry: Array) -> bool: return entry[0] == "progress").map(func(entry: Array) -> float: return entry[1])
	var rising := true
	for i in range(1, progress.size()):
		rising = rising and progress[i] >= progress[i - 1]
	check(rising and not progress.is_empty() and progress.back() == 1.0, "Progress only rises and ends at 1.0")
	check(not is_instance_valid(room) or room.is_queued_for_deletion() or not room.is_inside_tree(), "The old room is gone")
	room = current_scene
	check(flow.get_current_room_id() == "test_room_b" and room.scene_file_path == ROOM_B_SCENE, "Room B is now current")
	check(room.player.controls_enabled and not flow.is_input_locked() and not flow.overlay.is_covering(), "Controls return and the screen is clear")
	var spawn_b: Marker3D = room.get_node("Spawns/past_entry")
	check(room.player.global_position.is_equal_approx(spawn_b.global_position), "The player enters Room B at its own entry marker")
	check(puzzles.get_session_id() == session and sessions_started == started_before, "The puzzle session is the same and no session started")
	check(puzzles.get_state(FREQ) == state and puzzles.get_revision(FREQ) == revision, "Puzzle state and revision are untouched")
	check(completions == 1, "The puzzle completion is not replayed in the new room")
	check(room.radio.owns_radio and room.radio.can_receive(), "The re-created TemporalRadio restores the connected link from PuzzleManager")
	check(network.state == network.State.IDLE and not network.in_game, "The network layer was never involved")
	check(count_nodes("CharacterBody3D") == 1 and count_nodes("TemporalRadio") == 1, "Exactly one character and one radio exist")
	check(root.get_child_count() == 5, "Only the autoloads and the room are under root, got %d" % root.get_child_count())
	var before: Vector3 = room.player.global_position
	Input.action_press("move_right")
	await tick(20)
	Input.action_release("move_right")
	await tick(4)
	check(room.player.global_position.x > before.x + 0.3, "The character moves after the transition")


func test_timeline_scenes() -> void:
	await fresh_solo("future")
	var room := current_scene
	check(room.scene_file_path == ROOM_A_SCENE and room.player.scene_file_path.ends_with("professor_3d_player.tscn"), "The shared Room A scene hosts the Professor for the Future")
	var spawn: Marker3D = room.get_node("Spawns/future_entry")
	check(room.player.global_position.is_equal_approx(spawn.global_position), "The Future timeline uses future_entry")
	await establish_link()
	check(flow.request_transition("test_room_b") == "", "The Professor can leave offline too")
	check(await move_to_idle("Future transition did not finish"), "The Future transition finishes")
	check(current_scene.scene_file_path == ROOM_B_FUTURE_SCENE, "The Future timeline loads its own Room B scene")
	check(current_scene.get_node("Spawns/future_entry").global_position.is_equal_approx(current_scene.player.global_position), "The Future player starts at the Future scene's marker")
	await fresh_solo("past")
	await establish_link()
	check(flow.request_transition("test_room_b") == "" and await move_to_idle("Past transition did not finish"), "The Past transition finishes")
	check(current_scene.scene_file_path == ROOM_B_SCENE, "The Past timeline loads the clean Room B scene")


# --- Real exit and interaction -------------------------------------------------------------

func test_exit_interaction() -> void:
	await fresh_solo("past")
	var room := current_scene
	var exit: Area3D = room.get_node("Exits/Exit")
	var controller: Node = room.controller
	check(exit.get_destination() == "test_room_b" and exit.get_interaction_prompt() == "Proceed to Next Area", "The exit names its destination and prompt")
	room.player.global_position = exit.global_position
	await tick(6)
	check(controller.get_current_interactable() == exit, "The existing detector selects the exit; there is no second detector")
	check(controller.try_interact(), "Pressing the interact key reaches the exit")
	check(not flow.is_transitioning() and flow.get_readiness().destination == "", "Without the radio link the exit does not start anything")
	await establish_link()
	var completions_before := completions
	events.clear()
	check(controller.try_interact(), "The interact key is accepted with the link up")
	check(flow.is_transitioning(), "The exit starts the transition through GameFlowManager")
	check(not controller.try_interact(), "Interaction is blocked while the transition runs")
	check(await move_to_idle("Exit transition did not finish"), "The exit transition finishes")
	room = current_scene
	exit = room.get_node("Exits/Exit")
	check(room.scene_file_path == ROOM_B_SCENE and exit.get_destination() == "test_room_a" and exit.get_interaction_prompt() == "Return to Previous Area", "Room B's exit leads back")
	room.player.global_position = exit.global_position
	await tick(6)
	check(room.controller.get_current_interactable() == exit and room.controller.try_interact(), "The return exit works in the new room")
	check(await move_to_idle("Return transition did not finish"), "The return transition finishes")
	check(current_scene.scene_file_path == ROOM_A_SCENE and flow.get_current_room_id() == "test_room_a", "The players are back in Room A")
	check(current_scene.radio.can_receive() and completions == completions_before, "The link survived both trips without a second completion")


func test_repeated_transitions() -> void:
	await fresh_solo("past")
	await establish_link()
	var baseline := 0
	for trip in range(6):
		var target := "test_room_b" if flow.get_current_room_id() == "test_room_a" else "test_room_a"
		check(flow.request_transition(target) == "", "Trip %d is accepted" % trip)
		check(await move_to_idle("Trip %d did not finish" % trip), "Trip %d finishes" % trip)
		await tick(2)
		check(flow.get_current_room_id() == target, "Trip %d arrives in %s" % [trip, target])
		check(count_nodes("CharacterBody3D") == 1 and count_nodes("TemporalRadio") == 1 and count_nodes("InteractionController") == 1, "Trip %d leaves one character, one radio, one controller" % trip)
		check(current_scene.find_children("StatusHUD", "CanvasLayer", true, false).size() == 1 and current_scene.get_node("Actors").get_child_count() == 1, "Trip %d leaves one HUD and one actor" % trip)
		check(root.get_child_count() == 5, "Trip %d leaves only the autoloads and the room under root" % trip)
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if trip == 0:
			baseline = nodes
		check(absi(nodes - baseline) < 80, "Trip %d does not accumulate nodes (%d vs %d)" % [trip, nodes, baseline])
	check(current_scene.radio.can_receive(), "The link is still up after repeated trips")


# --- Rules, readiness helpers and blockers -------------------------------------------------

func test_rules_and_blockers() -> void:
	await fresh_solo("past")
	await establish_link()
	check(flow.get_readiness() == {"destination": "", "past": false, "future": false}, "Nobody is ready at the start")
	var stub: Node = load("res://tests/fixtures/dialogue_stub.gd").new()
	root.add_child(stub)
	check(flow.request_transition("test_room_b") == "blocked", "An open conversation blocks leaving")
	var rejected: Array = events.filter(func(entry: Array) -> bool: return entry[0] == "request_rejected").back()
	check(rejected[3] == "Finish the conversation first.", "The player is told why")
	stub.active = false
	flow.add_ready_blocker(&"terminal", func() -> String: return "Close the terminal first.")
	check(flow.request_transition("test_room_b") == "blocked", "A registered blocker also stops the request")
	flow.remove_ready_blocker(&"terminal")
	stub.free()
	check(not flow.is_transitioning(), "Blocked requests never start a transition")
	check(flow.begin_transition("test_room_b") == "" and await move_to_idle("Scripted transition did not finish"), "begin_transition starts a scripted transition without readiness")
	check(flow.get_current_room_id() == "test_room_b", "The scripted transition arrived")
	check(flow.begin_transition("test_room_b") == "not_adjacent", "Scripted transitions follow the same destination rules")
	# Rooms that are not neighbours.
	var island := make_room("island", ROOM_B_SCENE, "")
	check(flow.register_room(island), "An isolated room can be registered")
	check(flow.begin_transition("island") == "not_adjacent", "A room that is not listed as an exit cannot be entered from here")
	flow.unregister_room("island")
	# Ready state changes are clean when the local player withdraws before anything happens.
	flow.cancel_transition_request()
	check(flow.get_readiness().destination == "", "Cancelling with nothing pending is harmless")
	check(not flow.abort_transition(), "There is nothing to abort while idle")


# --- The input lock holds even if a room releases its character -----------------------------

func test_lock_enforcement() -> void:
	await fresh_solo("past")
	await establish_link()
	var observed: Array = []
	var on_changed := func(_id: String) -> void:
		current_scene.player.controls_enabled = true  # a room that re-enables its character on entry
	var on_phase := func(phase: int) -> void:
		if phase == flow.Phase.FADING_IN:
			observed.append(current_scene.player.controls_enabled)
	flow.room_changed.connect(on_changed)
	flow.phase_changed.connect(on_phase)
	check(flow.request_transition("test_room_b") == "" and await move_to_idle("The lock test transition did not finish"), "The transition runs")
	flow.room_changed.disconnect(on_changed)
	flow.phase_changed.disconnect(on_phase)
	check(observed == [false], "A character a room released is held again before the fade-in begins, got %s" % str(observed))
	check(current_scene.player.controls_enabled and not flow.is_input_locked(), "Controls come back once the transition completes")


# --- The real Signal Laboratory as Room 01 -------------------------------------------------

func finish_dialogue(game: Node3D) -> void:
	for i in range(32):
		if not game.director.is_dialogue_active():
			return
		game.director.skip_typewriter()
		game.director.advance_dialogue()
		await process_frame
	check(false, "The director could not finish its conversation")


func test_signal_laboratory() -> void:
	check(flow.has_room("room_01"), "resources/levels/room_01.tres is registered automatically")
	var definition: RoomDef = flow.get_room("room_01")
	check(definition.shared_scene == LAB_SCENE and definition.next_room_id == "room_02" and definition.required_puzzles == PackedStringArray([FREQ]), "Room 01 is the lab, gated on the Lost Frequency")
	check(flow.has_room("room_02") and flow.get_room("room_02").missing_scenes().is_empty(), "Production Room 02 is registered with available scenes")
	puzzles.offline_role = "past"
	puzzles.begin_session()
	check(flow.start_room("room_01"), "The manager enters the real laboratory")
	await tick(8)
	var lab := current_scene
	lab.pause_when_unfocused = false
	lab._set_paused(false)
	var game: Node3D = lab.gameplay
	check(flow.get_current_room_id() == "room_01" and lab.scene_file_path == LAB_SCENE and game.configured, "The laboratory is the current room and fully initialised")
	check(flow.get_entry_spawn_id() == &"SpawnPoint" and flow.find_spawn_point(&"SpawnPoint") == lab.get_node("SpawnPoint"), "Room 01 names the lab's existing SpawnPoint as its entry")
	var exit: Area3D = game.get_node("Props/LevelExit")
	check(exit.get_destination() == "room_02", "The corridor exit leads to the room's next_room_id")
	lab.player.global_position = exit.global_position
	await tick(6)
	check(game.controller.get_current_interactable() == exit and game.controller.try_interact(), "The existing detector offers the corridor exit")
	check(flow.get_block_reason("room_02") == "puzzle_incomplete" and flow.get_reason_message("puzzle_incomplete") == definition.locked_message, "With the door sealed the lab's own message is shown")
	for radio_role in ["past", "future"]:
		puzzles.submit_action(FREQ, "acquire_radio", {"radio_role": radio_role}, radio_role)
	puzzles.submit_action(FREQ, "tune_frequency", {"frequency": Rules.DEFAULT_FREQUENCY}, "past")
	puzzles.submit_action(FREQ, "tune_amplitude", {"amplitude": 70}, "past")
	await tick(4)
	var completions_before := completions
	var revision: int = puzzles.get_revision(FREQ)
	check(game.radio.can_receive(), "The real puzzle actions established the link")
	check(lab.get_node("Actors").find_children("*", "CharacterBody3D", false, false).size() == 1, "The lab starts with exactly one character")
	# The link starts a radio conversation: leaving waits for it, as the dialogue system requires.
	check(game.director.is_dialogue_active(), "The radio-link conversation is playing")
	check(flow.request_transition("room_02") == "blocked", "Leaving is refused while an important conversation plays")
	await finish_dialogue(game)
	# A document is open when the players decide to leave: it must be closed, not left behind.
	lab.lab.ui.open_document("TEST NOTE", "Open while leaving.")
	check(game.has_modal(), "A document is open")
	check(flow.request_transition("room_02") == "", "Leaving is accepted with a document open on screen")
	check(not game.has_modal() and flow.is_input_locked(), "The open document was closed and input is locked")
	check(lab.is_gameplay_paused() and not lab.player.controls_enabled, "The lab reports a paused state and holds the character")
	check(not game.can_switch_role(), "The solo role switch (T) is refused while a transition runs")
	await tick(2)
	check(not lab.player.controls_enabled, "The lab's own control sync does not release the character during the transition")
	check(await move_to_idle("Leaving the laboratory did not finish"), "The transition out of the laboratory finishes")
	check(flow.get_current_room_id() == "room_02" and current_scene.scene_file_path == ROOM_02_SCENE, "The players are in the playable Maintenance Gallery")
	check(get_nodes_in_group("dialogue_director").size() == 1 and not is_instance_valid(lab), "The gallery replaces the laboratory and owns one dialogue director")
	current_scene.pause_when_unfocused = false
	await tick(4)
	await finish_dialogue(current_scene)
	await tick(8)
	check(current_scene.radio.can_receive() and current_scene.radio.owns_radio, "The radio link is connected in Room 02")
	check(count_nodes("CharacterBody3D") == 1 and count_nodes("Camera3D") == 1, "Room 02 has one character and one existing fixed camera")
	check(current_scene.player.is_on_floor() and absf(current_scene.player.position.y) < 0.1, "Room 02 spawn is grounded on its floor")
	check("67 MHz" in current_scene.radio_label.text and current_scene.radio.get_calibrated_frequency() == 67, "Room 02 HUD restores the 67 MHz link")
	var position_before: Vector3 = current_scene.player.position
	Input.action_press("move_right")
	await tick(15)
	Input.action_release("move_right")
	await tick(4)
	check(current_scene.player.position.x > position_before.x + 0.2, "Room 02 accepts normal movement after the fade")
	# The optional return uses the same actual detector/exit readiness flow.
	var return_exit: Area3D = current_scene.get_node("ReturnExit")
	current_scene.player.global_position = return_exit.global_position
	await tick(6)
	check(current_scene.controller.get_current_interactable() == return_exit and current_scene.controller.try_interact(), "Temporary return exit uses the existing interaction flow")
	check(await move_to_idle("Returning to the laboratory did not finish"), "The return finishes")
	lab = current_scene
	lab.pause_when_unfocused = false
	game = lab.gameplay
	check(flow.get_current_room_id() == "room_01" and lab.scene_file_path == LAB_SCENE and game.configured, "The laboratory is current again")
	check(lab.player.controls_enabled and not lab.is_gameplay_paused() and not flow.is_input_locked(), "Controls and the lab's own pause state are released")
	check(game.radio.can_receive() and game.radio.owns_radio, "The re-created lab radio restores the connected link")
	check(completions == completions_before and puzzles.get_revision(FREQ) == revision, "Re-entering the lab does not replay the completion or change the revision")
	check(not game.director.is_dialogue_active(), "The completed radio conversation does not replay")
	check(lab.get_node("Actors").find_children("*", "CharacterBody3D", false, false).size() == 1, "Still exactly one character")
	check(get_nodes_in_group("dialogue_director").size() == 1 and game.get_node_or_null("GameplayHUD") != null, "One director and one gameplay HUD")
	check(count_nodes("InteractionController") == 1 and lab.find_children("RadioHUD", "", true, false).size() == 1, "One interaction controller and one radio HUD")
	check(root.get_child_count() == 5, "Only the autoloads and the lab are under root")
	# The new lab's exit works too.
	var exit_again: Area3D = game.get_node("Props/LevelExit")
	lab.player.global_position = exit_again.global_position
	await tick(6)
	check(game.controller.get_current_interactable() == exit_again, "The corridor exit works again in the new lab")
	check(game.controller.try_interact(), "Using the corridor exit")
	check(await move_to_idle("Leaving through the corridor exit did not finish"), "The corridor exit transition finishes")
	check(flow.get_current_room_id() == "room_02", "The corridor exit led to Room 02")
	check(flow.unregister_room("room_02") == false, "A room in use cannot be unregistered")
	await tick(4)
	await finish_dialogue(current_scene)
	check(flow.begin_transition("room_01") == "" and await move_to_idle("Final return did not finish"), "Back to the lab once more")
	await create_timer(1.0).timeout  # a conversation replayed on entry would start shortly after it
	check(not current_scene.gameplay.director.is_dialogue_active(), "A third visit to the lab still plays no conversation (%s)" % current_scene.gameplay.director.get_current_sequence_id())
	check(flow.has_room("room_02"), "Room 02 stays in the production registry after returning")
	current_scene.free()  # leave a clean tree for the next test
	await process_frame


# --- Sandbox entry points ------------------------------------------------------------------

func test_sandbox_entry_points() -> void:
	# The launcher scene: press "solo Student" like a tester would.
	var launcher: Control = load("res://scenes/testing/transition_flow_sandbox.tscn").instantiate()
	root.add_child(launcher)
	current_scene = launcher
	await tick(2)
	check(flow.has_room("test_room_a") and flow.has_room("test_room_b"), "The launcher registers both sandbox rooms")
	check(launcher._lobby_buttons.size() == 4 and not launcher._lobby_buttons[0].disabled, "The launcher offers solo, host and join")
	launcher._lobby_buttons[0].pressed.emit()
	check(await wait_for(func() -> bool: return flow.get_current_room_id() == "test_room_a", "The launcher never entered Room A"), "Solo Student enters Room A")
	check(current_scene.scene_file_path == ROOM_A_SCENE and current_scene.role == "past" and not is_instance_valid(launcher), "The launcher is replaced by Room A as the Student")
	# Opening a room scene directly (F6 in the editor): it attaches itself and is fully usable.
	current_scene.free()
	await process_frame
	check(flow.get_current_room_id() == "", "No room is current once the scene is gone")
	puzzles.begin_session()
	var direct: Node3D = load(ROOM_A_SCENE).instantiate()
	root.add_child(direct)
	current_scene = direct
	await tick(6)
	check(flow.get_current_room_id() == "test_room_a" and direct.player != null, "A room opened directly attaches itself to the level flow")
	check(flow.request_transition("test_room_b") == "puzzle_incomplete", "The directly opened room enforces its prerequisites")
	await establish_link()
	var reason: String = flow.request_transition("test_room_b")
	check(reason == "", "It can transition once the link is established (got '%s')" % reason)
	check(await move_to_idle("The directly opened room could not transition"), "The transition out of the directly opened room finishes")
	check(flow.get_current_room_id() == "test_room_b" and current_scene.scene_file_path == ROOM_B_SCENE, "It arrived in Room B")


# --- Failure paths -------------------------------------------------------------------------

func test_failures() -> void:
	await fresh_solo("past")
	await establish_link()
	var a: RoomDef = flow.get_room("test_room_a")
	var session: int = puzzles.get_session_id()
	var state: Dictionary = puzzles.get_state(FREQ)
	var revision: int = puzzles.get_revision(FREQ)
	# Rooms reachable from A for the failure cases, all through runtime-registered definitions.
	var missing := make_room("missing_scene_room", "res://scenes/testing/not_here.tscn")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_DIRECTORY))
	var broken_file := FileAccess.open(BROKEN_LOAD_SCENE, FileAccess.WRITE)
	broken_file.store_string("[gd_scene format=3]\n\n[node name=\"BrokenLoadRoom\" type=\"Node3D\"]\nposition = Vector3(1, 2\n")
	broken_file.close()
	var broken_load := make_room("broken_load_room", BROKEN_LOAD_SCENE)
	var never_ready := make_room("never_ready_room", "res://tests/fixtures/never_ready_room.tscn")
	for definition in [missing, broken_load, never_ready]:
		check(flow.register_room(definition), "Failure-case room %s registers" % definition.room_id)
	a.allowed_exits = PackedStringArray(["missing_scene_room", "broken_load_room", "never_ready_room"])
	check(flow.request_transition("missing_scene_room") == "scene_missing", "A missing scene file is caught before anything fades")
	check(not flow.is_transitioning() and not flow.overlay.is_covering(), "Nothing changed after the early refusal")
	for case in [["broken_load_room", "scene_load_failed"]]:
		events.clear()
		check(flow.request_transition(case[0]) == "", "%s is accepted and then fails" % case[0])
		check(await move_to_idle("%s failure did not resolve" % case[0]), "%s failure resolves" % case[0])
		check(names().count("transition_failed") == 1 and events[index_of("transition_failed")][1] == case[1], "%s fails with %s" % [case[0], case[1]])
		check(names().count("transition_completed") == 0 and names().count("room_changed") == 0, "%s never reports success or swaps rooms" % case[0])
		check_still_in_room_a(session, state, revision, "after %s" % case[0])
	# A room that never finishes initialising: timeout, then the previous room is reloaded.
	flow.transition_timeout_seconds = 0.6
	events.clear()
	var old_room := current_scene
	check(flow.request_transition("never_ready_room") == "", "A room that never becomes ready is entered")
	check(await wait_for(func() -> bool: return flow.get_current_room_id() == "never_ready_room", "The never-ready room was never swapped in", 4.0), "The room is swapped in behind the black screen")
	check(flow.overlay.is_fully_black() and flow.is_input_locked(), "While it is not ready the screen stays black and input locked")
	check(await move_to_idle("The timeout did not resolve"), "The timeout resolves")
	flow.transition_timeout_seconds = 20.0
	check(events.filter(func(entry: Array) -> bool: return entry[0] == "transition_failed").map(func(entry: Array) -> String: return entry[1]) == ["timeout"], "The failure reason is timeout")
	check(current_scene != old_room and current_scene.scene_file_path == ROOM_A_SCENE, "Rollback reloaded a fresh Room A")
	check_still_in_room_a(session, state, revision, "after the timeout rollback")
	check(current_scene.radio.can_receive() and completions >= 1, "The reloaded room restores the radio link without replaying the completion")
	# A rollback that cannot load ends the session safely instead of leaving a dead room.
	var failures_before := failures
	var original_scene := a.shared_scene
	var fatal_reasons: Array = []
	flow.transition_failed.connect(func(reason: String) -> void: fatal_reasons.append(reason))
	flow.fallback_scene = "res://scenes/testing/transition_flow_sandbox.tscn"  # stand-in for the menu
	flow.transition_timeout_seconds = 0.6
	check(flow.request_transition("never_ready_room") == "", "Another never-ready transition starts")
	check(await wait_for(func() -> bool: return flow.get_current_room_id() == "never_ready_room", "Second never-ready room was not swapped in", 4.0), "It swaps in")
	a.shared_scene = "res://scenes/testing/vanished.tscn"  # the room we would roll back to disappears
	check(await move_to_idle("The fatal path did not resolve"), "The failure resolves")
	a.shared_scene = original_scene
	flow.transition_timeout_seconds = 20.0
	check(fatal_reasons.has("rollback_failed"), "An impossible rollback is reported as rollback_failed")
	check(flow.get_current_room_id() == "" and not flow.is_input_locked() and not flow.overlay.is_covering(), "No room is claimed and nothing stays locked or black")
	await tick(3)
	check(current_scene != null and current_scene.scene_file_path == flow.fallback_scene, "The fallback scene is shown")
	check(failures == failures_before, "No unexpected failures in the fatal path")
	a.allowed_exits = PackedStringArray()
	# A rollback that never becomes ready is also fatal instead of hanging on a black screen.
	var stuck_a := make_room("stuck_a", "res://tests/fixtures/never_ready_room.tscn", "stuck_b")
	var stuck_b := make_room("stuck_b", "res://tests/fixtures/never_ready_room.tscn")
	check(flow.register_room(stuck_a) and flow.register_room(stuck_b), "Two rooms that never become ready register")
	check(flow.start_room("stuck_a"), "A never-ready room can be the starting room")
	await tick(2)
	fatal_reasons.clear()
	flow.transition_timeout_seconds = 0.5
	check(flow.begin_transition("stuck_b") == "", "The stuck transition begins")
	check(await wait_for(func() -> bool: return fatal_reasons.has("rollback_timeout"), "No rollback_timeout was reported", 6.0), "A rollback that never settles ends as rollback_timeout")
	flow.transition_timeout_seconds = 20.0
	await tick(3)
	check(not flow.is_transitioning() and not flow.is_input_locked() and not flow.overlay.is_covering() and flow.get_current_room_id() == "", "Nothing stays locked, black or half-current")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BROKEN_LOAD_SCENE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GENERATED_DIRECTORY))


func check_still_in_room_a(session: int, state: Dictionary, revision: int, when: String) -> void:
	check(flow.get_current_room_id() == "test_room_a" and current_scene.scene_file_path == ROOM_A_SCENE, "Room A is still current " + when)
	check(not flow.is_transitioning() and not flow.is_input_locked() and not flow.overlay.is_covering(), "Nothing is locked or black " + when)
	check(current_scene.player.controls_enabled, "The player can move again " + when)
	check(puzzles.get_session_id() == session and puzzles.get_state(FREQ) == state and puzzles.get_revision(FREQ) == revision, "Session and puzzle progress are untouched " + when)
	check(count_nodes("CharacterBody3D") == 1 and root.get_child_count() == 5, "No duplicate characters or scenes " + when)
