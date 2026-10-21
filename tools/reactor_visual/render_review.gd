extends SceneTree
## Actual GL Compatibility captures; no headless image substitutes.
const PREVIEW := preload("res://scenes/level3/reactor_visual/reactor_preview.tscn")
const OUT := "res://assets/environments/level3/reactor_visual/review"
var preview: Node3D
var captures: int = 0
var metrics: Dictionary = {}


func _initialize() -> void: run.call_deferred()


func settle(seconds: float = 4.0) -> void:
	for i in range(ceili(seconds*60)):
		preview.reactor._update_visuals(1.0/60.0)
	for i in range(8): await process_frame


func capture(label: String) -> void:
	preview.refresh()
	await settle()
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	assert(frame.save_png(OUT.path_join(label+".png")) == OK)
	metrics[label] = {
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"node_count": preview.reactor.get_child_count(),
		"phase": preview.reactor.reactor_phase,
		"timeline": preview.reactor.timeline,
		"ending": preview.reactor.ending_id}
	captures += 1


func run() -> void:
	create_timer(100.0).timeout.connect(func() -> void: push_error("REACTOR REVIEW: FAIL watchdog"); quit(1))
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(OUT)
	preview = PREVIEW.instantiate()
	root.add_child(preview)
	current_scene = preview
	preview.reactor.set_process(false)
	preview.reactor.set_charge_ratio(0.8)
	await capture("past_discovery_detail")
	preview.reactor.set_reactor_phase("synchronization")
	await capture("past_synchronization_detail")
	preview.set_timeline("future")
	preview.reactor.trigger_overload()
	await capture("future_overload_detail")
	for ending: String in preview.ENDINGS:
		preview.reactor.play_ending(ending)
		await capture("ending_"+ending)
	preview.reactor.set_reactor_phase("discovery")
	preview.set_timeline("past")
	preview.set_gameplay_camera(true)
	await capture("past_gameplay_entry")
	preview.set_timeline("future")
	await capture("future_gameplay_entry")
	preview.set_gameplay_camera(true, Vector3(-3.2, 0, 0.8))
	await capture("future_gameplay_phase_switch")
	var file := FileAccess.open(OUT.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "captures": metrics}, "\t")+"\n")
	file.close()
	print("REACTOR REVIEW: PASS (%d Compatibility captures)" % captures)
	preview.queue_free()
	await process_frame
	quit()
