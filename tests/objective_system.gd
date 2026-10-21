extends SceneTree
## Objective tracker checks against the real autoloads and the real puzzle rules (offline, headless):
##   godot --headless --path . --script res://tests/objective_system.gd
## 1. The data: every objective is valid, points at things that exist, and is spoiler-safe.
## 2. The condition vocabulary on its own.
## 3. A full playthrough of Levels 1-3 for both timelines through PuzzleManager.submit_action, checking
##    after every step which objective each role sees, what completed, and what was announced.
## 4. Persistence across rooms, silent reconstruction, campaign restart, repeated reactor attempts.
## Nothing is mocked except the reactor's proximity gate; the rules, autoloads and journal are real.

const Freq := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Corridor := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const Core := preload("res://scripts/level3/core_rules.gd")
const Story := preload("res://scripts/level3/core_story.gd")

const F1 := "puzzle_01_frequency"
const M2 := "puzzle_02_maintenance"
const C3 := "puzzle_03_final_fracture"

## Nothing a tracker shows may contain these: codes, answers, outcomes of private choices.
const SPOILERS := ["3142", "67 MHz", "67MHz", "70%", "2, 0, 1", "[2,0,1]", "GROUND THE CORE", "CLAIM ORIGIN",
	"RELEASE THE ECHO", "PRESERVE ECHO", "paradox", "ITERATION", "erased", "trust", "override", "4.8 kg",
	"2.6 kg", "7.2 kg", "R-17", "K-04", "M-22", "extract"]
## Knowledge that only the other timeline has.
const STUDENT_MUST_NOT_SAY := ["routing", "datapad", "continuity", "recovered recording", "receiver trace", "archive",
	"live receiver", "reading corner", "manifest"]
const PROFESSOR_MUST_NOT_SAY := ["notebook", "handwritten", "authorization sheet", "pressure plate", "isolator", "keypad"]

var puzzles: Node
var flow: Node
var objectives: Node
var journal: Node
var corridor_rules: Corridor
var failures: int = 0
var checks: int = 0
var announced: Array[String] = []   # "role:id" for every live completion, in order
var activations: Array[String] = []
var rooms: Array[Node] = []
var core_seq: Dictionary = {"past": 0, "future": 0}


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)


func settle() -> void:
	# Evaluation is deferred, and a reset looks at the current room two frames later.
	for i in 5:
		await process_frame


## Offline, one machine plays both timelines and only the one being played is told about progress,
## so each action is performed as the role that takes it.
func act(puzzle: String, action: String, role: String, payload: Dictionary = {}) -> Dictionary:
	puzzles.offline_role = role
	var result: Dictionary = puzzles.submit_action(puzzle, action, payload, role)
	await settle()
	return result


## Room C actions carry the attempt and a per-role sequence number.
func act3(action: String, role: String, extra: Dictionary = {}) -> Dictionary:
	core_seq[role] += 1
	var payload := extra.duplicate()
	payload.attempt = puzzles.get_state(C3).attempt
	payload.seq = core_seq[role]
	return await act(C3, action, role, payload)


func current_key(role: String) -> String:
	var definition: ObjectiveDefinition = objectives.get_current(role)
	return "" if definition == null else definition.objective_id.trim_prefix("student_").trim_prefix("professor_")


func done(role: String, key: String) -> bool:
	return objectives.is_completed(("student_" if role == "past" else "professor_") + key, role)


func announced_count(role: String, key: String) -> int:
	return announced.count(role + ":" + ("student_" if role == "past" else "professor_") + key)


func enter_room(room_id: String) -> void:
	var node := Node.new()
	node.name = "TestRoom_" + room_id
	root.add_child(node)
	rooms.append(node)
	check(flow.attach_room(room_id, node), "Room %s should attach" % room_id)
	await settle()


## Back to a place that is not a room (the menu): what a real new campaign starts from.
func leave_rooms() -> void:
	for node in rooms:
		node.queue_free()
	rooms.clear()
	await settle()


func unlock_entry(role: String, entry_id: String) -> void:
	var previous: String = puzzles.offline_role
	puzzles.offline_role = role
	check(journal.unlock_entry(entry_id), "%s should unlock journal entry %s" % [role, entry_id])
	puzzles.offline_role = previous
	await settle()


