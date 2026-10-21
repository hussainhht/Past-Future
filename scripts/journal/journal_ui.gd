class_name JournalUI
extends CanvasLayer
## One journal screen with two skins: the Student's paper notebook (past) and the Professor's
## research DataPad (future). It only presents what JournalManager hands it; opening and closing
## (and locking the player) is the manager's job. Built in code so both skins share one layout:
##   header / [contents list | reading page] / footer (previous, page count, next).

const GROUP_HEADERS := {
	"past": ["EXPERIMENT NOTES", "COLLECTED DOCUMENTS", "RESEARCH OBSERVATIONS"],
	"future": ["RESEARCH LOGS", "RECOVERED DOCUMENTS", "INCIDENT EVIDENCE"],
}
const SCANLINES := """
shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, step(0.5, fract(FRAGCOORD.y / 6.0)) * 0.10);
}
"""

var _role: String = "past"
var _skin: Dictionary = {}
var _entries: Array[JournalEntry] = []
var _buttons: Array[Button] = []
var _index: int = 0
var _tween: Tween
var _toast_tween: Tween
var _pulse_tween: Tween
var _showing: bool = false

var _root: Control
var _dim: ColorRect
var _frame: Control
var _title_label: Label
var _read_box: VBoxContainer
var _read_title: Label
var _read_subtitle: Label
var _read_image: TextureRect
var _read_body: RichTextLabel
var _read_scroll: ScrollContainer
var _counter: Label
var _prev: Button
var _next: Button
var _hint: Label
var _toast: PanelContainer
var _toast_head: Label
var _toast_text: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	add_child(_root)
	_build_overlays()


func _process(_delta: float) -> void:
	_hint.visible = not _showing and JournalManager.can_open()


func _input(event: InputEvent) -> void:
	if not _showing or _entries.is_empty():
		return
	if event.is_action_pressed(&"ui_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		_step(1)
		get_viewport().set_input_as_handled()


# --- Open / close -------------------------------------------------------------------------

func open(role: String) -> void:
	_role = role
	_skin = _make_skin(role)
	_entries = JournalManager.get_unlocked_entries(role)
	if _tween:
		_tween.kill()
	if _pulse_tween:
		_pulse_tween.kill()
	_build_frame()
	_populate()
	_showing = true
	_root.show()
	_hint.hide()
	if _tween:
		_tween.kill()
	_dim.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_frame.position.y += 18.0
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_frame, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_frame, "position:y", _frame.position.y - 18.0, 0.2)
	var first_new := -1
	for i in _entries.size():
		if JournalManager.is_new(_entries[i].entry_id):
			first_new = i
			break
	if not _entries.is_empty():
		_select(maxi(first_new, 0), false)
		_buttons[_index].grab_focus()
	else:
		_prev.grab_focus()


func close() -> void:
	_showing = false
	get_viewport().gui_release_focus()
	if _tween:
		_tween.kill()
	if _pulse_tween:
		_pulse_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, 0.12)
	_tween.tween_property(_frame, "modulate:a", 0.0, 0.12)
	_tween.chain().tween_callback(func() -> void:
		if not _showing:
			_root.hide())


# --- Toast and hint -----------------------------------------------------------------------

func show_toast(entry: JournalEntry) -> void:
	var skin := _make_skin(JournalManager.get_local_role())
	_toast.add_theme_stylebox_override("panel", _box(skin.toast_bg, skin.toast_border, 2, skin.radius, Vector2(22, 12), skin.glow))
	_toast_head.text = skin.toast_head
	_toast_head.add_theme_color_override("font_color", skin.accent)
	_toast_head.add_theme_font_override("font", skin.head_font)
	_toast_head.add_theme_font_size_override("font_size", skin.toast_head_size)
	_toast_text.text = entry.title
	_toast_text.add_theme_color_override("font_color", skin.toast_ink)
	_toast_text.add_theme_font_override("font", skin.body_font)
	_toast_text.add_theme_font_size_override("font_size", skin.toast_size)
	_toast.show()
	_toast.reset_size()
	var rest_y := 70.0
	_toast.position = Vector2((1600.0 - _toast.size.x) * 0.5, rest_y - 24.0)
	_toast.modulate.a = 0.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_property(_toast, "position:y", rest_y, 0.25)
	_toast_tween.chain().tween_interval(2.6)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.45)
	_toast_tween.chain().tween_callback(_toast.hide)
	refresh_hint()


