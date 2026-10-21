extends SceneTree
## Actual Godot gameplay and choice captures. Run with a graphics device.
const Rules = preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const OUTPUT := "res://docs/level02/screenshots"
var room
var puzzles: Node
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> void:
	room.set_paused(false)
	await create_timer(0.45).timeout
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png")) == OK)
func quiet() -> void:
	room.director.stop_dialogue()
	room._pending_lines.clear()
	await create_timer(.45).timeout
func act(action: String, who: String, payload: Dictionary = {}) -> void:
	var result: Dictionary = puzzles.submit_action(Rules.ID, action, payload, who)
	assert(result.status != puzzles.Status.REJECTED, str(result))
func restore_power() -> void:
	act("isolate_service", "past")
	act("charge_battery", "future")
func finish(recording: String) -> void:
	preload("res://tests/storage_fixture.gd").repair(root.get_node("PuzzleManager"))
	act("read_archive", "future")
	if recording == "preserved":
		act("repair_bypass", "past")
		act("repair_bypass", "future")
		act("preserve_recording", "future")
	else:
		act("extract_cell", "future")
		act("repair_bypass", "past")
		act("repair_bypass", "future")
	act("authorize_core", "past", {"code":"3142"})
	act("release_door", "future")
	act("arm_anchor", "past")
	act("arm_anchor", "future")
func run() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	puzzles = root.get_node("PuzzleManager")
	room = load(Rules.DESTINATION).instantiate()
	room.pause_when_unfocused = false
	root.add_child(room)
	current_scene = room
	# Capture automation must not react to keyboard input meant for the editor or terminal.
	room.set_process_input(false)
	room.ui.inspector.set_process_input(false)
	root.gui_disable_input = true
	await create_timer(.3).timeout
	await quiet()
	await capture("past_entry")
	room._show_device("Service")
	await capture("service_lever")
	room.ui.close_modal()
	room.switch_role()
	await quiet()
	await capture("future_entry")
	room.player.position = Vector3(1.2,0,3.3)
	room.get_node("CameraRig").snap_to_target()
	await capture("future_passage")
	act("isolate_service", "past")
	room._show_device("ReserveFuture")
	await capture("reserve_choice")
	room.ui.close_modal()
	restore_power()
	await create_timer(1.3).timeout
	await quiet()
	await capture("future_powered_passage")
	room.player.position = Vector3(0,0,-4.1)
	room.get_node("CameraRig").snap_to_target()
	await quiet()
	await capture("future_records")
	preload("res://tests/storage_fixture.gd").repair(root.get_node("PuzzleManager"))
	act("read_archive", "future")
	await quiet()
	room.player.position = Vector3(5.4,0,-5.2)
	room.get_node("CameraRig").snap_to_target()
	room._show_device("Recorder")
	await capture("recorder_choice")
	room.ui.close_modal()
	finish("preserved")
	await capture("ending_preserved")
	room.ending_screen.hide()
	room.player.position = Vector3(0,0,-11.1)
	room.get_node("CameraRig").snap_to_target()
	await quiet()
	await capture("core_stable")
	puzzles.reset_puzzle(Rules.ID)
	restore_power()
	finish("erased")
	await capture("ending_erased")
	room.queue_free()
	await process_frame
	await process_frame
	print("MAINTENANCE VISUAL REVIEW: CAPTURED (eleven actual gameplay/physical-device images)")
	quit()
