extends SceneTree
## Quick journal check against the real game (offline solo preview): godot --headless -s tests/journal_system.gd
## Opens the notebook/DataPad through the journal input action, discovers entries via the real
## interactables, plays through the radio puzzle into Room 02, and checks separation and persistence.

const FREQ := "puzzle_01_frequency"
var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAILED  ") + what)
	if not ok:
		failures += 1


func tick(frames: int = 3) -> void:
	for i in frames:
		await process_frame


func press_journal() -> void:
	var event := InputEventAction.new()
	event.action = &"journal"
	event.pressed = true
	Input.parse_input_event(event)
	await tick()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var journal := root.get_node("JournalManager")
	var flow := root.get_node("GameFlowManager")
	var puzzles := root.get_node("PuzzleManager")
	check(journal.load_directory("res://resources/journal") == 0, "entries were already loaded once by the autoload")
	puzzles.offline_role = "past"
	puzzles.begin_session()
	check(flow.start_room("room_01"), "Room 01 starts")
	await tick(8)
	var lab: Node3D = current_scene
	lab.pause_when_unfocused = false
	lab._set_paused(false)

	# Student notebook
	check(InputMap.has_action(&"journal"), "journal input action exists")
	check(not journal.unlock_entry("future_frequency_log"), "Student cannot unlock a Future entry")
	var notebook := lab.find_child("ResearchNotebook", true, false)
	notebook.get_node("Interactable").interacted.emit(lab.player, "past")
	check(journal.is_unlocked("past_lab_notes"), "reading the research notebook unlocks Lab Experiment Notes")
	check(not journal.is_unlocked("future_recovered_notebook_page"), "the Student does not get the Professor's page")
	await press_journal()
	check(not journal.is_open(), "the journal refuses to open over the document viewer")
	lab.gameplay.close_overlays()
	await tick()
	await press_journal()
	check(journal.is_open() and not lab.player.controls_enabled, "J opens the notebook and freezes the player")
	var ui := journal.get_node("JournalUI")
	check(ui._role == "past" and ui._entries.size() == 1 and ui._title_label.text == "STUDENT'S NOTEBOOK", "notebook skin shows the Student's one entry")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await tick()
	check(not journal.is_open() and lab.player.controls_enabled and not lab.is_gameplay_paused(), "Escape closes the journal before the pause menu; controls return")
	await press_journal()
	await press_journal()
	check(not journal.is_open() and lab.player.controls_enabled, "J toggles closed again")

	# Professor DataPad
	lab.timeline = "Future"
	lab._apply_timeline()
	await tick(4)
	check(journal.get_unlocked_entries().is_empty(), "Professor starts with an empty DataPad (no leak from the Student)")
	var clue := lab.find_child("RecoveredLog", true, false)
	clue.interacted.emit(lab.player, "future")
	check(journal.is_unlocked("future_frequency_log"), "the recovered 67 MHz log is recorded for the Professor")
	check("67 MHz" in journal.get_entry("future_frequency_log").body, "entry carries the 67 MHz clue")
	lab.gameplay.close_overlays()
	await tick()
	await press_journal()
	check(journal.is_open() and ui._role == "future" and ui._title_label.text == "RESEARCH DATAPAD", "J opens the DataPad skin")
	journal.close_journal()
	await tick()
	check(lab.player.controls_enabled, "controls restored after the DataPad closes")

	# Radio puzzle -> confirmed anomaly entries, then Room 02
	puzzles.submit_action(FREQ, "acquire_radio", {"radio_role": "past"}, "past")
	puzzles.submit_action(FREQ, "acquire_radio", {"radio_role": "future"}, "future")
	puzzles.submit_action(FREQ, "tune_frequency", {"frequency": 67}, "past")
	puzzles.submit_action(FREQ, "tune_amplitude", {"amplitude": 70}, "past")
	await tick(4)
	check(journal.is_unlocked("future_fracture_observation"), "completing the link unlocks the Professor's fracture observation")
	check(not journal.is_unlocked("past_temporal_anomaly", "future") and not journal.is_unlocked("past_temporal_anomaly"), "...and not the Student's anomaly note while playing the Professor")
	check(flow.begin_transition("room_02") == "", "Room 02 transition begins")
	var waited := 0
	while (flow.get_current_room_id() != "room_02" or flow.is_transitioning()) and waited < 600:
		await process_frame
		waited += 1
	check(flow.get_current_room_id() == "room_02", "arrived in Room 02")
	await tick(10)
	check(journal.is_unlocked("future_frequency_log"), "Frequency Log still unlocked in Room 02")
	await press_journal()
	check(journal.is_open() and journal.get_node("JournalUI")._entries.size() == 2, "DataPad opens in Room 02 with both Professor entries")
	journal.close_journal()
	puzzles.offline_role = "past"
	check(journal.get_unlocked_entries().size() == 1 and journal.get_unlocked_entries()[0].entry_id == "past_lab_notes", "back as the Student, only the Student's entry is present")

	puzzles.begin_session()
	check(journal.get_unlocked_entries().is_empty() and journal.get_unlocked_entries("future").is_empty(), "a new session clears the journal")
	print("JOURNAL CHECK %s" % ("FAILED" if failures > 0 else "OK"))
	quit(1 if failures > 0 else 0)