func _run() -> void:
	puzzles = root.get_node("PuzzleManager")
	flow = root.get_node("GameFlowManager")
	objectives = root.get_node("ObjectiveManager")
	journal = root.get_node("JournalManager")
	puzzles.log_rejections = false
	flow.log_problems = false
	objectives.objective_completed.connect(func(role: String, id: String) -> void: announced.append(role + ":" + id))
	objectives.objective_activated.connect(func(role: String, id: String) -> void: activations.append(role + ":" + id))
	corridor_rules = Corridor.new()
	puzzles.register_puzzle(F1, Freq.new())
	puzzles.register_puzzle(M2, corridor_rules)
	_register_evidence()
	puzzles.begin_session()
	await settle()

	_test_definitions()
	_test_conditions()
	_test_input_map()
	await _test_before_any_room()
	await _test_level_one()
	await _test_level_two()
	await _test_level_three()
	await _test_persistence_and_restart()
	await _test_reconstruction()
	await _test_reactor_restart()

	for node in rooms:
		node.queue_free()
	await settle()
	print("OBJECTIVE SYSTEM: ", "PASS" if failures == 0 else "FAIL", " (%d checks, %d failures)" % [checks, failures])
	quit(0 if failures == 0 else 1)


## Room C registers its evidence pages as journal entries when it loads; do the same here.
func _register_evidence() -> void:
	for id: String in Story.EVIDENCE:
		var data: Array = Story.EVIDENCE[id]
		var entry := JournalEntry.new()
		entry.entry_id = data[0]
		entry.title = data[1]
		entry.body = data[2]
		entry.timeline = JournalEntry.Timeline.PAST if id in ["evidence_past", "warning"] else JournalEntry.Timeline.FUTURE
		journal.register_entry(entry)


# --- 1. The data ---------------------------------------------------------------------------

func _test_definitions() -> void:
	var seen := {}
	for role in ["past", "future"]:
		var list: Array = objectives.get_definitions(role)
		check(list.size() >= 8, "%s has a real objective sequence (%d)" % [role, list.size()])
		var last_order := 0
		for definition: ObjectiveDefinition in list:
			var id := definition.objective_id
			check(not seen.has(id), "Objective IDs are unique: " + id)
			seen[id] = true
			check(definition.validate().is_empty(), "%s is valid: %s" % [id, str(definition.validate())])
			check(definition.role == role, "%s sits in its own role's list" % id)
			check(id.begins_with("student_" if role == "past" else "professor_"), "%s is named for its role" % id)
			check(flow.has_room(definition.chapter), "%s points at a registered room (%s)" % [id, definition.chapter])
			check(definition.chapter_order >= last_order, "%s keeps chapters in order" % id)
			last_order = definition.chapter_order
			check(not definition.summary.is_empty() and definition.summary.length() <= 64, "%s has a short HUD summary" % id)
			if definition.secret:
				check(definition.hint.is_empty(), "%s is secret, so it carries no hint" % id)
			_check_references(definition)
			_check_spoilers(definition)
		# Chapters follow the level order.
		check(int(objectives._chapters.get("room_01")) < int(objectives._chapters.get("room_02")) and int(objectives._chapters.get("room_02")) < int(objectives._chapters.get("room_03")), "Chapters are ordered 1 < 2 < 3")
	check(objectives.get_definitions("past").size() == 15 and objectives.get_definitions("future").size() == 18, "Student has 15 and Professor 18 objectives")


func _check_references(definition: ObjectiveDefinition) -> void:
	var all: Array = definition.conditions + definition.expires + definition.progress
	for condition: Dictionary in all:
		_check_reference(definition.objective_id, condition)


func _check_reference(id: String, condition: Dictionary) -> void:
	match condition.kind:
		"flag", "one_of", "at_least", "array_count", "solved":
			check(condition.puzzle in [F1, M2, C3], "%s references a real puzzle (%s)" % [id, condition.puzzle])
			if condition.has("path"):
				_check_path(id, condition)
		"journal":
			var known: bool = journal.get_entry(condition.entry) != null
			check(known, "%s references a real journal entry (%s)" % [id, condition.entry])
		"room":
			check(flow.has_room(condition.room), "%s references a real room" % id)
		"any":
			for nested: Dictionary in condition.of:
				_check_reference(id, nested)


