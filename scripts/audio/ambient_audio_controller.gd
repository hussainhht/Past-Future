class_name AmbientAudioController
extends Node
## Manages atmospheric background audio loops for Past and Future timelines.
## Features smooth crossfading, duplicate-trigger prevention, and safe bus routing.

const Catalog := preload("res://scripts/audio/sound_catalog.gd")

var _volumes: Dictionary = {}

signal ambience_started(ambience_id: StringName)
signal ambience_stopped()

@export var audio_bus: StringName = &"Ambience"
@export var base_volume_db: float = -14.0
@export var crossfade_time: float = 1.0

var _streams: Dictionary = {}
var _current_id: StringName = &""
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _tween: Tween

func _ready() -> void:
	_setup_players()
	_load_streams()

func _setup_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "AmbiencePlayerA"
	add_child(_player_a)
	
	_player_b = AudioStreamPlayer.new()
	_player_b.name = "AmbiencePlayerB"
	add_child(_player_b)
	
	var bus_to_use := &"Master"
	if AudioServer.get_bus_index(audio_bus) != -1:
		bus_to_use = audio_bus
	
	_player_a.bus = bus_to_use
	_player_b.bus = bus_to_use
	_player_a.volume_db = -80.0
	_player_b.volume_db = -80.0
	_active_player = _player_a

func _load_streams() -> void:
	var definitions := Catalog.definitions()
	for id: String in definitions:
		var definition: Dictionary = definitions[id]
		if not definition.get("loop", false) or definition.get("bus", "") != String(audio_bus):
			continue
		var entry := Catalog.load_entry(definition)
		var stream := Catalog.loop_stream(entry["stream"])
		if stream != null:
			_streams[StringName(id)] = stream
			_volumes[StringName(id)] = float(definition.get("volume_db", base_volume_db))

func start_ambience(ambience_id: StringName, fade_time: float = -1.0) -> void:
	if fade_time < 0.0:
		fade_time = crossfade_time
	
	# If already playing this ambience, ensure target volume
	if _current_id == ambience_id and _active_player != null and _active_player.playing:
		return
	
	var stream: AudioStream = _streams.get(ambience_id)
	if stream == null:
		push_warning("AmbientAudioController: Unknown ambience ID '%s'" % ambience_id)
		return
	
	_current_id = ambience_id
	var incoming := _player_b if _active_player == _player_a else _player_a
	var outgoing := _active_player
	
	incoming.stop()
	incoming.bus = audio_bus if AudioServer.get_bus_index(audio_bus) >= 0 else &"Master"
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	
	_tween.tween_property(incoming, "volume_db", float(_volumes.get(ambience_id, base_volume_db)), fade_time)
	if outgoing.playing:
		_tween.tween_property(outgoing, "volume_db", -80.0, fade_time)
		_tween.chain().tween_callback(outgoing.stop)
	
	_active_player = incoming
	ambience_started.emit(ambience_id)

func stop_ambience(fade_time: float = -1.0) -> void:
	if fade_time < 0.0:
		fade_time = crossfade_time
	_current_id = &""
	if _tween and _tween.is_valid():
		_tween.kill()
	# Room/menu teardown may free this node in the same frame. A zero-duration
	# Tween would never run, leaving the looping playback alive at shutdown.
	if fade_time <= 0.0:
		_on_stop_complete()
		return
	_tween = create_tween().set_parallel(true)
	if _player_a.playing:
		_tween.tween_property(_player_a, "volume_db", -80.0, fade_time)
	if _player_b.playing:
		_tween.tween_property(_player_b, "volume_db", -80.0, fade_time)
	_tween.tween_interval(fade_time)
	_tween.chain().tween_callback(_on_stop_complete)

func _on_stop_complete() -> void:
	for player in [_player_a, _player_b]:
		player.stop()
		player.stream = null
	ambience_stopped.emit()


func _exit_tree() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	for player in [_player_a, _player_b]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_streams.clear()

func switch_timeline(timeline: StringName, fade_time: float = -1.0) -> void:
	var tl_str := str(timeline).to_lower()
	if "past" in tl_str:
		start_ambience(&"lab_ambience_past", fade_time)
	elif "future" in tl_str:
		start_ambience(&"lab_ambience_future", fade_time)
	else:
		push_warning("AmbientAudioController: Unrecognized timeline '%s'" % timeline)

func get_current_ambience_id() -> StringName:
	return _current_id

func is_playing() -> bool:
	return (_player_a != null and _player_a.playing) or (_player_b != null and _player_b.playing)

