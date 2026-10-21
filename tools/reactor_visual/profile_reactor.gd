extends SceneTree
## Uncapped frame timing for the standalone preview on the available adapter.
const PREVIEW := preload("res://scenes/level3/reactor_visual/reactor_preview.tscn")


func _initialize() -> void: run.call_deferred()


func run() -> void:
	create_timer(45.0).timeout.connect(func() -> void: push_error("REACTOR PROFILE: FAIL watchdog"); quit(1))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1600, 900)
	var preview := PREVIEW.instantiate()
	root.add_child(preview)
	preview.set_timeline("future")
	preview.reactor.trigger_overload()
	preview._controls.hide()
	for i in range(45): await process_frame
	preview.reactor.set_process(false)
	var samples: Array[float] = []
	var process_samples: Array[float] = []
	for i in range(150):
		var begin := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec()-begin)/1000.0)
		var update_begin := Time.get_ticks_usec()
		preview.reactor._update_visuals(1.0/60.0)
		process_samples.append((Time.get_ticks_usec()-update_begin)/1000.0)
	samples.sort()
	process_samples.sort()
	var data := {"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "resolution": "1600x900",
		"scenario": "Future overload, standalone preview floor and station proxies, controls hidden, uncapped",
		"sample_count": samples.size(), "frame_median_ms": samples[75], "frame_p95_ms": samples[142],
		"module_update_median_ms": process_samples[75], "module_update_p95_ms": process_samples[142],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	var file := FileAccess.open("res://assets/environments/level3/reactor_visual/review/profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t")+"\n")
	file.close()
	print("REACTOR PROFILE: PASS " + JSON.stringify(data))
	preview.queue_free()
	await process_frame
	quit()