## A path must exist in the puzzle's real initial state, so a typo cannot silently never complete.
func _check_path(id: String, condition: Dictionary) -> void:
	var initial: Dictionary = {}
	match condition.puzzle:
		F1: initial = Freq.new().get_initial_state()
		M2: initial = Corridor.new().get_initial_state()
		C3: initial = Core.new().get_initial_state()
	var node: Variant = initial
	for key in String(condition.path).split("."):
		if node is Dictionary and (node as Dictionary).has(key):
			node = node[key]
		else:
			check(false, "%s: path '%s' does not exist in %s's state" % [id, condition.path, condition.puzzle])
			return
	check(true, "path ok")
	if condition.kind == "at_least":
		check(condition.order.has(Core.new().get_initial_state().stage) and condition.order.has(condition.value), "%s: stage order is real" % id)


func _check_spoilers(definition: ObjectiveDefinition) -> void:
	var text := " ".join([definition.title, definition.summary, definition.description, definition.hint]).to_lower()
	for banned: String in SPOILERS:
		check(not text.contains(banned.to_lower()), "%s must not contain '%s'" % [definition.objective_id, banned])
	var other: Array = STUDENT_MUST_NOT_SAY if definition.role == "past" else PROFESSOR_MUST_NOT_SAY
	for banned: String in other:
		check(not text.contains(banned.to_lower()), "%s must not reveal the other timeline's '%s'" % [definition.objective_id, banned])
	# No digits at all except numbers the game itself shows (the 150 s clock, 31 years, "Anchor 01").
	var digits := RegEx.create_from_string("[0-9]+")
	for match in digits.search_all(text):
		check(match.get_string() in ["150", "31", "01"], "%s mentions only public numbers (found %s)" % [definition.objective_id, match.get_string()])


# --- 2. The vocabulary ---------------------------------------------------------------------

func _test_conditions() -> void:
	var context := ObjectiveConditions.Context.new()
	context.role = "future"
	var state := {"flag": true, "name": "preserved", "stage": "STAGE_B", "n": 3,
		"bays": [{"sealed": true, "item": "r17"}, {"sealed": true, "item": ""}, {"sealed": false, "item": "k04"}],
		"installed": {"reader": "r17", "memory": ""}}
	context.state_of = func(puzzle_id: String) -> Dictionary: return state if puzzle_id == "p" else {}
	context.solved_of = func(puzzle_id: String) -> bool: return puzzle_id == "done"
	context.journal_has = func(entry: String, role: String) -> bool: return entry == "page" and role == "future"
	context.rooms = {"room_01": true}
	var order := ["A", "STAGE_A", "STAGE_B", "STAGE_C"]
	check(ObjectiveConditions.holds({"kind": "flag", "puzzle": "p", "path": "flag"}, context), "flag defaults to true")
	check(not ObjectiveConditions.holds({"kind": "flag", "puzzle": "p", "path": "missing"}, context), "A missing path is false")
	check(ObjectiveConditions.holds({"kind": "flag", "puzzle": "p", "path": "name", "value": "preserved"}, context), "flag compares strings")
	check(ObjectiveConditions.holds({"kind": "flag", "puzzle": "p", "path": "n", "value": 3.0}, context), "Numbers compare by value, not type")
	check(ObjectiveConditions.holds({"kind": "flag", "puzzle": "p", "path": "installed.reader", "value": "*"}, context), "'*' matches a non-empty value")
	check(not ObjectiveConditions.holds({"kind": "flag", "puzzle": "p", "path": "installed.memory", "value": "*"}, context), "'*' rejects an empty value")
	check(ObjectiveConditions.holds({"kind": "one_of", "puzzle": "p", "path": "name", "values": ["erased", "preserved"]}, context), "one_of matches any listed value")
	check(not ObjectiveConditions.holds({"kind": "one_of", "puzzle": "p", "path": "name", "values": ["pending"]}, context), "one_of rejects others")
	check(ObjectiveConditions.holds({"kind": "at_least", "puzzle": "p", "path": "stage", "order": order, "value": "STAGE_A"}, context), "at_least accepts a later stage")
	check(not ObjectiveConditions.holds({"kind": "at_least", "puzzle": "p", "path": "stage", "order": order, "value": "STAGE_C"}, context), "at_least rejects an earlier stage")
	check(ObjectiveConditions.holds({"kind": "array_count", "puzzle": "p", "path": "bays", "match": {"sealed": true, "item": "*"}, "min": 1}, context), "array_count counts matching entries")
	check(not ObjectiveConditions.holds({"kind": "array_count", "puzzle": "p", "path": "bays", "match": {"sealed": true, "item": "*"}, "min": 2}, context), "array_count needs the minimum")
	check(ObjectiveConditions.holds({"kind": "solved", "puzzle": "done"}, context) and not ObjectiveConditions.holds({"kind": "solved", "puzzle": "p"}, context), "solved reads the puzzle")
	check(ObjectiveConditions.holds({"kind": "journal", "entry": "page"}, context), "journal asks about this role's discoveries")
	context.role = "past"
	check(not ObjectiveConditions.holds({"kind": "journal", "entry": "page"}, context), "Another role's page does not count")
	check(ObjectiveConditions.holds({"kind": "room", "room": "room_01"}, context) and not ObjectiveConditions.holds({"kind": "room", "room": "room_02"}, context), "room reads the reached rooms")
	check(ObjectiveConditions.holds({"kind": "any", "of": [{"kind": "room", "room": "x"}, {"kind": "room", "room": "room_01"}]}, context), "any needs just one")
	check(not ObjectiveConditions.holds({"kind": "mystery"}, context), "An unknown kind never holds")
	check(not ObjectiveConditions.validate({"kind": "mystery"}).is_empty() and not ObjectiveConditions.validate({"kind": "flag"}).is_empty(), "Invalid conditions are reported")
	check(ObjectiveConditions.all_hold([{"kind": "room", "room": "room_01"}], context) and not ObjectiveConditions.all_hold([], context), "An empty condition list never completes anything")
	var invalid := ObjectiveDefinition.new()
	check(not invalid.validate().is_empty() and not objectives.register_objective(invalid), "An empty definition is refused")


