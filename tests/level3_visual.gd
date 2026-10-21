extends SceneTree
## Brief visual smoke review; run with a renderer, not --headless.

var room: Node3D
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func shot(label: String) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png("res://docs/assets/screenshots/level3/" + label + ".png")
	checks += 1


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/assets/screenshots/level3")
	root.get_node("GameFlowManager").start_room("room_03")
	for i in range(4): await process_frame
	room = current_scene
	await shot("past_discovery")
	room.player.position = Vector3(-7, 0, 5.5)
	room.camera_rig.snap_to_target()
	for i in range(3): await physics_frame
	room.operate("evidence_past")
	await shot("private_evidence")
	room._close()
	room.switch_debug_role()
	await shot("future_discovery")
	# Presentation variants use the exact production sequences; gameplay is tested separately.
	for ending: String in ["trust", "student_override", "professor_override", "paradox"]:
		var s: Dictionary = room.state.duplicate(true)
		s.stage = "ENDING"
		s.ending = ending
		s.solved = true
		room._on_state("puzzle_03_final_fracture", s, 100)
		await create_timer(3.1).timeout
		await shot("ending_" + ending)
		room._ending_tween.kill()
		room._show_conclusion()
		await shot("conclusion_" + ending)
		root.get_node("PuzzleManager").reset_puzzle("puzzle_03_final_fracture")
	print("LEVEL3 VISUAL: PASS (%d rendered screenshots)" % checks)
	quit()
