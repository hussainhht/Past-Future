extends SceneTree
## Run: godot --headless --path . --script res://tests/dialogue_system.gd
## Or: python tests/run_dialogue_tests.py. The runner imports the project first (new class_names must be
## registered) and fails on any script error, because this script prints PASS even if the engine logs one.
##
## Covers the dialogue system without a window: resources, the director's state machine, queue,
## timeline filtering, play-once history, narrative events, input, cleanup, the box, the trigger
## adapter, the hand-off from PuzzleManager, and the sandbox scene.
##
## Lambdas capture numbers and bools by value, so anything a handler must report lives in an Array.

const SYSTEM_SCENE := "res://scenes/dialogue/dialogue_system.tscn"
const BOX_SCENE := "res://scenes/dialogue/dialogue_box.tscn"
const SANDBOX_SCENE := "res://scenes/testing/dialogue_sandbox.tscn"
const SAMPLE_DIR := "res://resources/dialogue/samples/"
const PowerSwitch := preload("res://scripts/puzzles/implementations/power_switch_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
const PAST := DialogueLine.Timeline.PAST
const FUTURE := DialogueLine.Timeline.FUTURE
const BOTH := DialogueLine.Timeline.BOTH
const State := DialogueDirector.State
## Characters per second at which every reveal completes before present_line() returns.
const INSTANT := 5000.0

var failures: int = 0
var checks: int = 0


## Listens to every signal of one director, in order.
class Recorder extends RefCounted:
	var events: Array = []
	var blocked: Array = []
	var rejections: Array = []

	func _init(director: DialogueDirector) -> void:
		director.dialogue_started.connect(func(id: String) -> void: events.append("started:" + id))
		director.dialogue_line_started.connect(func(id: String, index: int) -> void: events.append("line_started:%s:%d" % [id, index]))
		director.dialogue_line_finished.connect(func(id: String, index: int) -> void: events.append("line_finished:%s:%d" % [id, index]))
		director.dialogue_finished.connect(func(id: String) -> void: events.append("finished:" + id))
		director.dialogue_cancelled.connect(func(id: String) -> void: events.append("cancelled:" + id))
		director.dialogue_skipped.connect(func(id: String) -> void: events.append("skipped:" + id))
		director.narrative_event_requested.connect(func(event_id: String) -> void: events.append("event:" + event_id))
		director.dialogue_rejected.connect(func(id: String, reason: String) -> void: rejections.append(id + ":" + reason))
		director.gameplay_input_block_changed.connect(func(is_blocked: bool) -> void:
			blocked.append(is_blocked)
			events.append("block:" + str(is_blocked)))

	func count(prefix: String) -> int:
		var total := 0
		for entry: String in events:
			if entry.begins_with(prefix):
				total += 1
		return total


## A node with signals of different shapes, for the trigger adapter.
class Emitter extends Node:
	signal fired(first: String, second: String)
	signal poked
	signal crowded(a: int, b: int, c: int, d: int, e: int, f: int, g: int, h: int, i: int)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_samples_match_the_spec()
	test_resource_validation()
	test_resource_round_trip()
	test_start_valid_and_invalid()
	test_state_machine_and_signal_order()
	test_speaker_names_and_text()
	await test_typewriter()
	await test_empty_and_missing_content()
	test_skipping()
	test_cancellation()
	test_queue()
	test_timeline_filtering()
	test_play_once_and_reset()
	await test_blocking_and_non_blocking()
	await test_input_handling()
	await test_rapid_input()
	await test_scene_cleanup()
	await test_presenter_swap()
	test_independent_directors()
	test_narrative_events()
	await test_auto_advance()
	test_reentrancy()
	test_box_styling()
	await test_no_node_growth()
	test_trigger_adapter()
	await test_trigger_on_ready()
	test_puzzle_manager_hand_off()
	test_interaction_hand_off()
	await test_pause_behaviour()
	await test_sandbox_scene()
	print("DIALOGUE SYSTEM: ", "PASS" if failures == 0 else "FAIL", " (", checks, " checks, ", failures, " failures)")
	quit(0 if failures == 0 else 1)


# --- Helpers ------------------------------------------------------------------------------

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		push_error("%s\n    expected: %s\n    actual:   %s" % [message, expected, actual])


func line(text: String, speaker: String = "Tester", timeline: DialogueLine.Timeline = PAST, event_id: String = "") -> DialogueLine:
	var result := DialogueLine.new()
	result.speaker_id = speaker.to_lower()
	result.speaker_name = speaker
	result.text = text
	result.timeline = timeline
	result.event_id = event_id
	return result


## Plain lines that reveal at once. `settings` overrides any DialogueSequence property.
func sequence(id: String, texts: Array = ["One.", "Two."], settings: Dictionary = {}) -> DialogueSequence:
	var result := DialogueSequence.new()
	result.sequence_id = id
	result.typing_speed = INSTANT
	var lines: Array[DialogueLine] = []
	for text: String in texts:
		lines.append(line(text))
	result.lines = lines
	for key: String in settings:
		result.set(key, settings[key])
	return result


func make_director(with_box: bool = true, timeline: String = "past") -> DialogueDirector:
	var director: DialogueDirector
	if with_box:
		director = load(SYSTEM_SCENE).instantiate()
	else:
		director = DialogueDirector.new()
	director.log_problems = false
	director.set_local_timeline(timeline)
	director.default_characters_per_second = INSTANT
	root.add_child(director)
	return director


func dispose(node: Node) -> void:
	if is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func box_text(box: DialogueBox) -> RichTextLabel:
	return box.get_node("%DialogueText")


## Send an action through the same path real input takes. Returns whether something handled it.
func press(action: StringName) -> bool:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	return root.is_input_handled()


func press_key(keycode: Key, echo: bool = false) -> bool:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	return root.is_input_handled()


func wait_until(condition: Callable, timeout: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


# --- Resources ----------------------------------------------------------------------------

func test_samples_match_the_spec() -> void:
	var expected := {
		"opening_past": {"audience": PAST, "play_once": true, "lines": [
			["The Student", "Something is wrong with the experiment.", PAST],
			["The Student", "That signal wasn't there a moment ago.", PAST],
			["The Student", "I need to find out what happened.", PAST],
		]},
		"first_rift_contact": {"audience": BOTH, "play_once": true, "lines": [
			["The Student", "Who's there?", PAST],
			["Unknown Voice", "Can you hear me?", BOTH],
			["The Student", "Where are you?", PAST],
			["Unknown Voice", "That's difficult to explain.", BOTH],
			["The Student", "Then start explaining.", PAST],
		]},
		"future_discovery": {"audience": FUTURE, "play_once": true, "lines": [
			["The Professor", "The laboratory is exactly where I remember it.", FUTURE],
			["The Professor", "Except thirty-one years have passed.", FUTURE],
			["The Professor", "And this time, I know what happens next.", FUTURE],
		]},
		"puzzle_completed": {"audience": BOTH, "play_once": false, "lines": [
			["The Student", "The signal is stable.", PAST],
			["The Professor", "Something just changed on my side.", FUTURE],
			["The Student", "Then maybe we can actually fix this.", PAST],
		]},
	}
	for id: String in expected:
		var path := SAMPLE_DIR + id + ".tres"
		var loaded: Resource = load(path)
		check(loaded is DialogueSequence, "%s must load as a DialogueSequence" % path)
		if not loaded is DialogueSequence:
			continue
		var sequence_resource: DialogueSequence = loaded
		var want: Dictionary = expected[id]
		check_eq(sequence_resource.sequence_id, id, "%s: the ID must match the file name" % id)
		check_eq(sequence_resource.audience, want.audience, "%s: audience" % id)
		check_eq(sequence_resource.play_once, want.play_once, "%s: play_once" % id)
		check_eq(sequence_resource.lines.size(), want.lines.size(), "%s: line count" % id)
		for index in mini(sequence_resource.lines.size(), want.lines.size()):
			var got := sequence_resource.lines[index]
			var wanted: Array = want.lines[index]
			check(got != null and got.speaker_name == wanted[0] and got.text == wanted[1] and got.timeline == wanted[2],
					"%s line %d must read %s: '%s'" % [id, index, wanted[0], wanted[1]])
		check(sequence_resource.validate().is_empty(), "%s must validate cleanly: %s" % [id, sequence_resource.validate()])
	var rift: DialogueSequence = load(SAMPLE_DIR + "first_rift_contact.tres")
	check_eq(rift.start_event_id, "rift_activated", "The rift sample announces rift_activated when it starts")
	check_eq(rift.lines[1].event_id, "rift_voice_detected", "The first Unknown Voice line announces rift_voice_detected")
	check_eq(rift.finish_event_id, "rift_conversation_finished", "The rift sample announces rift_conversation_finished when it ends")
	check(rift.lines[1].speaker_id == "professor" and rift.lines[1].speaker_name == "Unknown Voice", "The professor is credited as Unknown Voice without changing his speaker ID")
	var future: DialogueSequence = load(SAMPLE_DIR + "future_discovery.tres")
	check(future.playback_mode == DialogueSequence.PlaybackMode.NON_BLOCKING and future.auto_advance, "The Future sample demonstrates non-blocking auto-advance")
	var opening: DialogueSequence = load(SAMPLE_DIR + "opening_past.tres")
	check(opening.is_blocking() and not opening.auto_advance, "The opening sample demonstrates blocking, manual playback")
	# Every .tres in the folder: unique IDs that match the file name, all valid.
	var seen := {}
	for file in DirAccess.get_files_at(SAMPLE_DIR):
		if file.get_extension() != "tres":
			continue
		var found: Resource = load(SAMPLE_DIR + file)
		check(found is DialogueSequence, "%s must be a DialogueSequence" % file)
		if found is DialogueSequence:
			check(not seen.has(found.sequence_id), "Sequence ID '%s' is used twice" % found.sequence_id)
			seen[found.sequence_id] = true
			check_eq(found.sequence_id, file.get_basename(), "%s: file name and sequence_id must agree" % file)
	check_eq(seen.size(), 4, "The sample folder must hold exactly the four sample sequences")


func test_resource_validation() -> void:
	check(sequence("good").validate().is_empty() and sequence("good").has_valid_id(), "A normal sequence must validate")
	for bad_id in ["", " ", "has space", "tab\tid", "new\nline", " leading", "trailing "]:
		var bad := sequence(bad_id)
		check(not bad.has_valid_id() and not bad.validate().is_empty(), "ID '%s' must be refused" % bad_id.c_escape())
	var empty := sequence("empty", [])
	check(empty.get_playable_indices().is_empty() and not empty.validate().is_empty(), "A sequence without lines must be reported")
	var mixed := sequence("mixed", ["A", "", "   ", "B"])
	mixed.lines.insert(1, null)
	check_eq(mixed.get_playable_indices(), PackedInt32Array([0, 4]), "Null entries and lines without text are skipped but keep their original indices")
	var problems := mixed.validate()
	check(problems.size() == 3 and "line 1 is empty (no DialogueLine assigned)" in problems, "Each unusable line must be named: %s" % [problems])
	var repeated := sequence("repeated", ["A", "B"])
	repeated.lines[0].line_id = "same"
	repeated.lines[1].line_id = "same"
	check(not repeated.validate().is_empty(), "A repeated line_id must be reported")
	var negative := sequence("negative", ["A"], {"typing_speed": -1.0, "auto_advance_delay": -1.0})
	negative.lines[0].typing_speed = -5.0
	check_eq(negative.validate().size(), 3, "Negative speeds and delays must be reported")
	check(DialogueLine.timeline_name(PAST) == "past" and DialogueLine.timeline_name(FUTURE) == "future" and DialogueLine.timeline_name(BOTH) == "both", "Timelines have stable lowercase names")
	for audience in [PAST, FUTURE, BOTH]:
		var s := sequence("aud", ["A"], {"audience": audience})
		check_eq([s.is_for_timeline("past"), s.is_for_timeline("future")], [audience != FUTURE, audience != PAST], "Audience %s must match its timeline" % audience)
	check(sequence("case", ["A"], {"audience": FUTURE}).is_for_timeline("FUTURE"), "Timeline names are case-insensitive")
	check(not sequence("nothing", ["A"], {"audience": PAST}).is_for_timeline(""), "An unknown timeline never matches a Past or Future audience")


func test_resource_round_trip() -> void:
	var original := sequence("round_trip", ["First line.", "Second [i]line[/i]."], {
		"audience": FUTURE, "playback_mode": DialogueSequence.PlaybackMode.NON_BLOCKING, "play_once": true,
		"allow_skip": false, "typing_speed": 33.0, "auto_advance": true, "auto_advance_delay": 2.5,
		"start_event_id": "begin", "finish_event_id": "end",
	})
	original.lines[0].line_id = "a"
	original.lines[0].event_id = "line_event"
	original.lines[0].typing_speed = 55.0
	original.lines[1].timeline = BOTH
	var path := "user://dialogue_test_round_trip.tres"
	check_eq(ResourceSaver.save(original, path), OK, "Saving a sequence must succeed")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as DialogueSequence
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(loaded != null, "A saved sequence must load again")
	if loaded == null:
		return
	check(loaded.sequence_id == "round_trip" and loaded.audience == FUTURE and loaded.lines.size() == 2, "Identity, audience and lines survive")
	check(loaded.playback_mode == DialogueSequence.PlaybackMode.NON_BLOCKING and loaded.play_once and not loaded.allow_skip, "Playback flags survive")
	check(is_equal_approx(loaded.typing_speed, 33.0) and loaded.auto_advance and is_equal_approx(loaded.auto_advance_delay, 2.5), "Speed and auto-advance survive")
	check(loaded.start_event_id == "begin" and loaded.finish_event_id == "end", "Sequence events survive")
	check(loaded.lines[0].line_id == "a" and loaded.lines[0].event_id == "line_event" and is_equal_approx(loaded.lines[0].typing_speed, 55.0), "Line fields survive")
	check(loaded.lines[1].text == "Second [i]line[/i]." and loaded.lines[1].timeline == BOTH, "Line text and timeline survive")
	check(loaded.lines.is_typed(), "The lines array must stay a typed Array[DialogueLine]")


# --- Starting -----------------------------------------------------------------------------

func test_start_valid_and_invalid() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	check(director.play_dialogue(sequence("valid")), "A valid sequence must be accepted")
	check(director.is_dialogue_active() and director.get_current_sequence_id() == "valid", "It must become the active sequence")
	check(director.get_current_line_index() == 0 and director.get_current_line().text == "One.", "The first line is current")
	check(director.dialogue_box.is_open(), "The box must be showing")
	director.stop_dialogue()
	rec.events.clear()
	rec.rejections.clear()
	var no_lines := sequence("no_lines", [])
	var nothing_to_show := sequence("nothing_to_show", ["", "   "])
	nothing_to_show.lines.append(null)
	var cases := [
		[null, "", "no_sequence"],
		[sequence(""), "", "invalid_id"],
		[sequence("has space"), "has space", "invalid_id"],
		[no_lines, "no_lines", "empty_sequence"],
		[nothing_to_show, "nothing_to_show", "empty_sequence"],
	]
	for case: Array in cases:
		check(not director.play_dialogue(case[0]), "A request refused as %s must return false" % case[2])
	check_eq(rec.rejections, [":no_sequence", ":invalid_id", "has space:invalid_id", "no_lines:empty_sequence", "nothing_to_show:empty_sequence"], "Every refusal must say why")
	check(rec.events.is_empty() and not director.is_dialogue_active() and not director.is_gameplay_input_blocked(), "A refused request must start nothing and lock nothing")
	var detached := DialogueDirector.new()
	detached.log_problems = false
	check(not detached.play_dialogue(sequence("detached")), "A director outside the tree cannot play")
	detached.free()
	dispose(director)


func test_state_machine_and_signal_order() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	var seq := sequence("flow", ["First.", "Second."], {"start_event_id": "start_ev", "finish_event_id": "finish_ev"})
	seq.lines[1].event_id = "line_ev"
	var states_at_finish: Array = []
	var idle_when_finished: Array = []
	director.narrative_event_requested.connect(func(event_id: String) -> void:
		if event_id == "finish_ev":
			states_at_finish.append(director.get_state()))
	director.dialogue_finished.connect(func(_id: String) -> void: idle_when_finished.append(not director.is_dialogue_active() and director.get_state() == State.IDLE))
	check(director.get_state() == State.IDLE and director.get_current_line() == null and director.get_current_sequence_id() == "", "A new director is idle with nothing current")
	check(not director.is_processing() and not director.is_processing_unhandled_input(), "An idle director must not process anything")
	director.play_dialogue(seq)
	check(director.get_state() == State.WAITING_FOR_INPUT, "An instant reveal waits for the player at once")
	check(director.is_processing_unhandled_input(), "An active director listens for input")
	director.advance_dialogue()
	check(director.get_current_line_index() == 1 and director.get_state() == State.WAITING_FOR_INPUT, "Advancing shows the next line")
	director.advance_dialogue()
	check_eq(rec.events, [
		"block:true", "started:flow", "event:start_ev", "line_started:flow:0", "line_finished:flow:0",
		"line_started:flow:1", "event:line_ev", "line_finished:flow:1", "event:finish_ev", "block:false", "finished:flow",
	], "Signals must fire in exactly this order")
	check_eq(states_at_finish, [State.FINISHING], "The finish event is announced while the director is FINISHING")
	check_eq(idle_when_finished, [true], "dialogue_finished arrives after the director is idle again")
	check(not director.is_dialogue_active() and not director.is_processing_unhandled_input(), "A finished director releases its state")
	check(rec.count("finished:") == 1 and rec.count("cancelled:") == 0, "Completion is announced once")
	director.advance_dialogue()
	director.advance_dialogue()
	check(rec.count("finished:") == 1, "Advancing an idle director changes nothing")
	dispose(director)


func test_speaker_names_and_text() -> void:
	var director := make_director()
	var box: DialogueBox = director.dialogue_box
	var seq := DialogueSequence.new()
	seq.sequence_id = "names"
	seq.typing_speed = INSTANT
	var lines: Array[DialogueLine] = [
		line("What happened to the machine?", "The Student", PAST),
		line("Can you hear me?", "Unknown Voice", BOTH),
		line("Hello, [b]Professor[/b] Ångström: [i]“café”[/i] ✓", "Dr. Å. Test", FUTURE),
	]
	seq.lines = lines
	director.play_dialogue(seq)
	for index in 3:
		check_eq(box.get_speaker_text(), lines[index].speaker_name, "Line %d must show its own speaker name from data" % index)
		check_eq(director.get_current_line().text, lines[index].text, "Line %d is current" % index)
		director.advance_dialogue()
	director.stop_dialogue()
	director.play_dialogue(seq)
	director.advance_dialogue()
	check_eq(box.get_line_text(), "Can you hear me?", "The box shows the line's text")
	director.advance_dialogue()
	check_eq(box.get_line_text(), "Hello, Professor Ångström: “café” ✓", "BBCode is rendered, not shown, and Unicode survives")
	dispose(director)


# --- Typewriter ---------------------------------------------------------------------------

func test_typewriter() -> void:
	var director := make_director()
	var box: DialogueBox = director.dialogue_box
	var text := box_text(box)
	var finished: Array = [0]
	box.typewriter_finished.connect(func() -> void: finished[0] += 1)
	var seq := sequence("typing", ["The quick brown fox jumps over the lazy dog, again and again."], {"typing_speed": 30.0})
	check(director.play_dialogue(seq), "The slow sequence starts")
	check(director.get_state() == State.SHOWING_LINE and box.is_typing(), "A slow line is SHOWING_LINE while it types")
	var total := text.get_total_character_count()
	check_eq(total, seq.lines[0].text.length(), "Every character is counted")
	check(text.visible_characters >= 0 and text.visible_characters < total, "A new line starts hidden")
	await create_timer(0.3).timeout
	var early := text.visible_characters
	await create_timer(0.3).timeout
	var later := text.visible_characters
	check(early > 0 and later > early and later < total, "Text must appear gradually (saw %d then %d of %d)" % [early, later, total])
	director.skip_typewriter()
	check(text.visible_characters == -1 and not box.is_typing() and director.get_state() == State.WAITING_FOR_INPUT, "Skipping the typewriter shows the whole line at once")
	check_eq(finished[0], 1, "The reveal completes exactly once")
	director.skip_typewriter()
	director.skip_typewriter()
	await create_timer(0.3).timeout
	check_eq(finished[0], 1, "Repeated skips and the cancelled Tween must not complete it again")
	check(director.get_current_line_index() == 0, "Skipping the typewriter never advances")
	director.stop_dialogue()
	director.play_dialogue(seq)
	check(box.is_typing(), "Test setup: a slow line is typing")
	director.stop_dialogue()
	check(not box.is_typing(), "Stopping the dialogue stops the reveal")
	await create_timer(0.2).timeout
	check_eq(finished[0], 1, "...and nothing is announced afterwards")
	# Finishing on its own.
	var quick := sequence("typing_quick", ["A line that takes a fraction of a second to type."], {"typing_speed": 300.0})
	director.play_dialogue(quick)
	var done: bool = await wait_until(func() -> bool: return director.get_state() == State.WAITING_FOR_INPUT)
	check(done and text.visible_characters == -1 and finished[0] == 2, "A line must finish by itself and wait for the player")
	check(box.get_node("%ContinueIndicator").modulate.a > 0.2, "The continue indicator appears once the line is complete")
	director.advance_dialogue()
	# A line replaced mid-way must not finish into its successor, even once its own reveal would have ended.
	var replaced: Array = [0]
	var standalone: DialogueBox = load(BOX_SCENE).instantiate()
	root.add_child(standalone)
	standalone.typewriter_finished.connect(func() -> void: replaced[0] += 1)
	standalone.present_line(line("Short one"), 20.0)  # would finish after 0.45 s
	await create_timer(0.1).timeout
	var second := "The second line is much longer, so it is still typing long after the first one would have ended."
	standalone.present_line(line(second), 20.0)
	check(box_text(standalone).visible_characters >= 0 and box_text(standalone).visible_characters < 5, "The replacement starts from the beginning")
	await create_timer(0.7).timeout
	check(standalone.is_typing() and replaced[0] == 0, "The replaced line's reveal must not complete its successor")
	check(box_text(standalone).visible_characters > 5 and box_text(standalone).visible_characters < second.length(), "The replacement keeps typing at its own pace")
	standalone.reveal_all()
	standalone.reveal_all()
	await create_timer(0.3).timeout
	check_eq(replaced[0], 1, "Only the line that completed reports completion")
	check_eq(standalone.get_line_text(), second, "The replacement is what is shown")
	# Closing mid-reveal cancels it: nothing is announced once the box is gone.
	var after_close: Array = [0]
	standalone.typewriter_finished.connect(func() -> void: after_close[0] += 1)
	standalone.present_line(line("Closing before the end."), 40.0)  # would finish after 0.55 s
	await create_timer(0.1).timeout
	standalone.close()
	check(not standalone.is_typing(), "Closing the box stops the reveal")
	check_eq(box_text(standalone).visible_characters, -1, "...and the line fades out complete instead of frozen half-written")
	await create_timer(0.8).timeout
	check_eq(after_close[0], 0, "A reveal that was closed never reports completion")
	standalone.close(true)
	standalone.close(true)
	check(not standalone.is_open(), "Closing twice is harmless")
	dispose(standalone)
	dispose(director)


func test_empty_and_missing_content() -> void:
	var box: DialogueBox = load(BOX_SCENE).instantiate()
	root.add_child(box)
	var finished: Array = [0]
	box.typewriter_finished.connect(func() -> void: finished[0] += 1)
	box.present_line(line(""), 40.0)
	check(finished[0] == 1 and not box.is_typing() and box_text(box).visible_characters == -1, "An empty line completes at once without dividing by zero")
	box.present_line(line("   "), 0.0)
	check_eq(finished[0], 2, "Whitespace and a zero speed also complete at once")
	box.present_line(line("A negative speed.", "Tester"), -10.0)
	check_eq(finished[0], 3, "A negative speed shows the line at once")
	# Optional portrait, voice and speaker name.
	var plain := line("Nothing optional here.", "Speaker")
	box.present_line(plain, INSTANT)
	check(not box.is_portrait_visible() and not box.get_node("%VoicePlayer").playing, "A line without a portrait or voice must show neither")
	check(box.get_node("%VoicePlayer").stream == null, "No voice stream is assigned")
	var portrait_line := line("With a portrait.", "Speaker")
	portrait_line.portrait = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var voice := AudioStreamWAV.new()
	voice.format = AudioStreamWAV.FORMAT_8_BITS
	voice.mix_rate = 8000
	voice.data = PackedByteArray([128, 128, 128, 128])
	portrait_line.voice = voice
	box.present_line(portrait_line, INSTANT)
	check(box.is_portrait_visible() and box.get_node("%Portrait").texture == portrait_line.portrait, "A portrait is shown when the line has one")
	check(box.get_node("%VoicePlayer").stream == voice, "The line's voice clip is handed to the player")
	box.present_line(plain, INSTANT)
	check(not box.is_portrait_visible() and not box.get_node("%VoicePlayer").playing, "The next line without them hides the portrait and stops the voice")
	var nameless := line("A warning label is half peeled from the console.", "")
	box.present_line(nameless, INSTANT)
	check(not box.get_node("%SpeakerName").visible and not box.get_node("%SpeakerRow").visible, "A line without a speaker leaves no empty name row")
	portrait_line.speaker_name = ""
	box.present_line(portrait_line, INSTANT)
	check(box.get_node("%SpeakerRow").visible and not box.get_node("%SpeakerName").visible and box.is_portrait_visible(), "A portrait alone still gets its row")
	dispose(box)
	# Through a director: empty lines are skipped but indices stay those of the sequence.
	var director := make_director()
	var rec := Recorder.new(director)
	var seq := sequence("gaps", ["First.", "", "Third.", "   ", "Fifth."])
	seq.lines.insert(2, null)
	director.play_dialogue(seq)
	for index in 4:
		director.advance_dialogue()
	var started := rec.events.filter(func(entry: String) -> bool: return entry.begins_with("line_started:"))
	check_eq(started, ["line_started:gaps:0", "line_started:gaps:3", "line_started:gaps:5"], "Lines without text are skipped and signals use the original indices")
	check_eq(rec.count("finished:"), 1, "The sequence still finishes once")
	dispose(director)


# --- Skipping, cancelling ------------------------------------------------------------------

func test_skipping() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	var seq := sequence("skippable", ["A.", "B.", "C.", "D."], {"finish_event_id": "done"})
	seq.lines[1].event_id = "seen_by_skip_1"
	seq.lines[3].event_id = "seen_by_skip_3"
	director.play_dialogue(seq)
	director.advance_dialogue()
	check(director.skip_dialogue(), "A skippable sequence can be skipped")
	check_eq(rec.events, [
		"block:true", "started:skippable", "line_started:skippable:0", "line_finished:skippable:0", "line_started:skippable:1",
		"event:seen_by_skip_1", "line_finished:skippable:1", "event:seen_by_skip_3", "event:done", "block:false", "skipped:skippable", "finished:skippable",
	], "Skipping fires the events of unseen lines, then finishes normally")
	check(director.has_played("skippable") and not director.is_dialogue_active(), "A skipped sequence counts as played and releases the director")
	check(not director.skip_dialogue(), "Nothing is skippable while idle")
	# Skip refused.
	rec.events.clear()
	var locked := sequence("locked", ["A.", "B."], {"allow_skip": false})
	director.play_dialogue(locked)
	check(not director.skip_dialogue(), "A sequence that disallows skipping must refuse")
	check(director.get_current_sequence_id() == "locked" and rec.count("skipped:") == 0 and rec.count("finished:") == 0, "A refused skip changes nothing")
	director.stop_dialogue()
	# From the very first moment, before any line is current.
	rec.events.clear()
	var early := sequence("early_skip", ["A.", "B."])
	early.lines[0].event_id = "never_shown_but_announced"
	director.dialogue_started.connect(func(_id: String) -> void: director.skip_dialogue(), CONNECT_ONE_SHOT)
	director.play_dialogue(early)
	check_eq(rec.events, [
		"block:true", "started:early_skip", "event:never_shown_but_announced", "block:false", "skipped:early_skip", "finished:early_skip",
	], "Skipping before the first line still announces every line's event and shows nothing")
	dispose(director)


func test_cancellation() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	var seq := sequence("cancel_me", ["A.", "B.", "C."], {"play_once": true, "finish_event_id": "never"})
	seq.lines[2].event_id = "also_never"
	director.play_dialogue(seq)
	director.advance_dialogue()
	director.stop_dialogue()
	check_eq(rec.events, [
		"block:true", "started:cancel_me", "line_started:cancel_me:0", "line_finished:cancel_me:0", "line_started:cancel_me:1",
		"line_finished:cancel_me:1", "block:false", "cancelled:cancel_me",
	], "Cancelling closes the open line, releases input and announces cancellation, with no story events")
	check(not director.is_dialogue_active() and not director.has_played("cancel_me"), "A cancelled sequence is idle and not counted as played")
	check(not director.dialogue_box.is_open(), "The box starts closing")
	director.stop_dialogue()
	check_eq(rec.count("cancelled:"), 1, "Stopping twice announces once")
	check(director.play_dialogue(seq), "A cancelled play-once sequence can be played again")
	director.stop_dialogue()
	dispose(director)


# --- Queue --------------------------------------------------------------------------------

func test_queue() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	var a := sequence("queue_a")
	var b := sequence("queue_b")
	var c := sequence("queue_c")
	check(director.play_dialogue(a) and director.play_dialogue(b) and director.play_dialogue(c), "The first plays; later requests are queued")
	check_eq(director.get_queued_sequence_ids(), PackedStringArray(["queue_b", "queue_c"]), "The queue is first-in, first-out")
	check(director.get_current_sequence_id() == "queue_a" and director.get_queue_size() == 2, "Only the first is active")
	check(not director.play_dialogue(a) and not director.play_dialogue(b), "Asking again for the active or a queued sequence is refused")
	check(not director.play_dialogue(sequence("queue_b")), "A different resource with the same ID counts as a duplicate")
	check_eq(rec.rejections, ["queue_a:duplicate", "queue_b:duplicate", "queue_b:duplicate"], "Duplicates are named as such")
	for i in 2:
		director.advance_dialogue()
	check(director.get_current_sequence_id() == "queue_b" and director.get_queue_size() == 1, "The next queued sequence starts when the first ends")
	for i in 2:
		director.advance_dialogue()
	check(director.get_current_sequence_id() == "queue_c" and director.get_queue_size() == 0, "...and the one after it")
	for i in 2:
		director.advance_dialogue()
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("started:") or entry.begins_with("finished:")),
			["started:queue_a", "finished:queue_a", "started:queue_b", "finished:queue_b", "started:queue_c", "finished:queue_c"], "They play strictly in request order")
	check(director.get_queue_size() == 0 and not director.is_dialogue_active(), "The queue drains completely")
	check_eq(rec.blocked, [true, false], "Back-to-back blocking sequences keep input locked instead of flickering")
	# Size limit.
	director.max_queue_size = 2
	director.play_dialogue(sequence("full_a"))
	director.play_dialogue(sequence("full_b"))
	director.play_dialogue(sequence("full_c"))
	check(not director.play_dialogue(sequence("full_d")) and rec.rejections.back() == "full_d:queue_full", "A full queue refuses more requests")
	# Clearing.
	rec.events.clear()
	check_eq(director.clear_queue(), 2, "clear_queue reports how many it dropped")
	check_eq(rec.events, ["cancelled:full_b", "cancelled:full_c"], "Each dropped request is announced as cancelled, in order")
	check(director.get_current_sequence_id() == "full_a", "Clearing the queue leaves the active sequence alone")
	# stop with and without clearing.
	director.play_dialogue(sequence("after_a"))
	rec.events.clear()
	director.stop_dialogue(false)
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("cancelled:") or entry.begins_with("started:")), ["cancelled:full_a", "started:after_a"], "stop_dialogue(false) lets the next one start")
	director.play_dialogue(sequence("doomed"))
	rec.events.clear()
	director.stop_dialogue()
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("cancelled:")), ["cancelled:after_a", "cancelled:doomed"], "stop_dialogue() also cancels everything waiting")
	check(not director.is_dialogue_active() and director.get_queue_size() == 0, "Nothing is left")
	# A queued sequence that stops being eligible is dropped, and still gets its cancellation.
	rec.events.clear()
	director.play_dialogue(sequence("front"))
	director.play_dialogue(sequence("went_stale", ["One."], {"play_once": true}))
	director.mark_played("went_stale")
	director.advance_dialogue()
	director.advance_dialogue()
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("started:") or entry.begins_with("cancelled:") or entry.begins_with("finished:")),
			["started:front", "finished:front", "cancelled:went_stale"], "A queued play-once sequence marked as played meanwhile is cancelled instead of started")
	check(not director.is_gameplay_input_blocked(), "Input is released when the stale entry is dropped")
	# Lock follows the sequence that is playing.
	var blocking := Recorder.new(director)
	director.play_dialogue(sequence("lock_a"))
	director.play_dialogue(sequence("lock_b", ["One."], {"playback_mode": DialogueSequence.PlaybackMode.NON_BLOCKING}))
	for i in 2:
		director.advance_dialogue()
	check_eq(blocking.blocked, [true, false], "Input is released when a non-blocking sequence follows a blocking one")
	director.stop_dialogue()
	dispose(director)