func _test_input_map() -> void:
	check(InputMap.has_action(&"mission_log"), "mission_log action exists")
	var has_key := false
	var has_back := false
	var has_touchpad := false
	for event in InputMap.action_get_events(&"mission_log"):
		if event is InputEventKey and event.physical_keycode == KEY_M:
			has_key = true
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK:
			has_back = true
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_TOUCHPAD:
			has_touchpad = true
	check(has_key and has_back and has_touchpad, "Mission Log is on M, View/Create and the touchpad")
	# None of those inputs may also drive another action.
	for action in InputMap.get_actions():
		if action == &"mission_log" or String(action).begins_with("spatial_editor") or String(action).begins_with("ui_text"):
			continue
		for event in InputMap.action_get_events(action):
			var plain_m := false
			if event is InputEventKey:
				var key := event as InputEventKey
				plain_m = (key.physical_keycode == KEY_M or key.keycode == KEY_M) and not (key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed)
			var clash: bool = plain_m or (event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_BACK, JOY_BUTTON_TOUCHPAD])
			check(not clash, "Mission Log's input is unused by %s" % action)
	var manager := InputManager.get_instance()
	check(manager != null and InputManager.get_action_label(&"mission_log") == "M", "Keyboard label is M")


# --- 3. Playing the game --------------------------------------------------------------------

func _test_before_any_room() -> void:
	check(not objectives.has_content(), "Nothing is tracked before a room is entered")
	check(objectives.get_current("past") == null and objectives.get_current("future") == null, "No current objective before a room")
	check(not objectives.can_open_log(), "The log cannot open outside a room")
	check(objectives.get_completed("past").is_empty(), "Nothing is completed at the start")


