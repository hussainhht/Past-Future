extends CanvasLayer
## Native scalable HUD and skippable terminal/document panels.

const TemporalButton := preload("res://scripts/menu/menu_button.gd")
const Inputs := preload("res://scripts/input/input_manager.gd")

signal device_control_pressed(caption: String)
signal device_close_requested
var device_panel: PanelContainer
var device_box: VBoxContainer
var device_feedback: Label
var device_hint: Label
var device_buttons: Dictionary = {}
var header: PanelContainer
var footer: PanelContainer
var reactor_status: Label
var progress: Label
var _error_until := 0
var _device_error := ""

var root: Control
var identity: Label
var timer: Label
var objective: Label
var status: Label
var modal: PanelContainer
var modal_box: VBoxContainer
var veil: ColorRect
var debug_button: Button
var journal_button: Button
var ending_caption: Label
var visible_modal: bool = false
var _status_panel: PanelContainer
var _last_status: String = ""
var _status_seconds: float = 0.0


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TemporalButton.theme_for(root)
	add_child(root)
	header = PanelContainer.new()
	header.position = Vector2(20, 16)
	header.size = Vector2(690, 108)
	header.add_theme_stylebox_override("panel", panel_style())
	root.add_child(header)
	var rows := VBoxContainer.new()
	header.add_child(rows)
	identity = text_label("III / THE FINAL FRACTURE", 21)
	rows.add_child(identity)
	reactor_status = text_label("REACTOR IDLE / CLOCK STOPPED", 17)
	rows.add_child(reactor_status)
	progress = text_label("A POWER / B ALIGNMENT / C IDENTITY", 16)
	rows.add_child(progress)
	timer = text_label("", 38)
	timer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer.position = Vector2(-235, 20)
	timer.size = Vector2(215, 55)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(timer)
	_status_panel = PanelContainer.new()
	_status_panel.position = Vector2(20, 138)
	_status_panel.size.x = 520
	_status_panel.add_theme_stylebox_override("panel", panel_style())
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.hide()
	root.add_child(_status_panel)
	status = text_label("", 18)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_panel.add_child(status)
	footer = PanelContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 20
	footer.offset_right = 780
	footer.offset_top = -190
	footer.offset_bottom = -14
	footer.add_theme_stylebox_override("panel", panel_style())
	root.add_child(footer)
	var bottom := VBoxContainer.new()
	footer.add_child(bottom)
	objective = text_label("", 19)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(objective)
	var controls := HBoxContainer.new()
	bottom.add_child(controls)
	journal_button = make_button("JOURNAL", func() -> void: JournalManager.toggle_journal())
	controls.add_child(journal_button)
	debug_button = make_button("DEV: OTHER TIMELINE", func() -> void: pass)
	controls.add_child(debug_button)
	debug_button.visible = false
	device_panel = PanelContainer.new()
	device_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	device_panel.add_theme_stylebox_override("panel", panel_style())
	root.add_child(device_panel)
	device_box = VBoxContainer.new()
	device_box.add_theme_constant_override("separation", 10)
	device_panel.add_child(device_box)
	device_panel.hide()
	veil = ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.06, 0.48)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	veil.visible = false
	modal = PanelContainer.new()
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.offset_left = -470
	modal.offset_top = -230
	modal.offset_right = 470
	modal.offset_bottom = 230
	modal.add_theme_stylebox_override("panel", panel_style())
	TemporalButton.theme_for(modal)
	root.add_child(modal)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 16)
	modal.add_child(modal_box)
	modal.visible = false
	ending_caption = text_label("", 28)
	ending_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ending_caption.position = Vector2(-600, -210)
	ending_caption.size = Vector2(1200, 80)
	ending_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(ending_caption)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if status.text != _last_status:
		_last_status = status.text
		_status_seconds = 5.0 if not status.text.is_empty() else 0.0
	_status_seconds = maxf(0.0, _status_seconds - delta)
	_status_panel.visible = _status_seconds > 0.0 and not visible_modal


