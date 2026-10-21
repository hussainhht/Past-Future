extends SceneTree
## Physics equivalence and production-room camera review for the decorative layer.
## --render-review adds six exact gameplay-camera captures and a draw-call sample.
const World := preload("res://scripts/level3/core_world.gd")
const Art := preload("res://scenes/level3/environment/laboratory_environment.tscn")
const OUT := "res://docs/assets/screenshots/level3/environment"
var checks := 0
var failures := 0
var room: Node3D
var metrics := {}


func _initialize() -> void: run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LEVEL3 ENVIRONMENT FAILED: " + message)


func physics_signature(world: Node) -> Array:
	var result := []
	for shape: CollisionShape3D in world.find_children("*", "CollisionShape3D", true, false):
		result.append([shape.global_transform, shape.shape.get_rid(), shape.disabled])
	return result


func settle() -> void:
	for i in range(8): await physics_frame
	await process_frame


func shot(label: String) -> void:
	await settle()
	RenderingServer.force_draw(false)
	var frame := root.get_texture().get_image()
	check(frame.save_png(OUT.path_join(label + ".png")) == OK, "saved " + label)
	var total_draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	metrics[label] = {
		"draw_calls": total_draws,
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"camera_position": str(room.camera.global_position),
		"player_local_position": str(room.local_position())}
	if label.ends_with("_core"):
		var art: Node3D = room.worlds[room.role].environment_art
		var casing: Node3D = room.worlds.future.gate.get_node("GateDressing") if room.role == "future" else null
		art.hide()
		if casing != null: casing.hide()
		RenderingServer.force_draw(false)
		var without_art := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		metrics[label].decoration_draw_calls = total_draws - without_art
		metrics[label].procedural_triangles = art.triangle_count
		metrics[label].instanced_boxes = art.instance_count
		check(total_draws - without_art < 80, label + " decoration adds fewer than 80 actual draws including reused props")
		art.show()
		if casing != null: casing.show()
		RenderingServer.force_draw(false)


func run() -> void:
	create_timer(100.0).timeout.connect(func() -> void: push_error("LEVEL3 ENVIRONMENT FAILED: watchdog"); quit(1))
	# Attach decoration to a fully built original physics layout, then compare every shape.
	for timeline: String in ["past", "future"]:
		var world := World.new()
		world.position.x = 100
		root.add_child(world)
		world.build(timeline, func(_id: String) -> void: pass, false)
		world.set_process(false)
		await settle()
		var before := physics_signature(world)
		var art := Art.instantiate()
		world.add_child(art)
		art.build(timeline == "future", world.gate)
		await settle()
		check(before == physics_signature(world), timeline + " every collision shape, transform and enabled flag unchanged")
		check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), timeline + " decoration adds no bodies or interaction areas")
		check(art.position == Vector3.ZERO, timeline + " decorative root stays on ground contact")
		check(art.triangle_count < 20000, timeline + " procedural decoration under 20k triangles")
		check(art.find_children("*", "MultiMeshInstance3D", true, false).size() < 50, timeline + " repeated details batched into fewer than 50 draws")
		if timeline == "future":
			var casing: Node3D = world.gate.get_node("GateDressing")
			var casing_at: Vector3 = casing.global_position
			var state: Dictionary = World.Rules.new().get_initial_state()
			state.receiver = true
			state.coils = World.Rules.COIL_TARGET.duplicate()
			world.apply_state(state)
			await settle()
			check(world.gate_shape.disabled and casing.global_position.is_equal_approx(casing_at + Vector3(0, -1.6, 0)), "Future casing follows the existing gate below the floor")
			world.apply_state(World.Rules.new().get_initial_state())
			await settle()
			check(not world.gate_shape.disabled and casing.global_position.is_equal_approx(casing_at), "replay restores gate casing without new motion logic")
		# Raycasts see the unchanged Y=0 slab beneath the walking lanes and entry.
		for point in [Vector3(0, 0, 5.9), Vector3(-4.4, 0, 3.8), Vector3(4.4, 0, 3.8), Vector3(0, 0, -4.2)]:
			var origin: Vector3 = world.position + point
			var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.15, origin - Vector3.UP * 0.3, 1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and absf(hit.position.y) < 0.001, timeline + " walking lane retains Y=0 physics")
		world.queue_free()
		await process_frame
	root.get_node("CinematicTransitionManager").enabled = false
	root.get_node("GameFlowManager").start_room("room_03")
	await settle()
	room = current_scene
	room.player.set_physics_process(false)
	check(room.state.stage == "DISCOVERY" and room.state.remaining == 150, "environment never arms the reactor")
	check(room.worlds.past.environment_art.materials.floor != room.worlds.future.environment_art.materials.floor, "timeline material instances are isolated")
	var past_color: Color = room.worlds.past.environment_art.materials.floor.get_shader_parameter("paint")
	room.worlds.future.environment_art.set_effects_enabled(false)
	check(room.worlds.past.environment_art.materials.floor.get_shader_parameter("paint") == past_color, "Future effects preference cannot recolor Past")
	check(room.camera.fov == 48.0 and is_equal_approx(room.camera.rotation.x, -deg_to_rad(35)), "actual fixed camera is unchanged")
	check(room.reactor_bridge.modules.size() == 2, "existing detailed reactor still mounted in both timelines")
	var reactor: Node3D = room.reactor_bridge.modules.past
	var ring_before: Vector3 = reactor.rings[0].rotation
	await create_timer(0.2).timeout
	check(reactor.is_processing() and not reactor.rings[0].rotation.is_equal_approx(ring_before), "existing reactor animation advances")
	# Existing suites separately exercise all actions and four endings through ENet.
	if "--render-review" in OS.get_cmdline_user_args():
		root.size = Vector2i(1600, 900)
		DirAccess.make_dir_recursive_absolute(OUT)
		for timeline: String in ["past", "future"]:
			if room.role != timeline: room.switch_debug_role()
			room.player.set_physics_process(false)
			for view: String in ["entry", "core", "rear"]:
				var positions := {"entry": Vector3(0, 0, 5.9), "core": Vector3(-0.4, 0, 2.7), "rear": Vector3(0, 0, -3.8)}
				room.player.position = room.worlds[timeline].position + positions[view]
				room.camera_rig.snap_to_target()
				await shot(timeline + "_" + view)
		metrics.renderer = RenderingServer.get_current_rendering_method()
		metrics.adapter = RenderingServer.get_video_adapter_name()
		var file := FileAccess.open(OUT.path_join("metrics.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(metrics, "\t") + "\n")
	print("LEVEL3 ENVIRONMENT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