func _test_level_one() -> void:
	await enter_room("room_01")
	check(objectives.has_content(), "Entering the laboratory starts tracking")
	check(current_key("past") == "l1_find_radio" and current_key("future") == "l1_find_radio", "Both start by finding their radio")
	check(objectives.get_current("past").objective_id != objectives.get_current("future").objective_id, "Each timeline has its own objective")
	check(announced.is_empty(), "Nothing is announced just for entering the room")

	await act(F1, "acquire_radio", "past", {"radio_role": "past"})
	check(done("past", "l1_find_radio") and announced_count("past", "l1_find_radio") == 1, "Student finds the radio: completed and announced once")
	check(not done("future", "l1_find_radio") and current_key("future") == "l1_find_radio", "The Professor's objective is untouched by the Student's pickup")
	check(current_key("past") == "l1_calibrate", "Student moves on to calibration")
	check(objectives.get_completed("future").is_empty(), "Professor has completed nothing")

	# Reading the log is a local discovery: it completes the Professor's terminal objective out of order.
	await unlock_entry("future", "future_frequency_log")
	check(done("future", "l1_terminal") and not done("future", "l1_find_radio"), "Professor's terminal objective completes on its own evidence")
	check(current_key("future") == "l1_find_radio", "The Professor still needs a radio, so that stays current")
	check(not done("past", "l1_calibrate"), "The Student is not affected by the Professor's discovery")

	await act(F1, "acquire_radio", "future", {"radio_role": "future"})
	check(done("future", "l1_find_radio") and current_key("future") == "l1_guide", "Professor's radio moves them to guiding the calibration")
	check(not done("past", "l1_calibrate") and not done("future", "l1_guide"), "Nothing completes before the signal is tuned")

	await act(F1, "tune_frequency", "past", {"frequency": 60})
	check(not done("past", "l1_calibrate"), "A wrong frequency completes nothing")
	await act(F1, "tune_frequency", "past", {"frequency": 67})
	await act(F1, "tune_amplitude", "past", {"amplitude": 70})
	check(done("past", "l1_calibrate") and done("future", "l1_guide"), "The confirmed link completes both calibration objectives")
	check(announced_count("past", "l1_calibrate") == 1, "The Student, who is playing, is told once")
	check(announced_count("future", "l1_guide") == 0, "Only the player being played is told: the Professor's completion is silent here")
	check(current_key("past") == "l1_exit" and current_key("future") == "l1_exit", "Both are told to leave through the door")
	check(not done("past", "l1_exit"), "Standing in the lab does not complete leaving it")

	await act(M2, "arrive", "past")
	check(not done("past", "l1_exit"), "Touching the exit zone is not leaving: the transition has not happened")


