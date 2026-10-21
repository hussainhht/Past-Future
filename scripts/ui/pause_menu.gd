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
var _submenu: VBoxContainer
var _view := ""
var _menu: Callable
const TemporalButton := preload("res://scripts/menu/menu_button.gd")


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
	_menu = menu
	_studio_callback = character_studio
	button("ResumeButton").pressed.connect(pause.bind(false))
	button("MenuButton").pressed.connect(func() -> void:
		if NetworkManager.in_game and NetworkManager.role == "future": _menu.call()
		else: GameFlowManager.end_demo())
	button("ResetSoloButton").text = "RESTART LEVEL"
	button("ResetSoloButton").pressed.connect(func() -> void: _navigate(GameFlowManager.get_current_room_id()))
	var content := _content.get_node("Content")
	var restart := button("ResetSoloButton")
	content.move_child(restart, content.get_node("ResumeButton").get_index() + 1)
	var skip := _add_button(content, "SkipLevelButton", "SKIP LEVEL", _skip_level)
	content.move_child(skip, restart.get_index() + 1)
	var select := _add_button(content, "LevelSelectButton", "LEVEL SELECT", _show_levels)
	content.move_child(select, skip.get_index() + 1)
	var finish := _add_button(content, "FinishDemoButton", "FINISH DEMO", _confirm_finish)
	content.move_child(finish, button("SettingsButton").get_index() + 1)
	content.move_child(button("MenuButton"), finish.get_index() + 1)
	_submenu = VBoxContainer.new()
	_submenu.add_theme_constant_override("separation", 8)
	content.add_child(_submenu)
	_submenu.hide()
	label("PauseDescription").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		_show_main()
		button("QuitGameButton").hide()
		label("PauseTitle").text = "A moment between years"
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
	if panel.visible and not _view.is_empty() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_show_main()
		button("LevelSelectButton").grab_focus()
		get_viewport().set_input_as_handled()
		return true
	return false


func _add_button(parent: Node, id: String, text: String, callback: Callable) -> Button:
	var b := TemporalButton.apply(Button.new())
	b.name = id
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _show_main() -> void:
	_view = ""
	_submenu.hide()
	for child in _content.get_node("Content").get_children():
		if child is Button: child.show()
	button("InterferenceButton").hide()
	button("QuitGameButton").hide()
	var last := GameFlowManager.get_current_room_id() == "room_03"
	button("SkipLevelButton").text = "FINISH DEMO" if last else ("SKIP TO LEVEL 3" if GameFlowManager.get_current_room_id() == "room_02" else "SKIP TO LEVEL 2")
	button("FinishDemoButton").visible = not last
	var reason: String = GameFlowManager.demo_navigation_reason(GameFlowManager.get_current_room_id())
	for id in ["ResetSoloButton", "SkipLevelButton", "LevelSelectButton", "FinishDemoButton"]:
		button(id).disabled = not reason.is_empty()
		button(id).tooltip_text = GameFlowManager.get_reason_message(reason) if not reason.is_empty() else ""
	_style.border_color = LabUI.FUTURE_ACCENT if _role.call() == "future" else LabUI.PAST_ACCENT
	label("PauseTitle").text = "A moment between years"
	label("PauseDescription").text = "Only the host can change levels. Your partner's session continues." if NetworkManager.in_game and NetworkManager.role == "future" else "Take your time. Choose where this timeline continues."
	_layout.call_deferred()


func _open_view(view: String, title: String, description: String) -> void:
	_view = view
	for child in _content.get_node("Content").get_children():
		if child is Button: child.hide()
	for child in _submenu.get_children():
		_submenu.remove_child(child)
		child.queue_free()
	label("PauseTitle").text = title
	label("PauseDescription").text = description
	_submenu.show()
	_scroll.scroll_vertical = 0


func _show_levels() -> void:
	_open_view("levels", "Choose a timeline", "Enter any level with its own puzzle ready to play.")
	for index in 3:
		var id: String = GameFlowManager.DEMO_ROOMS[index]
		_add_button(_submenu, "Level%dButton" % (index + 1), "LEVEL %d / %s" % [index + 1, GameFlowManager.get_room_display_name(id).to_upper()], _navigate.bind(id))
	_add_button(_submenu, "BackButton", "BACK", func() -> void: _show_main(); button("LevelSelectButton").grab_focus())
	_submenu.get_child(0).grab_focus()
	_layout.call_deferred()


func _skip_level() -> void:
	match GameFlowManager.get_current_room_id():
		"room_01": _navigate("room_02")
		"room_02": _navigate("room_03")
		"room_03": _confirm_finish()


func _navigate(destination: String) -> void:
	var reason: String = GameFlowManager.demo_navigation_reason(destination)
	if reason.is_empty():
		_pause.call(false)
		reason = GameFlowManager.navigate_demo(destination)
	if not reason.is_empty(): label("PauseDescription").text = GameFlowManager.get_reason_message(reason)


func _confirm_finish() -> void:
	_open_view("finish", "Finish this demo?", "Return to the main menu and clear this session? Unsolved puzzles stay unsolved.")
	_add_button(_submenu, "ConfirmFinishButton", "FINISH DEMO", GameFlowManager.end_demo)
	var back := _add_button(_submenu, "CancelFinishButton", "BACK", func() -> void: _show_main(); button("SkipLevelButton").grab_focus())
	back.grab_focus()
	_layout.call_deferred()


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
	_style.content_margin_top = 16.0 if compact else 24.0
	_style.content_margin_bottom = _style.content_margin_top
	_content.get_node("Content").add_theme_constant_override("separation", 8 if compact else 12)
	label("PauseTitle").add_theme_font_size_override("font_size", 28 if compact else 34)
	label("PauseDescription").add_theme_font_size_override("font_size", 17 if compact else 20)
	for node in panel.find_children("*", "Button", true, false):
		node.custom_minimum_size.y = 42 if compact else 46
		node.add_theme_font_size_override("font_size", 16 if compact else 18)
	var height := minf(_content.get_combined_minimum_size().y, size.y - 32)
	_scroll.custom_minimum_size = Vector2(minf(520, size.x - 32), height)
	_scroll.size = _scroll.custom_minimum_size