# --- Timeline -----------------------------------------------------------------------------

func test_timeline_filtering() -> void:
	var past := make_director(false, "past")
	var past_rec := Recorder.new(past)
	var for_past := sequence("only_past", ["A."], {"audience": PAST})
	var for_future := sequence("only_future", ["A."], {"audience": FUTURE})
	var for_both := sequence("for_both", ["A."], {"audience": BOTH})
	check(not past.play_dialogue(for_future), "A Past director refuses a Future-only sequence")
	check_eq(past_rec.rejections, ["only_future:wrong_timeline"], "...and says why")
	check(past.play_dialogue(for_past), "A Past director plays a Past-only sequence")
	past.stop_dialogue()
	check(past.play_dialogue(for_both), "...and a shared one")
	past.stop_dialogue()
	var future := make_director(false, "future")
	check(not future.play_dialogue(for_past) and future.play_dialogue(for_future), "A Future director is the mirror image")
	future.stop_dialogue()
	check(future.play_dialogue(for_both), "...and also plays shared sequences")
	future.stop_dialogue()
	# Per-request context, for one director serving several local players.
	check(past.play_dialogue(for_future, {"timeline": "future"}), "A request can name the local player's timeline")
	past.stop_dialogue()
	check(not past.play_dialogue(for_future, {"timeline": "bogus"}), "An unknown timeline in the context is ignored")
	check(not past.play_dialogue(for_past, {"timeline": "future"}), "The context timeline replaces the director's own for that request")
	# Explicit setting, names and AUTO following the network role.
	future.set_local_timeline("PAST")
	check(future.get_local_timeline() == "past", "Timeline names are case-insensitive")
	future.set_local_timeline("auto")
	check(future.local_timeline == DialogueDirector.LocalTimeline.AUTO, "'auto' returns to following the network")
	var network := root.get_node("NetworkManager")
	check(future.get_local_timeline() == "past", "Without a session, AUTO falls back to the Past")
	network.role = "future"
	check(future.get_local_timeline() == "future" and future.play_dialogue(for_future), "AUTO follows NetworkManager.role (Future)")
	future.stop_dialogue()
	network.role = "past"
	check(future.get_local_timeline() == "past" and not future.play_dialogue(for_future), "AUTO follows NetworkManager.role (Past)")
	network.role = "nonsense"
	check(future.get_local_timeline() == "past", "An unknown role falls back to the Past")
	future.set_local_timeline("future")
	network.role = "past"
	check(future.get_local_timeline() == "future", "An explicit setting wins over the network role")
	network.role = ""
	dispose(past)
	dispose(future)


