class_name MissionLog
extends CanvasLayer
## The Mission Log panel: completed, current and upcoming objectives for the local timeline.
## It only presents what ObjectiveManager hands it. Opening, closing and locking the player is the
## manager's job; this layer owns the look, keyboard / controller navigation inside the panel, and
## closing on Escape, the cancel button or the Mission Log shortcut.

const TemporalButton := preload("res://scripts/menu/menu_button.gd")

const TITLE := "MISSION LOG"
const SUBTITLE := "YOUR JOURNEY THROUGH TIME"
const OPEN_TIME := 0.24
const CLOSE_TIME := 0.14
const REDUCED_TIME := 0.12
const STICK_SCROLL_SPEED := 760.0
const STICK_DEADZONE := 0.3
## Actions the panel's own focus navigation needs; every other key or button is held back from the room.
const NAVIGATION := [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_select",
	&"ui_focus_next", &"ui_focus_prev", &"ui_page_up", &"ui_page_down", &"ui_home", &"ui_end"]

var _role: String = "past"
var _showing := false
var _tween: Tween
var _shimmer: Tween
var _focus_target: Control

var _root: Control
var _dim: ColorRect
var _frame: PanelContainer
var _title: Label
var _subtitle: Label
var _badge: Label
var _line: ColorRect
var _glint: ColorRect
var _scroll: ScrollContainer
var _body: VBoxContainer
var _close: Button
var _hint: Label


func _ready() -> void:
	layer = 95  # Above rooms, pause menus and the tutorial; the journal (100) can never be open with it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	ObjectiveManager.state_changed.connect(_on_state_changed)
	get_viewport().size_changed.connect(_fit)
	InputManager.get_instance().device_changed_signal.connect(func(_device: int, _controller: int) -> void: _refresh_labels())


func _process(delta: float) -> void:
	if not _showing:
		return
	# Right stick scrolls long histories; the d-pad and left stick move focus (which also scrolls).
	var pad := InputManager.active_joypad_id
	if pad < 0:
		return
	var axis := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
	if absf(axis) > STICK_DEADZONE:
		_scroll.scroll_vertical += int(axis * STICK_SCROLL_SPEED * delta)


func _input(event: InputEvent) -> void:
	if not _showing:
		return
	if (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(ObjectiveManager.ACTION)) and not event.is_echo():
		ObjectiveManager.close_log()
		get_viewport().set_input_as_handled()
		return
	# The room underneath is locked, but its own handlers (pause, role switch, journal) still see
	# raw keys and buttons. Hold them back; the panel keeps only what it navigates with.
	if event is InputEventKey or event is InputEventJoypadButton:
		for action in NAVIGATION:
			if event.is_action(action):
				return
		get_viewport().set_input_as_handled()


func _on_dim_input(event: InputEvent) -> void:
	# Clicking the dimmed area outside the panel closes it.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _frame.get_global_rect().has_point(event.global_position):
			ObjectiveManager.close_log()


# --- Open / close -------------------------------------------------------------------------

func open(role: String) -> void:
	_role = role
	# Rooms are added to the root after this layer, and later nodes hear input first: be last.
	var tree_root := get_tree().root
	if get_parent() == tree_root:
		tree_root.move_child(self, tree_root.get_child_count() - 1)
	_showing = true
	_apply_role()
	_populate(false)
	_fit()
	_root.show()
	if _tween != null:
		_tween.kill()
	var reduced := ObjectiveStyle.reduced_motion()
	_dim.modulate.a = 0.0
	_frame.modulate.a = 0.0
	var rest := _frame.position
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", 1.0, REDUCED_TIME if reduced else OPEN_TIME)
	_tween.tween_property(_frame, "modulate:a", 1.0, REDUCED_TIME if reduced else OPEN_TIME)
	if not reduced:
		_frame.position = rest + Vector2(0.0, 22.0)
		_tween.tween_property(_frame, "position", rest, OPEN_TIME)
	_start_shimmer(reduced)
	_focus_current.call_deferred()


