class_name DialogueDirector
extends Node
## Owns dialogue playback: one conversation at a time, a FIFO queue behind it, and the session
## history behind "play once". It never moves cameras, opens doors, touches puzzles or drives the
## player. It reports what happened through signals and other systems decide what that means.
##
## Showing the text is delegated to a DialogueBox. Without one the director still runs and treats
## every typewriter as instantly finished, which suits tests and headless tools.
##
## Dialogue is local presentation. Each peer runs its own director, nothing here uses the network,
## and no conversation can change authoritative state such as PuzzleManager's puzzles.
##
## Two guarantees hold for every signal listener:
##   - every request that play_dialogue() accepts ends in exactly one dialogue_finished or
##     dialogue_cancelled for its sequence_id;
##   - every dialogue_line_started is followed by exactly one dialogue_line_finished.

## A sequence began playing. Its first line follows immediately.
signal dialogue_started(sequence_id: String)
## A line became current. `line_index` is a position in DialogueSequence.lines.
signal dialogue_line_started(sequence_id: String, line_index: int)
## A line ended because it was advanced past, skipped or interrupted.
signal dialogue_line_finished(sequence_id: String, line_index: int)
## The sequence ran to its end or was skipped. Emitted once, after the director is idle again.
signal dialogue_finished(sequence_id: String)
## The sequence was stopped early (stop, reset, queue clear, scene exit). Never follows dialogue_finished.
signal dialogue_cancelled(sequence_id: String)
## The player skipped the rest of a sequence. dialogue_finished follows immediately.
signal dialogue_skipped(sequence_id: String)
## A line or sequence announced a story event. This system only announces; listeners decide what it means.
signal narrative_event_requested(event_id: String)
## play_dialogue() refused a request. `reason` is one of the REJECT_* constants.
signal dialogue_rejected(sequence_id: String, reason: String)
## Gameplay input should be locked (true) or restored (false). It is true while a BLOCKING sequence plays.
signal gameplay_input_block_changed(blocked: bool)

enum State { IDLE, SHOWING_LINE, WAITING_FOR_INPUT, FINISHING }
## AUTO follows NetworkManager's role, falling back to the Past when no session exists.
enum LocalTimeline { AUTO, PAST, FUTURE }

const GROUP := &"dialogue_director"
const DEFAULT_TIMELINE := "past"
const MIN_AUTO_ADVANCE_DELAY := 0.01

const REJECT_NO_SEQUENCE := "no_sequence"
const REJECT_INVALID_ID := "invalid_id"
const REJECT_EMPTY_SEQUENCE := "empty_sequence"
const REJECT_WRONG_TIMELINE := "wrong_timeline"
const REJECT_ALREADY_PLAYED := "already_played"
const REJECT_DUPLICATE := "duplicate"
const REJECT_QUEUE_FULL := "queue_full"
const REJECT_UNAVAILABLE := "unavailable"

@export_group("Presentation")
## Shows the lines. Left empty, a child named "DialogueBox" is used when there is one.
@export var dialogue_box: DialogueBox

@export_group("Playback")
## Used when neither the line nor its sequence sets a typing speed.
@export_range(1.0, 300.0, 1.0, "or_greater") var default_characters_per_second: float = 40.0
## How many sequences may wait behind the active one. Requests beyond that are rejected.
@export_range(1, 32) var max_queue_size: int = 8

@export_group("Input")
## InputMap action that reveals the line, then advances. Point it at a dedicated action if ui_accept is taken.
@export var advance_action: StringName = &"ui_accept"
## InputMap action that skips a sequence, when the sequence allows it.
@export var skip_action: StringName = &"ui_cancel"

@export_group("Timeline")
## Which timeline this director serves. Give each local player's director its own for split-screen.
@export var local_timeline: LocalTimeline = LocalTimeline.AUTO

## Warn about authoring mistakes (missing ID, no lines). Normal outcomes such as wrong_timeline stay quiet.
## On in debug builds only. Not exported, because Godot would save the debug value into scenes.
var log_problems: bool = OS.is_debug_build()


## A request waiting behind the active sequence.
class QueuedRequest:
	var sequence: DialogueSequence
	var context: Dictionary

	func _init(requested: DialogueSequence, requested_context: Dictionary) -> void:
		sequence = requested
		context = requested_context


