class_name LabUI
extends CanvasLayer
## Room-level screens for the Signal Laboratory: a document reader that works in both timelines,
## short toasts, and the banner. Everything is built in code and styled with the timeline accent.
## Opening a document blocks movement and interaction (modal_changed); Esc or F closes it before the
## pause menu sees the key. Puzzle 01's own screens (the calibration terminal and the Future research
## log) are the frequency puzzle's FrequencyTerminal and FrequencyLogReader, not part of this layer.

signal modal_changed(open: bool)

const PAST_ACCENT := Color("e4bf7f")
const FUTURE_ACCENT := Color("86c9d1")
const INK := Color("1d2b31")

var future: bool = false

var _root: Control
var _modal: Control
var _modal_kind: String = ""
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _banner: PanelContainer
var _banner_title: Label
var _banner_subtitle: Label
# A toast or banner raised while a screen is open waits for it to close (the screen already
# shows the same news in its own status line).
var _pending_toast: Array = []
var _pending_banner: Array = []


func _ready() -> void:
	add_to_group("lab_ui")
	layer = 20
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_toast()
	_build_banner()


func accent() -> Color:
	return FUTURE_ACCENT if future else PAST_ACCENT


func set_timeline(is_future: bool) -> void:
	if future != is_future:
		close_modal()
	future = is_future
	_restyle()


func is_modal_open() -> bool:
	return _modal != null


func modal_kind() -> String:
	return _modal_kind


# --- Toast and banner ----------------------------------------------------------------------

func toast(text: String, seconds: float = 3.6) -> void:
	if _modal != null:
		_pending_toast = [text, seconds]
		return
	_toast_label.text = text
	_restyle()
	if _toast_tween:
		_toast_tween.kill()
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


## The toast on screen, or the one waiting for the open screen to close.
func toast_text() -> String:
	if not _pending_toast.is_empty():
		return _pending_toast[0]
	return _toast_label.text if _toast.visible else ""


func banner(title: String, subtitle: String, seconds: float = 7.0) -> void:
	if _modal != null:
		_pending_banner = [title, subtitle, seconds]
		return
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_restyle()
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.6)
	tween.tween_interval(seconds)
	tween.tween_property(_banner, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void: _banner.visible = false)


## The banner on screen, or the one waiting for the open screen to close.
func banner_text() -> String:
	if not _pending_banner.is_empty():
		return _pending_banner[0]
	return _banner_title.text if _banner.visible else ""


## Timeline accent on the toast and banner (they can outlive a solo preview timeline switch).
func _restyle() -> void:
	if _toast == null:
		return
	_toast.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.08, 0.1, 0.92), accent(), 1))
	_toast_label.add_theme_color_override("font_color", accent().lightened(0.35))
	_banner_title.add_theme_color_override("font_color", accent().lightened(0.25))
	_banner.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.06, 0.08, 0.94), accent(), 2))


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -430
	_toast.offset_right = 430
	_toast.offset_top = -210
	_toast.offset_bottom = -112
	_toast.visible = false
	_toast_label = _label("", 22)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_child(_margin(_toast_label, 22, 12))
	_root.add_child(_toast)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.name = "Banner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -560
	_banner.offset_right = 560
	_banner.offset_top = 150
	_banner.offset_bottom = 300
	_banner.visible = false
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_title = _label("", 40)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle = _label("", 22)
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	box.add_child(_banner_title)
	box.add_child(_banner_subtitle)
	_banner.add_child(_margin(box, 30, 18))
	_root.add_child(_banner)


# --- Modals --------------------------------------------------------------------------------

func open_document(title: String, body: String, footer: String = "") -> void:
	var panel := _open_modal("document", Vector2(980, 640))
	var box: VBoxContainer = panel.get_meta("content")
	var heading := _label(title, 32)
	heading.add_theme_color_override("font_color", INK if not future else Color("d8e6e4"))
	box.add_child(heading)
	box.add_child(_rule())
	var text := _label(body, 22)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("font_color", Color("2b3434") if not future else Color("c6d4d2"))
	text.add_theme_constant_override("line_spacing", 6)
	box.add_child(text)
	box.add_child(_hint(footer if not footer.is_empty() else "ESC / F  ·  CLOSE"))
	panel.add_theme_stylebox_override("panel", _panel_style(Color("efe4c8") if not future else Color("1d3138"), accent(), 2))


func close_modal() -> void:
	if _modal == null:
		return
	_modal.queue_free()
	_modal = null
	_modal_kind = ""
	modal_changed.emit(false)
	var banner_args := _pending_banner
	var toast_args := _pending_toast
	_pending_banner = []
	_pending_toast = []
	if not banner_args.is_empty():
		banner(banner_args[0], banner_args[1], banner_args[2])
	if not toast_args.is_empty():
		toast(toast_args[0], toast_args[1])


func _open_modal(kind: String, size: Vector2) -> PanelContainer:
	close_modal()
	# A screen replaces whatever the world was saying.
	if _toast_tween:
		_toast_tween.kill()
	_toast.visible = false
	var dim := ColorRect.new()
	dim.name = "Modal_" + kind
	dim.color = Color(0.01, 0.02, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.08, 0.1, 0.97), accent(), 2))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(_margin(content, 44, 34))
	panel.set_meta("content", content)
	centre.add_child(panel)
	_root.add_child(dim)
	_modal = dim
	_modal_kind = kind
	modal_changed.emit(true)
	return panel


func _input(event: InputEvent) -> void:
	if _modal == null:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		close_modal()
		get_viewport().set_input_as_handled()


# --- Widgets -------------------------------------------------------------------------------

func _label(text: String, size: int, color: Color = Color(0.85, 0.88, 0.86)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _hint(text: String) -> Label:
	var label := _label(text, 16, Color(0.55, 0.62, 0.62) if future else Color(0.42, 0.42, 0.36))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(accent().r, accent().g, accent().b, 0.45)
	return rule


func _margin(child: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, horizontal)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, vertical)
	margin.add_child(child)
	return margin


static func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	return style
