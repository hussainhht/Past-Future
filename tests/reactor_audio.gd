extends SceneTree
## Focused Level 2 / Level 3 audio checks: countdown music progression and reset behavior,
## confirmed-event triggering, catalog coverage and cleanup. Short by design.

const Rules := preload("res://scripts/level3/core_rules.gd")
const Profile := preload("res://scripts/audio/reactor_music_profile.gd")
const MusicScript := preload("res://scripts/audio/reactor_music.gd")
const MaintRules := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
var checks := 0
var failures := 0
var room: Node3D


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("REACTOR AUDIO FAILED: " + label)


func tick() -> void:
	for i in 3: await physics_frame
	await process_frame


func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: push_error("REACTOR AUDIO: watchdog"); quit(1))
	_profile()
	await _music()
	await _level3()
	await _level2()
	print("REACTOR AUDIO: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _profile() -> void:
	var expected := {150.0: 1, 111.0: 1, 110.4: 1, 110.0: 2, 76.0: 2, 75.5: 2, 75.0: 3, 41.0: 3, 40.0: 4, 21.0: 4, 20.0: 5, 11.0: 5, 10.0: 6, 0.5: 6, 0.0: 0}
	for remaining: float in expected:
		check(Profile.tier(remaining) == expected[remaining], "tier at %.1f s remaining is %d" % [remaining, expected[remaining]])
	var previous := 99.0
	for remaining in [100.0, 60.0, 30.0, 15.0, 8.0, 3.0, 0.5]:
		var interval := Profile.pulse_interval(remaining)
		check(interval > 0.0 and interval <= previous, "pulses never slow down: %.1f s -> %.3f s" % [remaining, interval])
		previous = interval
	check(Profile.pulse_interval(130.0) == 0.0, "first tier has no percussion")
	check(Profile.pulse_interval(100.0) > 6.0 * Profile.pulse_interval(0.5), "final flutter is more than six times faster than the first pulse")
	for tier_index in range(1, 7):
		check(Profile.stem_db(tier_index, &"bed") > Profile.OFF_DB, "bed stem stays under tier %d" % tier_index)
	check(Profile.stem_db(1, &"drive") == Profile.OFF_DB and Profile.stem_db(4, &"lead") > Profile.OFF_DB, "layers enter progressively")
	check(is_equal_approx(Profile.LOOP_SECONDS, 16.0 * 4.0 * 60.0 / 135.0), "stem loop is exactly 16 bars at 135 BPM")
	check(Profile.alarm_interval(150.0) == 0.0 and Profile.alarm_interval(15.0) > Profile.alarm_interval(5.0) and Profile.alarm_interval(5.0) > 0.0, "alarm is silent early and quickens")


func _music() -> void:
	var music: Node = MusicScript.new()
	root.add_child(music)
	await tick()
	var tiers: Array[int] = []
	music.tier_changed.connect(func(t: int) -> void: tiers.append(t))
	var per_tier := {}
	var counted := 0
	var remaining := 150.0
	while remaining > 0.0:
		music.update(remaining, true, false, 0.1)
		per_tier[music.tier] = int(per_tier.get(music.tier, 0)) + (music.pulse_count - counted)
		counted = music.pulse_count
		remaining -= 0.1
	check(tiers == [1, 2, 3, 4, 5, 6], "countdown visits all six tiers in order: %s" % [tiers])
	check(music.start_count == 1 and music.seek_count == 0, "one continuous start; no restart or seek over the full countdown")
	check(music.hit_count == 5, "five tier stingers fire")
	check(int(per_tier[6]) / 10.0 > int(per_tier[5]) / 9.0 and int(per_tier[5]) / 9.0 > int(per_tier[3]) / 35.0, "pulse density rises tier over tier")
	music.update(0.0, true, false, 0.1)
	check(not music.active, "music stops when the countdown expires")
	music.update(150.0, true, false, 0.1)
	check(music.active and music.start_count == 2 and music.tier == 1, "retry restarts at tier 1 exactly once")
	music.update(149.9, true, false, 0.1)
	music.update(149.8, true, false, 0.1)
	check(music.start_count == 2, "music is not restarted every frame")
	music.update(60.0, true, false, 0.1)
	check(music.seek_count == 1 and music.tier == 3, "state synchronization jump re-seeks to the authoritative time")
	var frozen: int = music.pulse_count
	music.update(59.0, true, true, 5.0)
	check(music.pulse_count == frozen, "solo pause freezes pulses")
	music.update(59.0, false, false, 0.1)
	check(not music.active, "leaving the armed stages stops the score")
	music.update(30.0, true, false, 0.1)
	check(music.active and music.tier == 4 and music.elapsed == 120.0, "late join starts at the authoritative position and tier")
	music.queue_free()
	await tick()


func _level3() -> void:
	root.get_node("GameFlowManager").start_room("room_03")
	await tick()
	room = current_scene
	room.player.set_physics_process(false)
	room.set_process(false)
	var sound: Node = room.sound
	var director: AudioDirector = sound.director
	check(director.ambient_controller.get_current_ambience_id() == &"core_ambience_past", "Past reactor bed plays on entry")
	check(not director.music_controller.is_playing(), "pre-activation has no countdown music")
	sound.events.clear()
	var base: Dictionary = room.state.duplicate(true)
	var armed := base.duplicate(true)
	armed.stage = "STAGE_A"
	sound.on_state(base, armed)
	check(&"core_arm_confirm" in sound.events, "ARM REACTOR confirmation sound")
	var step := 0.25
	var remaining := 150.0
	var alarms := 0
	room.state = armed
	while remaining > 0.0:
		sound.tick(step, remaining, 0.0)
		remaining -= step
	alarms = sound.events.count(&"core_alarm")
	check(sound.music.start_count == 1 and sound.music.tier == 6, "music started with the activation and reached the final tier")
	check(alarms >= 6, "alarm quickens through the last twenty seconds (%d)" % alarms)
	sound.tick(step, 0.0, 0.0)
	check(not sound.music.active, "music stops at expiry")
	var power := armed.duplicate(true)
	power.coils = [2, 1, 1]
	power.receiver = true
	sound.on_state(armed, power)
	check(&"core_coil_surge" in sound.events and &"core_battery_connect" in sound.events, "coils and receiver confirmations")
	sound.on_device_action("coil_0", "_coil")
	sound.on_device_action("receiver", "receiver")
	sound.on_device_action("anchor", "anchor")
	check(&"core_relay_clunk" in sound.events and &"core_battery_latch" in sound.events and &"core_anchor_calibrate" in sound.events, "physical presses use mechanism sounds, not UI clicks")
	var aligned := power.duplicate(true)
	aligned.coils = Rules.COIL_TARGET.duplicate()
	aligned.stage = "STAGE_B"
	sound.on_state(power, aligned)
	check(&"core_power_restore" in sound.events, "conduit power routing restored")
	var calibrated := aligned.duplicate(true)
	calibrated.anchor = true
	calibrated.origin = true
	sound.on_state(aligned, calibrated)
	check(&"core_anchor_lock" in sound.events and &"core_origin_stabilize" in sound.events, "Signal Anchor and Origin Core stabilizer")
	var pressed := calibrated.duplicate(true)
	pressed.sync_past = true
	sound.on_state(calibrated, pressed)
	check(&"core_sync_engage" in sound.events, "local phase switch engage")
	room.state = pressed
	sound.events.clear()
	sound.tick(0.1, 100.0, 4.9)
	sound.tick(0.1, 100.0, 4.8)
	sound.tick(0.1, 100.0, 4.2)
	check(sound.events.count(&"core_sync_tick") == 2, "five-second window pulses once per half second")
	var missed := pressed.duplicate(true)
	missed.sync_past = false
	sound.on_state(pressed, missed)
	check(&"core_sync_fail" in sound.events, "missed window failure sound")
	var remote := calibrated.duplicate(true)
	remote.sync_future = true
	sound.on_state(calibrated, remote)
	check(&"core_sync_engage_remote" in sound.events, "partner's confirmed switch is heard")
	var synced := remote.duplicate(true)
	synced.sync_past = true
	synced.stage = "STAGE_C"
	sound.on_state(remote, synced)
	check(&"core_sync_success" in sound.events, "synchronization success")
	var locked := synced.duplicate(true)
	locked.locked_past = true
	locked.locked_future = true
	sound.on_state(synced, locked)
	check(&"core_command_lock" in sound.events and &"core_command_lock_remote" in sound.events, "both identity terminals")
	sound.on_rejected()
	check(&"core_reject" in sound.events, "rejected operation")
	for ending in ["trust", "student_override", "professor_override", "paradox"]:
		sound.play(ending)
		check(StringName("core_ending_" + ending) in sound.events, "distinct ending cue: " + ending)
	var done := locked.duplicate(true)
	done.stage = "ENDING"
	var fresh := base.duplicate(true)
	fresh.attempt = base.attempt + 1
	sound.on_state(done, fresh)
	check(&"core_reset_return" in sound.events and not sound.music.active, "replay returns to the ambient atmosphere with the score stopped")
	for cue in ["impact", "rupture", "shockwave"]:
		sound.explosion_cue(StringName(cue), room.explosion_audio_cues)
	check(&"core_overload_impact" in sound.events and &"core_overload_rupture" in sound.events and &"core_overload_shockwave" in sound.events, "meltdown cues map to overload sounds")
	var missing: Array[StringName] = []
	for id: StringName in sound.events:
		if not director.has_sound(id):
			missing.append(id)
	check(missing.is_empty(), "every event ID exists in the catalog %s" % [missing])
	room.queue_free()
	await tick()
	await create_timer(0.2).timeout


func _level2() -> void:
	room = load(MaintRules.DESTINATION).instantiate()
	room.pause_when_unfocused = false
	root.add_child(room)
	current_scene = room
	await tick()
	await tick()
	var sound: Node = room.sound
	check(room.audio.ambient_controller.get_current_ambience_id() == &"maint_bed_past", "industrial bed replaces the laboratory room tone")
	var base: Dictionary = room.state.duplicate(true)
	var next := base.duplicate(true)
	next.service_isolated = true
	sound.on_state(base, next)
	var charged := next.duplicate(true)
	charged.battery_ready = true
	sound.on_state(next, charged)
	var routed := charged.duplicate(true)
	routed.priority = "past"
	routed.bypass_past = true
	routed.archive_read = true
	routed.recording = "preserved"
	routed.core_authorized = true
	routed.future_release_open = true
	routed.anchor_past = true
	sound.on_state(charged, routed)
	for id in [&"maint_lever_clunk", &"maint_crank", &"maint_reserve_lever", &"maint_fuse_seat", &"maint_archive", &"maint_recorder_export", &"maint_keypad_authorize", &"maint_release_wheel", &"maint_anchor_latch"]:
		check(id in sound.events, "Level 2 confirmed cue: " + String(id))
	var missing: Array[StringName] = []
	for id: StringName in sound.events:
		if not room.audio.has_sound(id):
			missing.append(id)
	check(missing.is_empty(), "Level 2 event IDs exist in the catalog %s" % [missing])
	check(sound.owns_action("charge_battery") and not sound.owns_action("pickup_storage_item"), "generic click only for unmapped actions")
	room.queue_free()
	await tick()
	await create_timer(0.2).timeout
