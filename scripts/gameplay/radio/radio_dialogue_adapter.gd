extends Node
## Stable radio boundary while DialogueDirector's public API is being developed.
## No story text, sequence interpreter, RPCs, or authoritative state writes live here.
## Bind a Callable accepting a sequence ID; the integrator resolves DialogueSequence resources.
## Wire the director's
## public line/finished signals to present_line()/end_conversation(); wire view.advance_requested
## to the director's public advance method. No assumed director method names.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")

signal conversation_requested(sequence_id: StringName, metadata: Dictionary)
signal conversation_finished(sequence_id: StringName)
signal conversation_unavailable(reason: String)
signal temporal_radio_link_established

@export var radio: TemporalRadio
@export var presenter: PanelContainer
@export var link_sequence_id: StringName = &""
## Confirmed puzzle ID or narrative event ID -> sequence ID for the future director.
@export var event_sequence_ids: Dictionary = {}
@export_enum("shared", "past", "future") var event_audience: String = "shared"

var _sequence_player: Callable
var active_sequence_id: StringName = &""


func _ready() -> void:
	PuzzleManager.puzzle_completed.connect(_on_puzzle_completed)
	PuzzleManager.session_ended.connect(end_conversation)
	if radio != null:
		radio.status_changed.connect(_on_radio_status_changed)


func bind_sequence_player(player: Callable) -> void:
	_sequence_player = player


func request_conversation(sequence_id: StringName, audience: String = "shared") -> bool:
	if audience not in ["shared", "past", "future"]:
		return _unavailable("invalid_audience")
	if radio == null or not radio.can_receive():
		return _unavailable("radio_unavailable")
	if audience != "shared" and audience != radio.player_role:
		return false
	if sequence_id.is_empty():
		return _unavailable("missing_sequence")
	if not active_sequence_id.is_empty():
		return _unavailable("conversation_busy")
	if not _sequence_player.is_valid() and not conversation_requested.has_connections():
		return _unavailable("dialogue_director_not_bound")
	active_sequence_id = sequence_id
	conversation_requested.emit(sequence_id, {"channel": "radio", "frequency_mhz": radio.display_frequency, "audience": audience})
	if _sequence_player.is_valid():
		var result: Variant = _sequence_player.call(sequence_id)
		if result is bool and not result:
			active_sequence_id = &""
			return _unavailable("dialogue_director_busy")
	return true


func request_event(event_id: String, audience: String = "shared") -> bool:
	return request_conversation(StringName(event_sequence_ids.get(event_id, &"")), audience)


func present_line(speaker_name: String, text: String) -> bool:
	return presenter != null and presenter.show_line(speaker_name, text)


func end_conversation() -> void:
	if is_instance_valid(presenter):
		presenter.end_transmission()
	if not active_sequence_id.is_empty():
		var finished_id := active_sequence_id
		active_sequence_id = &""
		conversation_finished.emit(finished_id)


func _on_puzzle_completed(puzzle_id: String) -> void:
	if puzzle_id == Rules.ID:
		temporal_radio_link_established.emit()
		if not link_sequence_id.is_empty():
			request_conversation(link_sequence_id, event_audience)
	elif event_sequence_ids.has(puzzle_id):
		request_event(puzzle_id, event_audience)


func _unavailable(reason: String) -> bool:
	conversation_unavailable.emit(reason)
	return false


func _on_radio_status_changed(_status: int, _owned: bool, _active: bool) -> void:
	if not radio.has_established_link():
		end_conversation()
