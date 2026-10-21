class_name InteractionPrompt
extends CanvasLayer
## Contextual on-screen prompt displaying available 3D interactions.
##
## Adjusts palette dynamically between Past (#E4BF7F) and Future (#86C9D1)
## with smooth tweened transitions.

const COLOR_PAST := Color("#e4bf7f")
const COLOR_FUTURE := Color("#86c9d1")
const COLOR_NEUTRAL := Color("#ffffff")
const InputManager := preload("res://scripts/input/input_manager.gd")

@onready var root_control: Control = $Root
@onready var panel: PanelContainer = $Root/PromptPanel
@onready var key_badge: PanelContainer = $Root/PromptPanel/Margin/HBox/KeyBadge
@onready var key_label: Label = $Root/PromptPanel/Margin/HBox/KeyBadge/KeyLabel
@onready var action_label: Label = $Root/PromptPanel/Margin/HBox/Text/ActionLabel
@onready var caption_label: Label = $Root/PromptPanel/Margin/HBox/Text/Caption

var _current_tween: Tween = null
var _is_visible: bool = false
var _is_blocked: bool = false
var _current_timeline: String = ""
var _target: Node3D
var _has_target := false


func _ready() -> void:
	layer = 10
	root_control.modulate.a = 0.0
	root_control.visible = false
	_apply_timeline_style("past")
	process_priority = 90
	_update_key_badge()
	InputManager.get_instance().device_changed_signal.connect(_on_device_changed)


func _on_device_changed(_device_type: int, _controller_type: int) -> void:
	_update_key_badge()


func _update_key_badge() -> void:
	if not is_instance_valid(key_label):
		return
	var label: String = InputManager.get_action_label(&"interact")
	key_label.text = label


func _process(_delta: float) -> void:
	if not root_control.visible: return
	_position_prompt()


func set_target(target: Node3D) -> void:
	_target = target
	_has_target = is_instance_valid(target)


func _position_prompt() -> void:
	var screen := get_viewport().get_visible_rect().size
	var point := screen * 0.5
	if is_instance_valid(_target):
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			panel.hide()
			return
		var world_point: Vector3 = _target.get_prompt_position() if _target.has_method("get_prompt_position") else _target.global_position
		if camera.is_position_behind(world_point):
			panel.hide()
			return
		point = camera.unproject_position(world_point)
	elif _has_target:
		hide_prompt()
		panel.hide()
		return
	panel.visible = Rect2(Vector2.ZERO, screen).has_point(point)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = panel.get_combined_minimum_size()
	panel.position = point - panel.size * 0.5
	panel.position.x = clampf(panel.position.x, 12.0, maxf(12.0, screen.x - panel.size.x - 12.0))
	panel.position.y = clampf(panel.position.y, 12.0, maxf(12.0, screen.y - panel.size.y - 12.0))


func _apply_timeline_style(timeline: String) -> void:
	_current_timeline = timeline
	var accent_color := COLOR_PAST
	if timeline.to_lower() == "future":
		accent_color = COLOR_FUTURE
	
	# Apply style to key badge
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.8)
	badge_style.border_color = accent_color
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(10)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	key_badge.add_theme_stylebox_override("panel", badge_style)
	key_label.add_theme_color_override("font_color", Color("14252b"))
	caption_label.add_theme_color_override("font_color", accent_color)

	# Apply style to main panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.065, 0.08, 0.65)
	panel_style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.2)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", panel_style)


## Displays the contextual prompt with the given text and timeline tint.
func show_prompt(text: String, timeline: String = "") -> void:
	if _is_blocked or text.is_empty():
		return

	if not timeline.is_empty() and timeline.to_lower() != _current_timeline.to_lower():
		_apply_timeline_style(timeline)

	action_label.text = text
	action_label.custom_minimum_size.x = minf(220.0, action_label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	_position_prompt()

	if _is_visible and root_control.visible and root_control.modulate.a >= 0.99:
		return

	_is_visible = true
	root_control.visible = true

	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(root_control, "modulate:a", 1.0, 0.14)


## Hides the interaction prompt with a smooth fade-out.
func hide_prompt() -> void:
	if not _is_visible:
		return

	_is_visible = false

	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(root_control, "modulate:a", 0.0, 0.1)
	_current_tween.tween_callback(func():
		if not _is_visible:
			root_control.visible = false
	)


## Updates the prompt action text immediately or while active.
func set_prompt_text(text: String) -> void:
	action_label.text = text


## Sets whether modal UIs or pause state block prompt presentation.
func set_interaction_blocked(blocked: bool) -> void:
	_is_blocked = blocked
	if blocked:
		if _current_tween != null: _current_tween.kill()
		_current_tween = null
		_is_visible = false
		root_control.modulate.a = 0.0
		root_control.hide()


## Convenience method matching prompt interface requirements.
func set_interaction_available(available: bool) -> void:
	if not available:
		hide_prompt()