# --- History ------------------------------------------------------------------------------

func test_play_once_and_reset() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	var once := sequence("only_once", ["A."], {"play_once": true})
	var again := sequence("again_and_again", ["A."])
	check(director.play_dialogue(once), "A play-once sequence plays the first time")
	check(not director.has_played("only_once"), "It is not played until it completes")
	director.advance_dialogue()
	check(director.has_played("only_once") and director.get_played_ids() == PackedStringArray(["only_once"]), "Completion is remembered")
	check(not director.play_dialogue(once) and rec.rejections.back() == "only_once:already_played", "A completed play-once sequence is refused")
	for i in 3:
		check(director.play_dialogue(again), "A repeatable sequence plays every time (%d)" % i)
		director.advance_dialogue()
	check(director.has_played("again_and_again"), "Repeatable sequences are remembered too, but never refused")
	director.mark_played("clue_found_elsewhere")
	director.mark_played("")
	check(not director.play_dialogue(sequence("clue_found_elsewhere", ["A."], {"play_once": true})) and director.get_played_ids().size() == 3, "mark_played counts a sequence as played; an empty ID is ignored")
	# Session reset.
	director.play_dialogue(sequence("active"))
	director.play_dialogue(sequence("waiting"))
	rec.events.clear()
	director.reset_session()
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("cancelled:")), ["cancelled:active", "cancelled:waiting"], "Reset cancels what is active and what is waiting")
	check(director.get_played_ids().is_empty() and not director.has_played("only_once"), "Reset forgets the session's history")
	check(not director.is_dialogue_active() and director.get_queue_size() == 0 and not director.is_gameplay_input_blocked(), "Reset leaves the director idle and unlocked")
	check(director.play_dialogue(once), "A play-once sequence plays again after a reset")
	director.stop_dialogue()
	director.reset_session()
	check(not director.is_dialogue_active(), "Resetting an idle director is harmless")
	dispose(director)


