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
	await capture("past-future-student-3d-front.png")
	var visual: Node3D = player.get_node("Visual")
	check(visual.find_children("*", "Sprite3D", true, false).is_empty(), "3D student must use solid meshes instead of sprite cards")
	check(visual.find_children("*", "MeshInstance3D", true, false).size() > 15, "3D student must have solid body, face, clothing, and limbs")
	var left_leg: Node3D = visual.get_node("StudentModel/LeftLeg")
	var right_leg: Node3D = visual.get_node("StudentModel/RightLeg")
	var left_knee: Node3D = left_leg.get_node("LeftKnee")
	var right_knee: Node3D = right_leg.get_node("RightKnee")
	for facing in [{"action": "move_right", "yaw": PI / 2.0}, {"action": "move_left", "yaw": -PI / 2.0}, {"action": "move_up", "yaw": PI}, {"action": "move_down", "yaw": 0.0}]:
		Input.action_press(facing.action)
		await tick(18)
		check(absf(angle_difference(visual.rotation.y, facing.yaw)) < 0.01, "Moving must turn the 3D student toward travel")
		check(absf(left_leg.rotation.x) > 0.005 and is_zero_approx(left_leg.rotation.x + right_leg.rotation.x), "Walking must swing the two legs in opposite phases")
		check(maxf(left_knee.rotation.x, right_knee.rotation.x) > 0.005, "Walking must bend a knee to lift the swinging foot")
		await capture("past-future-student-3d-" + facing.action + ".png")
		Input.action_release(facing.action)
		await tick(15)
		check(absf(angle_difference(visual.rotation.y, facing.yaw)) < 0.01, "Idle must retain the last facing direction")
		check(is_zero_approx(left_knee.rotation.x) and is_zero_approx(right_knee.rotation.x), "Knees must straighten when the character stops")
		check(absf(visual.position.y) < 0.001 and is_zero_approx(left_leg.rotation.x) and is_zero_approx(right_leg.rotation.x), "Limbs and walking bounce must settle when movement stops")
	area.respawn()
	Input.action_press("move_right")
	await tick(12)
	check(player.position.x > spawn.x + 0.7, "Movement should move the student across the ground")
	Input.action_press("move_up")
	await tick()
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
	await tick(30)
	Input.action_release("move_up")
	await tick()
	check(player.position.z >= 1.24 and player.position.z <= 1.36, "Furniture footprint must block an approach from the front")
	player.position = Vector3(-8, 0, -0.4)
	Input.action_press("move_right")
	await tick(45)
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
	var jacket: MeshInstance3D = visual.get_node("StudentModel/Jacket")
	var past_jacket: Color = jacket.material_override.get_shader_parameter("paint_color")
	var past_color: Color = player.body_color
	area.get_node("%TimelineButton").pressed.emit()
	check(area.timeline == "Future" and player.body_color != past_color, "Preview toggle must switch timeline and character appearance")
	await tick()
	check(jacket.material_override.get_shader_parameter("paint_color") != past_jacket, "Timeline switching must recolor the 3D jacket")
	check(left_top.material_override.get_shader_parameter("paint_color") != past_paint, "Future timeline must recolor the solid furniture")
	area.get_node("Actors/LeftTable").future = false
	check(left_top.material_override.get_shader_parameter("paint_color") == past_paint, "Furniture must restore its past paint")
	check(right_top.material_override.get_shader_parameter("paint_color") != past_paint, "Recoloring one furniture instance must not affect another")
	area.get_node("Actors/LeftTable").future = true
	await capture("past-future-student-3d-future.png")
	area.get_node("%TimelineButton").pressed.emit()
	var camera_basis := camera.global_basis
	var camera_position := camera.global_position
	for key in [KEY_Q, KEY_E, KEY_P]:
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
	await tick(8)
	send_key(KEY_W, false)
	await tick()
	check(area.player.position.z < start_position.z - 0.4, "Physical W key must move along the ground")
	send_key(KEY_R, true)
	await tick()
	send_key(KEY_R, false)
	check(area.player.position.distance_to(area.get_node("SpawnPoint").position) < 0.04, "Physical R key must respawn the student")
	print("SPAWN AREA: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
