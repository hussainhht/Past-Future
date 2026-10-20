extends SceneTree
## Render the original mesh with actual imported KayKit animation tracks.
## godot --path . --script res://tools/preview_student_3d.gd

const MODEL := "res://assets/characters/student_3d/student.glb"
var models: Array[Node3D] = []

func _initialize() -> void:
	_render.call_deferred()

func pose(model: Node3D, clip: String, at: float = 0.1) -> void:
	var animator: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	animator.play(clip)
	animator.advance(at)
	animator.pause()

func capture(path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var error := root.get_texture().get_image().save_png(path)
	assert(error == OK)

func _render() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202f3b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d7e8ff")
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	stage.add_child(key)
	key.rotation_degrees = Vector3(-40, -32, 0)
	key.light_color = Color("fff0dc")
	key.light_energy = 1.15
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.position = Vector3(0, 2.6, 8)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.current = true
	for i in range(3):
		var model: Node3D = load(MODEL).instantiate()
		stage.add_child(model)
		model.position.x = (i - 1) * 1.75
		model.rotation.y = [0.0, -0.7, PI - 0.4][i]
		pose(model, "Idle_A", 0.1)
		models.append(model)
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var title := Label.new()
	canvas.add_child(title)
	title.text = "THE STUDENT  /  ORIGINAL 3D MESH  /  KAYKIT ANIMATIONS"
	title.position = Vector2(32, 20)
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("e4bf7f")
	await create_timer(0.4).timeout
	await capture("res://assets/characters/student_3d/preview.png")
	models[0].hide()
	models[2].hide()
	models[1].position.x = 0
	for view in [["front",0.0], ["three_quarter",-.65], ["side",-PI/2], ["back",PI]]:
		models[1].rotation.y = view[1]
		pose(models[1], "Idle_A", 0.1)
		title.text = "THE STUDENT  /  " + str(view[0]).to_upper()
		await capture("/tmp/past-future-student-3d-" + view[0] + ".png")
	models[1].rotation.y = -0.6
	for clip in ["Walking_A", "Running_A", "Interact", "PickUp", "Crouching", "Waving", "Working_A", "Holding_A"]:
		pose(models[1], clip, 0.35)
		title.text = "THE STUDENT  /  KAYKIT: " + clip
		await capture("/tmp/past-future-student-3d-" + clip + ".png")
	stage.queue_free()
	canvas.queue_free()
	await process_frame
	var lab = load("res://scenes/world/spawn_area.tscn").instantiate()
	lab.pause_when_unfocused = false
	root.add_child(lab)
	current_scene = lab
	lab._set_paused(false)
	await create_timer(0.4).timeout
	await capture("res://assets/characters/student_3d/lab_preview.png")
	lab._open_character_studio()
	await create_timer(0.4).timeout
	await capture("res://assets/characters/student_3d/studio_preview.png")
	print("STUDENT 3D PREVIEW: PASS")
	quit()