# --- Blocking -----------------------------------------------------------------------------

func test_blocking_and_non_blocking() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	director.play_dialogue(sequence("blocking", ["A."]))
	check(director.is_gameplay_input_blocked() and rec.blocked == [true], "A blocking sequence requests a lock when it starts")
	director.advance_dialogue()
	check(not director.is_gameplay_input_blocked() and rec.blocked == [true, false], "...and releases it when it finishes")
	director.play_dialogue(sequence("cancelled_blocking"))
	director.stop_dialogue()
	check(not director.is_gameplay_input_blocked() and rec.blocked == [true, false, true, false], "...and when it is cancelled")
	rec.blocked.clear()
	var ambient := sequence("ambient", ["A.", "B."], {"playback_mode": DialogueSequence.PlaybackMode.NON_BLOCKING})
	check(director.play_dialogue(ambient), "A non-blocking sequence plays")
	check(director.is_dialogue_active() and not director.is_gameplay_input_blocked() and rec.blocked.is_empty(), "It never asks for a lock")
	await process_frame
	check(not press(&"move_left") and not press(&"move_right"), "Movement input stays untouched while it plays")
	check(press(&"ui_accept"), "...while the dialogue still takes its own input")
	director.advance_dialogue()
	check(rec.blocked.is_empty() and rec.count("finished:ambient") == 1, "It finishes without ever touching the lock")
	check(sequence("default_mode").is_blocking(), "Sequences block by default")
	dispose(director)


