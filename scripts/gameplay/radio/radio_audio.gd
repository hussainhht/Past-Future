extends Node
## Local bridge to the one event catalog. No generated noise or second playback system.

@export var audio_director: Node
@export var radio: TemporalRadio
@export var cue_map: Dictionary = {
	&"incoming": &"radio_incoming", &"outgoing": &"radio_outgoing",
	&"connected": &"radio_connect", &"disconnected": &"radio_disconnect",
	&"pickup": &"radio_pickup", &"attempt": &"computer_calibrate",
	&"failed": &"computer_invalid", &"static": &"radio_static",
	&"power_on": &"radio_activate", &"power_off": &"radio_deactivate",
	&"searching": &"radio_search", &"tune": &"computer_tune"
}

var _search_timer: Timer
var _known_owner: bool = false

func _ready() -> void:
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 1.8
	add_child(_search_timer)
	_search_timer.timeout.connect(_on_search)
	if radio != null:
		_known_owner = radio.owns_radio
		radio.audio_cue_requested.connect(play_cue)
		radio.status_changed.connect(_on_status_changed)

func play_cue(cue: StringName) -> void:
	if not is_instance_valid(audio_director):
		return
	var sound: StringName = cue_map.get(cue, &"")
	if not sound.is_empty():
		audio_director.play_sfx(sound)

func stop_static() -> void:
	# All one-shots are stopped by the owning director during room shutdown.
	if is_instance_valid(_search_timer):
		_search_timer.stop()

func set_suspended(suspended: bool) -> void:
	_search_timer.paused = suspended

func _on_status_changed(status: int, owned: bool, _active: bool) -> void:
	if owned and not _known_owner and status == TemporalRadio.SignalState.SEARCHING:
		_search_timer.start()
	if not owned or status != TemporalRadio.SignalState.SEARCHING:
		_search_timer.stop()
	_known_owner = owned

func _on_search() -> void:
	if radio != null and radio.owns_radio and radio.presentation_active and radio.signal_state == TemporalRadio.SignalState.SEARCHING:
		play_cue(&"searching")
