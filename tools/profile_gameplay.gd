extends SceneTree
## Repeatable rendered frame and script-cost samples. PROFILE_OUTPUT saves machine-local results.

var results: Array[Dictionary] = []
var room

func _initialize() -> void: run.call_deferred()

func tick(count: int) -> void:
	for index in count:
		await process_frame
		RenderingServer.force_draw()

func stats(samples: Array[float]) -> Dictionary:
	samples.sort()
	var total := 0.0
	for sample in samples: total += sample
	return {"mean_ms": snappedf(total / samples.size(), .001), "p50_ms": snappedf(samples[samples.size() / 2], .001),
		"p95_ms": snappedf(samples[mini(samples.size() - 1, int(samples.size() * .95))], .001), "max_ms": snappedf(samples.back(), .001)}

func script_cost(callback: Callable, count: int = 40) -> Dictionary:
	var samples: Array[float] = []
	for index in count:
		var start := Time.get_ticks_usec()
		callback.call()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	return stats(samples)

func ghost_geometry() -> Dictionary:
	var vertices := 0
	var outside := 0
	var maximum_radius := 0.0
	for batch: MeshInstance3D in room.temporal_ghost._batches:
		if batch.mesh == null: continue
		for surface in batch.mesh.get_surface_count():
			for vertex: Vector3 in batch.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				vertices += 1
				var offset: Vector3 = batch.global_transform * vertex - room.temporal_ghost.echo_position
				var radius := Vector2(offset.x, offset.z).length()
				maximum_radius = maxf(maximum_radius, radius)
				if radius > room.temporal_ghost.RADIUS + .001: outside += 1
	return {"vertices": vertices, "vertices_outside_radius": outside, "maximum_radius": maximum_radius}

func sample(name: String, ghost_enabled: bool) -> void:
	room.temporal_ghost.enabled = ghost_enabled
	room.temporal_ghost.refresh()
	await tick(60)
	var elapsed: Array[float] = []
	var process: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 180:
		await process_frame
		RenderingServer.force_draw()
		var now := Time.get_ticks_usec()
		elapsed.append((now - previous) / 1000.0)
		previous = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var result := {"case": name, "frame": stats(elapsed), "process": stats(process),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"ghost_sources": room.temporal_ghost._sources.size(), "ghost_copies": room.temporal_ghost._copies.size(),
		"ghost_geometry": ghost_geometry()}
	results.append(result)
	print(JSON.stringify(result))

func run() -> void:
	root.size = Vector2i(1600,900)
	root.gui_disable_input = true
	root.get_node("CinematicTransitionManager").enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.render_loop_enabled = false
	for level in ["maintenance_corridor", "spawn_area"]:
		room = load("res://scenes/world/%s.tscn" % level).instantiate()
		room.pause_when_unfocused = false
		var baseline_script := OS.get_environment("PROFILE_GHOST_SCRIPT")
		if not baseline_script.is_empty(): room.temporal_ghost_enabled = false
		root.add_child(room)
		current_scene = room
		room.set_process_input(false)
		if level == "maintenance_corridor":
			room.director.stop_dialogue()
			room._pending_lines.clear()
			room._positions.future = Vector3(1.2,.05,1.6)
			room.player.position = Vector3(-2.5,.05,3.8)
		else:
			room.level_travel_enabled = false
			room.gameplay.get_node("StudentDiscovery").enabled = false
			room.gameplay.get_node("FutureDiscovery").enabled = false
			room.gameplay.director.stop_dialogue()
			room.gameplay._positions.future = Vector3(1,.05,-5.5)
			room.player.position = Vector3(-2,.05,-3.3)
		if not baseline_script.is_empty():
			room.temporal_ghost = load(baseline_script).new()
			room.add_child(room.temporal_ghost)
			var roots: Array[Node3D] = []
			if level == "maintenance_corridor": roots.append(room.get_node("Layout"))
			else:
				roots.append(room.get_node("SignalLab/Layout"))
				for prop in room.get_node("Actors").get_children():
					if prop != room.player: roots.append(prop.get_node("Visual"))
			room.temporal_ghost.configure(room, roots, room._temporal_ghost_context)
			var baseline_shader := OS.get_environment("PROFILE_GHOST_SHADER")
			if not baseline_shader.is_empty():
				for material in room.temporal_ghost._materials: material.shader = load(baseline_shader)
		room.get_node("CameraRig").snap_to_target()
		await sample(level + "_ghost_off", false)
		await sample(level + "_ghost_on", true)
		var scripts := {"case": level + "_script_cost", "ghost_sync": script_cost(room.temporal_ghost._sync_visuals)}
		if level == "maintenance_corridor":
			scripts.wayfinding = script_cost(room._refresh_wayfinding.bind(1.0 / 60.0))
			room._show_device("Service")
			await tick(60)
			scripts.record_layout = script_cost(room.ui.inspector._layout_record)
			room.ui.close_modal()
		results.append(scripts)
		print(JSON.stringify(scripts))
		room.queue_free()
		await tick(10)
	var output := OS.get_environment("PROFILE_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "\t"))
	print("GAMEPLAY PROFILE: COMPLETE")
	quit()
