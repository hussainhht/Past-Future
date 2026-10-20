extends Control
## Interactive test bench for the dialogue system, runnable on its own (scenes/testing/dialogue_sandbox.tscn).
## Everything outside the DialogueSystem node is a testing aid, not game UI. The dialogue box itself is
## the real, finished one, driven by a real DialogueDirector exactly as the game will drive it.

const OPENING := preload("res://resources/dialogue/samples/opening_past.tres")
const RIFT_CONTACT := preload("res://resources/dialogue/samples/first_rift_contact.tres")
const FUTURE_DISCOVERY := preload("res://resources/dialogue/samples/future_discovery.tres")
const PUZZLE_COMPLETED := preload("res://resources/dialogue/samples/puzzle_completed.tres")

const MARKER_SPEED := 300.0
const MARKER_SIZE := Vector2(30.0, 30.0)
const LOG_LINE_LIMIT := 120
const FAST_TYPING := 140.0

const PAST_COLOR := Color("e4bf7f")
const FUTURE_COLOR := Color("86c9d1")
const RIFT_COLOR := Color("9f96e8")
const OK_COLOR := Color("8fd3a1")
const WARN_COLOR := Color("e39b86")
const DIM_COLOR := Color("8d9ea0")
const TEXT_COLOR := Color("c9d3d0")

## Fired for every sequence that finishes or is cancelled, so test scenarios can wait for either.
signal _sequence_ended(sequence_id: String, finished: bool)

var _clock: float = 0.0
var _log: RichTextLabel
var _status: Label
var _arena: Panel
var _marker: ColorRect
var _timeline_button: Button

@onready var director: DialogueDirector = $DialogueSystem


func _ready() -> void:
	theme = _make_theme()
	_build_ui()
	_connect_director()
	_update_timeline_button()
	_log_line("Ready. Local timeline: %s. Use the buttons above, then Enter/Space to continue." % director.get_local_timeline().to_upper(), DIM_COLOR)


func _process(delta: float) -> void:
	_clock += delta
	var blocked := director.is_gameplay_input_blocked()
	# What the real game will do with gameplay_input_block_changed: stop reading player input.
	var direction := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_marker.position = (_marker.position + direction * MARKER_SPEED * delta).clamp(Vector2.ZERO, _arena.size - MARKER_SIZE)
	_marker.color = WARN_COLOR if blocked else OK_COLOR
	_status.text = _status_text()


# --- Test controls ------------------------------------------------------------------------

func _play(sequence: DialogueSequence) -> void:
	_log_line("play_dialogue('%s')" % sequence.sequence_id, DIM_COLOR)
	var accepted := director.play_dialogue(sequence)
	_log_line("   -> %s" % ("accepted" if accepted else "refused"), OK_COLOR if accepted else WARN_COLOR)


func _toggle_timeline() -> void:
	var next := "future" if director.get_local_timeline() == "past" else "past"
	director.set_local_timeline(next)
	_update_timeline_button()
	_log_line("Local timeline is now %s. Requests are filtered by it from here on." % next.to_upper(), FUTURE_COLOR if next == "future" else PAST_COLOR)


func _test_play_once() -> void:
	if _refuse_while_busy():
		return
	_log_line("-- Play-once test (runs by itself) --", DIM_COLOR)
	var once := _quick("sandbox_play_once", "This conversation can only be heard once per session.", {"play_once": true})
	var repeatable := _quick("sandbox_repeatable", "This one can be heard again and again.", {})
	_expect("first request for a play-once sequence is accepted", director.play_dialogue(once))
	if not await _wait_for_end(once.sequence_id):
		_interrupted()
		return
	_expect("second request is refused", not director.play_dialogue(once))
	_expect("the session history remembers it", director.has_played(once.sequence_id))
	_expect("a repeatable sequence is accepted", director.play_dialogue(repeatable))
	if not await _wait_for_end(repeatable.sequence_id):
		_interrupted()
		return
	_expect("and accepted again straight after", director.play_dialogue(repeatable))