func dismiss_notifications() -> void:
	if _toast_tween: _toast_tween.kill()
	_toast.hide()
	_hint.hide()


func refresh_hint() -> void:
	var skin := _make_skin(JournalManager.get_local_role())
	var fresh := JournalManager.get_new_count()
	_hint.text = "%s  %s%s" % [skin.hint_name, "● " if fresh > 0 else "", ("%d new" % fresh) if fresh > 0 else ""]
	_hint.add_theme_color_override("font_color", skin.accent if fresh > 0 else skin.hint_ink)
	_hint.add_theme_font_override("font", skin.head_font)
	_hint.add_theme_font_size_override("font_size", skin.hint_size)
	_hint.add_theme_stylebox_override("normal", _box(skin.toast_bg, skin.toast_border, 1, skin.radius, Vector2(12, 5)))


func _build_overlays() -> void:
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -20.0
	_hint.offset_bottom = -20.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.hide()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_toast.add_child(box)
	_toast_head = Label.new()
	_toast_text = Label.new()
	box.add_child(_toast_head)
	box.add_child(_toast_text)
	add_child(_toast)
	refresh_hint()


# --- Skins --------------------------------------------------------------------------------

func _make_skin(role: String) -> Dictionary:
	if role == "past":
		var hand := Typography.font(&"past_journal")
		return {
			"title": "STUDENT'S NOTEBOOK", "subtitle": "Signal Laboratory  ·  Research Journal",
			"cover": Color("5a3a20"), "cover_edge": Color("3a2412"), "cover_ink": Color("ead6a6"),
			"page": Color("f3e8ca"), "page_edge": Color("c9b88c"), "ink": Color("3b2a1b"), "ink_dim": Color("85704f"),
			"accent": Color("a8452b"), "select": Color("e6d29a"), "hover": Color("ecdcae"),
			"button_bg": Color("c8a96d"), "button_ink": Color("3b2a1b"), "dim": Color(0.08, 0.05, 0.02, 0.62),
			"toast_bg": Color("f3e8ca"), "toast_border": Color("5a3a20"), "toast_ink": Color("3b2a1b"),
			"toast_head": "NEW RESEARCH ENTRY", "hint_name": "J  ·  NOTEBOOK", "hint_ink": Color("3b2a1b"),
			"radius": 6, "glow": 0, "student": true,
			"head_font": hand, "body_font": hand, "bold_font": hand, "list_font": hand,
			"title_size": 34, "sub_size": 22, "label_size": 22, "small_size": 20, "list_size": 24, "body_size": 26,
			"counter_size": 22, "button_size": 22, "hint_size": 22, "toast_head_size": 20, "toast_size": 26, "line_gap": 8,
			"list_width": 420,
			"close_hint": "J / Esc  close", "prev": "◀  Previous page", "next": "Next page  ▶",
			"page_word": "Page", "empty": "These pages are still blank.\n\nExamine research papers in the laboratory and the important ones will be copied here.",
			"status": "",
		}
	return {
		"title": "RESEARCH DATAPAD", "subtitle": "RECOVERED ARCHIVE",
		"cover": Color("0a1119"), "cover_edge": Color("3fd6e6"), "cover_ink": Color("8fe9f2"),
		"page": Color("0e1b27"), "page_edge": Color("1f5662"), "ink": Color("cfe6ea"), "ink_dim": Color("5f8a93"),
		"accent": Color("3fd6e6"), "select": Color(0.25, 0.84, 0.9, 0.2), "hover": Color(0.25, 0.84, 0.9, 0.09),
		"button_bg": Color("0e2a35"), "button_ink": Color("8fe9f2"), "dim": Color(0.01, 0.03, 0.05, 0.72),
		"toast_bg": Color("0a1119"), "toast_border": Color("3fd6e6"), "toast_ink": Color("cfe6ea"),
		"toast_head": "NEW RESEARCH ENTRY", "hint_name": "J  ·  DATAPAD", "hint_ink": Color("8fe9f2"),
		"radius": 3, "glow": 12, "student": false,
		"head_font": Typography.font(&"future_journal_title"), "body_font": Typography.font(&"future_journal_body"),
		"bold_font": Typography.font(&"future_journal_bold"), "list_font": Typography.font(&"future_journal_body"),
		"title_size": 33, "sub_size": 18, "label_size": 22, "small_size": 20, "list_size": 18, "body_size": 22,
		"counter_size": 22, "button_size": 20, "hint_size": 20, "toast_head_size": 20, "toast_size": 22, "line_gap": 6,
		"list_width": 440,
		"close_hint": "[J] / [ESC]  CLOSE", "prev": "◀  PREV", "next": "NEXT  ▶",
		"page_word": "FILE", "empty": "> NO FILES RECOVERED\n\n> Examine terminals and documents to add them to the archive.",
		"status": "● OFFLINE  ·  LOCAL STORAGE",
	}


