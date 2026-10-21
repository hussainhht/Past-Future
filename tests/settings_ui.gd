extends SceneTree
## Shared settings, room input locks, audio bus wiring and compact HUD layout.

var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func tick() -> void:
	for index in 8: await process_frame


func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await create_timer(0.2).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/past-future-" + name + ".png")


func audio_checks(content: VBoxContainer, director: AudioDirector) -> void:
	# Exercise real slider and mute signals without changing the user's saved preferences.
	director.persist_preferences = false
	for category: StringName in AudioDirector.CATEGORIES:
		var index := AudioServer.get_bus_index(category)
		var original_volume := AudioServer.get_bus_volume_db(index)
		var original_mute := AudioServer.is_bus_mute(index)
		var slider: HSlider = content.audio_sliders[category]
		slider.value = 0.37
		check(is_equal_approx(director.get_category_volume_linear(category), 0.37), String(category) + " slider controls its actual bus")
		var mute: CheckButton = content.mute_buttons[category]
		mute.button_pressed = true
		check(director.is_category_muted(category), String(category) + " mute controls its actual bus")
		mute.button_pressed = false
		check(is_equal_approx(director.get_category_volume_linear(category), 0.37), "Unmute restores the chosen volume")
		slider.value = 0.0
		check(director.is_category_muted(category) and mute.button_pressed, "Zero volume also updates mute")
		check(db_to_linear(AudioServer.get_bus_volume_db(index)) <= 0.00011, "Zero stores a silent level for reopening settings")
		slider.value = 0.6
		check(not director.is_category_muted(category) and not mute.button_pressed, "Raising the slider unmutes")
		AudioServer.set_bus_volume_db(index, original_volume)
		AudioServer.set_bus_mute(index, original_mute)


func run() -> void:
	var menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.audio.persist_preferences = false
	menu._open_page("SettingsPage")
	await tick()
	var content: VBoxContainer = menu.pages.get_node("SettingsPage/SettingsContent")
	check(content.tabs.get_tab_count() == 3, "Title menu offers Display, Audio and Controls")
	check(menu.fullscreen_toggle.is_visible_in_tree(), "Display settings still open first")
	content.tabs.current_tab = 1
	await tick()
	audio_checks(content, menu.audio)
	await capture("menu-audio-settings")
	content.tabs.current_tab = 2
	await tick()
	check(content.tabs.get_current_tab_control().name == "Controls", "Controls tab is accessible in the title menu")
	var controls_scroll: ScrollContainer = content.tabs.get_current_tab_control()
	controls_scroll.grab_focus()
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	root.push_input(down, true)
	await tick()
	check(controls_scroll.scroll_vertical > 0, "Keyboard and controller navigation can scroll the controls reference")
	controls_scroll.scroll_vertical = 0
	await capture("menu-controls-settings")
	menu.queue_free()
	await tick()
	for scene: String in ["res://scenes/world/spawn_area.tscn", "res://scenes/world/maintenance_corridor.tscn", "res://scenes/rooms/temporal_core.tscn"]:
		root.get_node("PuzzleManager").begin_session()
		var room = load(scene).instantiate()
		if "pause_when_unfocused" in room: room.pause_when_unfocused = false
		root.add_child(room)
		current_scene = room
		await tick()
		room.settings_overlay.content.audio.persist_preferences = false
		var is_lab := scene.contains("spawn_area")
		var is_core := scene.contains("temporal_core")
		if is_lab:
			room.gameplay.director.stop_dialogue()
			room._set_paused(false)
			check(not room.has_node("HUD/Interface/Footer"), "Laboratory has no bottom control legend")
			check(not room.gameplay.objective.visible, "Objective is presented once in the guide")
			for dimensions in [Vector2i(1600,900), Vector2i(960,540)]:
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
				root.content_scale_size = Vector2i.ZERO
				root.size = dimensions
				await tick()
				var header: Control = room.get_node("HUD/Interface/Header")
				check(header.get_global_rect().encloses(room.get_node("%PauseButton").get_global_rect()), "Header buttons fit at " + str(dimensions))
				check(room.get_node("%CharacterButton").get_parent() == room.get_node("%ResumeButton").get_parent(), "Character studio lives in pause menu")
				await capture("hud-%d" % dimensions.x)
			room._set_paused(true)
			room.get_node("%SettingsButton").pressed.emit()
		elif is_core:
			room._close()
			var escape := InputEventAction.new()
			escape.action = "ui_cancel"
			escape.pressed = true
			room._unhandled_input(escape)
			for button in room.pause_menu.panel.find_children("", "Button", true, false):
				if button.text == "SETTINGS": button.pressed.emit()
		else:
			room.set_paused(true)
			for button in room.pause_screen.find_children("", "Button", true, false):
				if button.text == "SETTINGS": button.pressed.emit()
		await tick()
		check(room.settings_overlay.visible, scene + " opens settings from pause")
		check(room.is_gameplay_paused() and not room.player.controls_enabled, "Settings keep gameplay input blocked")
		check(not root.get_node("JournalManager").can_open(), "Journal cannot open over settings")
		var settings_panel: Control = room.settings_overlay.content.get_parent().get_parent()
		check(root.get_visible_rect().encloses(settings_panel.get_global_rect()), "Settings fit the minimum viewport")
		await capture("pause-audio-settings")
		room.settings_overlay.content.tabs.current_tab = 1
		await tick()
		await capture("pause-controls-settings")
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		if is_core: room._unhandled_input(cancel)
		else: room._input(cancel)
		check(not room.settings_overlay.visible and room.is_gameplay_paused(), "Back returns to pause without resuming gameplay")
		if is_lab: room._set_paused(false)
		elif is_core: room._close()
		else: room.set_paused(false)
		check(not room.is_gameplay_paused(), "Resume leaves settings and pause")
		room.queue_free()
		await tick()
	await create_timer(0.2).timeout
	print("SETTINGS UI: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