func _test_level_two() -> void:
	await enter_room("room_02")
	check(done("past", "l1_exit") and done("future", "l1_exit"), "Arriving in the corridor completes leaving the lab")
	check(announced_count("past", "l1_exit") == 1, "Leaving is announced once to the Student")
	check(current_key("past") == "l2_isolate_service" and current_key("future") == "l2_charge_cell", "Each role starts the corridor with its own task")

	await act(M2, "isolate_service", "past")
	check(done("past", "l2_isolate_service") and current_key("past") == "l2_restore_power", "Student isolates the service circuit")
	check(current_key("future") == "l2_charge_cell", "The Professor's current objective does not change when the Student acts")
	await act(M2, "charge_battery", "future")
	check(done("future", "l2_charge_cell") and done("past", "l2_restore_power"), "The confirmed charge completes the Professor's task and unlocks the Student's next step")
	check(current_key("past") == "l2_preserve_parts" and current_key("future") == "l2_inspect_archive", "Storage is next for both")

	await act(M2, "read_manifest", "future")
	check(done("future", "l2_inspect_archive") and current_key("future") == "l2_recover_parts", "Reading the shipping record moves the Professor on")
	check(current_key("past") == "l2_preserve_parts" and not done("past", "l2_preserve_parts"), "The Student keeps storing parts")
	var upcoming: Array = objectives.get_upcoming("past")
	check(upcoming.size() >= 2 and upcoming[0].kind == "known" and upcoming[0].definition.objective_id == "student_l2_ask_record", "The Student sees only the next step in full")
	for entry: Dictionary in upcoming.slice(1):
		check(entry.kind in ["locked", "chapter"] and not entry.has("definition"), "Later steps expose no definition (%s)" % entry.kind)
	check(upcoming[-1].kind == "chapter" and upcoming[-1].chapter == "room_03", "The unreached chapter is one anonymous placeholder")

	var parts := [["r17", "reader", 0], ["k04", "regulator", 1], ["m22", "memory", 2]]
	for index in parts.size():
		var part: Array = parts[index]
		await act(M2, "pickup_storage_item", "past", {"item": part[0]})
		await act(M2, "place_storage_item", "past", {"bay": part[2]})
		await act(M2, "seal_bay", "past", {"bay": part[2]})
		await act(M2, "raise_storage_tray", "future", {"bay": part[2]})
		await act(M2, "retrieve_storage_item", "future", {"bay": part[2]})
		var before_progress: Vector2i = objectives.get_progress(objectives.get_current("future"), "future")
		check(before_progress == Vector2i(index, 3), "Professor's progress reads %d / 3 (got %s)" % [index, str(before_progress)])
		await act(M2, "install_component", "future", {"part": part[1]})
	check(done("past", "l2_preserve_parts") and done("future", "l2_recover_parts"), "Three installed parts complete the storage objectives for both")
	check(current_key("past") == "l2_ask_record" and current_key("future") == "l2_read_record", "Past waits on the record; Future reads it")
	var recorder_upcoming: Array = objectives.get_upcoming("future")
	check(recorder_upcoming[0].kind == "locked" and not recorder_upcoming[0].has("definition"), "A secret step stays hidden even when it is the very next one (the recorder)")

	await act(M2, "read_archive", "future")
	check(done("future", "l2_read_record") and done("past", "l2_ask_record"), "The confirmed archive read completes both")
	check(current_key("past") == "l2_authorize_core", "Student can now work on the keypad")
	check(current_key("future") == "l2_recorder" and objectives.get_current("future").secret, "The secret step is revealed the moment it becomes current")

	await act(M2, "authorize_core", "past", {"code": "0000"})
	check(not done("past", "l2_authorize_core"), "A refused code completes nothing")
	await act(M2, "authorize_core", "past", {"code": corridor_rules.access_code})
	check(not done("past", "l2_authorize_core"), "The recorder must be resolved before the keypad accepts the code")
	await act(M2, "repair_bypass", "past")
	await act(M2, "repair_bypass", "future")
	await act(M2, "preserve_recording", "future")
	check(done("future", "l2_recorder") and current_key("future") == "l2_release", "Resolving the recorder completes it and moves on")
	check(not done("past", "l2_authorize_core"), "The Student's keypad objective is its own")
	await act(M2, "authorize_core", "past", {"code": corridor_rules.access_code})
	check(done("past", "l2_authorize_core") and current_key("past") == "l2_anchor", "The right code completes the Student's keypad objective")
	await act(M2, "release_door", "future")
	check(done("future", "l2_release") and current_key("future") == "l2_anchor", "Professor opens the release")
	await act(M2, "arm_anchor", "past")
	check(done("past", "l2_anchor") and not done("future", "l2_anchor"), "Student's contact is theirs alone")
	check(objectives.is_chapter_done("past") and not objectives.is_chapter_done("future"), "Student is done with the chapter while the Professor is not")
	check(objectives.get_current("past") == null, "A finished chapter has no current objective")
	await act(M2, "arm_anchor", "future")
	check(done("future", "l2_anchor") and objectives.is_chapter_done("future"), "Professor's contact completes their chapter")
	check(puzzles.is_solved(M2), "The corridor puzzle itself is solved")
	for role in ["past", "future"]:
		for definition: ObjectiveDefinition in objectives.get_definitions(role):
			if definition.chapter == "room_02":
				check(announced_count(role, definition.objective_id.trim_prefix("student_").trim_prefix("professor_")) <= 1, "%s was never announced twice" % definition.objective_id)
	check(announced_count("past", "l2_isolate_service") == 1 and announced_count("future", "l2_charge_cell") == 1, "Each player is told once about the task they performed")