func close() -> void:
	_showing = false
	get_viewport().gui_release_focus()
	if _tween != null:
		_tween.kill()
	if _shimmer != null:
		_shimmer.kill()
	var seconds := REDUCED_TIME if ObjectiveStyle.reduced_motion() else CLOSE_TIME
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, seconds)
	_tween.tween_property(_frame, "modulate:a", 0.0, seconds)
	_tween.chain().tween_callback(func() -> void:
		if not _showing:
			_root.hide())


func is_showing() -> bool:
	return _showing


func _focus_current() -> void:
	if not _showing:
		return
	if is_instance_valid(_focus_target):
		_focus_target.grab_focus()
		_scroll.ensure_control_visible(_focus_target)
	else:
		_close.grab_focus()


func _on_state_changed() -> void:
	if _showing:
		_populate(true)


func _start_shimmer(reduced: bool) -> void:
	if _shimmer != null:
		_shimmer.kill()
	_glint.position.x = -80.0
	if reduced:
		_glint.hide()
		return
	_glint.show()
	_shimmer = create_tween().set_loops()
	_shimmer.tween_property(_glint, "position:x", _line.size.x, 3.6).from(-80.0).set_trans(Tween.TRANS_SINE)
	_shimmer.tween_interval(1.4)


# --- Content ------------------------------------------------------------------------------

func _apply_role() -> void:
	var accent := ObjectiveStyle.accent(_role)
	_frame.add_theme_stylebox_override("panel", ObjectiveStyle.box(ObjectiveStyle.PANEL_SOLID, Color(accent, 0.5), 2, 12, Vector2(30, 22)))
	_title.add_theme_color_override("font_color", accent)
	_badge.text = ObjectiveStyle.role_name(_role)
	_badge.add_theme_color_override("font_color", accent)
	_line.color = Color(accent, 0.35)
	_glint.color = Color(accent, 0.95)
	_refresh_labels()


func _refresh_labels() -> void:
	if _close == null:
		return
	_close.text = "CLOSE  [%s / %s]" % [InputManager.get_action_label(ObjectiveManager.ACTION), InputManager.get_action_label(&"cancel")]
	_hint.text = "Scroll  ·  Up / Down to move between objectives" if InputManager.active_device_type == InputManager.DeviceType.KEYBOARD else "D-pad: move between objectives   ·   Right stick: scroll"


func _populate(keep_scroll: bool) -> void:
	var offset := _scroll.scroll_vertical
	var focus_index := _focus_index()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_focus_target = null
	var accent := ObjectiveStyle.accent(_role)
	var done := ObjectiveManager.get_completed(_role)
	var current := ObjectiveManager.get_current(_role)

	_section("COMPLETED OBJECTIVES", ObjectiveStyle.DONE, "%d" % done.size())
	if done.is_empty():
		_note("Nothing completed yet. Finished objectives are kept here for the whole journey.")
	var chapter := ""
	for definition in _ordered(done):
		if definition.chapter != chapter:
			chapter = definition.chapter
			_chapter_header(ObjectiveManager.get_chapter_name(chapter).to_upper())
		_body.add_child(_row(definition, "done", accent))

	_section("CURRENT OBJECTIVE", accent, "")
	if current != null:
		var card := _current_card(current, accent)
		_body.add_child(card)
		_focus_target = card
	elif ObjectiveManager.is_chapter_done(_role):
		_note("Every objective for this chapter is complete. New objectives appear as you advance.")
	else:
		_note("No objective yet. Keep exploring.")

	_section("UPCOMING OBJECTIVES", ObjectiveStyle.SOFT, "")
	var upcoming := ObjectiveManager.get_upcoming(_role)
	if upcoming.is_empty():
		_note("Nothing further is known yet.")
	chapter = ""
	for entry in upcoming:
		if entry.chapter != chapter:
			chapter = entry.chapter
			_chapter_header("UNCHARTED AREA" if entry.kind == "chapter" else ObjectiveManager.get_chapter_name(chapter).to_upper())
		if entry.kind == "known":
			_body.add_child(_row(entry.definition, "known", accent))
		else:
			_body.add_child(_row(null, "locked", accent))

	if keep_scroll:
		# Restore position and focus once the new rows have been laid out.
		_restore.call_deferred(offset, focus_index)


