extends SceneTree
const OUTPUT := "res://docs/interactions/screenshots"
var room
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> void:
	room._set_paused(false)
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png")) == OK)
func run() -> void:
	root.size = Vector2i(1600, 900)
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	room = load("res://scenes/world/spawn_area.tscn").instantiate()
	room.pause_when_unfocused = false
	room.level_travel_enabled = false
	root.add_child(room)
	current_scene = room
	room.set_process_input(false)
	var game = room.gameplay
	game.get_node("StudentDiscovery").enabled = false
	game.get_node("FutureDiscovery").enabled = false
	game.adapter.link_sequence_id = &""
	game.physical_devices.inspector.set_process_input(false)
	var puzzles := root.get_node("PuzzleManager")
	puzzles.submit_action("puzzle_01_frequency", "acquire_radio", {"radio_role":"past"}, "past")
	room.player.position = Vector3(0,0,-5.6)
	await create_timer(.25).timeout
	game.physical_devices.open_frequency(room.player, "past")
	game.physical_devices.inspector.adjust_dial(16)
	game.physical_devices.inspector.press_control("Calibrate signal")
	await capture("frequency_retry")
	game.physical_devices.inspector.adjust_dial(1)
	await capture("frequency_dial")
	game.physical_devices.inspector.press_control("Calibrate signal")
	await capture("frequency_locked")
	game.close_overlays()
	room.timeline = "Future"
	room._apply_timeline()
	game.physical_devices.open_log(game.clue.research_text, room.player, "future")
	await capture("recovered_console_record")
	game.close_overlays()
	room.queue_free()
	await process_frame
	await process_frame
	print("PHYSICAL DEVICE REVIEW: PASS (four actual console captures)")
	quit()
