class_name TemporalRadio
extends Node
## Attachable per-character component. Read-only replica + action requests; no RPCs or meshes.
## Presentation activity/interference never changes the persistent canonical connection.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")

enum SignalState { DISCONNECTED, SEARCHING, CONNECTED }

signal status_changed(status: int, owns_radio: bool, active: bool)
signal ownership_changed(owns_radio: bool)
signal presentation_active_changed(active: bool)
signal audio_cue_requested(cue: StringName)
signal transmission_changed(transmitting: bool)

@export_enum("past", "future") var player_role: String = "past"
@export_range(1, 999, 1) var display_frequency: int = Rules.DEFAULT_FREQUENCY

var signal_state: SignalState = SignalState.DISCONNECTED
var owns_radio: bool = false
var presentation_active: bool = true
var transmitting: bool = false
var _interference_left: float = 0.0


func _ready() -> void:
	PuzzleManager.puzzle_state_changed.connect(_on_state_changed)
	PuzzleManager.puzzle_completed.connect(_on_completed)
	PuzzleManager.session_ended.connect(_on_session_ended)
	refresh()
	set_process(false)


func request_acquisition() -> Dictionary:
	return PuzzleManager.submit_action(Rules.ID, "acquire_radio", {"radio_role": player_role}, player_role)


func has_established_link() -> bool:
	return Rules.link_established(PuzzleManager.get_state(Rules.ID))


func can_receive() -> bool:
	return signal_state == SignalState.CONNECTED


func get_calibrated_frequency() -> int:
	# Do not give the Student the research clue through an uncalibrated HUD.
	return display_frequency if PuzzleManager.get_state(Rules.ID).get("frequency_calibrated", false) == true else 0


func set_player_role(role: String) -> void:
	if role not in ["past", "future"]:
		return
	player_role = role
	refresh()


func set_presentation_active(active: bool) -> void:
	if presentation_active == active:
		return
	presentation_active = active
	if not active:
		set_transmitting(false)
	if owns_radio:
		audio_cue_requested.emit(&"power_on" if active else &"power_off")
	presentation_active_changed.emit(active)
	refresh()


func interfere(seconds: float) -> void:
	if not owns_radio or not presentation_active or seconds <= 0.0:
		return
	_interference_left = maxf(_interference_left, seconds)
	set_transmitting(false)
	audio_cue_requested.emit(&"static")
	set_process(true)
	refresh()


func set_transmitting(value: bool, incoming: bool = true) -> void:
	value = value and can_receive()
	if value != transmitting:
		transmitting = value
		transmission_changed.emit(value)
		if value:
			audio_cue_requested.emit(&"incoming" if incoming else &"outgoing")


func refresh() -> void:
	var state := PuzzleManager.get_state(Rules.ID)
	var owned: bool = state.get(Rules.ownership_key(player_role), false) == true
	if not owned:
		_interference_left = 0.0
		set_process(false)
	if owned != owns_radio:
		owns_radio = owned
		ownership_changed.emit(owned)
	# Scene entry/resync is silent. Connection audio comes from confirmed completion only.
	var next := SignalState.DISCONNECTED
	if owns_radio and presentation_active:
		next = SignalState.CONNECTED if Rules.link_established(state) and _interference_left <= 0.0 else SignalState.SEARCHING
	signal_state = next
	if next != SignalState.CONNECTED:
		set_transmitting(false)
	status_changed.emit(signal_state, owns_radio, presentation_active)


func _on_state_changed(puzzle_id: String, _state: Dictionary, _revision: int) -> void:
	if puzzle_id == Rules.ID:
		refresh()


func _on_session_ended() -> void:
	_interference_left = 0.0
	set_process(false)
	refresh()


func _on_completed(puzzle_id: String) -> void:
	if puzzle_id == Rules.ID and can_receive():
		audio_cue_requested.emit(&"connected")


func _process(delta: float) -> void:
	_interference_left = maxf(0.0, _interference_left - delta)
	if _interference_left == 0.0:
		set_process(false)
		refresh()
