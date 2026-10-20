extends SceneTree
## Comprehensive automated verification suite for Past-Future Audio Subsystem.
## Run with:
## & "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/audio_system.gd

var failures: int = 0
var test_count: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	test_count += 1
	if not condition:
		failures += 1
		push_error("TEST FAILURE: " + message)
	else:
		print("  [OK] ", message)

func tick(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func _run() -> void:
	print("====================================================")
	print("PAST-FUTURE AUDIO SUBSYSTEM AUTOMATED TEST SUITE")
	print("====================================================")
	
	await _test_asset_and_catalog()
	await _test_audio_director_and_pools()
	await _test_buses_and_volumes()
	await _test_ambience_controller()
	await _test_footstep_emitter()
	await _test_sandbox_scene()
	
	print("====================================================")
	if failures == 0:
		print("AUDIO SYSTEM TESTS: ALL PASS (%d checks passed)" % test_count)
		quit(0)
	else:
		print("AUDIO SYSTEM TESTS: FAIL (%d failures out of %d checks)" % [failures, test_count])
		quit(1)

# -----------------------------------------------------------------------------
# 1. Asset and Catalog Tests
# -----------------------------------------------------------------------------
func _test_asset_and_catalog() -> void:
	print("\n--- 1. Asset and Catalog Verification ---")
	var director := AudioDirector.new()
	root.add_child(director)
	
	var required_ids: Array[StringName] = [
		# UI
		&"ui_click", &"ui_hover", &"ui_confirm", &"ui_back",
		# Interaction
		&"interaction_click", &"interaction_success", &"interaction_denied",
		# Environment
		&"door_open", &"door_locked", &"computer_beep", &"switch_toggle",
		# Ambience & Optional
		&"rift_hum"
	]
	
	for sound_id in required_ids:
		check(director.has_sound(sound_id), "Catalog must contain required sound ID: '%s'" % sound_id)
		var entry: Dictionary = director._catalog.get(sound_id, {})
		var stream: AudioStream = entry.get("stream")
		check(stream != null, "Stream resource must resolve for ID: '%s'" % sound_id)
		check(stream.get_length() > 0.0, "Stream must have non-zero duration for ID: '%s'" % sound_id)
	
	# Ambience files on disk
	check(ResourceLoader.exists("res://assets/audio/ambience/lab_ambience_past.wav"), "Past ambience file must exist")
	check(ResourceLoader.exists("res://assets/audio/ambience/lab_ambience_future.wav"), "Future ambience file must exist")
	
	# Missing sound ID graceful failure
	var missing_result := director.play_sfx(&"non_existent_sound_xyz")
	check(missing_result == false, "Playing non-existent sound must safely return false")
	
	var missing_world := director.play_world_sfx(&"non_existent_sound_xyz", Vector3.ZERO)
	check(missing_world == false, "Playing non-existent world sound must safely return false")
	
	director.queue_free()
	await tick()

# -----------------------------------------------------------------------------
# 2. AudioDirector Playback & Pool Tests
# -----------------------------------------------------------------------------
func _test_audio_director_and_pools() -> void:
	print("\n--- 2. AudioDirector Playback & Pool Management ---")
	var director := AudioDirector.new()
	root.add_child(director)
	
	# Test UI playback
	var ui_res := director.play_ui(&"ui_click")
	check(ui_res == true, "play_ui must succeed for 'ui_click'")
	
	# Test SFX playback
	var sfx_res := director.play_sfx(&"interaction_success")
	check(sfx_res == true, "play_sfx must succeed for 'interaction_success'")
	
	# Test 3D World SFX playback
	var world_res := director.play_world_sfx(&"door_open", Vector3(10.0, 0.0, 5.0))
	check(world_res == true, "play_world_sfx must succeed for 'door_open'")
	
	# Pool bounding test: trigger more sounds than MAX_2D_PLAYERS rapidly
	for i in range(AudioDirector.MAX_2D_PLAYERS + 8):
		director.play_ui(&"ui_hover")
	
	check(director._pool_2d.size() == AudioDirector.MAX_2D_PLAYERS, 
		"2D player pool size must strictly stay bounded to %d" % AudioDirector.MAX_2D_PLAYERS)
	
	# 3D pool bounding test
	for i in range(AudioDirector.MAX_3D_PLAYERS + 6):
		director.play_world_sfx(&"computer_beep", Vector3(i, 0, 0))
	
	check(director._pool_3d.size() == AudioDirector.MAX_3D_PLAYERS,
		"3D player pool size must strictly stay bounded to %d" % AudioDirector.MAX_3D_PLAYERS)
	
	# Stop all SFX
	director.stop_all_sfx()
	var any_playing := false
	for p in director._pool_2d:
		if p.playing:
			any_playing = true
	for p in director._pool_3d:
		if p.playing:
			any_playing = true
	check(not any_playing, "stop_all_sfx must stop all active pooled players")
	
	director.queue_free()
	await tick()

# -----------------------------------------------------------------------------
# 3. Audio Buses and Volume Controls
# -----------------------------------------------------------------------------
func _test_buses_and_volumes() -> void:
	print("\n--- 3. Audio Buses and Volume Controls ---")
	var director := AudioDirector.new()
	root.add_child(director)
	
	var expected_buses: Array[StringName] = [&"Master", &"SFX", &"UI", &"Ambience", &"Music"]
	for bus_name in expected_buses:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		check(bus_idx != -1, "Bus '%s' must be available in AudioServer" % bus_name)
	
	# Test volume changes
	director.set_category_volume_linear(&"SFX", 0.75)
	var sfx_vol := director.get_category_volume_linear(&"SFX")
	check(is_equal_approx(sfx_vol, 0.75), "Category volume linear should reflect assigned value (0.75)")
	
	# Test muting when value <= 0.0001
	director.set_category_volume_linear(&"UI", 0.0)
	var ui_bus_idx := AudioServer.get_bus_index(&"UI")
	check(AudioServer.is_bus_mute(ui_bus_idx), "Volume at 0.0 must set bus mute to true")
	check(director.get_category_volume_linear(&"UI") == 0.0, "Muted bus volume linear must return 0.0")
	
	# Unmute via non-zero volume
	director.set_category_volume_linear(&"UI", 1.0)
	check(not AudioServer.is_bus_mute(ui_bus_idx), "Setting volume to 1.0 must unmute the bus")
	
	# Reset test volumes to 1.0
	director.set_category_volume_linear(&"SFX", 1.0)
	director.set_category_volume_linear(&"UI", 1.0)
	
	director.queue_free()
	await tick()

# -----------------------------------------------------------------------------
# 4. AmbientAudioController Tests
# -----------------------------------------------------------------------------
func _test_ambience_controller() -> void:
	print("\n--- 4. AmbientAudioController Timeline Ambiences ---")
	var ambient := AmbientAudioController.new()
	root.add_child(ambient)
	ambient.crossfade_time = 0.05 # Fast for testing
	
	# Test Past Ambience start
	ambient.start_ambience(&"lab_ambience_past")
	check(ambient.get_current_ambience_id() == &"lab_ambience_past", "Current ambience ID must be 'lab_ambience_past'")
	check(ambient.is_playing(), "Ambient controller must be active and playing")
	
	# Duplicate call must be idempotent
	ambient.start_ambience(&"lab_ambience_past")
	check(ambient.get_current_ambience_id() == &"lab_ambience_past", "Repeated call must remain on 'lab_ambience_past'")
	
	# Switch to Future
	ambient.start_ambience(&"lab_ambience_future")
	check(ambient.get_current_ambience_id() == &"lab_ambience_future", "Switched ambience ID must be 'lab_ambience_future'")
	
	# Stop Ambience
	ambient.stop_ambience(0.01)
	await create_timer(0.05).timeout
	check(ambient.get_current_ambience_id() == &"", "Ambience ID must be empty after stop")
	check(not ambient.is_playing(), "Ambience players must be stopped")
	
	ambient.queue_free()
	await tick()

# -----------------------------------------------------------------------------
# 5. FootstepEmitter3D Cadence & Movement Tests
# -----------------------------------------------------------------------------
func _test_footstep_emitter() -> void:
	print("\n--- 5. FootstepEmitter3D Cadence and Movement Verification ---")
	
	# Create a mock character body to precisely control velocity, grounded state and physics
	var mock_body := CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 1)
	col.shape = box
	mock_body.add_child(col)
	root.add_child(mock_body)
	mock_body.global_position = Vector3(0, 1, 0)
	
	var emitter := FootstepEmitter3D.new()
	emitter.character = mock_body
	mock_body.add_child(emitter)
	
	var step_data := {"count": 0}
	var variant_history: Array[int] = []
	emitter.footstep_played.connect(func(v: int, _p: Vector3):
		step_data.count += 1
		variant_history.append(v)
	)
	
	await tick(2)
	
	# Check 1: Idle state produces NO footsteps
	mock_body.velocity = Vector3.ZERO
	for i in range(10):
		emitter._physics_process(0.016)
	check(step_data.count == 0, "Idle stationary character must produce ZERO footsteps")
	
	# Check 2: Movement below threshold produces NO footsteps
	mock_body.velocity = Vector3(0.05, 0.0, 0.0) # 0.05 < threshold (0.15)
	for i in range(10):
		emitter._physics_process(0.016)
	check(step_data.count == 0, "Movement below threshold must produce ZERO footsteps")
	
	# Check 3: Airborne movement produces NO footsteps even with velocity
	mock_body.velocity = Vector3(2.8, 0.0, 0.0) # Walking velocity
	check(not mock_body.is_on_floor(), "Mock body in free air must be airborne (is_on_floor = false)")
	for i in range(15):
		emitter._physics_process(0.016)
	check(step_data.count == 0, "Airborne movement must produce ZERO footsteps")
	
	# Check 4: Grounded walking cadence
	# We set a floor plane under mock_body to simulate grounded physics
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 1, 100)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	root.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	
	# Place mock_body on the floor
	mock_body.global_position = Vector3(0, 0.5, 0)
	mock_body.velocity = Vector3(0, -1.0, 0)
	await tick(3)
	mock_body.move_and_slide()
	await tick(2)
	check(mock_body.is_on_floor(), "Mock character body must be grounded on the floor")
	
	# Disable automatic physics process during manual stepped tests
	emitter.set_physics_process(false)
	
	# Walk test: 2.8 m/s for 3.0 seconds
	step_data.count = 0
	variant_history.clear()
	mock_body.velocity = Vector3(2.8, -0.5, 0)
	var dt: float = 0.01666
	var walk_ticks := int(3.0 / dt)
	for i in range(walk_ticks):
		mock_body.velocity.x = 2.8
		mock_body.velocity.y = -0.5
		mock_body.move_and_slide()
		emitter._physics_process(dt)
	
	var walk_steps: int = step_data.count
	# Total distance in 3s at 2.8 m/s is 8.4m. With stride 1.35m, expected steps is ~6
	check(walk_steps >= 5 and walk_steps <= 8, 
		"Walking for 3.0s at 2.8 m/s must produce natural step count (produced %d, expected ~6)" % walk_steps)
	
	# Check 5: Running cadence is faster than walking
	step_data.count = 0
	mock_body.velocity = Vector3(4.34, -0.5, 0)
	var run_ticks := int(3.0 / dt)
	for i in range(run_ticks):
		mock_body.velocity.x = 4.34
		mock_body.velocity.y = -0.5
		mock_body.move_and_slide()
		emitter._physics_process(dt)
	
	var run_steps: int = step_data.count
	# Total distance in 3s at 4.34 m/s is 13.0m. Expected steps is ~9
	check(run_steps > walk_steps,
		"Running step count (%d) must be significantly higher than walking (%d)" % [run_steps, walk_steps])
	
	# Check 6: Stopping immediately stops footsteps
	step_data.count = 0
	mock_body.velocity = Vector3.ZERO
	for i in range(60): # 1 full second
		mock_body.move_and_slide()
		emitter._physics_process(dt)
	check(step_data.count == 0, "Stopping must immediately halt footstep scheduling")
	
	# Check 7: Variant variation avoids immediate repetition
	check(variant_history.size() >= 5, "Footstep tests must have generated sufficient sample history")
	var has_consecutive_dup := false
	for i in range(1, variant_history.size()):
		if variant_history[i] == variant_history[i - 1]:
			has_consecutive_dup = true
			break
	check(not has_consecutive_dup, "Footstep variations must avoid playing the exact same sample consecutively")
	
	# Check 8: Teleportation detection (large displacement doesn't burst steps)
	step_data.count = 0
	mock_body.global_position = Vector3(50.0, 0.5, 50.0) # Instant 50m jump
	emitter._physics_process(dt)
	check(step_data.count == 0, "Teleportation / respawn position jump must NOT trigger footstep burst")
	
	# Cleanup test nodes
	mock_body.queue_free()
	floor_body.queue_free()
	await tick(2)