func _test_queue() -> void:
	if _refuse_while_busy():
		return
	var timeline := director.get_local_timeline()
	_log_line("-- Queue test on the %s timeline: five requests at once --" % timeline.to_upper(), DIM_COLOR)
	var past_only := _variant(OPENING, "sandbox_queue_a")
	var both := _variant(RIFT_CONTACT, "sandbox_queue_b")
	var future_only := _variant(FUTURE_DISCOVERY, "sandbox_queue_c")
	var both_again := _variant(PUZZLE_COMPLETED, "sandbox_queue_d")
	# Each entry: sequence, whether it should be accepted on this timeline, and why.
	var requests := [
		[past_only, past_only.is_for_timeline(timeline), "Past-only"],
		[both, true, "both timelines"],
		[future_only, future_only.is_for_timeline(timeline), "Future-only"],
		[both_again, true, "both timelines"],
		[past_only, false, "asked again: a duplicate, or still the wrong timeline"],
	]
	for request: Array in requests:
		var accepted := director.play_dialogue(request[0])
		_expect("%s (%s) %s" % [request[0].sequence_id, request[2], "is accepted" if request[1] else "is refused"], accepted == request[1])
	var queued := director.get_queued_sequence_ids()
	_log_line("   waiting behind the active one: %s" % (", ".join(queued) if not queued.is_empty() else "nothing"), DIM_COLOR)


func _test_skipping() -> void:
	if _refuse_while_busy():
		return
	_log_line("-- Skip test: press Esc. Events of the skipped lines still fire. --", DIM_COLOR)
	_play(_variant(RIFT_CONTACT, "sandbox_skip"))


func _test_skip_locked() -> void:
	if _refuse_while_busy():
		return
	_log_line("-- Skip-locked test: Esc does nothing here --", DIM_COLOR)
	var locked := _variant(OPENING, "sandbox_skip_locked", {"allow_skip": false})
	_play(locked)
	await get_tree().create_timer(0.8).timeout
	if director.get_current_sequence_id() == locked.sequence_id:
		_expect("skip_dialogue() refuses to skip it", not director.skip_dialogue())
		_expect("and it is still playing", director.get_current_sequence_id() == locked.sequence_id)


func _test_blocking() -> void:
	if _refuse_while_busy():
		return
	_log_line("-- Blocking: the marker locks (turns red) while this plays --", DIM_COLOR)
	_play(_variant(OPENING, "sandbox_blocking", {"playback_mode": DialogueSequence.PlaybackMode.BLOCKING}))


func _test_non_blocking() -> void:
	if _refuse_while_busy():
		return
	_log_line("-- Non-blocking: keep moving the marker with WASD while this plays --", DIM_COLOR)
	_play(_variant(OPENING, "sandbox_non_blocking", {"playback_mode": DialogueSequence.PlaybackMode.NON_BLOCKING, "auto_advance": true, "auto_advance_delay": 1.6}))


func _stop() -> void:
	_log_line("stop_dialogue()", DIM_COLOR)
	director.stop_dialogue()


func _reset() -> void:
	_log_line("reset_session(): history cleared, active and queued dialogue cancelled", DIM_COLOR)
	director.reset_session()


# --- Helpers for the tests ----------------------------------------------------------------

## A copy of a sample under a new ID that can be replayed freely, with optional setting overrides.
func _variant(source: DialogueSequence, sequence_id: String, overrides: Dictionary = {}) -> DialogueSequence:
	var copy := source.duplicate() as DialogueSequence
	copy.lines = source.lines.duplicate()
	copy.sequence_id = sequence_id
	copy.play_once = false
	for key: String in overrides:
		copy.set(key, overrides[key])
	return copy


## A one-line sequence that plays by itself, so a scenario needs no key presses.
func _quick(sequence_id: String, text: String, overrides: Dictionary) -> DialogueSequence:
	var line := DialogueLine.new()
	line.speaker_id = "sandbox"
	line.speaker_name = "Sandbox"
	line.text = text
	line.timeline = DialogueLine.Timeline.BOTH
	var sequence := DialogueSequence.new()
	sequence.sequence_id = sequence_id
	sequence.lines = [line]
	sequence.typing_speed = FAST_TYPING
	sequence.auto_advance = true
	sequence.auto_advance_delay = 0.6
	sequence.playback_mode = DialogueSequence.PlaybackMode.NON_BLOCKING
	for key: String in overrides:
		sequence.set(key, overrides[key])
	return sequence


## Waits until the sequence finishes (true) or is cancelled (false). The director guarantees one of the two.
func _wait_for_end(sequence_id: String) -> bool:
	var result: Array = await _sequence_ended
	while result[0] != sequence_id:
		result = await _sequence_ended
	return result[1]


func _refuse_while_busy() -> bool:
	if director.is_dialogue_active():
		_log_line("A dialogue is already active. Finish it, or press Stop, first.", WARN_COLOR)
		return true
	return false


