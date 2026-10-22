extends SceneTree
## Run with a graphics device: godot --path . --script res://tools/render_storage_review.gd
const Maintenance := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const OUTPUT := "res://docs/assets/screenshots/level02"
var room
var puzzles: Node
func _initialize() -> void: run.call_deferred()
func quiet() -> void:
	room.director.stop_dialogue()
	room._pending_lines.clear()
	root.get_node("JournalManager")._ui._toast.hide()
func act(action: String, role: String, payload: Dictionary = {}) -> void:
	var result: Dictionary = puzzles.submit_action(Maintenance.ID, action, payload, role)
	assert(result.status != puzzles.Status.REJECTED, str(result))
func capture(id: String) -> void:
	quiet()
	await create_timer(0.5).timeout
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(OUTPUT.path_join(id + ".png")) == OK)
func run() -> void:
	root.size = Vector2i(1600, 900)
	puzzles = root.get_node("PuzzleManager")
	room = load(Maintenance.DESTINATION).instantiate()
	room.pause_when_unfocused = false
	room.temporal_ghost_enabled = false
	root.add_child(room)
	current_scene = room
	room.set_process_input(false)
	room.ui.inspector.set_process_input(false)
	root.gui_disable_input = true
	await create_timer(0.3).timeout
	quiet()
	act("isolate_service", "past")
	act("charge_battery", "future")
	room.player.position = Vector3(0, 0, -3.7)
	room.get_node("CameraRig").snap_to_target()
	await capture("storage_past")
	act("pickup_storage_item", "past", {"item": "r17"})
	act("place_storage_item", "past", {"bay": 0})
	room._show_device("StorageBay0")
	await capture("storage_weighing")
	room.ui.close_modal()
	act("seal_bay", "past", {"bay": 0})
	room._show_device("StorageBay0")
	await create_timer(.25).timeout
	await capture("storage_lowering")
	await create_timer(1.2).timeout
	await capture("storage_underground")
	room.ui.close_modal()
	room.switch_role()
	quiet()
	room.player.position = room.devices.Archive.global_position + Vector3(0, 0, .5)
	room.get_node("CameraRig").snap_to_target()
	room._show_device("Archive")
	await capture("storage_manifest")
	room.ui.close_modal()
	room._show_device("StorageBay0")
	act("raise_storage_tray", "future", {"bay": 0})
	await create_timer(1.6).timeout
	await capture("storage_retrieval")
	room.ui.close_modal()
	act("retrieve_storage_item", "future", {"bay": 0})
	room._show_device("Archive")
	await capture("storage_installation")
	room.ui.close_modal()
	act("install_component", "future", {"part": "reader"})
	room.player.position = Vector3(0, 0, -3.7)
	room.get_node("CameraRig").snap_to_target()
	await capture("storage_future")
	room.queue_free()
	await process_frame
	await process_frame
	print("STORAGE VISUAL REVIEW: CAPTURED")
	quit()
