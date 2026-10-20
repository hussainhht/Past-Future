extends Node
## Confirmed integration: sequence IDs -> DialogueSequence -> play_dialogue().
## The existing director owns queueing, typewriting, timeline filtering and history.

@export var adapter: Node
@export var director: DialogueDirector
@export var radio: TemporalRadio
@export var sequences: Array[DialogueSequence] = []

var _external_suspension: bool = false


func _ready() -> void:
	adapter.bind_sequence_player(play_sequence)
	director.dialogue_started.connect(_on_started)
	director.dialogue_finished.connect(_on_finished)
	director.dialogue_cancelled.connect(_on_finished)
	adapter.conversation_finished.connect(_on_adapter_finished)
	radio.status_changed.connect(_on_radio_status_changed)


func play_sequence(sequence_id: StringName) -> bool:
	for sequence in sequences:
		if sequence != null and sequence.sequence_id == String(sequence_id):
			return director.play_dialogue(sequence, {"timeline": radio.player_role, "channel": "radio"})
	return false


func set_suspended(value: bool) -> void:
	_external_suspension = value
	_refresh_suspension()


func _on_started(sequence_id: String) -> void:
	director.dialogue_box.set_radio_mode(String(adapter.active_sequence_id) == sequence_id)
	_refresh_suspension()


func _on_finished(sequence_id: String) -> void:
	if String(adapter.active_sequence_id) == sequence_id:
		adapter.end_conversation()
	_refresh_suspension()


func _on_adapter_finished(sequence_id: StringName) -> void:
	if director.get_current_sequence_id() == String(sequence_id):
		director.stop_dialogue()


func _on_radio_status_changed(_status: int, _owned: bool, _active: bool) -> void:
	_refresh_suspension()


func _refresh_suspension() -> void:
	var radio_sequence := director.is_dialogue_active() and director.get_current_sequence_id() == String(adapter.active_sequence_id)
	var suspended_now := _external_suspension or (radio_sequence and not radio.can_receive())
	director.dialogue_box.suspended = suspended_now
	director.process_mode = Node.PROCESS_MODE_DISABLED if suspended_now else Node.PROCESS_MODE_INHERIT