func _expect(description: String, passed: bool) -> void:
	_log_line("   %s  %s" % ["PASS" if passed else "FAIL", description], OK_COLOR if passed else WARN_COLOR)


func _interrupted() -> void:
	_log_line("   Scenario interrupted (the dialogue was cancelled).", WARN_COLOR)


# --- Director signals ---------------------------------------------------------------------

func _connect_director() -> void:
	director.dialogue_started.connect(func(id: String) -> void: _log_line("started   %s" % id, TEXT_COLOR))
	director.dialogue_line_started.connect(_on_line_started)
	director.dialogue_line_finished.connect(func(id: String, index: int) -> void: _log_line("line end  %s[%d]" % [id, index], DIM_COLOR))
	director.dialogue_finished.connect(func(id: String) -> void:
		_log_line("FINISHED  %s" % id, OK_COLOR)
		_sequence_ended.emit(id, true))
	director.dialogue_cancelled.connect(func(id: String) -> void:
		_log_line("CANCELLED %s" % id, WARN_COLOR)
		_sequence_ended.emit(id, false))
	director.dialogue_skipped.connect(func(id: String) -> void: _log_line("skipped   %s" % id, WARN_COLOR))
	director.narrative_event_requested.connect(func(event_id: String) -> void: _log_line("EVENT     %s" % event_id, RIFT_COLOR))
	director.dialogue_rejected.connect(func(id: String, reason: String) -> void: _log_line("refused   %s  (%s)" % [id, reason], WARN_COLOR))
	director.gameplay_input_block_changed.connect(func(blocked: bool) -> void: _log_line("input     %s" % ("BLOCKED" if blocked else "FREE"), WARN_COLOR if blocked else OK_COLOR))


func _on_line_started(sequence_id: String, index: int) -> void:
	var line := director.get_current_line()
	_log_line("line      %s[%d]  %s: %s" % [sequence_id, index, line.speaker_name, line.text.left(34)], TEXT_COLOR)


func _log_line(message: String, color: Color) -> void:
	_log.append_text("[color=#%s]%6.2f  %s[/color]\n" % [color.to_html(false), _clock, message.replace("[", "[lb]")])
	while _log.get_paragraph_count() > LOG_LINE_LIMIT:
		_log.remove_paragraph(0)


func _status_text() -> String:
	var line := director.get_current_line()
	var queued := director.get_queued_sequence_ids()
	var played := director.get_played_ids()
	return "\n".join(PackedStringArray([
		"Local timeline   %s" % director.get_local_timeline().to_upper(),
		"Director state   %s" % DialogueDirector.State.keys()[director.get_state()],
		"Sequence         %s" % (director.get_current_sequence_id() if director.is_dialogue_active() else "-"),
		"Line index       %s" % (str(director.get_current_line_index()) if line != null else "-"),
		"Speaker          %s" % (line.speaker_name if line != null else "-"),
		"Queued           %s" % (", ".join(queued) if not queued.is_empty() else "-"),
		"Gameplay input   %s" % ("BLOCKED" if director.is_gameplay_input_blocked() else "free"),
		"Played           %s" % (", ".join(played) if not played.is_empty() else "-"),
	]))


func _update_timeline_button() -> void:
	var timeline := director.get_local_timeline()
	_timeline_button.text = "Switch Local Timeline  (now %s)" % timeline.to_upper()
	_timeline_button.add_theme_color_override("font_color", FUTURE_COLOR if timeline == "future" else PAST_COLOR)