func _box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 0, margin: Vector2 = Vector2.ZERO, glow: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	if glow > 0:
		style.shadow_color = Color(border.r, border.g, border.b, 0.35)
		style.shadow_size = glow
	return style


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", font)
	return label


func _flat_button(text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_font_override("font", _skin.head_font)
	button.focus_mode = Control.FOCUS_ALL
	return button


# --- Layout -------------------------------------------------------------------------------

func _build_frame() -> void:
	if is_instance_valid(_frame):
		_frame.free()
	if is_instance_valid(_dim):
		_dim.free()
	var s := _skin
	_dim = ColorRect.new()
	_dim.color = s.dim
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(1120, 650)
	outer.add_theme_stylebox_override("panel", _box(s.cover, s.cover_edge, 3 if s.student else 2, 14 if s.student else 4, Vector2(22, 16), s.glow))
	center.add_child(outer)
	_frame = center

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	outer.add_child(column)

	# Header
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title_label = _label(s.title, s.title_size, s.cover_ink, s.head_font)
	titles.add_child(_title_label)
	titles.add_child(_label(s.subtitle, s.sub_size, s.cover_ink.darkened(0.15), s.body_font))
	if not s.student:
		var status := _label(s.status, s.small_size, s.accent, s.head_font)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(status)
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(status, "modulate:a", 0.45, 0.9)
		_pulse_tween.tween_property(status, "modulate:a", 1.0, 0.9)
		var gap := Control.new()
		gap.custom_minimum_size.x = 18
		header.add_child(gap)
	var close_button := _flat_button("✕", s.button_size)
	_style_button(close_button)
	close_button.pressed.connect(JournalManager.close_journal)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(close_button)

	# Pages
	var pages := HBoxContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 0 if s.student else 14)
	column.add_child(pages)

	var list_page := PanelContainer.new()
	list_page.custom_minimum_size.x = s.list_width
	list_page.add_theme_stylebox_override("panel", _page_box(true))
	pages.add_child(list_page)
	var list_column := VBoxContainer.new()
	list_column.add_theme_constant_override("separation", 6)
	list_page.add_child(list_column)
	list_column.add_child(_label("CONTENTS" if s.student else "> ARCHIVE INDEX", s.label_size, s.accent, s.head_font))
	list_column.add_child(_rule())
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	list_scroll.add_child(list)

	if s.student:
		var spine := ColorRect.new()
		spine.color = s.cover_edge
		spine.custom_minimum_size.x = 8
		pages.add_child(spine)

	var read_page := PanelContainer.new()
	read_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	read_page.add_theme_stylebox_override("panel", _page_box(false))
	pages.add_child(read_page)
	var read_row := HBoxContainer.new()
	read_row.add_theme_constant_override("separation", 14)
	read_page.add_child(read_row)
	if s.student:  # red margin line, like ruled school paper
		var margin_line := ColorRect.new()
		margin_line.color = Color(s.accent, 0.45)
		margin_line.custom_minimum_size.x = 2
		read_row.add_child(margin_line)
	_read_box = VBoxContainer.new()
	_read_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_read_box.add_theme_constant_override("separation", 6)
	read_row.add_child(_read_box)
	_read_title = _label("", s.title_size, s.ink, s.head_font)
	_read_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_read_box.add_child(_read_title)
	_read_subtitle = _label("", s.sub_size, s.ink_dim, s.body_font)
	_read_box.add_child(_read_subtitle)
	_read_box.add_child(_rule())
	_read_scroll = ScrollContainer.new()
	_read_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_read_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_read_box.add_child(_read_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_read_scroll.add_child(content)
	_read_image = TextureRect.new()
	_read_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_read_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_read_image.custom_minimum_size.y = 190
	content.add_child(_read_image)
	_read_body = RichTextLabel.new()
	_read_body.bbcode_enabled = true
	_read_body.fit_content = true
	_read_body.scroll_active = false
	_read_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_read_body.add_theme_font_override("normal_font", s.body_font)
	_read_body.add_theme_font_override("bold_font", s.bold_font)
	_read_body.add_theme_font_size_override("normal_font_size", s.body_size)
	_read_body.add_theme_font_size_override("bold_font_size", s.body_size)
	_read_body.add_theme_font_size_override("italics_font_size", s.body_size)
	_read_body.add_theme_font_size_override("bold_italics_font_size", s.body_size)
	_read_body.add_theme_font_size_override("mono_font_size", s.body_size)
	_read_body.add_theme_font_override("italics_font", s.body_font)
	_read_body.add_theme_font_override("bold_italics_font", s.bold_font)
	_read_body.add_theme_font_override("mono_font", Typography.font(&"terminal_log"))
	_read_body.add_theme_constant_override("line_separation", s.line_gap)
	_read_body.add_theme_color_override("default_color", s.ink)
	content.add_child(_read_body)

	# Footer
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	_prev = _flat_button(s.prev, s.button_size)
	_next = _flat_button(s.next, s.button_size)
	for button: Button in [_prev, _next]:
		_style_button(button)
		button.custom_minimum_size.x = 190
	_prev.pressed.connect(_step.bind(-1))
	_next.pressed.connect(_step.bind(1))
	footer.add_child(_prev)
	_counter = _label("", s.counter_size, s.cover_ink, s.head_font)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_counter)
	footer.add_child(_next)
	var close_hint := _label(s.close_hint, s.small_size, s.cover_ink.darkened(0.25), s.head_font)
	close_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(close_hint)

	if not s.student:
		var scan := ColorRect.new()
		var shader := Shader.new()
		shader.code = SCANLINES
		var material := ShaderMaterial.new()
		material.shader = shader
		scan.material = material
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(scan)