func _restore(offset: int, focus_index: int) -> void:
	_scroll.scroll_vertical = offset
	if not _showing:
		return
	var rows := _focusables()
	if focus_index >= 0 and focus_index < rows.size():
		rows[focus_index].grab_focus()
	elif is_instance_valid(_focus_target):
		_focus_target.grab_focus()


func _focusables() -> Array[Control]:
	var result: Array[Control] = []
	for child in _body.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL:
			result.append(child)
	return result


func _focus_index() -> int:
	var owner := get_viewport().gui_get_focus_owner()
	return _focusables().find(owner) if owner != null else -1


func _ordered(items: Array[ObjectiveDefinition]) -> Array[ObjectiveDefinition]:
	var result := items.duplicate()
	result.sort_custom(func(a: ObjectiveDefinition, b: ObjectiveDefinition) -> bool:
		if a.chapter_order != b.chapter_order:
			return a.chapter_order < b.chapter_order
		return a.sort_order < b.sort_order)
	return result


func _section(text: String, color: Color, count: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _body.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 10.0
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(gap)
	row.add_child(ObjectiveStyle.label(text, &"button", 15, color, 2.0))
	if not count.is_empty():
		row.add_child(ObjectiveStyle.label(count, &"settings_label", 13, ObjectiveStyle.MUTED, 1.0))
	var rule := ColorRect.new()
	rule.color = Color(color, 0.22)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	_body.add_child(row)


func _chapter_header(text: String) -> void:
	var label := ObjectiveStyle.label(text, &"settings_label", 12, ObjectiveStyle.MUTED, 1.8)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)
	_body.add_child(margin)


func _note(text: String) -> void:
	var label := ObjectiveStyle.label(text, &"settings_note", 15, ObjectiveStyle.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)