# --- Input --------------------------------------------------------------------------------

func test_input_handling() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	var slow := sequence("input", ["The text takes a moment to type out on screen."], {"typing_speed": 25.0})
	slow.lines.append(line("Second line."))
	director.play_dialogue(slow)
	# The press that started a conversation must not also advance it.
	check(not press(&"ui_accept") and director.get_state() == State.SHOWING_LINE, "Input in the frame a sequence starts is ignored and left unhandled")
	await process_frame
	check(press(&"ui_accept") and director.get_state() == State.WAITING_FOR_INPUT and director.get_current_line_index() == 0, "First press reveals the whole line")
	check(press(&"ui_accept") and director.get_current_line_index() == 1 and director.get_state() == State.SHOWING_LINE, "Second press moves to the next line, which starts typing")
	check(not press_key(KEY_ENTER, true) and director.get_state() == State.SHOWING_LINE, "A held key's echo events are ignored")
	check(press_key(KEY_ENTER) and director.get_state() == State.WAITING_FOR_INPUT, "The Enter key reveals the line")
	check(press_key(KEY_SPACE) and rec.count("finished:input") == 1 and not director.is_dialogue_active(), "Space continues, and the last press closes the dialogue")
	check(not press(&"ui_accept") and not press_key(KEY_SPACE), "An idle director consumes nothing")
	# Space and Escape through real key events.
	var skippable := sequence("keys", ["A.", "B.", "C."])
	director.play_dialogue(skippable)
	await process_frame
	check(press_key(KEY_SPACE) and director.get_current_line_index() == 1, "Space advances")
	check(not press_key(KEY_F5), "Unrelated keys are not consumed")
	check(press_key(KEY_ESCAPE) and rec.count("skipped:keys") == 1, "Escape skips a skippable sequence and is consumed")
	var locked := sequence("keys_locked", ["A.", "B."], {"allow_skip": false})
	director.play_dialogue(locked)
	await process_frame
	check(not press_key(KEY_ESCAPE) and director.get_current_sequence_id() == "keys_locked", "Escape on an unskippable sequence is left unhandled, so a pause menu can still use it")
	director.stop_dialogue()
	# Actions are configurable, and a missing one is harmless.
	if not InputMap.has_action(&"dialogue_test_advance"):
		InputMap.add_action(&"dialogue_test_advance")
	director.advance_action = &"dialogue_test_advance"
	director.play_dialogue(sequence("custom_action", ["A.", "B."]))
	await process_frame
	check(not press(&"ui_accept") and director.get_current_line_index() == 0, "A reassigned advance action replaces ui_accept")
	check(press(&"dialogue_test_advance") and director.get_current_line_index() == 1, "...and the new action advances")
	director.advance_action = &"action_that_does_not_exist"
	check(not press(&"action_that_does_not_exist"), "An action missing from the InputMap is ignored")
	director.advance_action = &""
	check(not press(&"ui_accept"), "An empty action name disables that input")
	director.stop_dialogue()
	InputMap.erase_action(&"dialogue_test_advance")
	dispose(director)


func test_rapid_input() -> void:
	var director := make_director()
	var rec := Recorder.new(director)
	var seq := sequence("rapid", ["The first line, typed slowly.", "The second line, typed slowly.", "The third line, typed slowly."], {"typing_speed": 40.0})
	director.play_dialogue(seq)
	await process_frame
	var handled := 0
	for i in 60:
		if press(&"ui_accept"):
			handled += 1
	check_eq(handled, 6, "Three lines take exactly six presses (reveal, then advance), however fast they come")
	check_eq(rec.count("finished:rapid"), 1, "Mashing the button finishes the sequence exactly once")
	check_eq(rec.count("line_started:"), 3, "Every line starts exactly once")
	check(rec.count("cancelled:") == 0 and not director.is_dialogue_active(), "Nothing is cancelled and the director ends idle")
	var started := rec.events.filter(func(entry: String) -> bool: return entry.begins_with("line_started:"))
	check_eq(started, ["line_started:rapid:0", "line_started:rapid:1", "line_started:rapid:2"], "Lines are never skipped or repeated")
	# The same through the API, in one burst.
	director.play_dialogue(sequence("burst", ["A.", "B.", "C."]))
	for i in 40:
		director.advance_dialogue()
		director.skip_typewriter()
	check_eq(rec.count("finished:burst"), 1, "A burst of API calls finishes it once")
	dispose(director)


# --- Cleanup ------------------------------------------------------------------------------

func test_scene_cleanup() -> void:
	# The whole system leaves the tree while a blocking dialogue plays and another waits.
	var director := make_director()
	var rec := Recorder.new(director)
	director.play_dialogue(sequence("playing", ["One.", "Two."]))
	director.play_dialogue(sequence("waiting"))
	check(director.is_gameplay_input_blocked(), "Test setup: input is locked")
	root.remove_child(director)
	check_eq(rec.events, [
		"block:true", "started:playing", "line_started:playing:0", "line_finished:playing:0", "block:false", "cancelled:playing", "cancelled:waiting",
	], "Leaving the tree cancels everything and hands input back")
	check(not director.is_gameplay_input_blocked() and not director.is_dialogue_active() and director.get_queue_size() == 0, "Nothing is left behind")
	check(not director.play_dialogue(sequence("too_late")), "A director outside the tree refuses new requests")
	director.free()
	# The same without a box: here the director's own exit path is the only protection.
	director = make_director(false)
	rec = Recorder.new(director)
	director.play_dialogue(sequence("bare_playing", ["One.", "Two."]))
	director.play_dialogue(sequence("bare_waiting"))
	root.remove_child(director)
	check_eq(rec.events, [
		"block:true", "started:bare_playing", "line_started:bare_playing:0", "line_finished:bare_playing:0", "block:false", "cancelled:bare_playing", "cancelled:bare_waiting",
	], "A director without a box also cancels everything and hands input back when it leaves the tree")
	director.free()
	# Only the box disappears: nothing can show the conversation, so it must not trap the player behind it.
	director = make_director()
	rec = Recorder.new(director)
	director.play_dialogue(sequence("boxed"))
	director.dialogue_box.free()
	check_eq(rec.events.slice(-2), ["block:false", "cancelled:boxed"], "Losing the box cancels the conversation and releases input")
	check(director.play_dialogue(sequence("without_box", ["One."])), "A director that lost its box still runs, invisibly")
	director.advance_dialogue()
	check_eq(rec.count("finished:without_box"), 1, "...and finishes")
	dispose(director)
	# The scene is freed while text is still typing, with a timer and tweens pending.
	director = make_director()
	director.play_dialogue(sequence("typing_away", ["A long line that is still being typed when the whole scene goes away."], {"typing_speed": 20.0, "auto_advance": true}))
	director.play_dialogue(sequence("auto_waiting", ["Auto."], {"auto_advance": true}))
	await create_timer(0.1).timeout
	director.queue_free()
	for i in 6:
		await process_frame
	check(not is_instance_valid(director), "The scene is freed mid-dialogue")
	# A director without a box, freed while its auto-advance timer is running.
	director = make_director(false)
	director.play_dialogue(sequence("timed", ["One.", "Two."], {"auto_advance": true, "auto_advance_delay": 0.1}))
	director.queue_free()
	await create_timer(0.3).timeout
	check(not is_instance_valid(director), "A pending timer cannot outlive its director")


func test_presenter_swap() -> void:
	# A director built in code gets its box later, in the middle of a conversation.
	var director := make_director(false)
	var rec := Recorder.new(director)
	director.play_dialogue(sequence("swap", ["First line.", "Second line."], {"typing_speed": 25.0}))
	var first_box: DialogueBox = load(BOX_SCENE).instantiate()
	root.add_child(first_box)
	director.set_dialogue_box(first_box)
	check(first_box.is_open() and first_box.get_line_text() == "First line.", "A box attached mid-dialogue shows the current line")
	check(not first_box.is_typing() and director.get_state() == State.WAITING_FOR_INPUT, "...fully revealed, so the conversation carries on")
	director.set_dialogue_box(first_box)
	check(first_box.get_line_text() == "First line." and director.get_state() == State.WAITING_FOR_INPUT, "Attaching the same box again changes nothing")
	await process_frame
	check(press(&"ui_accept") and director.get_current_line_index() == 1 and first_box.get_line_text() == "Second line.", "The attached box is driven like any other")
	check(first_box.is_typing() and director.get_state() == State.SHOWING_LINE, "...including its typewriter")
	director.set_dialogue_box(first_box)
	check(first_box.is_typing() and director.get_state() == State.SHOWING_LINE, "Attaching the same box mid-reveal does not disturb it")
	# Swapped while a line is typing: the old box closes, the new one takes over, nothing hangs.
	var second_box: DialogueBox = load(BOX_SCENE).instantiate()
	root.add_child(second_box)
	director.set_dialogue_box(second_box)
	check(not first_box.is_open() and not first_box.is_typing(), "The previous box is closed and silent")
	check(second_box.get_line_text() == "Second line." and not second_box.is_typing() and director.get_state() == State.WAITING_FOR_INPUT, "The new box shows the current line at once")
	check(press(&"ui_accept") and rec.count("finished:swap") == 1, "The conversation still ends normally")
	# Removing the box mid-line must not leave the director waiting for a reveal nobody will report.
	director.play_dialogue(sequence("detach", ["A slowly typed line.", "Next."], {"typing_speed": 20.0}))
	check(second_box.is_typing() and director.get_state() == State.SHOWING_LINE, "Test setup: a line is typing")
	director.set_dialogue_box(null)
	check(not second_box.is_open() and director.get_state() == State.WAITING_FOR_INPUT, "Detaching the box completes the line instead of hanging")
	director.advance_dialogue()
	director.advance_dialogue()
	check(rec.count("finished:detach") == 1, "A director without a box finishes the conversation")
	check(not second_box.typewriter_finished.is_connected(director._on_typewriter_finished), "A detached box is disconnected")
	# Attached by hand before the director is ready: _ready must not connect it a second time.
	var early := DialogueDirector.new()
	early.log_problems = false
	var early_box: DialogueBox = load(BOX_SCENE).instantiate()
	early.set_dialogue_box(early_box)
	root.add_child(early_box)
	root.add_child(early)
	check_eq(early_box.typewriter_finished.get_connections().size(), 1, "A box attached before _ready is connected exactly once")
	check(early.play_dialogue(sequence("early", ["Hello."])) and early_box.get_line_text() == "Hello.", "...and it works")
	early.stop_dialogue()
	dispose(early_box)
	dispose(early)
	dispose(first_box)
	dispose(second_box)
	dispose(director)


