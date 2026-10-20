class_name AudioDirector
extends Node
## Central coordinator for game audio: UI sounds, 2D SFX, 3D world sounds,
## bounded playback pools, audio buses, and volume management.

signal sound_played(sound_id: StringName, is_3d: bool, position: Vector3)

const Catalog := preload("res://scripts/audio/sound_catalog.gd")
const SETTINGS_PATH := "user://menu_settings.cfg"

const MAX_2D_PLAYERS: int = 12
const MAX_3D_PLAYERS: int = 8

const CATEGORIES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience"]

@export var persist_preferences: bool = true
@export var ambient_controller: AmbientAudioController

var music_controller: AmbientAudioController
var _last_played: Dictionary = {}
var _last_variant: Dictionary = {}
var _timeline: StringName = &""
var _detail_left: float = 24.0
var _catalog: Dictionary = {}
var _warned_ids: Dictionary = {}

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	_ensure_audio_buses()
	_build_catalog()
	_create_player_pools()
	_ensure_ambient_controller()
	music_controller = AmbientAudioController.new()
	music_controller.name = "MusicController"
	music_controller.audio_bus = &"Music"
	add_child(music_controller)
	_load_preferences()

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
	var definitions := Catalog.definitions()
	for id: String in definitions:
		var entry := Catalog.load_entry(definitions[id])
		if entry["stream"] != null:
			_catalog[StringName(id)] = entry

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

func _get_available_2d_player(priority: int = 60) -> AudioStreamPlayer:
	# First check for idle player
	for p in _pool_2d:
		if not p.playing:
			return p
	var candidate := _pool_2d[0]
	for player in _pool_2d:
		if int(player.get_meta("priority", 0)) < int(candidate.get_meta("priority", 0)):
			candidate = player
	return candidate if priority >= int(candidate.get_meta("priority", 0)) else null

func _get_available_3d_player(priority: int = 60) -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	var candidate := _pool_3d[0]
	for player in _pool_3d:
		if int(player.get_meta("priority", 0)) < int(candidate.get_meta("priority", 0)):
			candidate = player
	return candidate if priority >= int(candidate.get_meta("priority", 0)) else null

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
	
	var player := _get_available_2d_player(int(entry.get("priority", 60)))
	if player == null or not _can_play(sound_id, entry):
		return false
	player.stop()
	player.stream = _choose_stream(sound_id, entry)
	player.set_meta("sound_id", sound_id)
	player.set_meta("priority", int(entry.get("priority", 60)))
	var bus_name: StringName = entry.get("bus", fallback_bus)
	player.bus = _get_safe_bus(bus_name)
	player.volume_db = entry.get("volume_db", 0.0)
	
	var variance: float = entry.get("pitch_variance", 0.0)
	if variance > 0.0:
		player.pitch_scale = 1.0 + randf_range(-variance, variance)
	else:
		player.pitch_scale = 1.0
	
	# The headless Dummy driver cannot output sound. Avoid native one-shot
	# playbacks that can outlive its shutdown; still report accepted event hooks.
	if AudioServer.get_driver_name() != "Dummy":
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
	
	var player := _get_available_3d_player(int(entry.get("priority", 60)))
	if player == null or not _can_play(sound_id, entry):
		return false
	player.stop()
	player.stream = _choose_stream(sound_id, entry)
	player.set_meta("sound_id", sound_id)
	player.set_meta("priority", int(entry.get("priority", 60)))
	var bus_name: StringName = entry.get("bus", &"SFX")
	player.bus = _get_safe_bus(bus_name)
	player.volume_db = entry.get("volume_db", 0.0)
	
	var variance: float = entry.get("pitch_variance", 0.0)
	if variance > 0.0:
		player.pitch_scale = 1.0 + randf_range(-variance, variance)
	else:
		player.pitch_scale = 1.0
	
	player.unit_size = float(entry.get("unit_size", 8.0))
	player.max_distance = float(entry.get("max_distance", 24.0))
	player.global_position = world_position
	if AudioServer.get_driver_name() != "Dummy":
		player.play()
	sound_played.emit(sound_id, true, world_position)
	return true

