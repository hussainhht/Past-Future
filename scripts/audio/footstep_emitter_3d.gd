class_name FootstepEmitter3D
extends Node3D
## Responsive, physically grounded 3D footstep emitter for CharacterBody3D.
## Reads actual resolved velocity and grounded state to schedule cadence.

const Catalog := preload("res://scripts/audio/sound_catalog.gd")

@export var surface_event: StringName = &"footstep_past_tile"

signal footstep_played(variant_index: int, world_position: Vector3)

@export var character: CharacterBody3D
@export var walk_step_distance: float = 1.35
@export var run_step_distance: float = 1.38
@export var movement_threshold: float = 0.15
@export var run_speed_threshold: float = 3.6
@export var pitch_variation_range: float = 0.04
@export var base_volume_db: float = -12.0
@export var run_volume_boost_db: float = 1.0
@export var audio_bus: StringName = &"SFX"
@export var footstep_streams: Array[AudioStream] = []

var player: AudioStreamPlayer3D

var _distance_accumulated: float = 0.0
var _is_moving: bool = false
var _last_sample_index: int = -1
var _last_valid_position: Vector3 = Vector3.ZERO
var _has_last_position: bool = false

func _ready() -> void:
	if character == null and get_parent() is CharacterBody3D:
		character = get_parent() as CharacterBody3D
	
	if footstep_streams.is_empty():
		_load_default_footsteps()
	
	_configure_player()
	if is_instance_valid(character):
		_last_valid_position = character.global_position
		_has_last_position = true

func _load_default_footsteps() -> void:
	var definition: Dictionary = Catalog.definitions().get(String(surface_event), {})
	var entry := Catalog.load_entry(definition)
	footstep_streams.assign(entry["streams"])
	base_volume_db = float(entry.get("volume_db", -12.0))

func set_surface(event_id: StringName) -> void:
	if event_id == surface_event and not footstep_streams.is_empty():
		return
	surface_event = event_id
	_last_sample_index = -1
	_load_default_footsteps()
	reset()

func set_timeline(timeline: StringName) -> void:
	set_surface(&"footstep_future_concrete" if String(timeline).to_lower() == "future" else &"footstep_past_tile")

func _configure_player() -> void:
	if player == null:
		player = get_node_or_null("FootstepPlayer") as AudioStreamPlayer3D
	if player == null:
		player = AudioStreamPlayer3D.new()
		player.name = "FootstepPlayer"
		add_child(player)
	
	# Ensure bus is valid, fallback to Master
	if AudioServer.get_bus_index(audio_bus) != -1:
		player.bus = audio_bus
	else:
		player.bus = &"Master"
	
	# Tune 3D attenuation for the game's ~20m camera distance
	player.unit_size = 5.0
	player.max_distance = 20.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.volume_db = base_volume_db

func _physics_process(delta: float) -> void:
	if not is_instance_valid(character):
		_is_moving = false
		_distance_accumulated = 0.0
		return
	
	var current_pos := character.global_position
	var displacement := current_pos - _last_valid_position if _has_last_position else Vector3.ZERO
	_last_valid_position = current_pos
	_has_last_position = true
	# Actual displacement after physics: pushing against a wall cannot produce footsteps.
	if displacement.length() > 2.5 or ("controls_enabled" in character and not character.get("controls_enabled")):
		reset()
		return
	var distance := Vector2(displacement.x, displacement.z).length()
	var horizontal_speed := distance / maxf(delta, 0.0001)

	var is_grounded: bool = character.is_on_floor()
	
	# Stationary, airborne, or moving below threshold
	if not is_grounded or horizontal_speed < movement_threshold:
		if _is_moving:
			_is_moving = false
			# Reset accumulator on stop to prevent delayed step
			_distance_accumulated = 0.0
		return
	
	var is_running: bool = horizontal_speed >= run_speed_threshold
	var target_stride: float = run_step_distance if is_running else walk_step_distance
	
	if not _is_moving:
		# Just started moving. Prime the accumulator with a realistic fraction (0.4)
		# so the first footstep lands naturally mid-stride instead of frame 0.
		_is_moving = true
		_distance_accumulated = target_stride * 0.40
	
	_distance_accumulated += distance
	
	if _distance_accumulated >= target_stride:
		_distance_accumulated -= target_stride
		# Clamp to avoid burst steps if delta had a hitch
		if _distance_accumulated > target_stride * 0.5:
			_distance_accumulated = 0.0
		_play_footstep(is_running)

func _play_footstep(is_running: bool = false) -> void:
	if footstep_streams.is_empty():
		return
	
	# Select variant avoiding immediate repetition
	var count := footstep_streams.size()
	var pick := randi() % count
	if count > 1 and pick == _last_sample_index:
		pick = (pick + 1 + (randi() % (count - 1))) % count
	_last_sample_index = pick
	
	var stream := footstep_streams[pick]
	if stream == null:
		return
	
	if not is_instance_valid(player):
		_configure_player()
	
	player.stream = stream
	# Pitch variation +/- range
	var pitch := 1.0 + randf_range(-pitch_variation_range, pitch_variation_range)
	player.pitch_scale = pitch
	
	# Volume
	player.volume_db = base_volume_db + randf_range(-0.6, 0.6) + (run_volume_boost_db if is_running else 0.0)
	
	# Keep player anchored to character's foot level
	if is_instance_valid(character):
		player.global_position = character.global_position
	
	player.play()
	footstep_played.emit(pick, player.global_position)

func trigger_manual_step(is_running: bool = false) -> void:
	_play_footstep(is_running)

func reset() -> void:
	if is_instance_valid(player):
		player.stop()
	_distance_accumulated = 0.0
	_is_moving = false

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
	footstep_streams.clear()
