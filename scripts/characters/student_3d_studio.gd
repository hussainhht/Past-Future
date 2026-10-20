extends Control
## Inspect the custom mesh and the genuine KayKit animation library in-game.

signal close_requested

const MODEL: PackedScene = preload("res://assets/characters/student_3d/student.glb")
var model: Node3D
var animator: AnimationPlayer
var _status: Label
var _selected_clip: String = "Idle_A"
var _clip_buttons: Dictionary = {}
var _paused: bool = false
var _timeline: HSlider

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101b24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_label(heading, "THE STUDENT  /  AGE 18", 29, Color("e4bf7f"))
	_label(heading, "Original 3D character  ·  KayKit character animations", 17, Color("a6b9bd"))
	header.add_child(_button("RETURN TO LAB  /  ESC", request_close))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	layout.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 245
	row.add_child(left)
	_label(left, "ANIMATIONS", 16, Color("e4bf7f"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var clips := VBoxContainer.new()
	clips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(clips)
	var container := SubViewportContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.stretch = true
	row.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 650)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202f3b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d7e8ff")
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-40, -32, 0)
	light.light_color = Color("fff0dc")
	light.light_energy = 1.15
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	camera.position = Vector3(0, 2.2, 6)
	camera.look_at(Vector3(0, 1.12, 0))
	camera.current = true
	model = MODEL.instantiate()
	stage.add_child(model)
	model.rotation.y = -0.6
	animator = model.get_node("AnimationPlayer")
	var library: AnimationLibrary = animator.get_animation_library("").duplicate(true)
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	for clip in library.get_animation_list():
		library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var featured: Array[String] = ["Idle_A", "Walking_A", "Running_A", "Interact", "PickUp", "Use_Item", "Holding_A", "Crouching", "Waving", "Working_A"]
	for clip in library.get_animation_list():
		if clip not in featured:
			featured.append(clip)
	for clip in featured:
		var button := _button(clip.replace("_", " "), select_clip.bind(clip))
		clips.add_child(button)
		_clip_buttons[clip] = button
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 220
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	_label(right, "VIEW", 16, Color("e4bf7f"))
	for view in [["Front", 0.0], ["Three-quarter", -.6], ["Side", -PI/2], ["Back", PI]]:
		right.add_child(_button(view[0], set_angle.bind(view[1])))
	_label(right, "Rotate character", 16, Color("a6b9bd"))
	var rotation_slider := HSlider.new()
	rotation_slider.min_value = -180
	rotation_slider.max_value = 180
	rotation_slider.value = -34.4
	rotation_slider.value_changed.connect(func(value: float) -> void: set_angle(deg_to_rad(value)))
	right.add_child(rotation_slider)
	_status = _label(right, "", 17, Color("bdcdd0"))
	var pause := CheckButton.new()
	pause.text = "Pause animation"
	pause.toggled.connect(func(value: bool) -> void:
		_paused = value
		animator.active = not value
	)
	right.add_child(pause)
	_label(right, "Playback speed", 16, Color("a6b9bd"))
	var speed := HSlider.new()
	speed.min_value = 0.25
	speed.max_value = 2.0
	speed.step = 0.25
	speed.value = 1.0
	speed.value_changed.connect(func(value: float) -> void: animator.speed_scale = value)
	right.add_child(speed)
	_label(right, "Pose / timeline", 16, Color("a6b9bd"))
	_timeline = HSlider.new()
	_timeline.min_value = 0
	_timeline.max_value = 1
	_timeline.step = 0.001
	_timeline.value_changed.connect(func(value: float) -> void:
		if _paused:
			animator.seek(value * animator.current_animation_length, true)
	)
	right.add_child(_timeline)
	select_clip("Idle_A")

func select_clip(clip: String) -> void:
	_selected_clip = clip
	animator.play(clip, 0.0)
	animator.advance(0.0)
	for key in _clip_buttons:
		_clip_buttons[key].modulate = Color("e4bf7f") if key == clip else Color.WHITE
	if is_instance_valid(_status):
		_status.text = "%s\n%.2f seconds" % [clip.replace("_", " "), animator.get_animation(clip).length]

func set_angle(angle: float) -> void:
	model.rotation.y = angle

func _label(parent: Node, content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 38
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func request_close() -> void:
	close_requested.emit()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
	else:
		queue_free()
