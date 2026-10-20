extends Control
## Review every illustrated animation and facing without leaving the live session.

signal close_requested

const RIG: PackedScene = preload("res://scenes/characters/student_paper_rig.tscn")
const RIG_SCRIPT: Script = preload("res://scripts/characters/student_paper_rig.gd")
var _rig: Node2D
var _preview: PanelContainer
var _status: Label
var _selected_clip: String = "idle"
var _selected_direction: String = "south"
var _clip_buttons: Dictionary = {}
var _view_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101b24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_label(heading, "THE STUDENT  /  AGE 18", 30, Color("e4bf7f"))
	_label(heading, "Character studio  ·  8 directions  ·  13 articulated 2D animations", 17, Color("a6b9bd"))
	var close_button := _button("RETURN TO LAB  /  ESC", request_close)
	header.add_child(close_button)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	layout.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	left.add_theme_constant_override("separation", 7)
	row.add_child(left)
	_label(left, "ANIMATIONS", 16, Color("e4bf7f"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var animation_list := VBoxContainer.new()
	animation_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animation_list.add_theme_constant_override("separation", 6)
	scroll.add_child(animation_list)
	for clip in RIG_SCRIPT.CLIPS:
		var button := _button(RIG_SCRIPT.CLIPS[clip].label, _select_clip.bind(clip))
		animation_list.add_child(button)
		_clip_buttons[clip] = button
	_preview = PanelContainer.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2b35")
	style.border_color = Color("3c535c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	_preview.add_theme_stylebox_override("panel", style)
	row.add_child(_preview)
	_rig = RIG.instantiate()
	_preview.add_child(_rig)
	_rig.animation_finished.connect(func(_clip: String) -> void: _rig.play(_selected_clip, true))
	_preview.resized.connect(_resize_preview)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 270
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	_label(right, "FACING DIRECTION", 16, Color("e4bf7f"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	for direction in RIG_SCRIPT.DIRECTIONS:
		var button := _button(direction.replace("_", " ").capitalize(), _select_view.bind(direction))
		button.custom_minimum_size.x = 130
		grid.add_child(button)
		_view_buttons[direction] = button
	_status = _label(right, "", 17, Color("bdcdd0"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pause := CheckButton.new()
	pause.text = "Pause preview"
	pause.toggled.connect(func(value: bool) -> void: _rig.paused = value)
	right.add_child(pause)
	_label(right, "Playback speed", 16, Color("a6b9bd"))
	var speed := HSlider.new()
	speed.min_value = 0.25
	speed.max_value = 2.0
	speed.step = 0.25
	speed.value = 1.0
	speed.value_changed.connect(func(value: float) -> void: _rig.playback_speed = value)
	right.add_child(speed)
	var info := _label(right, "Gameplay controls\n\nWASD / arrows: move\nShift: run\nF: interact animation\nI: inspect / read\nE: pick up / put down\nF2: character studio", 16, Color("a6b9bd"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_select_clip("idle")
	_select_view("south")
	_resize_preview.call_deferred()


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
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button


func _select_clip(clip: String) -> void:
	_selected_clip = clip
	_rig.holding_object = clip.begins_with("carry")
	_rig.play(clip, true)
	for key in _clip_buttons:
		_clip_buttons[key].modulate = Color("e4bf7f") if key == clip else Color.WHITE
	_update_status()


func _select_view(direction: String) -> void:
	_selected_direction = direction
	_rig.set_view(direction)
	for key in _view_buttons:
		_view_buttons[key].modulate = Color("89ccd4") if key == direction else Color.WHITE
	_update_status()


func _update_status() -> void:
	if is_instance_valid(_status):
		_status.text = "%s\n%s\n\n%.2f seconds / cycle" % [RIG_SCRIPT.CLIPS[_selected_clip].label, _selected_direction.replace("_", " ").capitalize(), RIG_SCRIPT.CLIPS[_selected_clip].duration]


func _resize_preview() -> void:
	if is_instance_valid(_rig):
		var scale_factor := minf((_preview.size.y - 60.0) / 550.0, (_preview.size.x - 40.0) / 300.0)
		_rig.scale = Vector2.ONE * maxf(scale_factor, 0.1)
		_rig.position = Vector2(_preview.size.x * 0.5, _preview.size.y - 24.0)


func request_close() -> void:
	close_requested.emit()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
	else:
		queue_free()