# --- Independence, events -----------------------------------------------------------------

func test_independent_directors() -> void:
	var past := make_director(true, "past")
	var future := make_director(true, "future")
	var past_rec := Recorder.new(past)
	var future_rec := Recorder.new(future)
	var shared := sequence("shared_once", ["Shared."], {"play_once": true})
	check(past.play_dialogue(shared) and future.play_dialogue(shared), "Two directors can play the same sequence at once")
	past.advance_dialogue()
	check(past.has_played("shared_once") and not future.has_played("shared_once"), "Each director keeps its own history")
	check(future.is_dialogue_active() and not past.is_dialogue_active(), "Each director keeps its own state")
	check(future.is_gameplay_input_blocked() and not past.is_gameplay_input_blocked(), "Each director keeps its own lock")
	check(past_rec.count("finished:") == 1 and future_rec.count("finished:") == 0, "Signals stay with their director")
	check(past.play_dialogue(sequence("past_only_queue")) and past.get_queue_size() == 0 and future.get_queue_size() == 0, "Queues are separate")
	past.stop_dialogue()
	future.stop_dialogue()
	past.reset_session()
	check(not past.has_played("shared_once"), "Resetting one director...")
	future.play_dialogue(shared)
	future.advance_dialogue()
	check(future.has_played("shared_once"), "...never touches the other")
	# Each box keeps its own look.
	var past_box: DialogueBox = past.dialogue_box
	var future_box: DialogueBox = future.dialogue_box
	past_box.present_line(line("Then.", "A", PAST), INSTANT)
	future_box.present_line(line("Later.", "B", FUTURE), INSTANT)
	var past_style: StyleBoxFlat = past_box.get_node("%DialoguePanel").get_theme_stylebox("panel")
	var future_style: StyleBoxFlat = future_box.get_node("%DialoguePanel").get_theme_stylebox("panel")
	check(past_style != future_style, "Each box owns its panel style (resource_local_to_scene)")
	check(past_style.border_color.is_equal_approx(Color(past_box.past_accent, 0.85)) and future_style.border_color.is_equal_approx(Color(future_box.future_accent, 0.85)), "...so one box's accent never leaks into the other")
	check(DialogueDirector.GROUP in past.get_groups() and get_nodes_in_group(DialogueDirector.GROUP).size() == 2, "Both directors register in the director group")
	dispose(past)
	dispose(future)


func test_narrative_events() -> void:
	var director := make_director(false)
	var rec := Recorder.new(director)
	var seq := sequence("events", ["A.", "B."], {"start_event_id": " spaced_start ", "finish_event_id": "   "})
	seq.lines[0].event_id = "first_line"
	seq.lines[1].event_id = ""
	director.play_dialogue(seq)
	director.advance_dialogue()
	director.advance_dialogue()
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("event:")), ["event:spaced_start", "event:first_line"], "Event IDs are trimmed, and empty ones announce nothing")
	var order := rec.events.filter(func(entry: String) -> bool: return entry != "block:true" and entry != "block:false")
	check(order.find("event:spaced_start") < order.find("line_started:events:0") and order.find("line_started:events:0") < order.find("event:first_line"), "The sequence event comes first, a line's event right after its line starts")
	rec.events.clear()
	var doomed := sequence("doomed_events", ["A.", "B."], {"start_event_id": "start", "finish_event_id": "finish"})
	doomed.lines[1].event_id = "second"
	director.play_dialogue(doomed)
	director.stop_dialogue()
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("event:")), ["event:start"], "Cancelling announces only what already happened")
	dispose(director)


func test_auto_advance() -> void:
	var director := make_director(false)
	var rec := Recorder.new(director)
	director.play_dialogue(sequence("auto", ["One.", "Two.", "Three."], {"auto_advance": true, "auto_advance_delay": 0.05}))
	check(director.get_state() == State.WAITING_FOR_INPUT and rec.count("line_started:") == 1, "Auto-advance waits for its delay first")
	var done: bool = await wait_until(func() -> bool: return rec.count("finished:auto") == 1)
	check(done and rec.count("line_started:") == 3, "It plays every line without any input")
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("line_started:")), ["line_started:auto:0", "line_started:auto:1", "line_started:auto:2"], "...in order")
	# A press during the wait moves on at once, and the timer does not advance a second time.
	rec.events.clear()
	director.play_dialogue(sequence("auto_press", ["One.", "Two.", "Three."], {"auto_advance": true, "auto_advance_delay": 0.15}))
	await process_frame
	director.advance_dialogue()
	check_eq(director.get_current_line_index(), 1, "A press during the wait advances immediately")
	await create_timer(0.1).timeout
	check_eq(director.get_current_line_index(), 1, "The cancelled timer does not advance again")
	director.stop_dialogue()
	var count := rec.events.size()
	await create_timer(0.35).timeout
	check_eq(rec.events.size(), count, "Stopping cancels the pending auto-advance")
	# The box does not prompt for a key the player does not need to press.
	var boxed := make_director(true)
	boxed.play_dialogue(sequence("auto_box", ["One."], {"auto_advance": true, "auto_advance_delay": 5.0}))
	check(boxed.dialogue_box.get_node("%ContinueIndicator").modulate.a == 0.0, "No continue prompt while auto-advancing")
	boxed.stop_dialogue()
	boxed.play_dialogue(sequence("manual_box", ["One."]))
	check(boxed.dialogue_box.get_node("%ContinueIndicator").modulate.a > 0.0, "...but one while waiting for the player")
	dispose(boxed)
	dispose(director)


# --- Re-entrancy --------------------------------------------------------------------------

## Every way a listener could poke the director while its sequence is finishing.
func poke_finishing_director(_event_id: String, director: DialogueDirector) -> void:
	check(director.get_state() == State.FINISHING, "Test setup: the finish event is announced while FINISHING")
	director.stop_dialogue()
	check(not director.skip_dialogue(), "A skip requested while finishing is refused")
	director.advance_dialogue()
	director.skip_typewriter()


## Listeners may call back into the director from inside any signal. None of these may corrupt it.
func test_reentrancy() -> void:
	# Stopped from the very first signal.
	var director := make_director(false)
	var rec := Recorder.new(director)
	director.dialogue_started.connect(func(_id: String) -> void: director.stop_dialogue(), CONNECT_ONE_SHOT)
	check(director.play_dialogue(sequence("stopped_at_once")), "The request is accepted")
	check_eq(rec.events, ["block:true", "started:stopped_at_once", "block:false", "cancelled:stopped_at_once"], "A stop from dialogue_started ends it cleanly: one cancellation, no line")
	# Skipped from the first line's start.
	rec.events.clear()
	var seq := sequence("skipped_in_handler", ["A.", "B.", "C."])
	seq.lines[1].event_id = "unseen"
	director.dialogue_line_started.connect(func(_id: String, _index: int) -> void: director.skip_dialogue(), CONNECT_ONE_SHOT)
	director.play_dialogue(seq)
	check_eq(rec.events, [
		"block:true", "started:skipped_in_handler", "line_started:skipped_in_handler:0", "line_finished:skipped_in_handler:0", "event:unseen",
		"block:false", "skipped:skipped_in_handler", "finished:skipped_in_handler",
	], "A skip from dialogue_line_started pairs the line and finishes once")
	# Advanced from inside the end of a line: one advance, not two.
	rec.events.clear()
	director.dialogue_line_finished.connect(func(_id: String, _index: int) -> void: director.advance_dialogue(), CONNECT_ONE_SHOT)
	director.play_dialogue(sequence("advance_in_handler", ["A.", "B.", "C."]))
	director.advance_dialogue()
	check_eq(rec.count("line_started:advance_in_handler:1"), 1, "An advance from dialogue_line_finished does not advance twice")
	check_eq(director.get_current_line_index(), 1, "...and lands on the next line")
	director.stop_dialogue()
	# Stopped from inside the end of a line.
	rec.events.clear()
	director.dialogue_line_finished.connect(func(_id: String, _index: int) -> void: director.stop_dialogue(), CONNECT_ONE_SHOT)
	director.play_dialogue(sequence("stop_in_line_end", ["A.", "B."]))
	director.advance_dialogue()
	check_eq(rec.events, ["block:true", "started:stop_in_line_end", "line_started:stop_in_line_end:0", "line_finished:stop_in_line_end:0", "block:false", "cancelled:stop_in_line_end"], "A stop from dialogue_line_finished cancels without starting the next line")
	# Stop, skip and advance requested while the sequence is already completing are too late.
	rec.events.clear()
	var finishing := sequence("finishing", ["A."], {"finish_event_id": "ending"})
	director.narrative_event_requested.connect(poke_finishing_director.bind(director), CONNECT_ONE_SHOT)
	director.play_dialogue(finishing)
	director.advance_dialogue()
	check(rec.count("finished:finishing") == 1 and rec.count("cancelled:") == 0 and rec.count("skipped:") == 0, "A sequence that has reached its end cannot be cancelled, skipped or advanced again")
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("line_") or entry.begins_with("started:")), ["started:finishing", "line_started:finishing:0", "line_finished:finishing:0"], "...and none of those calls started or ended anything extra")
	# Chained from the end of another.
	rec.events.clear()
	rec.blocked.clear()
	director.dialogue_finished.connect(func(_id: String) -> void: director.play_dialogue(sequence("second_of_chain", ["B."])), CONNECT_ONE_SHOT)
	director.play_dialogue(sequence("first_of_chain", ["A."]))
	director.advance_dialogue()
	check(director.get_current_sequence_id() == "second_of_chain", "A listener can start the next conversation from dialogue_finished")
	check_eq(rec.events.filter(func(entry: String) -> bool: return entry.begins_with("started:") or entry.begins_with("finished:")), ["started:first_of_chain", "finished:first_of_chain", "started:second_of_chain"], "...and it starts after the first has finished")
	check_eq(rec.blocked, [true, false, true], "Input is released, then requested again, when a listener chains a blocking sequence (a queue would keep it locked)")
	director.stop_dialogue()
	# Queue order is kept even when a listener adds to it while the director has just gone idle.
	rec.events.clear()
	director.dialogue_finished.connect(func(_id: String) -> void: director.play_dialogue(sequence("late_comer", ["C."])), CONNECT_ONE_SHOT)
	director.play_dialogue(sequence("head", ["A."]))
	director.play_dialogue(sequence("already_waiting", ["B."]))
	director.advance_dialogue()
	check(director.get_current_sequence_id() == "already_waiting" and director.get_queued_sequence_ids() == PackedStringArray(["late_comer"]), "A request made while the queue is draining joins the back of it")
	director.stop_dialogue()
	# Nothing can be requested from inside a reset.
	rec.events.clear()
	rec.rejections.clear()
	director.dialogue_cancelled.connect(func(_id: String) -> void: director.play_dialogue(sequence("slipped_in", ["A."])), CONNECT_ONE_SHOT)
	director.play_dialogue(sequence("being_reset"))
	director.reset_session()
	check(not director.is_dialogue_active() and rec.rejections == ["slipped_in:unavailable"], "A reset cannot be undone by a handler starting something new")
	dispose(director)