var _state: State = State.IDLE
var _sequence: DialogueSequence
var _playable: PackedInt32Array = PackedInt32Array()
var _cursor: int = -1
var _line_open: bool = false
## Bumped whenever a sequence or line starts or ends. Transitions compare it after every signal
## they emit, because a listener may stop, reset or queue dialogue from inside the handler.
var _generation: int = 0
var _start_frame: int = -1
var _input_blocked: bool = false
var _unavailable: bool = false
var _queue: Array[QueuedRequest] = []
var _played: Dictionary = {}
var _auto_timer: Timer


func _ready() -> void:
	add_to_group(GROUP)
	set_process_unhandled_input(false)
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.timeout.connect(_on_auto_advance_timeout)
	add_child(_auto_timer, false, Node.INTERNAL_MODE_BACK)
	if dialogue_box == null:
		dialogue_box = get_node_or_null("DialogueBox") as DialogueBox
	_connect_box()


func _exit_tree() -> void:
	# Whatever is playing cannot continue without the tree: end it, hand input back, forget the queue.
	_unavailable = true
	_cancel_active(true)
	clear_queue()
	_set_input_blocked(false)
	_unavailable = false


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.SHOWING_LINE and _state != State.WAITING_FOR_INPUT:
		return
	# The press that started a conversation must not also advance it.
	if Engine.get_process_frames() == _start_frame:
		return
	var viewport := get_viewport()
	if _is_pressed(event, advance_action):
		advance_dialogue()
		viewport.set_input_as_handled()
	elif _sequence != null and _sequence.allow_skip and _is_pressed(event, skip_action):
		skip_dialogue()
		viewport.set_input_as_handled()


# --- Playing ------------------------------------------------------------------------------

## Ask for a conversation. Returns true when it was accepted, either playing now or queued behind the
## active one; false when it was refused (see dialogue_rejected for the reason).
## `context` is optional. The key "timeline" ("past" or "future") overrides this director's own
## timeline for this request, for routers that serve several local players through one director.
func play_dialogue(sequence: DialogueSequence, context: Dictionary = {}) -> bool:
	var reason := _request_problem(sequence, context)
	if not reason.is_empty():
		_report_rejection(sequence, reason)
		return false
	if _state == State.IDLE and _queue.is_empty():
		_begin_sequence(sequence)
	else:
		_queue.append(QueuedRequest.new(sequence, context.duplicate()))
		_pump_queue()
	return true


## The player pressed "continue". While the text is typing it reveals the whole line; once the line
## is fully visible it moves to the next line, or finishes after the last one.
func advance_dialogue() -> void:
	match _state:
		State.SHOWING_LINE:
			skip_typewriter()
		State.WAITING_FOR_INPUT:
			_advance_from_waiting()


## Reveal the rest of the current line immediately. Never advances.
func skip_typewriter() -> void:
	if _state != State.SHOWING_LINE or not _line_open:
		return
	if _has_box():
		dialogue_box.reveal_all()
	else:
		_on_typewriter_finished()


## Skip the rest of the active sequence, when its allow_skip permits. The story still moves forward:
## events of the lines that were skipped fire in order, then the sequence finishes normally.
## Returns whether a skip happened.
func skip_dialogue() -> bool:
	if _sequence == null or not _sequence.allow_skip:
		return false
	if _state != State.SHOWING_LINE and _state != State.WAITING_FOR_INPUT:
		return false
	var generation := _generation
	_end_line()
	if generation != _generation:
		return false
	_complete(true)
	return true


## Abort the active sequence. With `clear` (the default) everything queued behind it is cancelled too;
## otherwise the next queued sequence starts. No narrative events fire for what was left unplayed.
func stop_dialogue(clear: bool = true) -> void:
	_cancel_active(false)
	if clear:
		clear_queue()
	else:
		_pump_queue()


## Cancel everything that is waiting, announcing dialogue_cancelled for each. Returns how many.
func clear_queue() -> int:
	var pending := _queue.duplicate()
	_queue.clear()
	for request: QueuedRequest in pending:
		dialogue_cancelled.emit(request.sequence.sequence_id)
	return pending.size()


# --- Queries ------------------------------------------------------------------------------

