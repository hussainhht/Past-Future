class_name DialogueSequence
extends Resource
## An ordered conversation and how it plays. Save one as a .tres, then hand it to
## DialogueDirector.play_dialogue(). Everything about a conversation lives here, so writing a
## new one never needs a code change.

## BLOCKING asks the game to lock gameplay input while it plays. NON_BLOCKING lets the player keep moving.
enum PlaybackMode { BLOCKING, NON_BLOCKING }

@export_group("Identity")
## Unique across the game and free of spaces, for example "first_rift_contact".
## It keys the play-once history and the queue.
@export var sequence_id: String = ""
## Who receives this conversation. Each player's director filters by that player's own timeline.
@export var audience: DialogueLine.Timeline = DialogueLine.Timeline.BOTH
@export var lines: Array[DialogueLine] = []

@export_group("Playback")
@export var playback_mode: PlaybackMode = PlaybackMode.BLOCKING
## Play at most once per session. Cancelled conversations do not count.
@export var play_once: bool = false
## Lets the player skip the rest of the conversation. Skipping still fires its events.
@export var allow_skip: bool = true
## Characters per second for every line of this sequence. 0 uses the director's default.
@export_range(0.0, 300.0, 1.0, "or_greater") var typing_speed: float = 0.0
## Move on by itself instead of waiting for the player.
@export var auto_advance: bool = false
## Seconds to wait after a line is fully visible before auto-advancing.
@export_range(0.0, 30.0, 0.1, "or_greater") var auto_advance_delay: float = 1.5

@export_group("Events")
## Announced when the sequence starts (DialogueDirector.narrative_event_requested).
@export var start_event_id: String = ""
## Announced when the sequence ends by finishing or being skipped. Not announced when it is cancelled.
@export var finish_event_id: String = ""


func is_blocking() -> bool:
	return playback_mode == PlaybackMode.BLOCKING


## An ID is required and must not contain whitespace, so two systems can never disagree about it.
func has_valid_id() -> bool:
	if sequence_id.is_empty():
		return false
	for index in sequence_id.length():
		if sequence_id.unicode_at(index) <= 32:
			return false
	return true


## Positions in `lines` of every line that can be shown. Null entries and lines without text are
## left out, but the indices stay those of `lines`, so a signal's line_index always maps back to it.
func get_playable_indices() -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index in lines.size():
		var line := lines[index]
		if line != null and line.has_text():
			indices.append(index)
	return indices


## Whether a player in `timeline` ("past" or "future", any case) should receive this sequence.
func is_for_timeline(timeline: String) -> bool:
	match audience:
		DialogueLine.Timeline.PAST:
			return timeline.to_lower() == "past"
		DialogueLine.Timeline.FUTURE:
			return timeline.to_lower() == "future"
	return true


## Problems that would make this sequence misbehave, as readable sentences. Empty when it is fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not has_valid_id():
		problems.append("sequence_id must be set and contain no spaces")
	if get_playable_indices().is_empty():
		problems.append("has no lines that can be shown")
	if typing_speed < 0.0:
		problems.append("typing_speed must not be negative")
	if auto_advance_delay < 0.0:
		problems.append("auto_advance_delay must not be negative")
	var seen_line_ids := {}
	for index in lines.size():
		var line := lines[index]
		if line == null:
			problems.append("line %d is empty (no DialogueLine assigned)" % index)
			continue
		for problem in line.validate():
			problems.append("line %d %s" % [index, problem])
		if not line.line_id.is_empty():
			if seen_line_ids.has(line.line_id):
				problems.append("line %d repeats line_id '%s'" % [index, line.line_id])
			seen_line_ids[line.line_id] = true
	return problems