# --- Interface (all testing aids) ---------------------------------------------------------

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0a1117")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)

	var title := Label.new()
	title.text = "DIALOGUE SANDBOX   -   testing controls, not part of the game interface"
	title.add_theme_color_override("font_color", PAST_COLOR)
	layout.add_child(title)
	var help := Label.new()
	help.text = "Enter / Space: reveal the line, then continue      Esc: skip (only where the sequence allows it)      WASD: move the marker"
	help.add_theme_color_override("font_color", DIM_COLOR)
	layout.add_child(help)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 14)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(controls)
	var samples := _group(controls, "SAMPLE CONVERSATIONS")
	_button(samples, "Play Opening Dialogue", _play.bind(OPENING), "opening_past: Past only, blocking, plays once")
	_button(samples, "Play Rift Dialogue", _play.bind(RIFT_CONTACT), "first_rift_contact: both timelines, plays once, announces the rift events")
	_button(samples, "Play Future Dialogue", _play.bind(FUTURE_DISCOVERY), "future_discovery: Future only, non-blocking, auto-advances, plays once")
	_button(samples, "Play Puzzle Completion Dialogue", _play.bind(PUZZLE_COMPLETED), "puzzle_completed: both timelines, repeatable")
	var timeline := _group(controls, "TIMELINE AND SESSION")
	_timeline_button = _button(timeline, "Switch Local Timeline", _toggle_timeline, "Past or Future: decides which sequences this director accepts")
	_button(timeline, "Stop Dialogue", _stop, "stop_dialogue(): cancels the active sequence and the queue")
	_button(timeline, "Reset Dialogue Session", _reset, "reset_session(): forgets what has been played")
	var tests := _group(controls, "BEHAVIOUR TESTS", 2)
	_button(tests, "Test Play-Once Behavior", _test_play_once, "Runs by itself and reports PASS/FAIL lines in the log")
	_button(tests, "Test Dialogue Queue", _test_queue, "Five requests at once: playing, queued, refused, duplicate")
	_button(tests, "Test Skipping", _test_skipping, "A skippable sequence: press Esc")
	_button(tests, "Test Skip Locked", _test_skip_locked, "A sequence that refuses to be skipped")
	_button(tests, "Test Blocking Playback", _test_blocking, "Locks the marker while it plays")
	_button(tests, "Test Non-Blocking Playback", _test_non_blocking, "The marker keeps moving")

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(body)
	_status = Label.new()
	_status.add_theme_font_override("font", _monospace())
	_status.add_theme_font_size_override("font_size", 14)
	_status.custom_minimum_size = Vector2(430, 0)
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.add_child(_panel_around(_status, "STATE"))
	_arena = Panel.new()
	_arena.custom_minimum_size = Vector2(420, 0)
	_arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_arena)
	_marker = ColorRect.new()
	_marker.size = MARKER_SIZE
	_marker.position = Vector2(40, 44)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_marker)
	var arena_label := Label.new()
	arena_label.text = "MARKER  -  WASD moves it; locked during blocking dialogue"
	arena_label.add_theme_color_override("font_color", DIM_COLOR)
	arena_label.position = Vector2(12, 8)
	_arena.add_child(arena_label)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = false
	_log.add_theme_font_override("normal_font", _monospace())
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.custom_minimum_size = Vector2(560, 0)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_panel_around(_log, "EVENT LOG"))
	# Leave the bottom of the screen free for the dialogue box.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 230)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)


## A headed panel of buttons: one column, or a grid when `columns` is above 1. Returns where to add them.
func _group(parent: Container, heading: String, columns: int = 1) -> Container:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var label := Label.new()
	label.text = heading
	label.add_theme_color_override("font_color", DIM_COLOR)
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	var buttons: Container
	if columns > 1:
		var grid := GridContainer.new()
		grid.columns = columns
		buttons = grid
	else:
		buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	box.add_child(buttons)
	parent.add_child(panel)
	return buttons


func _panel_around(content: Control, heading: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var label := Label.new()
	label.text = heading
	label.add_theme_color_override("font_color", DIM_COLOR)
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(content)
	return panel


func _button(parent: Container, text: String, action: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	# Keyboard focus would make Space/Enter press the last-clicked button instead of reaching the dialogue.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _monospace() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New"])
	return font


func _make_theme() -> Theme:
	var sandbox_theme := Theme.new()
	sandbox_theme.default_font_size = 15
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("15242b")
		style.border_color = Color("3b4b4c")
		style.set_border_width_all(1)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		if state == "hover":
			style.bg_color = Color("203338")
			style.border_color = FUTURE_COLOR
		elif state == "pressed":
			style.bg_color = Color("30464a")
		sandbox_theme.set_stylebox(state, "Button", style)
	sandbox_theme.set_color("font_color", "Button", Color("dadcd2"))
	sandbox_theme.set_color("font_hover_color", "Button", Color("f0e9d7"))
	sandbox_theme.set_color("font_pressed_color", "Button", Color("f0e9d7"))
	sandbox_theme.set_color("font_color", "Label", TEXT_COLOR)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0f1a21")
	panel.border_color = Color("26363c")
	panel.set_border_width_all(1)
	panel.set_content_margin_all(12)
	sandbox_theme.set_stylebox("panel", "PanelContainer", panel)
	var arena_style := StyleBoxFlat.new()
	arena_style.bg_color = Color("0d161c")
	arena_style.border_color = Color("26363c")
	arena_style.set_border_width_all(1)
	sandbox_theme.set_stylebox("panel", "Panel", arena_style)
	return sandbox_theme