func _page_box(is_list: bool) -> StyleBoxFlat:
	var s := _skin
	var style := _box(s.page, s.page_edge, 1, s.radius, Vector2(24, 18))
	if s.student:  # the two pages meet at the spine, so only the outer corners are round
		style.set_corner_radius_all(0)
		if is_list:
			style.corner_radius_top_left = 8
			style.corner_radius_bottom_left = 8
		else:
			style.corner_radius_top_right = 8
			style.corner_radius_bottom_right = 8
	return style


func _rule() -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = _skin.page_edge
	style.thickness = 2 if _skin.student else 1
	line.add_theme_stylebox_override("separator", style)
	return line


func _style_button(button: Button) -> void:
	var s := _skin
	var normal := _box(s.button_bg, s.page_edge if not s.student else s.cover_edge, 1, s.radius, Vector2(14, 6))
	var hover := _box(s.button_bg.lightened(0.15), s.accent, 1, s.radius, Vector2(14, 6))
	var disabled := _box(s.button_bg.darkened(0.25), Color.TRANSPARENT, 0, s.radius, Vector2(14, 6))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", s.button_ink)
	button.add_theme_color_override("font_hover_color", s.button_ink)
	button.add_theme_color_override("font_focus_color", s.button_ink)
	button.add_theme_color_override("font_pressed_color", s.button_ink)
	button.add_theme_color_override("font_disabled_color", s.button_ink.darkened(0.5))