func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("111f2aee")
	s.border_color = Color("8aabab")
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func text_label(value: String, size: int) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font", Typography.font(&"ui_regular"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("f4eedf"))
	return l


func make_button(value: String, callback: Callable) -> Button:
	var b := TemporalButton.apply(Button.new(), &"SecondaryButton")
	b.text = value
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	return b


func show_panel(title: String, body: String, options: Array) -> void:
	for child in modal_box.get_children():
		modal_box.remove_child(child)
		child.queue_free()
	modal_box.add_child(text_label(title, 30))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 150
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_box.add_child(scroll)
	var content := text_label(body, 23)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var first: Button
	for option: Dictionary in options:
		# Menu buttons match the title screen; the first option is the room's main action.
		var b := TemporalButton.apply(Button.new(), &"PrimaryButton" if first == null else &"SecondaryButton")
		b.text = option.label
		b.custom_minimum_size.y = 48
		b.pressed.connect(option.callback)
		modal_box.add_child(b)
		if first == null: first = b
	visible_modal = true
	modal.visible = true
	veil.visible = true
	journal_button.disabled = true
	if first != null: first.grab_focus()


func close_panel() -> void:
	visible_modal = false
	modal.visible = false
	veil.visible = false
	journal_button.disabled = device_panel.visible
	var focus := root.get_viewport().gui_get_focus_owner()
	if focus != null and modal.is_ancestor_of(focus): focus.release_focus()


func render(state: Dictionary, role: String, predicted_remaining: float, predicted_sync: float = -1.0) -> void:
	identity.text = "III / THE FINAL FRACTURE  ·  " + ("II / PROFESSOR / FUTURE" if role == "future" else "I / STUDENT / PAST")
	identity.modulate = Color("9edfeb") if role == "future" else Color("edc894")
	timer.visible = true
	timer.text = "%02d:%02d" % [int(ceil(predicted_remaining)) / 60, int(ceil(predicted_remaining)) % 60]
	if state.stage == "DISCOVERY": timer.text = "IDLE"
	elif state.stage == "ENDING": timer.text = "COMPLETE"
	timer.modulate = Color("f0a581") if predicted_remaining <= 10 else Color.WHITE
	reactor_status.text = {"DISCOVERY": "REACTOR IDLE / AWAITING CONFIRMED ARMING", "STAGE_A": "REACTOR ACTIVE / RESTORE POWER", "STAGE_B": "REACTOR ACTIVE / ALIGN BOTH TIMELINES", "STAGE_C": "REACTOR ACTIVE / IDENTITY COMMANDS", "OVERLOAD": "OVERLOAD / RESETTING ATTEMPT", "ENDING": "REACTOR RESOLVED"}.get(state.stage, "WAITING FOR REACTOR")
	var current := ["STAGE_A", "STAGE_B", "STAGE_C", "ENDING"].find(state.stage)
	var parts := PackedStringArray()
	for index in 3:
		parts.append(("[ACTIVE] " if index == current else ("[OK] " if index < current else "")) + ["A POWER", "B ALIGNMENT", "C IDENTITY"][index])
	progress.text = "  /  ".join(parts)
	var text := ""
	match state.stage:
		"DISCOVERY": text = "INVESTIGATE  /  Read your records, then use ARM REACTOR. No timer until confirmation."
		"STAGE_A":
			text = "RESTORE POWER  /  Cycle the three coils using the Professor's routing diagram." if role == "past" else "RESTORE POWER  /  Restore the receiver and inspect the routing diagram. Read its settings to the Student."
		"STAGE_B":
			if not state.anchor: text = "SYNCHRONIZE  /  Professor: cross the rebuilt conduit and calibrate the Signal Anchor."
			elif not state.origin: text = "SYNCHRONIZE  /  Student: the exposed waveform enables the Origin Core. Stabilize it."
			else:
				var seconds: float = maxf(0.0, predicted_sync) if predicted_sync >= 0 else state.sync_remaining
				var sync_text := "WINDOW: %.1fs" % seconds if state.sync_past or state.sync_future else "SYNC WINDOW: 5 SECONDS"
				text = "Both engage your PHASE SWITCH. " + sync_text
				if device_panel.visible: device_feedback.text = "STUDENT: %s\nPROFESSOR: %s\n%s" % ["HELD" if state.sync_past else "READY", "HELD" if state.sync_future else "READY", sync_text]
		"STAGE_C": text = "IDENTITY LOCK  /  Operate your final terminal. Two versions. One identity. One survivor."
		"OVERLOAD": text = "OVERLOAD CONTAINMENT  /  Room C will reset. Your investigation and earlier rooms are safe."
		"ENDING": text = "END OF CHAPTER 0"
	if state.stage == "STAGE_C":
		text += "  /  YOU: %s  ·  PARTNER: %s" % ["LOCKED" if state["locked_" + role] else "WAITING", "LOCKED" if state["locked_" + ("past" if role == "future" else "future")] else "WAITING"]
	objective.text = text


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var width := minf(710.0, screen.x - 270.0)
	header.custom_minimum_size.x = width
	header.size.x = width
	footer.offset_right = minf(780.0, screen.x - 24.0)
	objective.custom_minimum_size.x = footer.offset_right - 60.0
	status.custom_minimum_size.x = objective.custom_minimum_size.x
	device_panel.offset_left = -clampf(screen.x * 0.23, 280.0, 340.0) - 26.0
	device_panel.offset_right = -26
	device_panel.offset_top = 108
	device_panel.offset_bottom = 108
	modal.offset_left = -minf(470.0, screen.x * 0.5 - 28.0)
	modal.offset_right = -modal.offset_left
	modal.offset_top = -minf(320.0, screen.y * 0.5 - 24.0)
	modal.offset_bottom = -modal.offset_top


