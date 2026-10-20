extends Node
## Local audio bridge. Existing AudioDirector plays catalog beeps and confirmations.
## One bounded static player uses the same SFX bus (and its mute/volume controls).
## A project-provided radio_static catalog entry takes precedence over synthesized static.

@export var audio_director: Node
@export var radio: TemporalRadio
@export var cue_map: Dictionary = {
	&"incoming": &"ui_hover", &"connected": &"ui_confirm",
	&"pickup": &"interaction_click", &"attempt": &"ui_click",
	&"failed": &"interaction_denied"
}

var _static_player: AudioStreamPlayer


func _ready() -> void:
	_static_player = AudioStreamPlayer.new()
	_static_player.stream = _make_static()
	_static_player.volume_db = -31.0
	_static_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(_static_player)
	if radio != null:
		radio.audio_cue_requested.connect(play_cue)


func play_cue(cue: StringName) -> void:
	if not is_instance_valid(audio_director):
		return
	if cue == &"static":
		if audio_director.has_sound(&"radio_static"):
			audio_director.play_sfx(&"radio_static")
		else:
			_static_player.play()
		return
	var sound: StringName = cue_map.get(cue, &"")
	if not sound.is_empty() and audio_director.has_sound(sound):
		audio_director.play_sfx(sound)


func stop_static() -> void:
	if is_instance_valid(_static_player):
		_static_player.stop()


func _exit_tree() -> void:
	stop_static()


func _make_static() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := 3307
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6701
	var previous := 0.0
	for i in range(samples):
		var noise := rng.randf_range(-1.0, 1.0)
		var envelope := sin(PI * float(i) / float(samples))
		var sample := int((noise - previous) * 7000.0 * envelope)
		bytes.encode_s16(i * 2, sample)
		previous = noise
	stream.data = bytes
	return stream
