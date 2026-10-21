extends CanvasLayer
## The laboratory pause menu, shared by every campaign room.

var panel: ColorRect
var settings: CanvasLayer
var tutorial: CanvasLayer
var studio: Control
var _room: Node
var _audio: Node
var _role: Callable
var _pause: Callable
var _studio_callback: Callable
var _scroll: ScrollContainer
var _content: PanelContainer
var _style: StyleBoxFlat


func _enter_tree() -> void:
	# Preserve the laboratory's public unique-node paths for existing integrations.
	if get_parent().scene_file_path == "res://scenes/world/spawn_area.tscn":
		for node in find_children("*", "Node", true, false):
			if node.unique_name_in_owner: node.owner = get_parent()


func _ready() -> void:
	panel = get_node("Interface/PausePanel")
	_scroll = get_node("Interface/PausePanel/Center/Scroll")
	_content = _scroll.get_node("Panel")
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style = _content.get_theme_stylebox("panel").duplicate()
	_content.add_theme_stylebox_override("panel", _style)
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


func button(id: String) -> Button:
	return find_child(id, true, false) as Button


func label(id: String) -> Label:
	return find_child(id, true, false) as Label


func configure(room: Node, audio: Node, role: Callable, pause: Callable, reset: Callable, menu: Callable, existing_tutorial: CanvasLayer = null, character_studio: Callable = Callable()) -> void:
	_room = room
	_audio = audio
	_role = role
	_pause = pause
	_studio_callback = character_studio
	button("ResumeButton").pressed.connect(pause.bind(false))
	button("MenuButton").pressed.connect(menu)
	button("ResetSoloButton").pressed.connect(reset)
	button("ResetSoloButton").visible = not NetworkManager.in_game
	button("InterferenceButton").hide()
	button("QuitGameButton").pressed.connect(func() -> void: get_tree().quit())
	settings = preload("res://scripts/ui/settings_overlay.gd").new()
	add_child(settings)
	settings.configure(audio)
	button("SettingsButton").pressed.connect(func() -> void: panel.hide(); settings.open())
	settings.closed.connect(func() -> void: panel.show(); button("SettingsButton").grab_focus())
	tutorial = existing_tutorial
	if tutorial == null:
		tutorial = load("res://scenes/ui/tutorial_popup.tscn").instantiate()
		add_child(tutorial)
		tutorial.configure(audio)
	tutorial.closed.connect(func(_dismissed: bool) -> void:
		if tutorial.from_pause: panel.show(); button("HowToPlayButton").grab_focus())
	button("HowToPlayButton").pressed.connect(func() -> void: panel.hide(); tutorial.open(_role.call(), true))
	button("CharacterButton").pressed.connect(open_studio)
	_audio.bind_ui(panel)


func present(open: bool) -> void:
	if not open and tutorial != null and tutorial.is_open() and tutorial.from_pause: tutorial.close_silently()
	panel.visible = open
	settings.hide()
	if open:
		button("QuitGameButton").hide()
		label("PauseTitle").text = "A moment between years"
		label("PauseDescription").text = "The session continues for your partner." if NetworkManager.in_game else "Take your time. This timeline will be here."
		button("ResumeButton").grab_focus()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null and panel.is_ancestor_of(focus): focus.release_focus()
	_layout.call_deferred()


func handle_input(event: InputEvent) -> bool:
	if settings.handle_input(event) or tutorial.handle_input(event): return true
	if is_instance_valid(studio):
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			studio.request_close()
		get_viewport().set_input_as_handled()
		return true
	return false


func open_studio() -> void:
	if _studio_callback.is_valid():
		_studio_callback.call()
		return
	panel.hide()
	studio = load("res://scenes/characters/%s_3d_studio.tscn" % ("professor" if _role.call() == "future" else "student")).instantiate()
	get_node("Interface").add_child(studio)
	studio.close_requested.connect(func() -> void: studio = null; panel.show(); button("CharacterButton").grab_focus())


func _layout() -> void:
	if _scroll == null: return
	var size := get_viewport().get_visible_rect().size
	var compact := size.y < 650
	_style.content_margin_top = 18.0 if compact else 36.0
	_style.content_margin_bottom = _style.content_margin_top
	_content.get_node("Content").add_theme_constant_override("separation", 8 if compact else 12)
	label("PauseTitle").add_theme_font_size_override("font_size", 28 if compact else 34)
	label("PauseDescription").add_theme_font_size_override("font_size", 17 if compact else 20)
	for node in panel.find_children("*", "Button", true, false):
		node.custom_minimum_size.y = 42 if compact else (60 if node == button("ResumeButton") else 54)
	var height := minf(_content.get_combined_minimum_size().y, size.y - 32)
	_scroll.custom_minimum_size = Vector2(minf(520, size.x - 32), height)
	_scroll.size = _scroll.custom_minimum_size
