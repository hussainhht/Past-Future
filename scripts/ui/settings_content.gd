extends VBoxContainer
## Shared settings pages for the title screen and room pause menus.

const TemporalButton := preload("res://scripts/menu/menu_button.gd")

var audio: AudioDirector
var tabs: TabContainer
var audio_sliders: Dictionary = {}
var mute_buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	tabs = TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.custom_minimum_size = Vector2(560, 320)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_build_audio(_page("Audio"))
	_build_controls(_page("Controls"))
	var hint := _label("Changes are saved automatically.", 17, &"settings_note")
	hint.modulate = Color("99afb2")
	add_child(hint)
	tabs.tab_changed.connect(func(_index: int) -> void:
		var scroll := tabs.get_current_tab_control() as ScrollContainer
		if scroll != null: scroll.scroll_vertical = 0
	)


func add_display_page(fullscreen: Control, motion: Control) -> void:
	var display := _page("Display")
	fullscreen.reparent(display)
	motion.reparent(display)
	tabs.move_child(display.get_parent().get_parent(), 0)
	tabs.current_tab = 0


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	if title == "Controls":
		scroll.focus_mode = Control.FOCUS_ALL
		scroll.gui_input.connect(func(event: InputEvent) -> void:
			if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
				scroll.scroll_vertical += 36 if event.is_action_pressed("ui_down") else -36
				scroll.accept_event()
		)
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


func _build_audio(box: VBoxContainer) -> void:
	box.add_theme_constant_override("separation", 10)
	for category: StringName in AudioDirector.CATEGORIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var label := _label({&"SFX": "Sound effects", &"UI": "Interface"}.get(category, String(category)))
		label.custom_minimum_size.x = 164
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = String(category) + "Volume"
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(150, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(category)))
		slider.tooltip_text = String(category) + " volume"
		row.add_child(slider)
		audio_sliders[category] = slider
		var percent := _label("%d%%" % roundi(slider.value * 100), 21, &"settings_value")
		percent.custom_minimum_size.x = 60
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(percent)
		var mute := CheckButton.new()
		TemporalButton.apply(mute, &"ToggleButton")
		mute.text = "Mute"
		Typography.apply(mute, &"settings_label", 20)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("203338") if state == "hover" else Color.TRANSPARENT
			style.set_content_margin_all(4)
			mute.add_theme_stylebox_override(state, style)
		mute.button_pressed = audio.is_category_muted(category)
		mute.toggled.connect(func(value: bool) -> void: audio.set_category_muted(category, value))
		slider.value_changed.connect(func(value: float) -> void:
			audio.set_category_volume_linear(category, value)
			percent.text = "%d%%" % roundi(value * 100)
			mute.set_pressed_no_signal(audio.is_category_muted(category))
		)
		row.add_child(mute)
		mute_buttons[category] = mute
	var explanation := _label("Master adjusts all audio. Set any slider to 0% to silence it.", 17, &"settings_note")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)


func _build_controls(box: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for heading in ["ACTION", "KEYBOARD / MOUSE", "CONTROLLER"]:
		grid.add_child(_label(heading, 15, &"settings_label"))
	for row in [
		["Move", "WASD / Arrow keys", "Left stick / D-pad"],
		["Run", "Shift", "L3 / LS"],
		["Interact", "F", "Cross / A"],
		["Continue dialogue", "Enter / Click dialogue", "Cross / A"],
		["Pause / Resume", "Esc", "Options / Menu"],
		["Back / Close", "Esc", "Circle / B"],
		["Journal", "J", "—"],
		["Temporal ghost (solo)", "G", "R1 / RB"],
		["Switch role (solo)", "T / On-screen button", "—"],
		["Respawn", "R", "—"],
		["Character studio (lab)", "F2", "Pause menu button"],
	]:
		for cell in row:
			grid.add_child(_label(cell, 17, &"settings_value"))
	var note := _label("Menus: arrow keys / D-pad to navigate, Enter / Cross / A to select.\nAudio sliders: Left / Right to adjust. Controls vary by room and device.", 17, &"settings_note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	box.add_child(_label("FREQUENCY CONSOLE", 15, &"settings_label"))
	var console := _label("Drag a dial to tune it. Use the mouse wheel or arrow keys for fine adjustments, Tab to select the other dial, and Shift for 10 steps. Esc / F steps back.", 17, &"settings_note")
	console.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(console)


func _label(value: String, size: int = 22, role: StringName = &"settings_label") -> Label:
	var label := Label.new()
	label.text = value
	Typography.apply(label, role, size)
	return label
