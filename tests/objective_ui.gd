extends SceneTree
## Objective HUD and Mission Log against the REAL rooms (offline, headless):
##   godot --headless --path . --script res://tests/objective_ui.gd
## Opens and closes the log with a real key, the Create/View button, the HUD button and Escape / B,
## and checks that the player is locked (and unlocked again exactly as before) in all three rooms,
## that nothing is paused, that the journal cannot be opened on top of it, and that every word the log
## shows is spoiler-safe. Rooms recompute their own controls every frame, so the lock is held for many
## frames, not just checked once.

const F1 := "puzzle_01_frequency"
const SPOILERS := ["3142", "67 MHz", "70%", "2, 0, 1", "GROUND THE CORE", "CLAIM ORIGIN", "RELEASE THE ECHO",
	"PRESERVE ECHO", "paradox", "ITERATION", "erased", "extract"]

var puzzles: Node
var flow: Node
var objectives: Node
var journal: Node
var failures: int = 0
var checks: int = 0
var completions: Array[String] = []
var closed_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)
	await frames(1)


func pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)
	await frames(1)


func room() -> Node:
	return flow.get_current_room_node()


## Untyped on purpose: naming ObjectiveTracker / MissionLog here would compile them before the
## autoload globals they use exist (a --script launch quirk; the game itself is unaffected).
func tracker() -> Node:
	return objectives.tracker


func log_layer() -> Node:
	return objectives.mission_log


func texts_of(node: Node) -> Array[String]:
	var result: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		result.append((label as Label).text)
	for button in node.find_children("*", "Button", true, false):
		result.append((button as Button).text)
	return result


func start_room(room_id: String, role: String) -> void:
	puzzles.offline_role = role
	puzzles.begin_session()
	if room_id != "room_01":
		var Freq := load("res://scripts/puzzles/implementations/frequency_puzzle.gd")
		puzzles.register_puzzle(Freq.ID, Freq.new())
		puzzles.submit_action(Freq.ID, "acquire_radio", {"radio_role": "past"}, "past")
		puzzles.submit_action(Freq.ID, "acquire_radio", {"radio_role": "future"}, "future")
		puzzles.submit_action(Freq.ID, "tune_frequency", {"frequency": 67}, "past")
		puzzles.submit_action(Freq.ID, "tune_amplitude", {"amplitude": 70}, "past")
	check(flow.start_room(room_id), "Room %s starts" % room_id)
	await frames(60)