# --- Box ----------------------------------------------------------------------------------

func test_box_styling() -> void:
	var box: DialogueBox = load(BOX_SCENE).instantiate()
	root.add_child(box)
	check_eq(box.get_accent_for(PAST), Color("e4bf7f"), "Past lines use warm amber #E4BF7F")
	check_eq(box.get_accent_for(FUTURE), Color("86c9d1"), "Future lines use cold cyan #86C9D1")
	var rift := box.get_accent_for(BOTH)
	check(rift != box.get_accent_for(PAST) and rift != box.get_accent_for(FUTURE) and rift.b > rift.g, "Voices across the rift use a distinct blue-violet accent")
	for timeline in [PAST, FUTURE, BOTH]:
		box.present_line(line("Accent test.", "Speaker", timeline), INSTANT)
		check_eq(box.get_current_accent(), box.get_accent_for(timeline), "The box applies the accent of the line it shows")
		check(box.get_node("%SpeakerName").get_theme_color("font_color").is_equal_approx(box.get_accent_for(timeline)), "The speaker name takes the accent")
	box.past_accent = Color.RED
	box.present_line(line("Accent test.", "Speaker", PAST), INSTANT)
	check_eq(box.get_current_accent(), Color.RED, "Accents can be reconfigured without touching code")
	check(box.layer > 1, "The box draws above the HUD layer")
	check(box.get_node("%DialoguePanel").anchor_top == 1.0 and box.get_node("%DialoguePanel").anchor_bottom == 1.0, "The panel is anchored to the bottom of the screen")
	check(box.get_node("%DialogueText") is RichTextLabel and box.get_node("%DialogueText").bbcode_enabled, "Text is a BBCode RichTextLabel")
	box.close(true)
	check(not box.is_open(), "A closed box is not open")
	dispose(box)


func test_no_node_growth() -> void:
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var director := make_director()
	await process_frame
	var with_director := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 60:
		director.play_dialogue(sequence("churn_%d" % i, ["One.", "Two."]))
		director.advance_dialogue()
		director.advance_dialogue()
	director.play_dialogue(sequence("churn_cancelled", ["One.", "Two."]))
	director.stop_dialogue()
	await process_frame
	check_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), with_director, "Playing dialogue must reuse the same nodes instead of creating new ones")
	dispose(director)
	await process_frame
	check_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), baseline, "Freeing the system leaves no node behind")


# --- Trigger adapter ----------------------------------------------------------------------

func make_trigger(emitter: Node, signal_name: StringName, seq: DialogueSequence, argument_index: int = -1, argument_value: String = "") -> DialogueTrigger:
	var trigger := DialogueTrigger.new()
	trigger.log_problems = false
	trigger.sequence = seq
	trigger.source = emitter.get_path()
	trigger.source_signal = signal_name
	trigger.argument_index = argument_index
	trigger.argument_value = argument_value
	root.add_child(trigger)
	return trigger


func test_trigger_adapter() -> void:
	var director := make_director(false)
	var emitter := Emitter.new()
	root.add_child(emitter)
	var seq := sequence("triggered", ["Hello."])
	# Filtered by an argument.
	var filtered := make_trigger(emitter, &"fired", seq, 1, "yes")
	check(filtered.is_listening(), "A trigger listens once its source is found")
	emitter.fired.emit("anything", "no")
	check(not director.is_dialogue_active(), "A non-matching argument does not trigger")
	emitter.fired.emit("anything", "yes")
	check(director.get_current_sequence_id() == "triggered", "A matching argument triggers the sequence on the director found by group")
	director.stop_dialogue()
	# Any emission of a signal without arguments.
	var poked := make_trigger(emitter, &"poked", seq)
	emitter.poked.emit()
	check(director.get_current_sequence_id() == "triggered", "A signal without arguments triggers on every emission")
	director.stop_dialogue()
	poked.free()
	# Misconfiguration is refused instead of silently never firing.
	var crowded := make_trigger(emitter, &"crowded", seq)
	check(not crowded.is_listening(), "A signal with more than %d arguments is refused" % DialogueTrigger.MAX_SIGNAL_ARGUMENTS)
	var unknown := make_trigger(emitter, &"no_such_signal", seq)
	check(not unknown.is_listening(), "An unknown signal is refused")
	var lost := DialogueTrigger.new()
	lost.log_problems = false
	lost.sequence = seq
	lost.source = ^"/root/NoSuchNode"
	lost.source_signal = &"fired"
	root.add_child(lost)
	check(not lost.is_listening(), "A missing source node is refused")
	var out_of_range := make_trigger(emitter, &"fired", seq, 5, "x")
	emitter.fired.emit("x", "x")
	check(not director.is_dialogue_active(), "Filtering on an argument the signal does not have never fires")
	# Direct calls, switches and director lookup.
	check(filtered.trigger() and director.get_current_sequence_id() == "triggered", "trigger() can be called from code")
	director.stop_dialogue()
	filtered.enabled = false
	emitter.fired.emit("anything", "yes")
	check(not filtered.trigger() and not director.is_dialogue_active(), "A disabled trigger does nothing")
	filtered.enabled = true
	filtered.sequence = null
	check(not filtered.trigger(), "A trigger without a sequence does nothing")
	filtered.sequence = seq
	# Context reaches the director.
	var future_only := sequence("future_context", ["Hello."], {"audience": FUTURE})
	filtered.sequence = future_only
	check(not filtered.trigger() and filtered.trigger({"timeline": "future"}), "A trigger passes its context on to the director")
	director.stop_dialogue()
	# Explicit director.
	var other := make_director(false, "future")
	other.name = "OtherDirector"
	filtered.director = other.get_path()
	check(filtered.get_director() == other and filtered.trigger(), "An explicit director path overrides the group lookup")
	check(other.is_dialogue_active() and not director.is_dialogue_active(), "...and only that director plays it")
	other.stop_dialogue()
	filtered.director = ^"/root/NoSuchDirector"
	check(filtered.get_director() == null and not filtered.trigger(), "A bad director path means no dialogue, not an error")
	for node in [filtered, crowded, unknown, lost, out_of_range, emitter, other, director]:
		dispose(node)
	var stray := DialogueTrigger.new()
	stray.log_problems = false
	stray.sequence = seq
	check(stray.get_director() == null and not stray.trigger(), "A trigger outside the tree has no director")
	stray.free()


func test_trigger_on_ready() -> void:
	var director := make_director(false)
	var trigger := DialogueTrigger.new()
	trigger.log_problems = false
	trigger.sequence = sequence("on_ready", ["Hello."])
	trigger.trigger_on_ready = true
	root.add_child(trigger)
	check(not director.is_dialogue_active(), "trigger_on_ready waits for the scene to finish loading")
	await process_frame
	check(director.get_current_sequence_id() == "on_ready", "...then requests the sequence")
	dispose(trigger)
	dispose(director)


# --- PuzzleManager hand-off ---------------------------------------------------------------

