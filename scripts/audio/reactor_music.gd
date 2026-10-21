class_name ReactorMusic
extends Node
## Adaptive 150-second reactor score. One AudioStreamSynchronized keeps five bar-aligned
## 135 BPM stems sample-locked; per-stem gain and a grid-locked percussion layer follow the
## authoritative remaining time handed to update(). Nothing here owns a timer of its own.

const Catalog := preload("res://scripts/audio/sound_catalog.gd")
const Profile := preload("res://scripts/audio/reactor_music_profile.gd")

signal started
signal stopped
signal tier_changed(tier: int)
signal pulse_fired(event_id: StringName, step: int)

const RESYNC_TOLERANCE := 0.4
const FADE_SECONDS := 0.9
const PERC_VOICES := 6
const MAX_PULSES_PER_FRAME := 4

@export var total_seconds: float = Profile.TOTAL_SECONDS

var active := false
var tier := 0
var elapsed := 0.0
var stem_target_db: Dictionary = {}
var stem_current_db: Dictionary = {}
# Counters for diagnostics and tests.
var start_count := 0
var seek_count := 0
var pulse_count := 0
var hit_count := 0
var riser_started := false

var _player: AudioStreamPlayer
var _riser: AudioStreamPlayer
var _perc: Array[AudioStreamPlayer] = []
var _perc_next := 0
var _sync: AudioStreamSynchronized
var _entries: Dictionary = {}
var _model_elapsed := 0.0
var _next_pulse_at := -1.0
var _last_interval := -1.0
var _last_second := -1
var _tween: Tween
var _suppress_hit := false


func _ready() -> void:
	var bus: StringName = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
	_player = AudioStreamPlayer.new()
	_player.name = "ScoreStems"
	_player.bus = bus
	add_child(_player)
	_riser = AudioStreamPlayer.new()
	_riser.name = "FinalRiser"
	_riser.bus = bus
	add_child(_riser)
	for i in PERC_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Percussion%d" % i
		voice.bus = bus
		add_child(voice)
		_perc.append(voice)
	var definitions := Catalog.definitions()
	for stem in Profile.STEMS:
		_load_entry(definitions, StringName("core_music_%s" % stem))
	for id in [&"core_riser_final", &"core_tier_hit", &"core_countdown_second", &"core_perc_kick", &"core_perc_tick", &"core_perc_hit", &"core_warn_beep"]:
		_load_entry(definitions, id)
	for stem in Profile.STEMS:
		stem_current_db[stem] = Profile.OFF_DB
		stem_target_db[stem] = Profile.OFF_DB


func _load_entry(definitions: Dictionary, id: StringName) -> void:
	if definitions.has(id):
		_entries[id] = Catalog.load_entry(definitions[id])


func _output() -> bool:
	# The headless Dummy driver cannot render; logic still runs so tests can observe it.
	return AudioServer.get_driver_name() != "Dummy"


## Called every frame with the predicted authoritative remaining time. `running` is true only
## while the host reports an armed reactor (stages A-C); `paused` freezes the model in solo pause.
func update(remaining: float, running: bool, paused: bool, delta: float) -> void:
	if not running or remaining <= 0.0:
		if active:
			stop(0.25 if remaining <= 0.0 and running else 0.8)
		return
	if not active:
		start(remaining)
	_player.stream_paused = paused
	_riser.stream_paused = paused
	if paused:
		return
	var e := Profile.elapsed_for(remaining, total_seconds)
	_model_elapsed += delta
	if absf(_model_elapsed - e) > RESYNC_TOLERANCE:
		_resync(e)
	elapsed = e
	var next_tier := Profile.tier(remaining)
	if next_tier != tier:
		_enter_tier(next_tier)
	_smooth_stems(delta)
	_run_pulses(remaining)
	_run_final_second(remaining)
	_run_riser(remaining)
	_suppress_hit = false


func start(remaining: float) -> void:
	_cancel_fade()
	_hard_stop()
	var e := Profile.elapsed_for(remaining, total_seconds)
	elapsed = e
	_model_elapsed = e
	_next_pulse_at = -1.0
	_last_interval = -1.0
	_last_second = -1
	riser_started = false
	_suppress_hit = true
	var late := e > 1.5
	for stem in Profile.STEMS:
		stem_target_db[stem] = Profile.stem_db(Profile.tier(remaining), stem)
		stem_current_db[stem] = stem_target_db[stem] if late else Profile.OFF_DB
	if _output():
		_sync = _build_sync()
		_player.stream = _sync
		_player.volume_db = -24.0 if late else 0.0
		_apply_stem_volumes()
		_player.play(Profile.loop_position(e))
		if late:
			_tween = create_tween()
			_tween.tween_property(_player, "volume_db", 0.0, 1.0)
	active = true
	tier = 0
	start_count += 1
	started.emit()


## Fade out and stop; safe to call repeatedly. The next update() with running=true restarts cleanly.
func stop(fade: float = 0.8) -> void:
	if not active:
		return
	active = false
	for stem in Profile.STEMS:
		stem_target_db[stem] = Profile.OFF_DB
	tier = 0
	if fade <= 0.0 or not is_inside_tree() or not _output():
		_hard_stop()
		stopped.emit()
		return
	_cancel_fade()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_player, "volume_db", -60.0, fade)
	_tween.tween_property(_riser, "volume_db", -60.0, fade)
	_tween.chain().tween_callback(_hard_stop)
	stopped.emit()


