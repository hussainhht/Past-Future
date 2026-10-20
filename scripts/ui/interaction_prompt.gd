class_name InteractionPrompt
extends CanvasLayer
## Contextual on-screen prompt displaying available 3D interactions.
##
## Adjusts palette dynamically between Past (#E4BF7F) and Future (#86C9D1)
## with smooth tweened transitions.

const COLOR_PAST := Color("#e4bf7f")
const COLOR_FUTURE := Color("#86c9d1")
const COLOR_NEUTRAL := Color("#ffffff")

@onready var root_control: Control = $Root
@onready var panel: PanelContainer = $Root/PromptPanel
@onready var key_badge: PanelContainer = $Root/PromptPanel/Margin/HBox/KeyBadge
@onready var key_label: Label = $Root/PromptPanel/Margin/HBox/KeyBadge/KeyLabel
@onready var action_label: Label = $Root/PromptPanel/Margin/HBox/ActionLabel

var _current_tween: Tween = null
var _is_visible: bool = false
var _is_blocked: bool = false
var _current_timeline: String = ""


func _ready() -> void:
	layer = 10
	root_control.modulate.a = 0.0
	root_control.visible = false
	_apply_timeline_style("past")


func _apply_timeline_style(timeline: String) -> void:
	_current_timeline = timeline
	var accent_color := COLOR_PAST
	if timeline.to_lower() == "future":
		accent_color = COLOR_FUTURE
	
	# Apply style to key badge
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.12, 0.15, 0.18, 0.95)
	badge_style.border_color = accent_color
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(4)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	key_badge.add_theme_stylebox_override("panel", badge_style)
	key_label.add_theme_color_override("font_color", accent_color)

	# Apply style to main panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.11, 0.88)
	panel_style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.35)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", panel_style)


## Displays the contextual prompt with the given text and timeline tint.
func show_prompt(text: String, timeline: String = "") -> void:
	if _is_blocked or text.is_empty():
		return

	if not timeline.is_empty() and timeline.to_lower() != _current_timeline.to_lower():
		_apply_timeline_style(timeline)

	action_label.text = text

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
	if not _is_visible and not root_control.visible:
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
		hide_prompt()


## Convenience method matching prompt interface requirements.
func set_interaction_available(available: bool) -> void:
	if not available:
		hide_prompt()

