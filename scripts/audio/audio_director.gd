class_name AudioDirector
extends Node
## Central coordinator for game audio: UI sounds, 2D SFX, 3D world sounds,
## bounded playback pools, audio buses, and volume management.

signal sound_played(sound_id: StringName, is_3d: bool, position: Vector3)

const MAX_2D_PLAYERS: int = 12
const MAX_3D_PLAYERS: int = 8

const CATEGORIES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience"]

@export var ambient_controller: AmbientAudioController

var _catalog: Dictionary = {}
var _warned_ids: Dictionary = {}

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d_index: int = 0
var _pool_3d_index: int = 0

func _ready() -> void:
	_ensure_audio_buses()
	_build_catalog()
	_create_player_pools()
	_ensure_ambient_controller()

func _ensure_audio_buses() -> void:
	# Ensure the required category buses exist in AudioServer without editing project.godot
	var default_buses: Array[StringName] = [&"Music", &"SFX", &"UI", &"Ambience"]
	for bus_name in default_buses:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")

func _get_safe_bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) != -1:
		return bus_name
	return &"Master"

func _ensure_ambient_controller() -> void:
	if ambient_controller == null:
		ambient_controller = get_node_or_null("AmbientAudioController") as AmbientAudioController
	if ambient_controller == null:
		ambient_controller = AmbientAudioController.new()
		ambient_controller.name = "AmbientAudioController"
		add_child(ambient_controller)

func _build_catalog() -> void:
	# Map each sound ID to {path, bus, volume_db, pitch_variance}
	var defs: Dictionary = {
		# UI SFX
		&"ui_click": {
			"path": "res://assets/audio/ui/ui_click.wav",
			"bus": &"UI",
			"volume_db": -4.0,
			"pitch_variance": 0.03
		},
		&"ui_hover": {
			"path": "res://assets/audio/ui/ui_hover.wav",
			"bus": &"UI",
			"volume_db": -10.0,
			"pitch_variance": 0.02
		},
		&"ui_confirm": {
			"path": "res://assets/audio/ui/ui_confirm.wav",
			"bus": &"UI",
			"volume_db": -3.0,
			"pitch_variance": 0.0
		},
		&"ui_back": {
			"path": "res://assets/audio/ui/ui_back.wav",
			"bus": &"UI",
			"volume_db": -4.0,
			"pitch_variance": 0.0
		},
		# Interaction SFX
		&"interaction_click": {
			"path": "res://assets/audio/interaction/interaction_click.wav",
			"bus": &"SFX",
			"volume_db": -4.0,
			"pitch_variance": 0.04
		},
		&"interaction_success": {
			"path": "res://assets/audio/interaction/interaction_success.wav",
			"bus": &"SFX",
			"volume_db": -2.0,
			"pitch_variance": 0.0
		},
		&"interaction_denied": {
			"path": "res://assets/audio/interaction/interaction_denied.wav",
			"bus": &"SFX",
			"volume_db": -3.0,
			"pitch_variance": 0.02
		},
		# Environment SFX
		&"door_open": {
			"path": "res://assets/audio/environment/door_open.wav",
			"bus": &"SFX",
			"volume_db": -2.0,
			"pitch_variance": 0.03
		},
		&"door_locked": {
			"path": "res://assets/audio/environment/door_locked.wav",
			"bus": &"SFX",
			"volume_db": -3.0,
			"pitch_variance": 0.02
		},
		&"computer_beep": {
			"path": "res://assets/audio/environment/computer_beep.wav",
			"bus": &"SFX",
			"volume_db": -6.0,
			"pitch_variance": 0.04
		},
		&"switch_toggle": {
			"path": "res://assets/audio/environment/switch_toggle.wav",
			"bus": &"SFX",
			"volume_db": -4.0,
			"pitch_variance": 0.03
		},
		&"rift_hum": {
			"path": "res://assets/audio/environment/rift_hum.wav",
			"bus": &"Ambience",
			"volume_db": -12.0,
			"pitch_variance": 0.0
		}
	}
	
	for id in defs:
		var entry: Dictionary = defs[id]
		var path: String = entry["path"]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream:
				entry["stream"] = stream
				_catalog[id] = entry
		else:
			push_warning("AudioDirector: Sound file missing for '%s' at '%s'" % [id, path])