func _test_level_three() -> void:
	await enter_room("room_03")
	var rules := Core.new()
	rules.proximity = func(_role: String, _station: String) -> bool: return true
	rules.available = func() -> bool: return true
	puzzles.register_puzzle(C3, rules, true)
	puzzles.reset_puzzle(C3)
	core_seq = {"past": 0, "future": 0}
	await settle()
	check(is_chapter_started(), "Room C starts its own chapter")
	check(current_key("past") == "l3_records" and current_key("future") == "l3_records", "Both start by examining the records")
	check(objectives.get_progress(objectives.get_current("past"), "past") == Vector2i(0, 2), "Student has two documents to read")
	await unlock_entry("past", "l3_authorization")
	check(objectives.get_progress(objectives.get_current("past"), "past") == Vector2i(1, 2) and not done("past", "l3_records"), "One of two documents is progress, not completion")
	await unlock_entry("past", "l3_warning")
	check(done("past", "l3_records") and current_key("past") == "l3_arm", "Both documents complete the Student's reading")
	check(current_key("future") == "l3_records", "The Professor has not read theirs")

	await act3("start", "past")
	check(done("past", "l3_arm") and done("future", "l3_arm"), "Arming the reactor completes it for both")
	check(not done("future", "l3_records") and current_key("future") == "l3_receiver", "The Professor's unread records are dropped when arming starts, not marked complete")
	check(current_key("past") == "l3_coils", "Student turns to the coils")
	for index in [0, 0, 2]:
		await act3("coil", "past", {"index": index})
	check(not done("past", "l3_coils"), "Correct coils alone do not finish the stage: the receiver is still dead")
	await act3("receiver", "future")
	check(done("future", "l3_receiver") and done("past", "l3_coils"), "Receiver plus coils rebuild the conduit for both")
	check(not done("future", "l3_routing"), "Skipping the diagram is allowed and is not recorded as read")
	check(current_key("future") == "l3_anchor" and current_key("past") == "l3_origin", "Stage B: anchor for the Professor, origin for the Student")
	await act3("origin", "past")
	check(not done("past", "l3_origin"), "The origin core does not respond before the anchor")
	await act3("anchor", "future")
	check(done("future", "l3_anchor"), "Professor calibrates the anchor")
	await act3("origin", "past")
	check(done("past", "l3_origin") and current_key("past") == "l3_sync", "Student stabilizes the origin once the anchor is calibrated")
	await act3("sync", "past")
	check(not done("past", "l3_sync"), "One switch is not both")
	await act3("sync", "future")
	check(done("past", "l3_sync") and done("future", "l3_sync"), "Both switches complete the phase objective")
	check(current_key("past") == "l3_command" and objectives.get_current("past").secret, "The final decision becomes visible only now")
	await act3("choose", "past", {"command": "GROUND THE CORE"})
	check(done("past", "l3_command") and not done("future", "l3_command"), "The Student's decision completes only the Student's objective")
	await act3("choose", "future", {"command": "RELEASE THE ECHO"})
	check(done("future", "l3_command") and puzzles.get_state(C3).stage == "ENDING", "Both decisions end the story and complete both roles' final objectives")
	check(objectives.is_chapter_done("past") and objectives.is_chapter_done("future"), "Both are done with the final chapter")
	check(objectives.get_completed("past").size() == 15, "Student completed all 15 objectives (%d)" % objectives.get_completed("past").size())
	check(objectives.get_completed("future").size() == 16, "Professor completed 16 of 18: the two optional reads they skipped are dropped, not counted (%d)" % objectives.get_completed("future").size())
	for role in ["past", "future"]:
		for definition: ObjectiveDefinition in objectives.get_definitions(role):
			var key := definition.objective_id.trim_prefix("student_").trim_prefix("professor_")
			check(announced_count(role, key) <= 1, "%s was never announced twice" % definition.objective_id)


func is_chapter_started() -> bool:
	return objectives.has_content() and objectives.get_current("past") != null and objectives.get_current("past").chapter == "room_03"


# --- 4. Persistence, reconstruction, restart --------------------------------------------------

func _test_persistence_and_restart() -> void:
	var past_done: int = objectives.get_completed("past").size()
	var future_done: int = objectives.get_completed("future").size()
	var heard: int = announced.size()
	# Changing rooms, even back and forth, forgets nothing and announces nothing.
	await enter_room("room_01")
	await enter_room("room_02")
	await enter_room("room_03")
	check(objectives.get_completed("past").size() == past_done and objectives.get_completed("future").size() == future_done, "Room changes keep the whole history")
	check(announced.size() == heard, "Room changes announce nothing new")
	var ids := {}
	for definition: ObjectiveDefinition in objectives.get_completed("past"):
		check(not ids.has(definition.objective_id), "History never lists an objective twice")
		ids[definition.objective_id] = true
	check(objectives.get_completed("past")[0].chapter == "room_01", "History keeps the order things were finished in")

	# A new campaign (started from the menu, so no room is current) forgets everything.
	await leave_rooms()
	puzzles.begin_session()
	await settle()
	check(objectives.get_completed("past").is_empty() and objectives.get_completed("future").is_empty(), "A new session clears both histories")
	check(announced.size() == heard, "Clearing progress announces nothing")
	check(not objectives.has_content(), "A fresh campaign shows nothing until a room is entered")
	await enter_room("room_01")
	check(current_key("past") == "l1_find_radio" and current_key("future") == "l1_find_radio", "The starting objectives are restored")
	check(objectives.get_upcoming("past").size() > 0 and objectives.get_upcoming("past")[0].kind == "known", "Upcoming objectives are rebuilt from the start")
	check(objectives.get_upcoming("past")[-1].chapter == "room_03", "Later chapters are anonymous again")


