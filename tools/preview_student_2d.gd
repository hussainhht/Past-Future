extends SceneTree
## Render the actual articulated 2D character from all eight directions.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var size := root.get_visible_rect().size
	var background := ColorRect.new()
	background.color = Color("13202a")
	background.size = size
	stage.add_child(background)
	var title := Label.new()
	title.text = "THE STUDENT  /  AGE 18  /  EIGHT DIRECTIONS"
	title.position = Vector2(32, 20)
	title.add_theme_font_size_override("font_size", 25)
	title.modulate = Color("e4bf7f")
	stage.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Illustrated from the supplied reference  ·  articulated 2D animation rig"
	subtitle.position = Vector2(32, 56)
	stage.add_child(subtitle)
	var scene: PackedScene = load("res://scenes/characters/student_paper_rig.tscn")
	var directions: Array[String] = ["south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east"]
	var rigs: Array[Node2D] = []
	var card_height: float = (size.y - 108.0) / 2.0
	for i in range(8):
		var rig = scene.instantiate()
		stage.add_child(rig)
		rig.set_process(false)
		rig.set_view(directions[i])
		rig.scale = Vector2.ONE * ((card_height - 42.0) / 525.0)
		rig.position = Vector2((i % 4 + 0.5) * size.x / 4.0, 106.0 + (i / 4 + 1) * card_height - 18.0)
		rigs.append(rig)
		var caption := Label.new()
		caption.text = directions[i].replace("_", " ").to_upper()
		caption.position = Vector2(i % 4 * size.x / 4.0 + 26.0, 92.0 + (i / 4) * card_height)
		caption.modulate = Color("90bec5")
		stage.add_child(caption)
	await create_timer(0.3).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://assets/characters/student_2d/directions_preview.png")
	for rig in rigs:
		rig.play("walk", true)
		rig.advance(0.2)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://assets/characters/student_2d/walk_preview.png")
	stage.queue_free()
	await process_frame
	var studio = load("res://scenes/characters/student_animation_studio.tscn").instantiate()
	root.add_child(studio)
	current_scene = studio
	await create_timer(0.3).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://assets/characters/student_2d/studio_preview.png")
	for direction in directions:
		studio._select_view(direction)
		studio._rig.set_process(false)
		studio._rig.play("idle", true)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/past-future-student-review-" + direction + ".png")
	for sample in [["south", "inspect"], ["east", "run"], ["south_west", "pick_up"], ["north_east", "interact"], ["west", "push"], ["north", "carry_walk"]]:
		studio._select_view(sample[0])
		studio._select_clip(sample[1])
		studio._rig.advance(float(studio._rig.CLIPS[sample[1]].duration) * 0.45)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/past-future-student-action-" + sample[1] + ".png")
	print("STUDENT 2D PREVIEW: PASS")
	quit()