func open_device(title: String, options: Array) -> void:
	for child in device_box.get_children():
		device_box.remove_child(child)
		child.queue_free()
	device_buttons.clear()
	var heading := text_label(title, 18)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	device_box.add_child(heading)
	device_feedback = text_label("", 18)
	device_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	device_box.add_child(device_feedback)
	for index in options.size():
		var option: Dictionary = options[index]
		var button := make_button("%d / %s" % [index + 1, option.label], func() -> void: device_control_pressed.emit(option.label))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 60
		device_box.add_child(button)
		device_buttons[option.label] = button
	device_hint = text_label("", 16)
	device_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	device_box.add_child(device_hint)
	var close_button := make_button("STEP BACK", func() -> void: device_close_requested.emit())
	device_box.add_child(close_button)
	device_panel.show()
	header.hide()
	footer.hide()
	journal_button.disabled = true
	close_button.grab_focus()


func close_device() -> void:
	device_panel.hide()
	header.show()
	footer.show()
	journal_button.disabled = visible_modal
	var focus := root.get_viewport().gui_get_focus_owner()
	if focus != null and device_panel.is_ancestor_of(focus): focus.release_focus()


func refresh_device(options: Array, state: Dictionary, role: String, pending: bool) -> void:
	for option: Dictionary in options:
		device_buttons[option.label].disabled = option.disabled
	device_hint.text = "Click the machine or use these controls.\n1-3: control / Arrows or D-pad: select\n%s: activate / %s or F: step back" % [Inputs.get_action_label(&"ui_accept"), Inputs.get_action_label(&"ui_cancel")]
	device_feedback.text = "REQUEST SENT / WAITING FOR HOST" if pending else state.notice
	if state.stage == "STAGE_C":
		device_feedback.text = "YOU: %s / PARTNER: %s" % ["LOCKED" if state["locked_" + role] else "WAITING", "LOCKED" if state["locked_" + ("past" if role == "future" else "future")] else "WAITING"]
	if Time.get_ticks_msec() < _error_until: device_feedback.text = _device_error


func show_error(message: String) -> void:
	_device_error = message
	_error_until = Time.get_ticks_msec() + 3000
	status.text = message
	if device_panel.visible: device_feedback.text = message