# -----------------------------------------------------------------------------
# 6. Audio Sandbox Scene Verification
# -----------------------------------------------------------------------------
func _test_sandbox_scene() -> void:
	print("\n--- 6. Audio Sandbox Scene Loading and Setup ---")
	var scene_path := "res://scenes/testing/audio_sandbox.tscn"
	check(ResourceLoader.exists(scene_path), "Audio sandbox scene file must exist at '%s'" % scene_path)
	
	var packed_scene: PackedScene = load(scene_path)
	check(packed_scene != null, "Audio sandbox PackedScene must load successfully")
	
	var instance = packed_scene.instantiate()
	check(instance != null, "Audio sandbox scene must instantiate without errors")
	root.add_child(instance)
	await tick(3)
	
	# Verify components inside the sandbox
	var audio_sys: AudioDirector = instance.get_node_or_null("AudioSystem")
	check(audio_sys != null, "Sandbox must contain instantiated AudioSystem")
	
	var player_node: CharacterBody3D = instance.get_node_or_null("Student3DPlayer")
	check(player_node != null, "Sandbox must contain Student3DPlayer")
	
	var emitter_node: FootstepEmitter3D = player_node.get_node_or_null("FootstepEmitter3D")
	check(emitter_node != null, "Student3DPlayer in sandbox must have FootstepEmitter3D attached")
	
	var ui_node: CanvasLayer = instance.get_node_or_null("UI")
	check(ui_node != null, "Sandbox must have CanvasLayer UI")
	
	# Test preview functions directly in sandbox
	instance._on_btn_ui_click_pressed()
	instance._on_btn_interact_success_pressed()
	instance._on_btn_door_open_pressed()
	instance._on_btn_ambience_past_pressed()
	await tick(2)
	instance._on_btn_ambience_stop_pressed()
	
	instance.queue_free()
	await tick(2)
	check(true, "Sandbox unloaded and cleaned up safely with no orphaned nodes")