func _test_reconstruction() -> void:
	# Progress that already exists when the manager looks (a joining peer's snapshot, a restarted
	# manager) is filled in without a single announcement.
	puzzles.begin_session()
	await settle()
	await leave_rooms()
	puzzles.begin_session()
	await settle()
	await act(F1, "acquire_radio", "past", {"radio_role": "past"})
	await act(F1, "acquire_radio", "future", {"radio_role": "future"})
	await act(F1, "tune_frequency", "past", {"frequency": 67})
	await act(F1, "tune_amplitude", "past", {"amplitude": 70})
	await act(M2, "isolate_service", "past")
	await act(M2, "charge_battery", "future")
	await enter_room("room_02")
	var completed_before: int = objectives.get_completed("past").size()
	var current_before := current_key("past")
	objectives.reset()  # what session_started does when the host's snapshot arrives
	await settle()
	var after_setup := announced.size()
	objectives.reset()
	await settle()
	check(announced.size() == after_setup, "Reconstruction announces nothing")
	check(objectives.get_completed("past").size() == completed_before, "Reconstruction restores every completed objective (%d)" % completed_before)
	check(current_key("past") == current_before, "Reconstruction lands on the same current objective")
	check(done("future", "l2_charge_cell") and done("past", "l2_isolate_service") and done("past", "l1_calibrate"), "Completed work comes back from confirmed state alone")
	var seen := {}
	for definition: ObjectiveDefinition in objectives.get_completed("future"):
		check(not seen.has(definition.objective_id), "No duplicates after reconstruction")
		seen[definition.objective_id] = true


## The reactor can overload or be replayed: its objectives start over, the evidence you already read stays.
func _test_reactor_restart() -> void:
	await leave_rooms()
	puzzles.begin_session()
	await settle()
	await enter_room("room_03")
	var rules := Core.new()
	rules.proximity = func(_role: String, _station: String) -> bool: return true
	rules.available = func() -> bool: return true
	puzzles.register_puzzle(C3, rules, true)
	puzzles.reset_puzzle(C3)
	core_seq = {"past": 0, "future": 0}
	await settle()
	await unlock_entry("past", "l3_authorization")
	await unlock_entry("past", "l3_warning")
	await act3("start", "past")
	for index in [0, 0, 2]:
		await act3("coil", "past", {"index": index})
	await act3("receiver", "future")
	await act3("anchor", "future")
	await act3("origin", "past")
	await act3("sync", "past")
	await act3("sync", "future")
	await act3("choose", "past", {"command": "CLAIM ORIGIN"})
	await act3("choose", "future", {"command": "PRESERVE ECHO"})
	check(puzzles.get_state(C3).ending == "paradox" and done("past", "l3_command"), "The whole reactor was solved")
	var first_arm := announced_count("past", "l3_arm")
	var first_records := announced_count("past", "l3_records")
	await act3("replay", "past")
	check(puzzles.get_state(C3).stage == "DISCOVERY", "The Student replayed the room")
	check(not done("past", "l3_arm") and not done("past", "l3_coils") and not done("past", "l3_command"), "A new attempt forgets the reactor objectives")
	check(done("past", "l3_records"), "Documents already read stay read")
	check(announced_count("past", "l3_records") == first_records, "...and are not announced a second time")
	check(current_key("past") == "l3_arm" and current_key("future") == "l3_records", "The Student re-arms; the Professor still has unread records")
	core_seq = {"past": 0, "future": 0}
	await act3("start", "past")
	check(done("past", "l3_arm") and announced_count("past", "l3_arm") == first_arm + 1, "Arming again in the new attempt is announced again, once")
