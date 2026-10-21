extends SceneTree
## Focused regression: actual pause buttons and production scenes, no solved prerequisites.
var flow: Node
var pm: Node
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DEMO NAVIGATION FAILED: " + message)


func settle() -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while flow.is_transitioning() and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 5: await physics_frame
	check(not flow.is_transitioning(), "transition completes")


func pause_menu() -> Node:
	var menu: Node = current_scene.pause_menu
	menu._pause.call(true)
	return menu


func _run() -> void:
	flow = root.get_node("GameFlowManager")
	pm = root.get_node("PuzzleManager")
	pm.log_rejections = false
	check(flow.start_room("room_01"), "real laboratory loads")
	await settle()
	var menu := pause_menu()
	check(menu.button("SkipLevelButton").visible and not menu.button("SkipLevelButton").disabled, "skip is visible and enabled")
	check(menu.button("SkipLevelButton").text == "SKIP TO LEVEL 2", "skip names target level")
	menu.button("SkipLevelButton").pressed.emit()
	await settle()
	check(flow.get_current_room_id() == "room_02", "laboratory skip enters real maintenance room")
	check(not pm.is_solved("puzzle_01_frequency"), "skip does not fabricate laboratory completion")
	check(current_scene.radio.has_established_link(), "demo radio works without solving laboratory")
	var result: Dictionary = pm.submit_action("puzzle_02_maintenance", "arrive", {}, "past")
	check(result.get("reason") != "prerequisite_not_met", "maintenance accepts actions with unsolved laboratory")
	menu = pause_menu()
	menu.button("SkipLevelButton").pressed.emit()
	await settle()
	check(flow.get_current_room_id() == "room_03", "maintenance skip enters real final fracture")
	check(pm.get_state("puzzle_03_final_fracture").stage == "DISCOVERY", "reactor begins unsolved")
	menu = pause_menu()
	check(menu.button("SkipLevelButton").text == "FINISH DEMO", "last level replaces skip with finish")
	menu.button("SkipLevelButton").pressed.emit()
	check(menu._view == "finish" and flow.get_current_room_id() == "room_03", "finish asks for confirmation")
	menu.button("CancelFinishButton").pressed.emit()
	menu.button("ResetSoloButton").pressed.emit()
	await settle()
	check(flow.get_current_room_id() == "room_03" and pm.get_state("puzzle_03_final_fracture").stage == "DISCOVERY", "restart stays in current level")
	pm.offline_role = "future"
	for id in ["room_01", "room_02", "room_03"]:
		menu = pause_menu()
		menu.button("LevelSelectButton").pressed.emit()
		var index: int = flow.DEMO_ROOMS.find(id) + 1
		menu.button("Level%dButton" % index).pressed.emit()
		await settle()
		check(flow.get_current_room_id() == id, "level select enters " + id)
		check(pm.get_local_role() == "future", "direct entry preserves Future assignment")
		check(current_scene.scene_file_path == flow.get_room(id).shared_scene, "production scene selected")
	check(not pm.is_solved("puzzle_01_frequency"), "level selection still does not solve earlier puzzles")
	for dimensions in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		for i in 5: await process_frame
		var hud: Node = current_scene.ui
		hud.render(pm.get_state("puzzle_03_final_fracture"), "future", 12.0)
		check(hud.header.size.y <= 54, "compact header at " + str(dimensions))
		check(hud.pause_button.get_global_rect().end.x <= dimensions.x, "pause stays on screen")
		check(hud.guidance._sidebar.get_global_rect().position.y >= hud.header.get_global_rect().end.y, "objective clears header")
	menu = pause_menu()
	menu.button("ResumeButton").pressed.emit()
	check(not menu.panel.visible, "resume closes pause menu")
	menu = pause_menu()
	menu.button("SkipLevelButton").pressed.emit()
	menu.button("ConfirmFinishButton").pressed.emit()
	for i in 10: await process_frame
	check(current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", "finish returns to existing menu")
	check(not flow.demo_radio_link and not pm.gameplay_suspended, "finish clears temporary access and timers")
	current_scene.free()
	print("DEMO NAVIGATION: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