# --- Content ------------------------------------------------------------------------------

func _populate() -> void:
	var s := _skin
	var list: VBoxContainer = _frame.find_child("List", true, false)
	var group := ButtonGroup.new()
	_buttons.clear()
	var last_category := -1
	var headers: Array = GROUP_HEADERS[_role]
	for i in _entries.size():
		var entry := _entries[i]
		if entry.category != last_category:
			last_category = entry.category
			var header := _label(headers[entry.category], s.small_size, s.ink_dim, s.head_font)
			var holder := MarginContainer.new()
			holder.add_theme_constant_override("margin_top", 10 if i > 0 else 2)
			holder.add_child(header)
			list.add_child(holder)
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_font_size_override("font_size", s.list_size)
		button.add_theme_font_override("font", s.list_font)
		button.add_theme_color_override("font_color", s.ink)
		button.add_theme_color_override("font_hover_color", s.ink)
		button.add_theme_color_override("font_pressed_color", s.ink)
		button.add_theme_color_override("font_focus_color", s.ink)
		button.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, s.radius, Vector2(10, 7)))
		button.add_theme_stylebox_override("hover", _box(s.hover, Color.TRANSPARENT, 0, s.radius, Vector2(10, 7)))
		button.add_theme_stylebox_override("focus", _box(s.hover, s.accent, 1, s.radius, Vector2(10, 7)))
		var picked := _box(s.select, s.accent, 0, s.radius, Vector2(10, 7))
		picked.border_width_left = 4
		button.add_theme_stylebox_override("pressed", picked)
		button.pressed.connect(_select.bind(i, true))
		list.add_child(button)
		_buttons.append(button)
		_refresh_button(i)
	_counter.text = ""
	_prev.disabled = true
	_next.disabled = true
	if _entries.is_empty():
		_read_title.text = "Empty" if s.student else "> ARCHIVE EMPTY"
		_read_subtitle.text = ""
		_read_image.hide()
		_read_body.text = s.empty


func _refresh_button(i: int) -> void:
	var fresh := JournalManager.is_new(_entries[i].entry_id)
	_buttons[i].text = ("● " if fresh else "   ") + _entries[i].title
	_buttons[i].add_theme_color_override("font_color", _skin.accent if fresh else _skin.ink)


func _step(delta: int) -> void:
	if _entries.is_empty():
		return
	var target := clampi(_index + delta, 0, _entries.size() - 1)
	if target != _index:
		_select(target, true)


func _select(i: int, animate: bool) -> void:
	_index = i
	var entry := _entries[i]
	JournalManager.mark_seen(entry.entry_id)
	for n in _buttons.size():
		_buttons[n].set_pressed_no_signal(n == i)
		_refresh_button(n)
	_read_title.text = entry.title
	_read_subtitle.text = entry.subtitle
	_read_subtitle.visible = not entry.subtitle.is_empty()
	_read_image.texture = entry.image
	_read_image.visible = entry.image != null
	_read_body.text = entry.body
	_read_scroll.scroll_vertical = 0
	_counter.text = "%s %d / %d" % [_skin.page_word, i + 1, _entries.size()]
	_prev.disabled = i == 0
	_next.disabled = i == _entries.size() - 1
	if animate:
		_read_box.modulate.a = 0.0
		create_tween().tween_property(_read_box, "modulate:a", 1.0, 0.14)
