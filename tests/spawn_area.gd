extends SceneTree
## Run: godot --headless --path . --script res://tests/spawn_area.gd
## Omit --headless and append -- --capture to save rendered previews in /tmp.

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func tick(count: int = 3) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func capture(filename: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/" + filename)


func send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _run() -> void:
	var area = load("res://scenes/world/spawn_area.tscn").instantiate()
	area.pause_when_unfocused = false
	root.add_child(area)
	current_scene = area
	await create_timer(0.4).timeout
	await tick()
	area._set_paused(false)
	var player: CharacterBody3D = area.player
	var spawn: Vector3 = area.get_node("SpawnPoint").global_position
	check(player.global_position.distance_to(spawn) < 0.04, "Player must appear on the ground at the spawn marker")
	check(area.timeline == "Past", "Direct scene run should preview Past")
	var camera: Camera3D = area.camera
	var near_point := camera.global_position - camera.global_basis.z * 10.0
	var far_point := camera.global_position - camera.global_basis.z * 25.0
	var near_span := camera.unproject_position(near_point + camera.global_basis.x).distance_to(camera.unproject_position(near_point))
	var far_span := camera.unproject_position(far_point + camera.global_basis.x).distance_to(camera.unproject_position(far_point))
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE and near_span > far_span * 2.0, "Perspective view must make distant objects appear smaller")
	await capture("past-future-student-3d-lab-past.png")
	var visual: Node3D = player.get_node("Visual")
	var animator: AnimationPlayer = player.animator
	check(player.skeleton.get_bone_count() == 23 and player.skinned_mesh.skin != null, "Student must use the real KayKit skeleton and a skinned original mesh")
	for facing in [{"action": "move_right", "yaw": PI/2}, {"action": "move_left", "yaw": -PI/2}, {"action": "move_up", "yaw": PI}, {"action": "move_down", "yaw": 0.0}]:
		Input.action_press(facing.action)
		await tick(20)
		check(absf(angle_difference(visual.rotation.y, facing.yaw)) < 0.1 and player.animation_name == "Walking_A", "Movement must turn the 3D student toward travel and play KayKit walking")
		Input.action_release(facing.action)
		await tick(8)
		check(absf(angle_difference(visual.rotation.y, facing.yaw)) < 0.1 and player.animation_name == "Idle_A", "Idle must retain the last 3D facing")
	area.respawn()
	Input.action_press("move_right")
	await tick(12)
	Input.action_press("move_up")
	await tick(1)
	check(player.velocity.x > absf(player.velocity.z) and player.velocity.z < 0.0, "Changing direction must steer through intermediate movement angles")
	Input.action_release("move_right")
	await tick(12)
	Input.action_release("move_up")
	await tick(1)
	check(Vector2(player.velocity.x, player.velocity.z).length() > 0.0 and Vector2(player.velocity.x, player.velocity.z).length() < player.speed, "Releasing input must brake smoothly")
	await tick(12)
	check(Vector2(player.velocity.x, player.velocity.z).is_zero_approx(), "Braking must come to a complete stop")
	Input.action_press("move_right", 0.35)
	Input.action_press("move_up", 1.0)
	await tick(20)
	var analog_heading := Vector3(0.35, 0.0, -1.0).normalized()
	check(Vector3(player.velocity.x, 0.0, player.velocity.z).normalized().is_equal_approx(analog_heading), "Analog steering must retain angles between the eight keyboard headings")
	check(absf(angle_difference(visual.rotation.y, atan2(analog_heading.x, analog_heading.z))) < 0.1, "The model must face the continuous movement heading")
	Input.action_release("move_right")
	Input.action_release("move_up")
	await tick(12)
	area.respawn()
	send_key(KEY_SHIFT, true)
	Input.action_press("move_right")
	await tick(16)
	check(Vector2(player.velocity.x, player.velocity.z).length() > player.speed * 1.4 and player.animation_name == "Running_A", "Shift must activate running and the KayKit run animation")
	send_key(KEY_SHIFT, false)
	Input.action_release("move_right")
	await tick()
	check(player.play_action("pick_up"), "Player must be able to start the pickup animation")
	var action_position := player.position
	Input.action_press("move_right")
	await tick(8)
	check(player.position.distance_to(action_position) < 0.03, "Pickup animation must keep the player grounded in place")
	Input.action_release("move_right")
	await create_timer(animator.get_animation("PickUp").length + 0.15).timeout
	check(player.carrying, "Finishing pickup must select the carrying pose")
	check(player.play_action("put_down"), "Carried object must have a put-down animation")
	await create_timer(animator.get_animation("PickUp").length + 0.15).timeout
	check(not player.carrying, "Finishing put-down must return to normal locomotion")
	area._open_character_studio()
	await tick()
	check(is_instance_valid(area._character_studio) and not player.controls_enabled, "Character studio must open without leaving the level and block movement")
	var studio = area._character_studio
	check(studio.animator.get_animation_list().size() == 77, "Studio must expose all 77 KayKit clips")
	studio.select_clip("Running_A")
	await tick(5)
	check(studio.animator.current_animation == "Running_A" and studio.animator.current_animation_position > 0.0, "Selecting a studio clip must play its real animation")
	studio.set_angle(PI / 2)
	check(is_equal_approx(studio.model.rotation.y, PI / 2), "Studio views must rotate the character independently of the gameplay camera")
	check(player.animator.get_animation("PickUp").loop_mode == Animation.LOOP_NONE, "Preview looping must not change gameplay action clips")
	area._character_studio.request_close()
	await tick()
	check(player.controls_enabled and not is_instance_valid(area._character_studio), "Closing the studio must restore gameplay")
	area.respawn()
	Input.action_press("move_right")
	await tick(16)
	check(player.position.x > spawn.x + player.speed * 0.15, "Movement should move the student across the ground")
	Input.action_press("move_up")
	await tick(8)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.speed), "Diagonal movement must retain normal speed")
	Input.action_release("move_up")
	Input.action_release("move_right")
	await tick()
	player.position = Vector3(11.4, 0, 4.8)
	Input.action_press("move_right")
	await tick(30)
	Input.action_release("move_right")
	await tick()
	check(player.position.x <= 12.15 and player.position.x >= 11.9, "Room wall must stop the player")
	player.position = Vector3(-5.4, 0, -1.4)
	Input.action_press("move_down")
	await tick(30)
	Input.action_release("move_down")
	await tick()
	check(player.position.z <= 0.03 and player.position.z >= -0.15, "Furniture footprint must block an approach from behind")
	player.position = Vector3(-5.4, 0, 2.8)
	Input.action_press("move_up")
	await tick(40)
	Input.action_release("move_up")
	await tick()
	check(player.position.z >= 1.24 and player.position.z <= 1.36, "Furniture footprint must block an approach from the front")
	player.position = Vector3(-8, 0, -0.4)
	Input.action_press("move_right")
	await tick(75)
	Input.action_release("move_right")
	await tick()
	check(player.position.x > -4.8, "Player must be able to pass behind a prop's ground footprint")
	area._set_paused(true)
	var paused_position := player.position
	Input.action_press("move_right")
	await tick(8)
	Input.action_release("move_right")
	check(player.position.distance_to(paused_position) < 0.04, "Pause must stop movement")
	area._set_paused(false)
	area.get_node("SpawnPoint").position = Vector3(1.8, 0, 4.6)
	area.respawn()
	check(player.position.distance_to(Vector3(1.8, 0, 4.6)) < 0.01, "Respawn must honor an edited 3D spawn marker")
	area.get_node("SpawnPoint").position = spawn
	area.respawn()
	for prop_name in ["LeftTable", "RightTable", "LeftCabinet", "RightCabinet", "Console"]:
		var prop: Node3D = area.get_node("Actors/" + prop_name)
		check(prop.get_node("Visual").find_children("*", "MeshInstance3D", true, false).size() >= 8, "Each furniture model must have solid 3D parts")
		check(prop.get_node("Visual").find_children("*", "Sprite3D", true, false).is_empty(), "Furniture must use meshes instead of sprite cards")
	var left_top: MeshInstance3D = area.get_node("Actors/LeftTable/Visual/Table/Top")
	var right_top: MeshInstance3D = area.get_node("Actors/RightTable/Visual/Table/Top")
	var past_paint: Color = left_top.material_override.get_shader_parameter("paint_color")
	var past_tint: Color = player._materials.jacket.material.albedo_color
	var past_color: Color = player.body_color
	area.get_node("%TimelineButton").pressed.emit()
	player = area.player
	check(area.timeline == "Future" and player.body_color != past_color, "Preview toggle must switch timeline and character appearance")
	check(player.scene_file_path == "res://scenes/characters/professor_3d_player.tscn", "Future gameplay must use the finished Professor character")
	await tick()
	check(player._materials.jacket.material.albedo_color != past_tint, "Timeline switching must tint the 3D jacket")
	check(left_top.material_override.get_shader_parameter("paint_color") != past_paint, "Future timeline must recolor the solid furniture")
	area.get_node("Actors/LeftTable").future = false
	check(left_top.material_override.get_shader_parameter("paint_color") == past_paint, "Furniture must restore its past paint")
	check(right_top.material_override.get_shader_parameter("paint_color") != past_paint, "Recoloring one furniture instance must not affect another")
	area.get_node("Actors/LeftTable").future = true
	await capture("past-future-student-3d-lab-future.png")
	area.get_node("%TimelineButton").pressed.emit()
	player = area.player
	var camera_basis := camera.global_basis
	var camera_position := camera.global_position
	for key in [KEY_Q, KEY_P]:
		send_key(key, true)
		send_key(key, false)
		await create_timer(0.35).timeout
		check(camera.global_basis.is_equal_approx(camera_basis), "Former camera shortcuts must preserve the viewing angle")
		check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Former camera shortcuts must preserve perspective projection")
	Input.action_press("move_right")
	await tick(15)
	Input.action_release("move_right")
	await tick(20)
	check(camera.global_position.x > camera_position.x + 0.5, "Fixed-angle camera must still follow the moving player")
	check(camera.global_basis.is_equal_approx(camera_basis), "Following the player must preserve the viewing angle")
	area.respawn()
	area._return_to_menu()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", "Return to menu must load the title screen")
	current_scene.get_node("%PlayButton").pressed.emit()
	current_scene.get_node("%PreviewButton").pressed.emit()
	await tick()
	area = current_scene
	area.pause_when_unfocused = false
	area._set_paused(false)
	check(area is Node3D, "Menu preview must enter the 3D world")
	var start_position: Vector3 = area.player.position
	send_key(KEY_W, true)
	await tick(12)
	send_key(KEY_W, false)
	await tick()
	check(area.player.position.z < start_position.z - area.player.speed * 0.09, "Physical W key must move along the ground")
	send_key(KEY_R, true)
	await tick()
	send_key(KEY_R, false)
	check(area.player.position.distance_to(area.get_node("SpawnPoint").position) < 0.04, "Physical R key must respawn the student")
	area._return_to_menu()
	await scene_changed
	await create_timer(0.15).timeout
	print("SPAWN AREA: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
