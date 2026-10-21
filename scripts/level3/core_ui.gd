extends CanvasLayer
## Native scalable HUD and skippable terminal/document panels.

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


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := PanelContainer.new()
	header.position = Vector2(20, 16)
	header.size = Vector2(1020, 108)
	header.add_theme_stylebox_override("panel", panel_style())
	root.add_child(header)
	var rows := VBoxContainer.new()
	header.add_child(rows)
	identity = text_label("III / THE FINAL FRACTURE", 26)
	rows.add_child(identity)
	status = text_label("", 20)
	status.custom_minimum_size.x = 940
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	timer = text_label("", 38)
	timer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer.position = Vector2(-235, 20)
	timer.size = Vector2(215, 55)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(timer)
	var footer := PanelContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 20
	footer.offset_right = -20
	footer.offset_top = -145
	footer.offset_bottom = -14
	footer.add_theme_stylebox_override("panel", panel_style())
	root.add_child(footer)
	var bottom := VBoxContainer.new()
	footer.add_child(bottom)
	objective = text_label("", 23)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(objective)
	var controls := HBoxContainer.new()
	bottom.add_child(controls)
	journal_button = make_button("JOURNAL", func() -> void: JournalManager.toggle_journal())
	controls.add_child(journal_button)
	debug_button = make_button("DEV: OTHER TIMELINE", func() -> void: pass)
	controls.add_child(debug_button)
	debug_button.visible = false
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
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("f4eedf"))
	return l


func make_button(value: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 44
	b.add_theme_font_size_override("font_size", 20)
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
		var b := make_button(option.label, option.callback)
		modal_box.add_child(b)
		if first == null: first = b
	visible_modal = true
	modal.visible = true
	veil.visible = true
	if first != null: first.grab_focus()


func close_panel() -> void:
	visible_modal = false
	modal.visible = false
	veil.visible = false


func render(state: Dictionary, role: String, predicted_remaining: float) -> void:
	identity.text = "III / THE FINAL FRACTURE  ·  " + ("II / PROFESSOR / FUTURE" if role == "future" else "I / STUDENT / PAST")
	identity.modulate = Color("9edfeb") if role == "future" else Color("edc894")
	timer.visible = state.stage in ["STAGE_A", "STAGE_B", "STAGE_C", "OVERLOAD"]
	timer.text = "%02d:%02d" % [int(ceil(predicted_remaining)) / 60, int(ceil(predicted_remaining)) % 60]
	timer.modulate = Color("f0a581") if predicted_remaining <= 10 else Color.WHITE
	var text := ""
	match state.stage:
		"DISCOVERY": text = "INVESTIGATE  /  Read your records, then use ARM REACTOR. No timer until confirmation."
		"STAGE_A":
			text = "RESTORE POWER  /  Cycle the three coils using the Professor's routing diagram." if role == "past" else "RESTORE POWER  /  Restore the receiver and inspect the routing diagram. Read its settings to the Student."
		"STAGE_B":
			if not state.anchor: text = "SYNCHRONIZE  /  Professor: cross the rebuilt conduit and calibrate the Signal Anchor."
			elif not state.origin: text = "SYNCHRONIZE  /  Student: the exposed waveform enables the Origin Core. Stabilize it."
			else: text = "SYNCHRONIZE  /  Both use your PHASE SWITCH within 5 seconds. Window: %.1fs" % state.sync_remaining
		"STAGE_C": text = "IDENTITY LOCK  /  Operate your final terminal. Two versions. One identity. One survivor."
		"OVERLOAD": text = "OVERLOAD CONTAINMENT  /  Room C will reset. Your investigation and earlier rooms are safe."
		"ENDING": text = "END OF CHAPTER 0"
	if state.stage == "STAGE_C":
		text += "  /  YOU: %s  ·  PARTNER: %s" % ["LOCKED" if state["locked_" + role] else "WAITING", "LOCKED" if state["locked_" + ("past" if role == "future" else "future")] else "WAITING"]
	objective.text = text
