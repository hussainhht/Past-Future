extends CanvasLayer
## Opens over an already paused room; closing returns to its pause menu.

const TemporalButton := preload("res://scripts/menu/menu_button.gd")

signal closed

var content: VBoxContainer
var back_button: Button


func configure(audio: AudioDirector) -> void:
	layer = 80
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.03, 0.045, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	TemporalButton.theme_for(dim)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("122028")
	style.border_color = Color("627f80")
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	content = preload("res://scripts/ui/settings_content.gd").new()
	content.audio = audio
	box.add_child(content)
	back_button = TemporalButton.apply(Button.new(), &"SecondaryButton", true)
	back_button.text = "BACK TO PAUSE MENU"
	back_button.custom_minimum_size.y = 54
	back_button.pressed.connect(close)
	box.add_child(back_button)
	hide()


func open() -> void:
	show()
	content.tabs.get_tab_bar().grab_focus()


func close() -> void:
	hide()
	closed.emit()


func handle_input(event: InputEvent) -> bool:
	if not visible: return false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	return true
