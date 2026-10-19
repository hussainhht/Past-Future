extends SceneTree
## Render a front, three-quarter and back model sheet without entering gameplay.
## godot --path . --script res://tools/preview_student.gd

func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17202b")
	stage.add_child(environment)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.position = Vector3(0, 3.2, 8)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.current = true
	for i in range(3):
		var player = load("res://scenes/characters/student_player.tscn").instantiate()
		stage.add_child(player)
		player.set_physics_process(false)
		player.position.x = (i - 1) * 2.25
		player.get_node("Visual").rotation.y = [0.0, -0.75, PI][i]
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var title := Label.new()
	title.text = "PAST & FUTURE  /  THE STUDENT"
	title.position = Vector2(48, 32)
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color("e4bf7f")
	canvas.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Original mesh  ·  front / three-quarter / back"
	subtitle.position = Vector2(48, 72)
	subtitle.add_theme_font_size_override("font_size", 17)
	canvas.add_child(subtitle)
	await create_timer(0.5).timeout
	RenderingServer.force_draw()
	var path := "res://assets/characters/student_v2_preview.png"
	var error := root.get_texture().get_image().save_png(path)
	print("STUDENT PREVIEW: ", "PASS" if error == OK else "FAIL", " — ", path)
	quit(0 if error == OK else 1)