func start_ambience(ambience_id: StringName, fade_time: float = -1.0) -> void:
	if is_instance_valid(ambient_controller):
		ambient_controller.start_ambience(ambience_id, fade_time)

func stop_ambience(fade_time: float = -1.0) -> void:
	_timeline = &""
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
	_save_preferences()

func get_category_volume_linear(category: StringName) -> float:
	var bus_idx := AudioServer.get_bus_index(category)
	if bus_idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(bus_idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func _choose_stream(sound_id: StringName, entry: Dictionary) -> AudioStream:
	var streams: Array = entry["streams"]
	var index := randi_range(0, streams.size() - 1)
	if streams.size() > 1 and index == _last_variant.get(sound_id, -1):
		index = (index + randi_range(1, streams.size() - 1)) % streams.size()
	_last_variant[sound_id] = index
	return streams[index]

func _can_play(sound_id: StringName, entry: Dictionary) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound_id, -1000.0)) < float(entry.get("cooldown", 0.0)):
		return false
	var count := 0
	for player in _pool_2d + _pool_3d:
		if player.playing and player.get_meta("sound_id", &"") == sound_id:
			count += 1
	if count >= int(entry.get("concurrency", 2)):
		return false
	_last_played[sound_id] = now
	return true

func start_music(timeline: StringName, fade_time: float = 2.5) -> void:
	var id := StringName("music_" + String(timeline).to_lower())
	music_controller.start_ambience(id, fade_time)

func stop_music(fade_time: float = 1.5) -> void:
	if is_instance_valid(music_controller):
		music_controller.stop_ambience(fade_time)

func start_soundscape(timeline: StringName) -> void:
	_timeline = StringName(String(timeline).to_lower())
	ambient_controller.switch_timeline(_timeline, 2.0)
	start_music(_timeline)
	_detail_left = randf_range(22.0, 38.0)

func _process(delta: float) -> void:
	if _timeline.is_empty() or not ambient_controller.is_playing():
		return
	_detail_left -= delta
	if _detail_left <= 0.0:
		play_sfx(&"past_equipment" if _timeline == &"past" else &"future_creak")
		_detail_left = randf_range(28.0, 48.0)

func set_category_muted(category: StringName, muted: bool) -> void:
	var index := AudioServer.get_bus_index(category)
	if index >= 0:
		AudioServer.set_bus_mute(index, muted)
		_save_preferences()

func is_category_muted(category: StringName) -> bool:
	var index := AudioServer.get_bus_index(category)
	return index >= 0 and AudioServer.is_bus_mute(index)

func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for category in CATEGORIES:
		var index := AudioServer.get_bus_index(category)
		var volume := clampf(float(config.get_value("audio", String(category), 1.0)), 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, bool(config.get_value("audio_mute", String(category), false)) or volume <= 0.0001)

func _save_preferences() -> void:
	if not persist_preferences:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for category in CATEGORIES:
		var index := AudioServer.get_bus_index(category)
		config.set_value("audio", String(category), db_to_linear(AudioServer.get_bus_volume_db(index)))
		config.set_value("audio_mute", String(category), AudioServer.is_bus_mute(index))
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("AudioDirector: could not save volume settings: %s" % error_string(error))

func _exit_tree() -> void:
	stop_all_sfx()
	stop_ambience(0.0)
	stop_music(0.0)
	for player in _pool_2d + _pool_3d:
		player.stream = null
	_catalog.clear()

func bind_ui(ui_root: Node) -> void:
	for node in ui_root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.has_meta("audio_bound"):
			continue
		button.set_meta("audio_bound", true)
		button.mouse_entered.connect(func() -> void:
			if not button.disabled and button.is_visible_in_tree():
				play_ui(&"ui_hover")
		)
		button.focus_entered.connect(func() -> void:
			if not button.disabled and button.is_visible_in_tree():
				play_ui(&"ui_hover")
		)
		button.pressed.connect(func() -> void:
			var id := StringName(button.get_meta("audio_event", &"ui_click"))
			if not id.is_empty():
				play_ui(id)
		)
