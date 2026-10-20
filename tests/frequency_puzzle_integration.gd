extends SceneTree
## Real scenes, input controller, UI, sound bridge and room teardown. Dialogue is a
## public-API test double because the DialogueDirector is absent in this checkout.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status

var manager: Node
var sandbox: Node3D
var checks: int = 0
var failures: int = 0
var link_events: int = 0
var requests: Array = []
var cues: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func tick(frames: int = 5) -> void:
	for i in range(frames):
		await physics_frame
	await process_frame


func capture(filename: String) -> void:
	var directory := OS.get_environment("RADIO_REVIEW_DIR")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(filename + ".png")) == OK, "Save visual review " + filename)


func _run() -> void:
	manager = root.get_node("PuzzleManager")
	manager.log_rejections = false
	sandbox = load("res://scenes/testing/frequency_puzzle_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	manager.begin_session()
	await tick()
	var radio: Node = sandbox.radio
	var terminal: Control = sandbox.terminal
	var controller: Node = sandbox.player.get_node("InteractionRig/InteractionController")
	var hud: Control = sandbox.get_node("HUD/RadioHUD")
	var pickup: Area3D = sandbox.room.get_node("PastStation/RadioPickup")
	var future_pickup: Area3D = sandbox.room.get_node("FutureStation/RadioPickup")
	var clue: Area3D = sandbox.room.get_node("ResearchLog")
	var view: PanelContainer = sandbox.dialogue_view
	var adapter: Node = sandbox.dialogue_adapter
	adapter.temporal_radio_link_established.connect(func(): link_events += 1)
	radio.audio_cue_requested.connect(func(cue: StringName): cues.append(cue))
	check(not terminal.visible and sandbox.player.controls_enabled, "Terminal starts closed and controls remain usable")
	check(not radio.owns_radio and radio.signal_state == 0, "Unowned radio is disconnected")
	check(hud.status_label.text == "RADIO NOT ACQUIRED", "HUD reflects no ownership")
	check(not future_pickup.can_interact(sandbox.player, "past"), "Past cannot interact with Future pickup")
	check(not clue.can_interact(sandbox.player, "past"), "Past cannot read Future clue")
	check("67 MHz" in clue.research_text, "Scientific research clue contains 67 MHz")
	await capture("01_lab")
	sandbox.player.position = Vector3(-3, 0, 1)
	await tick()
	check(controller.get_current_interactable() == pickup, "Existing detector selects nearby radio")
	check(controller.try_interact(), "Existing controller performs radio acquisition")
	check(radio.owns_radio and radio.signal_state == 1, "Confirmed pickup enables searching")
	check(not pickup.placeholder.visible and not pickup.interaction_enabled, "Confirmed pickup hides replaceable mesh")
	check(hud.status_label.text == "SEARCHING" and hud.frequency_label.text == "-- MHz", "HUD responds to ownership without revealing the Future research clue")
	check(not adapter.request_conversation(&"test.radio_check"), "Cannot transmit before connection")
	sandbox.player.position = Vector3(-4, 0, -2)
	await tick()
	check(controller.get_current_interactable() == sandbox.room.get_node("Computer"), "Detector selects calibration computer")
	check(controller.try_interact() and terminal.visible, "Computer opens actual terminal through interaction API")
	check(not sandbox.player.controls_enabled and not controller.is_interaction_available(), "Modal blocks movement and underlying interaction")
	await capture("02_terminal")
	for text in ["", "0", "abc", "1.5", "-1"]:
		terminal.frequency_input.text = text
		terminal._validate_text(text)
		check(terminal.calibrate_button.disabled, "Invalid numeric input disables calibration: %s" % text)
	check(terminal.submit_frequency().status == Status.REJECTED, "Invalid text never submits an action")
	terminal.frequency_input.text = "66"
	terminal._validate_text("66")
	check(not terminal.calibrate_button.disabled, "Whole-number input enables calibration")
	var revision: int = manager.get_revision(Rules.ID)
	check(terminal.submit_frequency().status == Status.NO_CHANGE, "Wrong frequency is retryable")
	check("SIGNAL NOT FOUND" in terminal.feedback_label.text, "Wrong-frequency feedback is visible")
	await capture("03_wrong_frequency")
	check(manager.get_revision(Rules.ID) == revision, "Wrong frequency leaves revision unchanged")
	terminal.frequency_input.text = "67"
	terminal._validate_text("67")
	check(terminal.submit_frequency().status == Status.CHANGED, "Correct calibration waits for second radio")
	check(terminal.status_label.text == "SIGNAL LOCKED" and link_events == 0, "No completion before both pickups")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	terminal._input(escape)
	check(not terminal.visible, "Escape closes the modal")
	check(sandbox.player.controls_enabled, "Closing restores player movement")
	manager.offline_role = "future"
	sandbox._apply_role()
	sandbox.player.position = Vector3(3, 0, 1)
	await tick()
	check(controller.get_current_interactable() == future_pickup, "Future detector selects its own radio")
	check(controller.try_interact(), "Professor acquires own radio through interaction controller")
	check(manager.is_solved(Rules.ID) and radio.can_receive(), "Final prerequisite establishes confirmed link")
	check(link_events == 1, "Confirmed completion exposes exactly one narrative hook")
	check(cues.count(&"connected") == 1, "Confirmed completion requests one radio connection sound")
	check(hud.status_label.text == "CONNECTED", "HUD reflects connection")
	check(terminal.status_label.text == "TEMPORAL RADIO LINK ESTABLISHED", "Terminal shows required success message")
	check(not future_pickup.placeholder.visible, "Professor pickup mesh disappears after confirmation")
	check(adapter.active_sequence_id == &"sandbox.radio_check" and view.speaker_label.text == "Student", "Confirmed link triggers sandbox scripted sequence by ID")
	view.reveal_line()
	view.request_advance()
	check(view.speaker_label.text == "Professor", "Temporary scripted UI alternates to Professor")
	view.reveal_line()
	await capture("04_radio_dialogue")
	for i in range(3):
		view.reveal_line()
		view.request_advance()
	check(adapter.active_sequence_id.is_empty() and not view.visible, "Temporary scripted conversation completes and releases the view")
	check(not terminal.open_for(sandbox.player, "future"), "Future cannot open the Past terminal")
	sandbox.player.position = Vector3(4, 0, -2)
	await tick()
	check(controller.get_current_interactable() == clue and controller.try_interact(), "Professor opens research document through interaction system")
	check(sandbox.reader.visible and "67 MHz" in sandbox.reader.document_label.text, "Future research reader presents the clue")
	await capture("05_future_research")
	sandbox.reader.close()
	check(sandbox.player.controls_enabled, "Reader releases movement")
	# The real integrator will resolve sequence IDs using DialogueDirector's eventual API.
	adapter.end_conversation()
	cues.clear()
	var sequence: StringName = &"test.radio_check"
	adapter.bind_sequence_player(func(sequence_id: StringName):
		requests.append(sequence_id)
		return true)
	check(not adapter.request_conversation(sequence, "past"), "Past-specific sequence does not run on Future view")
	check(adapter.request_conversation(sequence, "future"), "Future-specific sequence reaches director binding")
	adapter.end_conversation()
	check(adapter.request_conversation(sequence, "shared"), "Shared sequence reaches director binding")
	check(requests.size() == 2 and requests[0] == sequence, "Adapter forwards the supplied sequence ID")
	check(adapter.present_line("Student", "Diagnostic line from the existing director."), "Dialogue API can present a Student line")
	check(view.speaker_label.text == "Student" and view.text_label.visible_characters == 0, "Speaker and typewriter initialize correctly")
	view.reveal_line()
	check(view.text_label.visible_characters == -1, "Typewriter may reveal the current line")
	check(adapter.present_line("Professor", "Reply supplied by the director."), "Alternating Professor line uses the same radio view")
	check(view.speaker_label.text == "Professor" and radio.transmitting, "Alternating speaker is displayed with transmission animation")
	check(cues.count(&"incoming") == 2, "Each incoming line requests a transmission cue")
	revision = manager.get_revision(Rules.ID)
	radio.interfere(0.05)
	check(not radio.can_receive() and view.advance_button.disabled and &"static" in cues, "Temporary interference updates view and requests static")
	await create_timer(0.12).timeout
	check(radio.can_receive() and not view.advance_button.disabled, "Signal recovers after interference")
	check(manager.get_revision(Rules.ID) == revision and manager.is_solved(Rules.ID), "Interference does not change authoritative link")
	radio.set_presentation_active(false)
	check(hud.status_label.text == "RADIO STOWED" and not radio.can_receive(), "Deactivation affects local presentation")
	check(manager.is_solved(Rules.ID), "Stowing leaves persistent connection intact")
	radio.set_presentation_active(true)
	check(radio.can_receive(), "Activation restores radio presentation")
	adapter.end_conversation()
	check(not view.visible and not radio.transmitting, "Dialogue completion clears the view and transmission")
	# Narrative event and confirmed completion hooks pass IDs to the future integration.
	adapter.event_sequence_ids["later_event"] = &"test.later_conversation"
	check(adapter.request_event("later_event") and requests[-1] == &"test.later_conversation", "Narrative events can request a subsequent conversation")
	adapter.end_conversation()
	adapter.event_sequence_ids["later_puzzle"] = &"test.puzzle_conversation"
	manager.register_puzzle("later_puzzle", load("res://scripts/puzzles/implementations/power_switch_puzzle.gd").new())
	manager.submit_action("later_puzzle", "activate_power", {}, "past")
	check(adapter.active_sequence_id == &"test.puzzle_conversation", "Confirmed later puzzle completion triggers a radio conversation")
	adapter.end_conversation()
	# Unload the actual room and create another presenter, keeping only the autoload state.
	var session: int = manager.get_session_id()
	sandbox.room.free()
	var next_room: Node3D = load("res://scenes/gameplay/frequency/temporal_link_indicator.tscn").instantiate()
	sandbox.room = next_room
	sandbox.add_child(next_room)
	check(next_room.connected and manager.get_session_id() == session, "New room presenter immediately shows retained connection")
	check(link_events == 1, "Room entry does not replay narrative completion")
	manager.offline_role = "past"
	radio.set_player_role("past")
	check(terminal.open_for(sandbox.player, "past"), "Student can reopen the completed terminal")
	check(terminal.frequency_input.text == "67" and terminal.calibrate_button.disabled, "Reopening shows locked frequency")
	await capture("06_connected_terminal")
	terminal.close()
	# Destroy and recreate the terminal itself after success.
	var other_terminal: Control = load("res://scenes/gameplay/frequency/frequency_terminal_ui.tscn").instantiate()
	root.add_child(other_terminal)
	check(other_terminal.status_label.text == "TEMPORAL RADIO LINK ESTABLISHED" and other_terminal.frequency_input.text == "67", "Fresh terminal queries confirmed state")
	other_terminal.open_for(sandbox.player, "past")
	other_terminal.free()
	check(sandbox.player.controls_enabled, "Unloading an open modal restores controls")
	manager.begin_session()
	check(not radio.owns_radio and radio.signal_state == 0, "Session reset clears radio component state")
	check(hud.status_label.text == "RADIO NOT ACQUIRED" and not next_room.connected, "Session reset updates HUD and new room indicator")
	check(not view.visible and adapter.active_sequence_id.is_empty() and link_events == 1, "Reset hides dialogue and clears pending presentation without replaying completion")
	# Audio mixing releases playbacks asynchronously. Stop before destroying the owned
	# scene and allow a mixer cycle before process shutdown, including the dummy driver.
	sandbox.get_node("AudioSystem").stop_all_sfx()
	sandbox.audio_bridge.stop_static()
	sandbox.free()
	await create_timer(0.1).timeout
	print("FREQUENCY INTEGRATION: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
