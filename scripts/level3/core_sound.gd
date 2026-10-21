extends Node
## Level 3 audio coordinator. Reacts only to confirmed PuzzleManager snapshots, the host's
## authoritative remaining time and local request feedback; it never writes puzzle state.
## Playback, buses and pools belong to AudioDirector; the countdown score to ReactorMusic.

const Rules := preload("res://scripts/level3/core_rules.gd")
const Catalog := preload("res://scripts/audio/sound_catalog.gd")
const Profile := preload("res://scripts/audio/reactor_music_profile.gd")
const ReactorMusicScript := preload("res://scripts/audio/reactor_music.gd")

const ARMED := ["STAGE_A", "STAGE_B", "STAGE_C"]
const ENDING_CUES := {"trust": &"core_ending_trust", "student_override": &"core_ending_student_override",
	"professor_override": &"core_ending_professor_override", "paradox": &"core_ending_paradox"}
const ENDING_FLASH := {"trust": Color("8ee5bb"), "student_override": Color("efb851"),
	"professor_override": Color("84a8ee"), "paradox": Color("b584e8")}
## Meltdown cue name (from ReactorExplosionDirector) -> catalog event.
const EXPLOSION_CUES := {"impact": &"core_overload_impact", "rupture": &"core_overload_rupture", "shockwave": &"core_overload_shockwave"}
## Seconds between ambient room details, [min, max], per timeline while idle.
const DETAIL_SPACING := {"past": {"arc": [14.0, 26.0], "clank": [22.0, 40.0], "pulse": [26.0, 46.0]},
	"future": {"arc": [7.0, 15.0], "clank": [14.0, 28.0], "pulse": [12.0, 24.0]}}

var director: AudioDirector
var music: Node
var room: Node3D
var role := "past"
var instability := 0.0
var events: Array[StringName] = []

var _hum: AudioStreamPlayer3D
var _pulse_light: OmniLight3D
var _coil_lights: Array[OmniLight3D] = []
var _flash_level := 0.0
var _flash_tint := Color.WHITE
var _coil_hums: Array[AudioStreamPlayer3D] = []
var _coil_targets: Array[float] = [-80.0, -80.0, -80.0]
var _hum_active := true
var _details: Dictionary = {}
var _sync_beat := -1
var _alarm_left := 0.0
var _alarm_tier := 0
var _age := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	director = load("res://scenes/audio/audio_system.tscn").instantiate()
	director.name = "AudioSystem"
	add_child(director)
	music = ReactorMusicScript.new()
	music.name = "ReactorMusic"
	add_child(music)
	music.pulse_fired.connect(_on_pulse)
	var definitions := Catalog.definitions()
	_hum = _loop_emitter(definitions[&"core_reactor_loop"])
	_hum.name = "ReactorCoreHum"
	for i in 3:
		var coil := _loop_emitter(definitions[&"core_coil_hum_loop"])
		coil.name = "CoilHum%d" % i
		coil.volume_db = -80.0
		_coil_hums.append(coil)
		_coil_lights.append(_make_light(Color("72dca8"), 2.8))
	_pulse_light = _make_light(Color("efc077"), 7.5)
	_reset_details()