func _hard_stop() -> void:
	if _player == null:
		return
	_player.stop()
	_riser.stop()
	_riser.volume_db = 0.0
	for voice in _perc:
		voice.stop()
	_player.volume_db = 0.0
	_player.stream = null
	_sync = null


func _cancel_fade() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _build_sync() -> AudioStreamSynchronized:
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = Profile.STEMS.size()
	for i in Profile.STEMS.size():
		var entry: Dictionary = _entries.get(StringName("core_music_%s" % Profile.STEMS[i]), {})
		sync.set_sync_stream(i, Catalog.loop_stream(entry.get("stream")))
	return sync


func _apply_stem_volumes() -> void:
	if _sync == null:
		return
	for i in Profile.STEMS.size():
		_sync.set_sync_stream_volume(i, float(stem_current_db[Profile.STEMS[i]]))


func _resync(e: float) -> void:
	_model_elapsed = e
	seek_count += 1
	_next_pulse_at = -1.0
	_last_interval = -1.0
	_last_second = -1
	_suppress_hit = true
	if _output() and _player.playing:
		_player.seek(Profile.loop_position(e))


func _enter_tier(next_tier: int) -> void:
	var previous := tier
	tier = next_tier
	for stem in Profile.STEMS:
		stem_target_db[stem] = Profile.stem_db(tier, stem)
	if previous > 0 and tier == previous + 1 and not _suppress_hit:
		hit_count += 1
		_play_oneshot(&"core_tier_hit", 0.0, 1.0)
	_suppress_hit = false
	_next_pulse_at = -1.0
	tier_changed.emit(tier)


func _smooth_stems(delta: float) -> void:
	var k := 1.0 - exp(-delta / FADE_SECONDS)
	for stem in Profile.STEMS:
		var target: float = stem_target_db[stem]
		var current: float = stem_current_db[stem]
		current += (target - current) * k
		if target <= Profile.OFF_DB and current < -60.0:
			current = Profile.OFF_DB
		stem_current_db[stem] = current
	_apply_stem_volumes()


func _run_pulses(remaining: float) -> void:
	var interval := Profile.pulse_interval(remaining)
	if interval <= 0.0:
		_next_pulse_at = -1.0
		return
	var grid := tier != 6
	if _next_pulse_at < 0.0 or (grid and not is_equal_approx(interval, _last_interval)):
		_next_pulse_at = (floorf(elapsed / interval) + 1.0) * interval if grid else elapsed
	_last_interval = interval
	var fired := 0
	while elapsed >= _next_pulse_at:
		if fired >= MAX_PULSES_PER_FRAME:
			# A long frame hitch: skip ahead instead of machine-gunning the backlog.
			_next_pulse_at = elapsed + interval
			break
		_fire_step(roundi(_next_pulse_at / Profile.STEP), remaining)
		_next_pulse_at += Profile.pulse_interval(remaining) if not grid else interval
		fired += 1


func _fire_step(step: int, remaining: float) -> void:
	if tier == 6:
		var pitch := Profile.final_pitch(remaining)
		_play_oneshot(&"core_warn_beep", 0.0, pitch)
		if pulse_count % 4 == 0:
			_play_oneshot(&"core_perc_kick", 1.0, 1.0)
		pulse_count += 1
		pulse_fired.emit(&"core_warn_beep", step)
		return
	for hit: Array in Profile.pattern(tier, step):
		_play_oneshot(hit[0], float(hit[1]), 1.0)
		pulse_fired.emit(hit[0], step)
	pulse_count += 1


func _run_final_second(remaining: float) -> void:
	if tier != 6:
		_last_second = -1
		return
	var second := ceili(remaining)
	if second != _last_second:
		if _last_second == -1 or second < _last_second:
			_play_oneshot(&"core_countdown_second", 0.0, 1.0)
		_last_second = second


func _run_riser(remaining: float) -> void:
	var inside := remaining <= 10.0
	if inside and not riser_started:
		riser_started = true
		if _output():
			_riser.stream = _entries.get(&"core_riser_final", {}).get("stream")
			_riser.volume_db = float(_entries.get(&"core_riser_final", {}).get("volume_db", 0.0))
			_riser.play(clampf(10.0 - remaining, 0.0, 9.9))
	elif not inside and riser_started:
		riser_started = false
		_riser.stop()


func _play_oneshot(id: StringName, extra_db: float, pitch: float) -> void:
	var entry: Dictionary = _entries.get(id, {})
	if entry.is_empty() or not _output():
		return
	var voice := _perc[_perc_next]
	_perc_next = (_perc_next + 1) % PERC_VOICES
	voice.stream = entry["stream"]
	voice.volume_db = float(entry.get("volume_db", 0.0)) + extra_db
	voice.pitch_scale = pitch
	voice.play()


func snapshot() -> Dictionary:
	return {"active": active, "tier": tier, "elapsed": elapsed, "stems": stem_target_db.duplicate(),
		"starts": start_count, "seeks": seek_count, "pulses": pulse_count, "hits": hit_count, "riser": riser_started}


func _exit_tree() -> void:
	_cancel_fade()
	active = false
	_hard_stop()
	_entries.clear()