## One confirmed gameplay event, two different conversations: each timeline listens on its own.
func test_puzzle_manager_hand_off() -> void:
	var manager := root.get_node("PuzzleManager")
	manager.log_rejections = false
	manager.register_puzzle("dialogue_hook_power", PowerSwitch.new())
	manager.register_puzzle("dialogue_hook_other", PowerSwitch.new())
	manager.begin_session()
	var past := make_director(false, "past")
	past.name = "PastDirector"
	var future := make_director(false, "future")
	future.name = "FutureDirector"
	var past_rec := Recorder.new(past)
	var future_rec := Recorder.new(future)
	var triggers: Array[DialogueTrigger] = []
	for setup: Array in [
		[past, sequence("power_on_past", ["The console hums."], {"audience": PAST})],
		[future, sequence("power_on_future", ["Decades-old lights flicker on."], {"audience": FUTURE})],
	]:
		var trigger := make_trigger(manager, &"puzzle_completed", setup[1], 0, "dialogue_hook_power")
		trigger.director = setup[0].get_path()
		triggers.append(trigger)
	# A request the manager rejects confirms nothing, so nothing is said.
	var rejected: Dictionary = manager.submit_action("dialogue_hook_power", "activate_power", {}, "future")
	check(rejected.status == Status.REJECTED and not past.is_dialogue_active() and not future.is_dialogue_active(), "A rejected puzzle action starts no dialogue")
	# Another puzzle completing is not this puzzle.
	manager.submit_action("dialogue_hook_other", "activate_power")
	check(not past.is_dialogue_active() and not future.is_dialogue_active(), "Another puzzle's completion starts no dialogue")
	# The confirmed completion starts a different conversation on each timeline.
	var result: Dictionary = manager.submit_action("dialogue_hook_power", "activate_power")
	check(result.status == Status.COMPLETED, "Test setup: the puzzle completes")
	var revision_after_action: int = manager.get_latest_revision()
	check(past.get_current_sequence_id() == "power_on_past" and future.get_current_sequence_id() == "power_on_future", "One confirmed event gave each timeline its own conversation")
	# Both triggers asked both directors? No: each is wired to one, and timeline filtering protects the rest.
	check(not past.play_dialogue(triggers[1].sequence) and past_rec.rejections.back() == "power_on_future:wrong_timeline", "A Past director refuses the Future's conversation even if asked")
	past.advance_dialogue()
	future.advance_dialogue()
	check(manager.is_solved("dialogue_hook_power") and manager.get_latest_revision() == revision_after_action, "Playing the dialogue changed no authoritative puzzle state and made no revision")
	check(past_rec.count("finished:") == 1 and future_rec.count("finished:") == 1, "Each conversation finished on its own director")
	for node in triggers:
		dispose(node)
	dispose(past)
	dispose(future)
	manager.unregister_puzzle("dialogue_hook_power")
	manager.unregister_puzzle("dialogue_hook_other")


## A conversation started by an Interactable3D. Runs only where the Interaction System exists, so this suite
## never depends on it; the output says so when it is skipped.
func test_interaction_hand_off() -> void:
	var path := "res://scripts/interaction/interactable_3d.gd"
	if not ResourceLoader.exists(path):
		print("DIALOGUE SYSTEM: interaction hand-off SKIPPED (the Interaction System is not in this checkout)")
		return
	var director := make_director(false)
	var prop := Node3D.new()
	root.add_child(prop)
	var interactable: Area3D = load(path).new()
	interactable.name = "Interactable3D"
	prop.add_child(interactable)
	var trigger := DialogueTrigger.new()
	trigger.log_problems = false
	trigger.sequence = sequence("terminal", ["Hello."])
	trigger.source = ^"../Interactable3D"
	trigger.source_signal = &"interacted"
	prop.add_child(trigger)
	var actor := Node3D.new()
	root.add_child(actor)
	check(trigger.is_listening(), "A trigger beside an Interactable3D finds it by relative path and listens to interacted(actor, role)")
	interactable.interact(actor, "past")
	check_eq(director.get_current_sequence_id(), "terminal", "Using the interactable starts the conversation")
	director.stop_dialogue()
	interactable.set("interaction_enabled", false)
	interactable.interact(actor, "past")
	check(not director.is_dialogue_active(), "A disabled interactable starts nothing: its own rules apply first")
	interactable.set("interaction_enabled", true)
	interactable.set("allowed_timeline", 2)  # Future only
	interactable.interact(actor, "past")
	check(not director.is_dialogue_active(), "An interactable restricted to the Future ignores a Past actor, so no dialogue starts")
	interactable.interact(actor, "future")
	check(director.is_dialogue_active(), "...and starts one for a Future actor")
	director.stop_dialogue()
	trigger.sequence = sequence("past_note", ["Only the Past reads this."], {"audience": PAST})
	director.set_local_timeline("future")
	interactable.interact(actor, "future")
	check(not director.is_dialogue_active(), "The director's rules apply second: a Future director refuses a Past-only conversation")
	for node in [actor, prop, director]:
		dispose(node)


## Dialogue must freeze when the game pauses: either the SceneTree pauses, or, as spawn_area does, the room
## "pauses" without pausing the tree and the documented recipe freezes the conversation by hand.
func test_pause_behaviour() -> void:
	var director := make_director()
	var text := box_text(director.dialogue_box)
	var slow := {"typing_speed": 20.0, "playback_mode": DialogueSequence.PlaybackMode.NON_BLOCKING}
	var long_line := "A long line that keeps typing for several seconds while the game is paused around it."
	director.play_dialogue(sequence("tree_pause", [long_line], slow))
	await create_timer(0.3).timeout
	var typed := text.visible_characters
	paused = true
	await create_timer(0.5).timeout
	check_eq(text.visible_characters, typed, "A paused SceneTree freezes the typewriter")
	check(not press(&"ui_accept"), "...and the director consumes no input while the tree is paused")
	paused = false
	await create_timer(0.3).timeout
	check(text.visible_characters > typed, "...and it carries on when the tree resumes")
	director.stop_dialogue()
	# A pause that leaves the tree running, handled with process_mode and visibility.
	director.play_dialogue(sequence("room_pause", [long_line], slow))
	await create_timer(0.3).timeout
	typed = text.visible_characters
	director.process_mode = Node.PROCESS_MODE_DISABLED
	director.dialogue_box.visible = false
	await create_timer(0.5).timeout
	check_eq(text.visible_characters, typed, "A disabled director's typewriter stands still")
	check(not director.dialogue_box.get_node("%RootControl").is_visible_in_tree(), "...the hidden box is off the screen")
	check(not press(&"ui_accept"), "...and the director consumes no input")
	director.process_mode = Node.PROCESS_MODE_INHERIT
	director.dialogue_box.visible = true
	await create_timer(0.3).timeout
	check(text.visible_characters > typed, "...and everything carries on from where it stopped when re-enabled")
	director.stop_dialogue()
	dispose(director)
	# The auto-advance timer stands still too.
	var timed := make_director(false)
	var rec := Recorder.new(timed)
	timed.play_dialogue(sequence("timed_pause", ["One.", "Two."], {"auto_advance": true, "auto_advance_delay": 0.3}))
	timed.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(0.7).timeout
	check_eq(rec.count("line_started:"), 1, "A disabled director's auto-advance timer stands still")
	timed.process_mode = Node.PROCESS_MODE_INHERIT
	var moved: bool = await wait_until(func() -> bool: return rec.count("line_started:") == 2)
	check(moved, "...and runs again when the director is re-enabled")
	dispose(timed)


# --- Sandbox ------------------------------------------------------------------------------

## How many PASS/FAIL lines a sandbox scenario has reported so far.
func scenario_results(sandbox: Control) -> int:
	var text: String = sandbox._log.get_parsed_text()
	return text.count("PASS") + text.count("FAIL")


func test_sandbox_scene() -> void:
	var sandbox: Control = load(SANDBOX_SCENE).instantiate()
	root.add_child(sandbox)
	await process_frame
	var director: DialogueDirector = sandbox.director
	director.log_problems = false
	var buttons := sandbox.find_children("*", "Button", true, false)
	var labels := buttons.map(func(button: Button) -> String: return button.text)
	for wanted in ["Play Opening Dialogue", "Play Rift Dialogue", "Play Future Dialogue", "Play Puzzle Completion Dialogue", "Switch Local Timeline",
			"Test Play-Once Behavior", "Test Dialogue Queue", "Test Skipping", "Test Blocking Playback", "Test Non-Blocking Playback", "Reset Dialogue Session"]:
		check(labels.any(func(text: String) -> bool: return text.begins_with(wanted)), "The sandbox must offer '%s'" % wanted)
	check(buttons.all(func(button: Button) -> bool: return button.focus_mode == Control.FOCUS_NONE), "Sandbox buttons never take keyboard focus, so Enter and Space reach the dialogue")
	# Every button works and leaves the director in a state it can recover from.
	for button: Button in buttons:
		button.pressed.emit()
		director.reset_session()
	check(not director.is_dialogue_active(), "Every button can be pressed without a script error")
	await create_timer(1.0).timeout  # let scenarios started by the buttons above run out before measuring the next
	# The self-running scenarios report PASS and no FAIL, on both timelines.
	sandbox._log.clear()
	sandbox._test_play_once()  # a coroutine that runs by itself: wait for its report, not for its end
	var reported: bool = await wait_until(func() -> bool: return scenario_results(sandbox) >= 5, 12.0)
	var log_text: String = sandbox._log.get_parsed_text()
	check(reported and log_text.count("PASS") == 5 and log_text.count("FAIL") == 0, "The play-once scenario passes: %s" % log_text)
	director.reset_session()
	for timeline in ["past", "future"]:
		director.set_local_timeline(timeline)
		sandbox._log.clear()
		sandbox._test_queue()
		log_text = sandbox._log.get_parsed_text()
		check(log_text.count("PASS") == 5 and log_text.count("FAIL") == 0, "The queue scenario passes on the %s timeline: %s" % [timeline, log_text])
		director.reset_session()
	director.set_local_timeline("past")
	sandbox._log.clear()
	sandbox._test_skip_locked()
	reported = await wait_until(func() -> bool: return scenario_results(sandbox) >= 2, 6.0)
	log_text = sandbox._log.get_parsed_text()
	check(reported and log_text.count("PASS") == 2 and log_text.count("FAIL") == 0, "The skip-locked scenario passes: %s" % log_text)
	director.reset_session()
	# The marker obeys the lock, which is what the real player controller will do with the same signal.
	sandbox._marker.position = Vector2(40, 44)
	director.play_dialogue(sandbox.OPENING)
	check(director.is_gameplay_input_blocked(), "Test setup: the opening sequence blocks")
	Input.action_press(&"move_right")
	await create_timer(0.2).timeout
	Input.action_release(&"move_right")
	check_eq(sandbox._marker.position.x, 40.0, "The marker must not move while gameplay input is blocked")
	director.reset_session()
	Input.action_press(&"move_right")
	await create_timer(0.2).timeout
	Input.action_release(&"move_right")
	check(sandbox._marker.position.x > 40.0, "The marker moves again once the lock is released")
	dispose(sandbox)