func _make_light(color: Color, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = 0.0
	light.visible = false
	add_child(light)
	return light


func _loop_emitter(definition: Dictionary) -> AudioStreamPlayer3D:
	var entry := Catalog.load_entry(definition)
	var player := AudioStreamPlayer3D.new()
	player.stream = Catalog.loop_stream(entry["stream"])
	player.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
	player.volume_db = float(definition.get("volume_db", -20.0))
	player.unit_size = float(definition.get("unit_size", 8.0))
	player.max_distance = float(definition.get("max_distance", 30.0))
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player


## Called by the room once its worlds exist.
func bind(owner_room: Node3D) -> void:
	room = owner_room


func set_role(new_role: String) -> void:
	role = new_role
	director.start_ambience(StringName("core_ambience_" + role), 2.0)
	_place_emitters()
	_reset_details()


func _place_emitters() -> void:
	if room == null or not room.worlds.has(role):
		return
	var origin: Vector3 = room.worlds[role].global_position
	_hum.global_position = origin + Vector3(0, 1.7, 0)
	_pulse_light.global_position = origin + Vector3(0, 2.4, 0)
	for i in 3:
		_coil_hums[i].global_position = origin + Rules.STATIONS["coil_%d" % i] + Vector3(0, 1.0, 0)
		_coil_lights[i].global_position = origin + Rules.STATIONS["coil_%d" % i] + Vector3(0.4, 1.3, 0)
	if AudioServer.get_driver_name() != "Dummy":
		if _hum_active and not _hum.playing:
			_hum.play()


func _reset_details() -> void:
	for kind in ["arc", "clank", "pulse"]:
		var range: Array = DETAIL_SPACING[role][kind]
		_details[kind] = _rng.randf_range(range[0] * 0.4, range[1] * 0.6)


## Legacy shim: radio hails and the four ending cues.
func play(id: String) -> void:
	if ENDING_CUES.has(id):
		_ending(id)
	elif id == "signal":
		_log(&"radio_incoming")
		director.play_sfx(&"radio_incoming")


# ---------------------------------------------------------------- per-frame
## `remaining` is the room's predicted authoritative time; `sync_left` the confirmed phase window.
func tick(delta: float, remaining: float, sync_left: float) -> void:
	if room == null or room.state.is_empty():
		return
	_age += delta
	var state: Dictionary = room.state
	var stage: String = state.stage
	var armed: bool = stage in ARMED and not room.disconnected
	var solo_paused: bool = room._paused and not room.networked
	music.update(remaining, armed, solo_paused, delta)
	if solo_paused:
		return
	var idle_floor := 0.15 if role == "future" else 0.0
	instability = maxf(idle_floor, Profile.instability(remaining)) if armed else idle_floor
	if stage in ["OVERLOAD", "ENDING"] or room._meltdown_started:
		instability = 0.0
	_drive_hum(delta, stage)
	_drive_coil_hums(delta)
	_drive_sync_pulse(state, sync_left, stage)
	_drive_alarm(delta, remaining, armed)
	_drive_details(delta, stage, armed)
	_drive_vfx(delta)


func _drive_hum(delta: float, stage: String) -> void:
	var live: bool = not (stage in ["OVERLOAD", "ENDING"] or room._meltdown_started)
	var target_db := lerpf(-26.0, -11.0, instability) if live else -80.0
	var target_pitch := lerpf(1.0, 1.28, instability) + (sin(_age * 0.9) * 0.025 if role == "future" else 0.0)
	var k := 1.0 - exp(-delta / 0.6)
	_hum.volume_db = lerpf(_hum.volume_db, target_db, k)
	_hum.pitch_scale = lerpf(_hum.pitch_scale, target_pitch, k)
	_hum_active = _hum.volume_db > -60.0
	if AudioServer.get_driver_name() != "Dummy":
		if _hum_active and not _hum.playing:
			_hum.play()
		elif not _hum_active and _hum.playing:
			_hum.stop()


func _drive_coil_hums(delta: float) -> void:
	var k := 1.0 - exp(-delta / 0.5)
	for i in 3:
		var coil := _coil_hums[i]
		coil.volume_db = lerpf(coil.volume_db, _coil_targets[i], k)
		if AudioServer.get_driver_name() == "Dummy":
			continue
		if coil.volume_db > -60.0 and not coil.playing:
			coil.play()
		elif coil.volume_db <= -60.0 and coil.playing:
			coil.stop()


## Five-second phase window: one pulse per half-second that rises in pitch as it closes.
func _drive_sync_pulse(state: Dictionary, sync_left: float, stage: String) -> void:
	if stage == "STAGE_B" and (state.sync_past or state.sync_future) and sync_left > 0.0:
		var beat := ceili(sync_left * 2.0)
		if beat != _sync_beat:
			_sync_beat = beat
			var urgency := clampf(1.0 - sync_left / Rules.SYNC_WINDOW, 0.0, 1.0)
			_log(&"core_sync_tick")
			director.play_sfx(&"core_sync_tick", lerpf(1.0, 1.7, urgency))
	else:
		_sync_beat = -1


func _drive_alarm(delta: float, remaining: float, armed: bool) -> void:
	var tier := Profile.tier(remaining)
	var interval := Profile.alarm_interval(remaining) if armed else 0.0
	if interval <= 0.0:
		_alarm_left = 0.0
		_alarm_tier = tier
		return
	if tier != _alarm_tier:
		_alarm_tier = tier
		_alarm_left = 0.0
	_alarm_left -= delta
	if _alarm_left <= 0.0:
		_alarm_left = interval
		_log(&"core_alarm")
		director.play_sfx(&"core_alarm")


func _drive_details(delta: float, stage: String, armed: bool) -> void:
	if stage in ["OVERLOAD", "ENDING"] or room._meltdown_started:
		return
	var speed := lerpf(1.0, 3.5, instability) if armed else 1.0
	for kind in ["arc", "clank", "pulse"]:
		_details[kind] -= delta * speed
		if _details[kind] > 0.0:
			continue
		var range: Array = DETAIL_SPACING[role][kind]
		_details[kind] = _rng.randf_range(range[0], range[1])
		var id: StringName = {"arc": &"core_arc", "clank": &"core_clank", "pulse": &"core_temporal_pulse"}[kind]
		var angle := _rng.randf() * TAU
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(3.0, 8.0)
		spot.y = _rng.randf_range(0.8, 2.6)
		_log(id)
		director.play_world_sfx(id, room.worlds[role].global_position + spot)
		if kind == "arc":
			_flash(0.45)


## Light-only reinforcement of the audio: beat-locked reactor pulses, flashes on major events and
## a green glow over aligned coils. Honors the world's effects toggle and reduced-motion setting.
func _drive_vfx(delta: float) -> void:
	var world: Node = room.worlds.get(role)
	var enabled: bool = world != null and world.effects_enabled
	var reduced: bool = CinematicTransitionManager.is_reduced_motion()
	_flash_level = move_toward(_flash_level, 0.0, delta * 2.4)
	var accent: Color = Color("74deed") if role == "future" else Color("efc077")
	var flicker := 0.0 if reduced else instability * 0.35 * (0.5 + 0.5 * sin(_age * (8.0 + 22.0 * instability)))
	var energy := (_flash_level * (0.8 if reduced else 1.8) + flicker) if enabled else 0.0
	_pulse_light.light_energy = energy
	_pulse_light.light_color = accent.lerp(_flash_tint, clampf(_flash_level, 0.0, 1.0))
	_pulse_light.visible = energy > 0.02
	for i in 3:
		var aligned := _coil_targets[i] > -60.0 and enabled
		var glow := (0.55 + (0.0 if reduced else 0.2 * sin(_age * 3.0 + i))) if aligned else 0.0
		var light := _coil_lights[i]
		light.light_energy = lerpf(light.light_energy, glow, 1.0 - exp(-delta / 0.25))
		light.visible = light.light_energy > 0.02


func _on_pulse(id: StringName, _step: int) -> void:
	if id == &"core_perc_kick" or id == &"core_warn_beep":
		_flash(0.14 + 0.3 * instability)


func _flash(strength: float, tint: Color = Color.WHITE) -> void:
	if strength >= _flash_level:
		_flash_level = strength
		_flash_tint = tint


# ---------------------------------------------------------------- confirmed state
func on_state(previous: Dictionary, state: Dictionary) -> void:
	_update_coil_targets(state)
	if previous.is_empty():
		return
	if previous.get("attempt") != state.attempt:
		_new_attempt(previous, state)
		return
	var stage: String = state.stage
	for i in 3:
		if previous.coils[i] != state.coils[i]:
			_at(&"core_coil_surge", "coil_%d" % i)
			_flash(0.4)
			if state.coils[i] == Rules.COIL_TARGET[i]:
				get_tree().create_timer(0.2).timeout.connect(_at.bind(&"core_coil_align", "coil_%d" % i))
	if not previous.receiver and state.receiver:
		_at(&"core_battery_connect", "receiver")
		_flash(0.5)
	if not previous.anchor and state.anchor:
		_at(&"core_anchor_lock", "anchor")
		_flash(0.6)
	if not previous.origin and state.origin:
		_at(&"core_origin_stabilize", "origin")
		_flash(0.9)
	for who in ["past", "future"]:
		if not previous["sync_" + who] and state["sync_" + who]:
			if who == role:
				_at(&"core_sync_engage", "sync_" + who)
			else:
				_log(&"core_sync_engage_remote")
				director.play_sfx(&"core_sync_engage_remote")
			_flash(0.5)
		if not previous["locked_" + who] and state["locked_" + who]:
			if who == role:
				_at(&"core_command_lock", "terminal_" + who)
			else:
				_log(&"core_command_lock_remote")
				director.play_sfx(&"core_command_lock_remote")
	if previous.stage != stage:
		match stage:
			"STAGE_A":
				_log(&"core_arm_confirm")
				director.play_sfx(&"core_arm_confirm")
				_flash(1.0)
			"STAGE_B":
				_log(&"core_power_restore")
				director.play_sfx(&"core_power_restore")
				_flash(0.9)
			"STAGE_C":
				_log(&"core_sync_success")
				director.play_sfx(&"core_sync_success")
				_flash(1.0)
			"OVERLOAD":
				on_meltdown_started()
	elif stage == "STAGE_B" and (previous.sync_past or previous.sync_future) and not state.sync_past and not state.sync_future:
		_log(&"core_sync_fail")
		director.play_sfx(&"core_sync_fail")
		_flash(0.3, Color("e48f65"))


func _new_attempt(previous: Dictionary, state: Dictionary) -> void:
	music.stop(0.4)
	_sync_beat = -1
	_alarm_left = 0.0
	_reset_details()
	if previous.get("stage") in ["ENDING", "OVERLOAD"]:
		_log(&"core_reset_return")
		director.play_sfx(&"core_reset_return")
	director.start_ambience(StringName("core_ambience_" + role), 2.5)


func _update_coil_targets(state: Dictionary) -> void:
	var live: bool = state.stage in ARMED
	for i in 3:
		_coil_targets[i] = -22.0 if live and state.coils[i] == Rules.COIL_TARGET[i] else -80.0


# ---------------------------------------------------------------- local feedback
## The player's own press, before the host confirms. Heavy mechanisms never use UI clicks.
func on_device_action(device_id: String, action: String) -> void:
	match action:
		"sync":
			pass  # The confirmed engage sound carries the thunk, so the press stays silent until the host answers.
		"receiver":
			_at(&"core_battery_latch", device_id)
		"anchor":
			_at(&"core_anchor_calibrate", device_id)
		_:
			_at(&"core_relay_clunk", device_id)


func on_rejected() -> void:
	_log(&"core_reject")
	director.play_sfx(&"core_reject")


func on_inspect(open: bool) -> void:
	var id: StringName = &"core_console_open" if open else &"core_console_close"
	_log(id)
	director.play_ui(id)


# ---------------------------------------------------------------- overload and endings
func on_meltdown_started() -> void:
	music.stop(0.3)
	_log(&"core_alarm")
	director.play_sfx(&"core_alarm")
	director.ambient_controller.stop_ambience(3.5)
	_flash(0.8, Color("e48f65"))


func explosion_cue(cue: StringName, overrides: Dictionary = {}) -> void:
	var id := StringName(overrides.get(String(cue), EXPLOSION_CUES.get(String(cue), "")))
	if id != &"":
		_log(id)
		director.play_sfx(id)
	if cue == &"impact":
		_flash(1.5, Color("ffe6c4"))


func _ending(ending: String) -> void:
	music.stop(1.0)
	director.ambient_controller.stop_ambience(1.2)
	_log(ENDING_CUES[ending])
	director.play_sfx(ENDING_CUES[ending])
	_flash(1.2, ENDING_FLASH[ending])


# ---------------------------------------------------------------- helpers
func _at(id: StringName, station: String) -> void:
	if room == null or not room.worlds.has(role):
		return
	var spot: Vector3 = Rules.STATIONS.get(station, Vector3.ZERO)
	_log(id)
	director.play_world_sfx(id, room.worlds[role].global_position + spot + Vector3(0, 1.0, 0))


func _log(id: StringName) -> void:
	events.append(id)
	if events.size() > 96:
		events.pop_front()


func _exit_tree() -> void:
	events.clear()
	if is_instance_valid(_hum):
		_hum.stop()
	for coil in _coil_hums:
		if is_instance_valid(coil):
			coil.stop()