func _create_player_pools() -> void:
	# Bounded non-positional player pool
	for i in range(MAX_2D_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.name = "Pool2DPlayer_%d" % i
		add_child(p)
		_pool_2d.append(p)
	
	# Bounded 3D world player pool
	for i in range(MAX_3D_PLAYERS):
		var p := AudioStreamPlayer3D.new()
		p.name = "Pool3DPlayer_%d" % i
		# Attenuation configured for standard ~20m camera distance
		p.unit_size = 18.0
		p.max_distance = 60.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool_3d.append(p)

func _get_available_2d_player() -> AudioStreamPlayer:
	# First check for idle player
	for p in _pool_2d:
		if not p.playing:
			return p
	# If all busy, round-robin steal the oldest
	var player := _pool_2d[_pool_2d_index]
	_pool_2d_index = (_pool_2d_index + 1) % _pool_2d.size()
	return player

func _get_available_3d_player() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	var player := _pool_3d[_pool_3d_index]
	_pool_3d_index = (_pool_3d_index + 1) % _pool_3d.size()
	return player

func has_sound(sound_id: StringName) -> bool:
	return _catalog.has(sound_id)

func play_sfx(sound_id: StringName) -> bool:
	return _play_2d(sound_id, &"SFX")

func play_ui(sound_id: StringName) -> bool:
	return _play_2d(sound_id, &"UI")

func _play_2d(sound_id: StringName, fallback_bus: StringName) -> bool:
	var entry: Dictionary = _catalog.get(sound_id, {})
	if entry.is_empty():
		if not _warned_ids.has(sound_id):
			_warned_ids[sound_id] = true
			push_warning("AudioDirector: Sound ID '%s' not found in catalog" % sound_id)
		return false
	
	var player := _get_available_2d_player()
	player.stream = entry["stream"]
	var bus_name: StringName = entry.get("bus", fallback_bus)
	player.bus = _get_safe_bus(bus_name)
	player.volume_db = entry.get("volume_db", 0.0)
	
	var variance: float = entry.get("pitch_variance", 0.0)
	if variance > 0.0:
		player.pitch_scale = 1.0 + randf_range(-variance, variance)
	else:
		player.pitch_scale = 1.0
	
	player.play()
	sound_played.emit(sound_id, false, Vector3.ZERO)
	return true

func play_world_sfx(sound_id: StringName, world_position: Vector3) -> bool:
	var entry: Dictionary = _catalog.get(sound_id, {})
	if entry.is_empty():
		if not _warned_ids.has(sound_id):
			_warned_ids[sound_id] = true
			push_warning("AudioDirector: Sound ID '%s' not found in catalog for world SFX" % sound_id)
		return false
	
	var player := _get_available_3d_player()
	player.stream = entry["stream"]
	var bus_name: StringName = entry.get("bus", &"SFX")
	player.bus = _get_safe_bus(bus_name)
	player.volume_db = entry.get("volume_db", 0.0)
	
	var variance: float = entry.get("pitch_variance", 0.0)
	if variance > 0.0:
		player.pitch_scale = 1.0 + randf_range(-variance, variance)
	else:
		player.pitch_scale = 1.0
	
	player.global_position = world_position
	player.play()
	sound_played.emit(sound_id, true, world_position)
	return true

func start_ambience(ambience_id: StringName, fade_time: float = -1.0) -> void:
	if is_instance_valid(ambient_controller):
		ambient_controller.start_ambience(ambience_id, fade_time)

func stop_ambience(fade_time: float = -1.0) -> void:
	if is_instance_valid(ambient_controller):
		ambient_controller.stop_ambience(fade_time)

func stop_all_sfx() -> void:
	for p in _pool_2d:
		if p.playing:
			p.stop()
	for p in _pool_3d:
		if p.playing:
			p.stop()

# --- Bus and Volume Controls ---

func set_category_volume_linear(category: StringName, value: float) -> void:
	var clamped_val := clampf(value, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index(category)
	if bus_idx == -1:
		push_warning("AudioDirector: Cannot set volume on unknown bus '%s'" % category)
		return
	
	if clamped_val <= 0.0001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamped_val))

func get_category_volume_linear(category: StringName) -> float:
	var bus_idx := AudioServer.get_bus_index(category)
	if bus_idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(bus_idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))