func _run() -> void:
	puzzles = root.get_node("PuzzleManager")
	flow = root.get_node("GameFlowManager")
	objectives = root.get_node("ObjectiveManager")
	journal = root.get_node("JournalManager")
	puzzles.log_rejections = false
	flow.log_problems = false
	var Tutorial := load("res://scripts/ui/tutorial_popup.gd")
	Tutorial.config_path = "user://objective_ui_test_tutorial.cfg"
	Tutorial.mark_shown()
	objectives.objective_completed.connect(func(role: String, id: String) -> void: completions.append(role + ":" + id))
	objectives.log_closed.connect(func() -> void: closed_count += 1)

	await _laboratory()
	await _corridor()
	await _reactor()
	await _restart_from_corridor()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://objective_ui_test_tutorial.cfg"))
	print("OBJECTIVE UI: ", "PASS" if failures == 0 else "FAIL", " (%d checks, %d failures)" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _laboratory() -> void:
	await start_room("room_01", "past")
	var lab: Node = room()
	var player: CharacterBody3D = lab.player
	var controller: Node = lab.gameplay.controller
	check(objectives.has_content() and objectives.get_current("past").objective_id == "student_l1_find_radio", "The laboratory starts the Student's first objective")

	# --- The HUD card -----------------------------------------------------------------------
	var card: PanelContainer = tracker().get_node("Root/Anchor/Card")
	check(card.visible and card.modulate.a > 0.95, "The objective card is visible during play")
	check(card.global_position.y > 52.0 and card.global_position.x < 40.0, "The card sits in the upper-left, below the room's top bar")
	var card_texts := texts_of(card)
	check("Find the Handheld Radio" in card_texts and "CURRENT OBJECTIVE" in card_texts, "The card shows the heading and the title")
	check("SIGNAL LABORATORY" in card_texts, "The card names the chapter")
	check(tracker()._bar.color == Typography.PAST_ACCENT, "The Student's card uses the warm amber accent")
	check(tracker()._icon.kind == &"radio", "The card carries an objective icon")
	check(card_texts.any(func(text: String) -> bool: return text == "M"), "The log button shows its shortcut")
	check(card.size.y < 190.0 and card.size.x <= 380.0, "The card stays compact (%s)" % str(card.size))

	# --- Opening and closing ----------------------------------------------------------------
	check(player.controls_enabled and not controller._interaction_blocked, "Before opening, the player is free")
	await key(KEY_M)
	check(objectives.is_log_open() and log_layer().is_showing(), "M opens the Mission Log")
	check(not paused, "Opening the log does not pause the game")
	check(not flow.is_input_locked() and not flow.is_transitioning(), "Opening the log does not start a level-flow lock")
	check(not player.controls_enabled and controller._interaction_blocked, "The player cannot move or interact while it is open")
	await create_timer(0.6).timeout  # real time: the fade is time-based
	check(not card.visible or card.modulate.a < 0.5, "The HUD card steps aside while the log is open")
	await frames(40)
	check(not player.controls_enabled and player.velocity == Vector3.ZERO, "The room cannot re-enable controls under the log")
	check(get_root_focus_name() == "CurrentObjective", "Focus lands on the current objective for keyboard and controller")
	check(log_layer().get_index() == root.get_child_count() - 1, "The log is the last root node, so it hears Escape before any room")
	check(texts_of(log_layer()).has("MISSION LOG") and texts_of(log_layer()).has("YOUR JOURNEY THROUGH TIME"), "Title and subtitle")
	check(texts_of(log_layer()).any(func(text: String) -> bool: return text.begins_with("CLOSE")), "There is an obvious CLOSE button")

	# Things that must not leak through to the room or the journal while it is open.
	await key(KEY_J)
	check(not journal.is_open(), "The journal cannot be opened on top of the log")
	await key(KEY_ESCAPE)
	check(not objectives.is_log_open(), "Escape closes the log")
	check(not lab._paused and not lab.pause_panel.visible, "...and does not also open the pause menu")
	await frames(6)
	check(player.controls_enabled and not controller._interaction_blocked, "Closing restores movement and interaction exactly")
	check(closed_count == 1, "Closed once")

	await key(KEY_M)
	await key(KEY_M)
	check(not objectives.is_log_open(), "M toggles it closed again")
	await pad(JOY_BUTTON_BACK)
	check(objectives.is_log_open(), "The View / Create button opens it")
	await pad(JOY_BUTTON_B)
	check(not objectives.is_log_open() and player.controls_enabled, "B / Circle closes it")
	await pad(JOY_BUTTON_TOUCHPAD)
	check(objectives.is_log_open(), "The DualSense touchpad opens it")
	var back_button: Button = log_layer().get_node("Root/Frame").find_child("CloseButton", true, false)
	back_button.pressed.emit()
	check(not objectives.is_log_open(), "The CLOSE button closes it")
	var hud_button: Button = tracker().find_child("MissionLogButton", true, false)
	check(not hud_button.disabled, "The HUD button is available during play")
	hud_button.pressed.emit()
	check(objectives.is_log_open(), "Clicking the HUD button opens it")
	await frames(3)
	var dim: Control = log_layer().get_node("Root/Dim")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(4.0, 4.0)
	outside.global_position = Vector2(4.0, 4.0)
	dim.gui_input.emit(outside)
	check(not objectives.is_log_open(), "Clicking outside the panel closes it")

	# --- What the panel says ----------------------------------------------------------------
	await key(KEY_M)
	var all_text := " | ".join(texts_of(log_layer()))
	for banned: String in SPOILERS:
		check(not all_text.to_lower().contains(banned.to_lower()), "The Student's log never shows '%s'" % banned)
	for professor_only in ["Investigate the Damaged Terminal", "Guide the Calibration", "Charge the Emergency Cell", "Read the Routing Diagram"]:
		check(not all_text.contains(professor_only), "The Student's log never shows the Professor's '%s'" % professor_only)
	var rows := texts_of(log_layer())
	check(rows.count("Undiscovered Objective") >= 2 and rows.count("LOCKED") >= 2 and rows.count("???") >= 2, "Locked steps read 'Undiscovered Objective' / '???'")
	check(rows.has("COMPLETED OBJECTIVES") and rows.has("CURRENT OBJECTIVE") and rows.has("UPCOMING OBJECTIVES"), "Three categories")
	check(rows.has("UNCHARTED AREA") and not rows.has("Maintenance Corridor") and not rows.has("MAINTENANCE CORRIDOR") and not rows.has("THE FINAL FRACTURE"), "Later chapters are anonymous")
	check(rows.has("Calibrate the Signal") and rows.has("UP NEXT") and not rows.has("Leave Through the Security Door"), "Only the very next step is visible, muted; the one after is locked")
	var scroll: ScrollContainer = log_layer().find_child("Scroll", true, false)
	check(scroll.follow_focus and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "The list scrolls and follows controller focus")
	await key(KEY_M)

	# --- A real completion: HUD updates, notice appears once -------------------------------------
	var before := completions.size()
	puzzles.submit_action(F1, "acquire_radio", {"radio_role": "past"}, "past")
	await frames(10)
	check(completions == ["past:student_l1_find_radio"] or completions.size() == before + 1, "Exactly one completion notice for the radio")
	var notice: PanelContainer = tracker().get_node("Root/Anchor/CompletedNotice")
	check(notice.visible and texts_of(notice).has("OBJECTIVE COMPLETED") and texts_of(notice).has("Find the Handheld Radio"), "The 'OBJECTIVE COMPLETED' notice shows the title")
	check(tracker()._stream != null and tracker()._player != null, "A completion sound is loaded from the game's own UI catalog")
	check("Calibrate the Signal" in texts_of(card) and tracker()._updated.visible, "The HUD moved on to calibration and flags the change")
	await frames(10)
	# The partner's progress must not touch this player's objective.
	puzzles.submit_action(F1, "acquire_radio", {"radio_role": "future"}, "future")
	await frames(10)
	check(completions.size() == before + 1, "Partner's progress is not announced as the Student's")
	check("Calibrate the Signal" in texts_of(card), "The Student's objective is unchanged by the Professor's progress")

	check(lab.gameplay.director.is_dialogue_active(), "The radio pickup starts a conversation of its own")
	check(not objectives.can_open_log(), "The log will not open over a dialogue")
	lab.gameplay.director.stop_dialogue()
	await frames(5)

	# --- Blocked while something else owns the screen ----------------------------------------
	lab._set_paused(true)
	await frames(3)
	check(not objectives.can_open_log(), "The log refuses to open over the pause menu")
	await key(KEY_M)
	check(not objectives.is_log_open(), "M does nothing while paused")
	lab._set_paused(false)
	await frames(3)
	journal.open_journal()
	await frames(3)
	check(journal.is_open() and not objectives.can_open_log(), "...or over the journal")
	await key(KEY_M)
	check(not objectives.is_log_open(), "M does nothing while the journal is open")
	journal.close_journal()
	await frames(3)

	# --- Reduced motion ---------------------------------------------------------------------
	var manager := root.get_node("CinematicTransitionManager")
	manager.reduced_motion_override = true
	var frame: Control = log_layer().get_node("Root/Frame")
	objectives.open_log()
	var rest := frame.position
	check(frame.position == rest and frame.position.y == roundf((root.get_visible_rect().size.y - frame.size.y) * 0.5), "Reduced motion: the panel only fades, it does not slide")
	objectives.close_log()
	await frames(20)
	manager.reduced_motion_override = false
	objectives.open_log()
	check(frame.position.y > rest.y, "Normal motion: the panel starts lower and slides up")
	await create_timer(0.6).timeout
	check(is_equal_approx(frame.position.y, rest.y), "...and settles at rest")

	# --- A level transition closes it -------------------------------------------------------
	flow.transition_started.emit("room_01", "room_02")
	check(not objectives.is_log_open(), "A level transition closes the log")
	await frames(10)
	check(player.controls_enabled, "...and gives control back")

	# --- Switching the previewed timeline shows the other player's own list ----------------------------
	lab._switch_preview_timeline()
	await frames(20)
	check(objectives.get_local_role() == "future" and "Investigate the Damaged Terminal" in texts_of(card), "Professor's card shows the Professor's own current objective")
	check(not ("Calibrate the Signal" in texts_of(card)), "...not the Student's")
	check(tracker()._bar.color == Typography.FUTURE_ACCENT, "The Professor's card uses cyan")
	check("Search the ruins for information about the signal." in texts_of(card), "...with the Professor's own summary")
	await key(KEY_M)
	check(objectives.is_log_open(), "The Professor can open the log")
	var future_text := " | ".join(texts_of(log_layer()))
	check(not future_text.contains("Calibrate the Signal") and future_text.contains("PROFESSOR · FUTURE"), "The Professor's log shows nothing from the Student's list")
	await key(KEY_M)
	puzzles.offline_role = "past"
	lab._switch_preview_timeline()
	await frames(10)


func get_root_focus_name() -> String:
	var owner := root.gui_get_focus_owner()
	return "" if owner == null else String(owner.name)


func _corridor() -> void:
	await start_room("room_02", "past")
	var corridor: Node = room()
	var player: CharacterBody3D = corridor.player
	check(objectives.get_current("past").objective_id == "student_l2_isolate_service", "Corridor: Student starts with the service circuit")
	check(objectives.is_completed("student_l1_exit", "past") and objectives.is_completed("student_l1_calibrate", "past"), "Corridor: the laboratory's objectives are already in the history")
	check(objectives.get_completed("past").size() == 3, "Corridor: history has the three laboratory objectives")
	await key(KEY_M)
	check(objectives.is_log_open(), "Corridor: the log opens")
	await frames(30)
	check(not player.controls_enabled, "Corridor: the room's per-frame control sync cannot unlock the player")
	check(corridor.controller._interaction_blocked, "Corridor: interactions stay blocked")
	await key(KEY_ESCAPE)
	check(not objectives.is_log_open() and not corridor._paused, "Corridor: Escape closes the log and does not pause")
	await frames(4)
	check(player.controls_enabled and not corridor.controller._interaction_blocked, "Corridor: control returns")
	var texts := " | ".join(texts_of(tracker()))
	check(texts.contains("MAINTENANCE CORRIDOR") and texts.contains("Isolate the Service Circuit"), "Corridor: the card names the chapter and the task")
	var card: Control = tracker().get_node("Root/Anchor/Card")
	check(card.global_position.y > corridor.find_child("Header", true, false).size.y + 12.0, "Corridor: the card does not overlap the room's header")


func _reactor() -> void:
	await start_room("room_03", "future")
	var core: Node = room()
	check(objectives.get_current("future").objective_id == "professor_l3_records", "Reactor: Professor starts by examining the records")
	check(objectives.get_current("past").objective_id == "student_l3_records", "Reactor: the Student's own list started too (offline)")
	check(objectives.get_completed("future").is_empty() or objectives.get_completed("future").size() <= 4, "Reactor: earlier chapters that were never played are not claimed as done")
	var card: Control = tracker().get_node("Root/Anchor/Card")
	check(card.visible and card.global_position.y >= 140.0, "Reactor: the card sits below the room's own header")
	await key(KEY_M)
	check(objectives.is_log_open() and not core.player.controls_enabled, "Reactor: the log opens and locks the player")
	var shown := texts_of(log_layer())
	check(shown.has("THE FINAL FRACTURE") or shown.has("Examine the Recovered Recording"), "Reactor: the log shows the chapter")
	check(not shown.has("Make Your Final Decision") and shown.count("Undiscovered Objective") >= 3, "Reactor: the secret final decision is not named in advance")
	await frames(30)
	check(not core.player.controls_enabled, "Reactor: the room cannot re-enable controls under the log")
	var clock_before: float = puzzles.get_state("puzzle_03_final_fracture").get("remaining", 0.0)
	await key(KEY_ESCAPE)
	check(not objectives.is_log_open() and not core.ui.visible_modal, "Reactor: Escape closes the log and opens no menu")
	await frames(4)
	check(core.player.controls_enabled, "Reactor: control returns")
	check(clock_before == puzzles.get_state("puzzle_03_final_fracture").get("remaining", 0.0), "Reactor: the log does not touch the shared reactor state")


## "Restart chapter from laboratory" begins a session while still in the corridor, then changes scene.
func _restart_from_corridor() -> void:
	await start_room("room_02", "past")
	puzzles.submit_action("puzzle_02_maintenance", "isolate_service", {}, "past")
	await frames(10)
	check(objectives.get_completed("past").size() >= 4, "Restart: there is progress to throw away")
	puzzles.begin_session()
	puzzles.offline_role = "past"
	change_scene_to_file.call_deferred("res://scenes/world/spawn_area.tscn")
	await frames(60)
	check(flow.get_current_room_id() == "room_01", "Restart: back in the laboratory")
	check(objectives.get_completed("past").is_empty() and objectives.get_completed("future").is_empty(), "Restart: both histories are cleared")
	check(objectives.get_current("past").objective_id == "student_l1_find_radio", "Restart: the Student's starting objective is restored, not the corridor's")
	check(objectives.get_current("future").objective_id == "professor_l1_find_radio", "Restart: so is the Professor's")
	var texts := " | ".join(texts_of(tracker()))
	check(texts.contains("SIGNAL LABORATORY") and not texts.contains("MAINTENANCE CORRIDOR"), "Restart: the HUD names the laboratory again")