func is_dialogue_active() -> bool:
	return _state != State.IDLE


func get_state() -> State:
	return _state


func get_current_sequence() -> DialogueSequence:
	return _sequence


## "" while idle.
func get_current_sequence_id() -> String:
	return _sequence.sequence_id if _sequence != null else ""


## The line being shown, or null while idle or between a sequence's start and its first line.
func get_current_line() -> DialogueLine:
	var index := get_current_line_index()
	return _sequence.lines[index] if index >= 0 else null


## Position of the current line in DialogueSequence.lines, or -1.
func get_current_line_index() -> int:
	if _sequence == null or _cursor < 0 or _cursor >= _playable.size():
		return -1
	return _playable[_cursor]


func get_queue_size() -> int:
	return _queue.size()


func get_queued_sequence_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for request in _queue:
		ids.append(request.sequence.sequence_id)
	return ids


func is_gameplay_input_blocked() -> bool:
	return _input_blocked


## "past" or "future": the explicit setting, else NetworkManager's role, else the Past.
func get_local_timeline() -> String:
	match local_timeline:
		LocalTimeline.PAST:
			return "past"
		LocalTimeline.FUTURE:
			return "future"
	return _network_timeline()


## Pick the timeline by name: "past", "future", or anything else (such as "auto") to follow the network.
## It affects requests made afterwards, never one that is already playing.
func set_local_timeline(timeline: String) -> void:
	match timeline.to_lower():
		"past":
			local_timeline = LocalTimeline.PAST
		"future":
			local_timeline = LocalTimeline.FUTURE
		_:
			local_timeline = LocalTimeline.AUTO


## Attach, swap or remove (null) the presenter at any time. A conversation in progress carries on:
## the previous box is closed and the new one shows the current line at once, fully revealed.
func set_dialogue_box(box: DialogueBox) -> void:
	if box == dialogue_box and _has_box():
		return
	var previous: DialogueBox = dialogue_box if _has_box() else null
	_disconnect_box()
	if previous != null:
		previous.close(true)
	dialogue_box = box
	_connect_box()
	var line := get_current_line()
	if line == null or _state == State.FINISHING:
		return
	if _has_box():
		dialogue_box.present_line(line, 0.0, not _sequence.auto_advance)
	else:
		_on_typewriter_finished()


# --- Session history ----------------------------------------------------------------------

## Whether the sequence has been completed (finished or skipped) or marked as played this session.
func has_played(sequence_id: String) -> bool:
	return _played.has(sequence_id)


## Count a sequence as played without playing it, for example when the story already told it.
func mark_played(sequence_id: String) -> void:
	if not sequence_id.is_empty():
		_played[sequence_id] = true


func get_played_ids() -> PackedStringArray:
	var ids := PackedStringArray(_played.keys())
	ids.sort()
	return ids


## Forget the session's narrative history and end any active or queued dialogue. Nothing can be
## requested while the reset runs, so a cancellation handler cannot start something new in the middle of it.
func reset_session() -> void:
	_unavailable = true
	stop_dialogue(true)
	_played.clear()
	_unavailable = false


# --- Requests -----------------------------------------------------------------------------

func _request_problem(sequence: DialogueSequence, context: Dictionary) -> String:
	if _unavailable or not is_inside_tree():
		return REJECT_UNAVAILABLE
	var reason := _eligibility_problem(sequence, context)
	if not reason.is_empty():
		return reason
	if _is_active_or_queued(sequence.sequence_id):
		return REJECT_DUPLICATE
	if _queue.size() >= max_queue_size:
		return REJECT_QUEUE_FULL
	return ""


## What stops a sequence from playing at all, checked on request and again when it leaves the queue.
func _eligibility_problem(sequence: DialogueSequence, context: Dictionary) -> String:
	if sequence == null:
		return REJECT_NO_SEQUENCE
	if not sequence.has_valid_id():
		return REJECT_INVALID_ID
	if sequence.get_playable_indices().is_empty():
		return REJECT_EMPTY_SEQUENCE
	if not sequence.is_for_timeline(_timeline_for(context)):
		return REJECT_WRONG_TIMELINE
	if sequence.play_once and _played.has(sequence.sequence_id):
		return REJECT_ALREADY_PLAYED
	return ""