## A history or upcoming row. `state` is "done", "known" or "locked"; a locked row has no definition.
func _row(definition: ObjectiveDefinition, state: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var idle_border := Color(1, 1, 1, 0.07)
	var normal := ObjectiveStyle.box(Color(1, 1, 1, 0.035), idle_border, 1, 8, Vector2(14, 10))
	var focused := ObjectiveStyle.box(Color(accent, 0.1), accent, 2, 8, Vector2(13, 9))
	_focus_styles(panel, normal, focused)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var glyph: ObjectiveIcon
	var title: String
	var body: String
	var tag: String
	var tag_color: Color
	var title_color := ObjectiveStyle.TEXT
	match state:
		"done":
			glyph = ObjectiveIcon.new(&"check", ObjectiveStyle.DONE, 24.0)
			title = definition.title
			body = definition.description
			tag = "COMPLETED"
			tag_color = ObjectiveStyle.DONE
		"known":
			glyph = ObjectiveIcon.new(&"upcoming", ObjectiveStyle.SOFT, 24.0)
			title = definition.title
			body = definition.description
			tag = "UP NEXT"
			tag_color = ObjectiveStyle.SOFT
			title_color = ObjectiveStyle.SOFT
			panel.modulate = Color(1, 1, 1, 0.82)
		_:
			glyph = ObjectiveIcon.new(&"lock", ObjectiveStyle.MUTED, 24.0)
			title = "Undiscovered Objective"
			body = "???"
			tag = "LOCKED"
			tag_color = ObjectiveStyle.MUTED
			title_color = ObjectiveStyle.MUTED
			panel.modulate = Color(1, 1, 1, 0.7)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(ObjectiveStyle.label(title, &"button", 17, title_color))
	var description := ObjectiveStyle.label(body, &"settings_note", 14, ObjectiveStyle.MUTED if state != "done" else ObjectiveStyle.SOFT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(description)
	var tag_label := ObjectiveStyle.label(tag, &"settings_label", 11, tag_color, 1.5)
	tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag_label)
	return panel


func _current_card(definition: ObjectiveDefinition, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CurrentObjective"
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var normal := ObjectiveStyle.box(Color(accent, 0.09), Color(accent, 0.7), 2, 10, Vector2(18, 15))
	var focused := ObjectiveStyle.box(Color(accent, 0.17), Color(accent.lightened(0.25), 1.0), 3, 10, Vector2(17, 14))
	_focus_styles(panel, normal, focused)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	head.add_child(ObjectiveIcon.new(definition.icon, accent, 38.0))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	names.add_child(ObjectiveStyle.label(definition.title, &"button", 23, ObjectiveStyle.TEXT))
	names.add_child(ObjectiveStyle.label(ObjectiveManager.get_chapter_name(definition.chapter).to_upper(), &"settings_label", 11, ObjectiveStyle.MUTED, 1.5))
	var tag := ObjectiveStyle.label("IN PROGRESS", &"settings_label", 11, accent, 1.5)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(tag)

	var description := ObjectiveStyle.label(definition.description, &"settings_note", 16, ObjectiveStyle.TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)

	if not definition.hint.is_empty():
		var hint := HBoxContainer.new()
		hint.add_theme_constant_override("separation", 10)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(hint)
		var label := ObjectiveStyle.label("HINT", &"settings_label", 11, accent, 1.5)
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		hint.add_child(label)
		var text := ObjectiveStyle.label(definition.hint, &"settings_note", 14, ObjectiveStyle.SOFT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.add_child(text)

	var progress := ObjectiveManager.get_progress(definition, _role)
	if progress.y > 0:
		var bar_row := HBoxContainer.new()
		bar_row.add_theme_constant_override("separation", 12)
		bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(bar_row)
		var bar := ProgressBar.new()
		bar.max_value = progress.y
		bar.value = progress.x
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 6.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", ObjectiveStyle.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 3, Vector2.ZERO))
		bar.add_theme_stylebox_override("fill", ObjectiveStyle.box(accent, Color(0, 0, 0, 0), 0, 3, Vector2.ZERO))
		bar_row.add_child(bar)
		bar_row.add_child(ObjectiveStyle.label("PROGRESS  %d / %d" % [progress.x, progress.y], &"settings_label", 12, accent, 1.0))
	return panel


## Rows are focusable for the keyboard and controller: the focus look replaces the resting look.
func _focus_styles(panel: PanelContainer, normal: StyleBoxFlat, focused: StyleBoxFlat) -> void:
	panel.add_theme_stylebox_override("panel", normal)
	panel.focus_entered.connect(func() -> void: panel.add_theme_stylebox_override("panel", focused))
	panel.focus_exited.connect(func() -> void: panel.add_theme_stylebox_override("panel", normal))


# --- Layout -------------------------------------------------------------------------------

func _fit() -> void:
	if _frame == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var width := clampf(screen.x - 160.0, 560.0, 1040.0)
	var height := clampf(screen.y - 80.0, 360.0, 800.0)
	_frame.custom_minimum_size = Vector2(width, height)
	_frame.size = Vector2(width, height)
	_frame.position = ((screen - _frame.size) * 0.5).round()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.004, 0.014, 0.022, 0.78)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	TemporalButton.theme_for(_dim)
	_root.add_child(_dim)

	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_frame.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = ObjectiveStyle.label(TITLE, &"chapter_name", 34, Color.WHITE, 3.0)
	titles.add_child(_title)
	_subtitle = ObjectiveStyle.label(SUBTITLE, &"settings_label", 13, ObjectiveStyle.SOFT, 3.0)
	titles.add_child(_subtitle)
	_badge = ObjectiveStyle.label("", &"settings_label", 12, Color.WHITE, 2.0)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_badge)
	_close = TemporalButton.apply(Button.new(), &"SecondaryButton")
	_close.name = "CloseButton"
	_close.text = "CLOSE"
	_close.custom_minimum_size = Vector2(190.0, 46.0)
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func() -> void: ObjectiveManager.close_log())
	header.add_child(_close)

	_line = ColorRect.new()
	_line.custom_minimum_size = Vector2(0.0, 2.0)
	_line.clip_contents = true
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_line)
	_glint = ColorRect.new()
	_glint.custom_minimum_size = Vector2(80.0, 2.0)
	_glint.size = Vector2(80.0, 2.0)
	_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.add_child(_glint)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	_hint = ObjectiveStyle.label("", &"settings_note", 13, ObjectiveStyle.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