func _is_active_or_queued(sequence_id: String) -> bool:
	if _sequence != null and _sequence.sequence_id == sequence_id:
		return true
	for request in _queue:
		if request.sequence.sequence_id == sequence_id:
			return true
	return false


func _report_rejection(sequence: DialogueSequence, reason: String) -> void:
	var sequence_id := sequence.sequence_id if sequence != null else ""
	if reason in [REJECT_NO_SEQUENCE, REJECT_INVALID_ID, REJECT_EMPTY_SEQUENCE]:
		var detail := "; ".join(sequence.validate()) if sequence != null else "no sequence was given"
		_warn("Cannot play '%s' (%s): %s" % [sequence_id, reason, detail])
	dialogue_rejected.emit(sequence_id, reason)


func _timeline_for(context: Dictionary) -> String:
	var requested := str(context.get("timeline", "")).to_lower()
	if requested == "past" or requested == "future":
		return requested
	return get_local_timeline()


func _network_timeline() -> String:
	if is_inside_tree():
		# Looked up by name so this script compiles without the autoload, and tests can run without it.
		var network := get_tree().root.get_node_or_null("NetworkManager")
		if network != null:
			var role := str(network.get("role")).to_lower()
			if role == "past" or role == "future":
				return role
	return DEFAULT_TIMELINE


# --- Transitions --------------------------------------------------------------------------
# Every function below leaves the director in a consistent state before it emits a signal, and
# compares _generation afterwards: a handler may have stopped, reset or advanced things already.

func _begin_sequence(sequence: DialogueSequence) -> void:
	_generation += 1
	var generation := _generation
	_sequence = sequence
	_playable = sequence.get_playable_indices()
	_cursor = -1
	_line_open = false
	_start_frame = Engine.get_process_frames()
	_state = State.SHOWING_LINE
	set_process_unhandled_input(true)
	if _playable.size() < sequence.lines.size():
		_warn("Sequence '%s' has %d line(s) without text; they are skipped." % [sequence.sequence_id, sequence.lines.size() - _playable.size()])
	_set_input_blocked(sequence.is_blocking())
	dialogue_started.emit(sequence.sequence_id)
	if generation != _generation:
		return
	_emit_event(sequence.start_event_id)
	if generation != _generation:
		return
	_show_line(0)


func _show_line(cursor: int) -> void:
	_generation += 1
	var generation := _generation
	_cursor = cursor
	_line_open = true
	_state = State.SHOWING_LINE
	var index := _playable[cursor]
	var line := _sequence.lines[index]
	dialogue_line_started.emit(_sequence.sequence_id, index)
	if generation != _generation:
		return
	_emit_event(line.event_id)
	if generation != _generation:
		return
	if _has_box():
		dialogue_box.present_line(line, _resolve_speed(line), not _sequence.auto_advance)
	else:
		_on_typewriter_finished()


## The presenter revealed the whole line (or the line had nothing to reveal).
func _on_typewriter_finished() -> void:
	if _state != State.SHOWING_LINE or not _line_open:
		return
	_state = State.WAITING_FOR_INPUT
	if _sequence.auto_advance:
		_auto_timer.start(maxf(_sequence.auto_advance_delay, MIN_AUTO_ADVANCE_DELAY))


func _on_auto_advance_timeout() -> void:
	if _state == State.WAITING_FOR_INPUT:
		_advance_from_waiting()


func _advance_from_waiting() -> void:
	var generation := _generation
	var next_cursor := _cursor + 1
	_end_line()
	if generation != _generation:
		return
	if next_cursor < _playable.size():
		_show_line(next_cursor)
	else:
		_complete(false)


## Close the current line, if one is open, so every dialogue_line_started gets its dialogue_line_finished.
func _end_line() -> void:
	_auto_timer.stop()
	if not _line_open:
		return
	_line_open = false
	dialogue_line_finished.emit(_sequence.sequence_id, _playable[_cursor])


## The sequence reached its end, or the player skipped it. Expects no line to be open.
func _complete(skipped: bool) -> void:
	var generation := _generation
	var sequence := _sequence
	var sequence_id := sequence.sequence_id
	_state = State.FINISHING
	_played[sequence_id] = true
	if skipped:
		for cursor in range(_cursor + 1, _playable.size()):
			_emit_event(sequence.lines[_playable[cursor]].event_id)
			if generation != _generation:
				return
	_emit_event(sequence.finish_event_id)
	if generation != _generation:
		return
	# Input stays locked across back-to-back blocking sequences instead of flickering off and on.
	var keep_blocked := not _queue.is_empty() and _queue[0].sequence.is_blocking()
	_teardown(false)
	_set_input_blocked(keep_blocked)
	if skipped:
		dialogue_skipped.emit(sequence_id)
	dialogue_finished.emit(sequence_id)
	_pump_queue()


## End the active sequence early. Returns false when nothing is active or it is already ending.
func _cancel_active(close_immediately: bool) -> bool:
	if _sequence == null or _state == State.FINISHING:
		return false
	var sequence_id := _sequence.sequence_id
	# FINISHING makes stop, skip and advance calls from the handlers below no-ops.
	_state = State.FINISHING
	_end_line()
	_teardown(close_immediately)
	_set_input_blocked(false)
	dialogue_cancelled.emit(sequence_id)
	return true


func _teardown(close_immediately: bool) -> void:
	_auto_timer.stop()
	_generation += 1
	_sequence = null
	_playable = PackedInt32Array()
	_cursor = -1
	_line_open = false
	_state = State.IDLE
	set_process_unhandled_input(false)
	if _has_box():
		dialogue_box.close(close_immediately)


## Start the next waiting sequence, dropping any that stopped being eligible while they waited.
func _pump_queue() -> void:
	while _state == State.IDLE and not _queue.is_empty() and not _unavailable:
		var request: QueuedRequest = _queue.pop_front()
		if _eligibility_problem(request.sequence, request.context).is_empty():
			_begin_sequence(request.sequence)
		else:
			dialogue_cancelled.emit(request.sequence.sequence_id)
	if _state == State.IDLE:
		_set_input_blocked(false)


func _emit_event(event_id: String) -> void:
	var clean_id := event_id.strip_edges()
	if not clean_id.is_empty():
		narrative_event_requested.emit(clean_id)


func _set_input_blocked(blocked: bool) -> void:
	if blocked != _input_blocked:
		_input_blocked = blocked
		gameplay_input_block_changed.emit(blocked)


func _resolve_speed(line: DialogueLine) -> float:
	if line.typing_speed > 0.0:
		return line.typing_speed
	if _sequence.typing_speed > 0.0:
		return _sequence.typing_speed
	return maxf(default_characters_per_second, 1.0)


func _is_pressed(event: InputEvent, action: StringName) -> bool:
	return not action.is_empty() and InputMap.has_action(action) and event.is_action_pressed(action)


func _warn(message: String) -> void:
	if log_problems:
		push_warning("[DialogueDirector] " + message)


# --- Presenter ----------------------------------------------------------------------------

func _has_box() -> bool:
	return is_instance_valid(dialogue_box)


func _connect_box() -> void:
	if not _has_box():
		return
	if not dialogue_box.typewriter_finished.is_connected(_on_typewriter_finished):
		dialogue_box.typewriter_finished.connect(_on_typewriter_finished)
	if not dialogue_box.advance_requested.is_connected(advance_dialogue):
		dialogue_box.advance_requested.connect(advance_dialogue)
	if not dialogue_box.tree_exiting.is_connected(_on_box_tree_exiting):
		dialogue_box.tree_exiting.connect(_on_box_tree_exiting)


func _disconnect_box() -> void:
	if not _has_box():
		return
	if dialogue_box.typewriter_finished.is_connected(_on_typewriter_finished):
		dialogue_box.typewriter_finished.disconnect(_on_typewriter_finished)
	if dialogue_box.advance_requested.is_connected(advance_dialogue):
		dialogue_box.advance_requested.disconnect(advance_dialogue)
	if dialogue_box.tree_exiting.is_connected(_on_box_tree_exiting):
		dialogue_box.tree_exiting.disconnect(_on_box_tree_exiting)


## Nothing can show the conversation any more. Ending it beats leaving the player locked out of an invisible one.
func _on_box_tree_exiting() -> void:
	_cancel_active(true)
	if not _queue.is_empty():
		clear_queue()
	_set_input_blocked(false)
