extends SceneTree
## Deterministic module checks; no room, puzzle or multiplayer state is touched.
const SCENE := preload("res://scenes/level3/reactor_visual/reactor_visual.tscn")
var failures: Array[String] = []
var checks: int = 0
var swept_bounds: AABB
var _bounds_started: bool = false


func _initialize() -> void: run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("REACTOR CHECK: " + label)


func step(reactor: Node3D, seconds: float) -> void:
	for i in range(ceili(seconds*60.0)): reactor._update_visuals(1.0/60.0)
	for mesh: MeshInstance3D in reactor.assembly.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		# Rotating a ring's square AABB invents empty diagonal corners. Measure the
		# actual vertices so this is a physical envelope rather than a culling box.
		for surface in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point := mesh.global_transform*vertex
				if not _bounds_started:
					swept_bounds = AABB(point, Vector3.ZERO)
					_bounds_started = true
				else: swept_bounds = swept_bounds.expand(point)


func run() -> void:
	create_timer(25.0).timeout.connect(func() -> void: push_error("REACTOR VISUAL: FAIL watchdog"); quit(1))
	var past := SCENE.instantiate()
	var future := SCENE.instantiate()
	future.set_timeline("future")
	future.play_ending("paradox")
	root.add_child(past)
	root.add_child(future)
	past.set_process(false)
	future.set_process(false)
	check(past.rings.size() == 3, "three independent rotors")
	check(future.ending_id == "paradox", "pre-tree ending configuration retained")
	check(future.timeline == "future", "pre-tree timeline configuration retained")
	check(not past.collision_enabled and past._body.collision_layer == 0, "no added collision by default")
	check(past.find_children("*", "Area3D", true, false).is_empty(), "no interaction areas")
	check(past._materials.size() == 9, "all nine material slots imported")
	var past_mesh := past.assembly.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var future_mesh := future.assembly.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check(past_mesh.mesh == future_mesh.mesh, "timelines share imported geometry")
	for slot: String in past._materials:
		check(past._materials[slot] != future._materials[slot], "material isolation: " + slot)
	var initial_paint: Color = past._materials.armor.get_shader_parameter("paint_color")
	future.set_timeline("past")
	future.set_timeline("future")
	check(past._materials.armor.get_shader_parameter("paint_color") == initial_paint, "timeline mutation cannot recolor another instance")
	check(not past._damage.visible and future._damage.visible, "Future damage only")
	check(not future._covers[1].visible and past._covers[1].visible, "missing Future shields")
	check(not past.set_timeline("invalid") and past.timeline == "past", "invalid timeline rejected")
	check(not past.set_reactor_phase("invalid"), "invalid phase rejected")
	check(not past.play_ending("invalid"), "invalid ending rejected")
	past.set_charge_ratio(2.0)
	check(past.charge_ratio == 1.0, "charge upper clamp")
	past.set_charge_ratio(-1.0)
	check(past.charge_ratio == 0.0, "charge lower clamp")
	past.set_charge_ratio(NAN)
	check(past.charge_ratio == 0.0, "NaN charge ignored")
	check(1.65+0.28 < 2.5, "floor platform clears phase-switch player footprint")
	var start_basis: Array[Basis] = []
	for ring in past.rings: start_basis.append(ring.basis)
	step(past, 0.5)
	for i in range(3): check(not past.rings[i].basis.is_equal_approx(start_basis[i]), "rotor %d moves" % i)
	check(past.rings[0].rotation.y*past.rings[1].rotation.y < 0, "opposed rotor directions")
	var discovery_speed: float = past._speed
	for phase: String in past.PHASES:
		check(past.set_reactor_phase(phase), "accept phase " + phase)
		past.set_charge_ratio(0.8)
		step(past, 2.0)
		check(is_finite(past._energy) and is_finite(past._speed), "finite animation state " + phase)
		if phase == "power": check(past._speed > discovery_speed*3, "charge/phase drives speed")
	var colors: Array[Color] = []
	for ending: String in past.ENDINGS:
		check(past.play_ending(ending), "accept ending " + ending)
		step(past, 5.0)
		check(past.reactor_phase == "ending", "ending selects phase")
		colors.append(past._color)
		if ending == "trust": check(past._speed > 0 and past._speed < 0.05, "trust slow controlled motion")
		if ending == "student_override": check(past._speed < 0, "student reverses motion")
		if ending == "professor_override": check(past._speed > 0, "Professor preserves forward motion")
		if ending == "paradox": check(past._speed < -1.0 and past._instability > 0.8, "paradox instability and reverse motion")
	for i in range(4):
		for j in range(i): check(colors[i] != colors[j], "distinct ending colors %d/%d" % [i, j])
	past.trigger_overload()
	step(past, 4.0)
	check(past.reactor_phase == "overload" and past.ending_id == "", "overload resets ending")
	check(past._arcs.visible, "bounded overload discharges")
	check(past._arcs.multimesh.instance_count == 18, "fixed effect allocation")
	past.set_effects_enabled(false)
	check(not past._arcs.visible and not past._shell.visible and past._light.light_energy == 0.0, "effect reduction")
	past.set_effects_enabled(true)
	past.set_motion_enabled(false)
	var frozen_basis: Basis = past.rings[0].basis
	var frozen_time: float = past._clock
	step(past, 2.0)
	check(past.rings[0].basis.is_equal_approx(frozen_basis) and past._clock == frozen_time, "motion reduction freezes rotations and shader clock")
	past.set_motion_enabled(true)
	past.play_shutdown(0.05)
	await create_timer(0.15).timeout
	step(past, 0.1)
	check(is_zero_approx(past._startup_progress) and not past._plasma.visible, "shutdown sequence")
	past.play_startup(0.05)
	await create_timer(0.15).timeout
	check(is_equal_approx(past._startup_progress, 1.0), "startup sequence")
	past.set_collision_enabled(true)
	check(past._body.collision_layer == 1 and past._body.get_child_count() == 1, "optional simple central collision")
	past.set_collision_enabled(false)
	past.set_active(false)
	check(not past.visible and not past.is_processing(), "inactive timeline culling")
	past.set_active(true)
	check(past.visible and past.is_processing(), "timeline reactivation")
	check(swept_bounds.size.x < 4.9 and swept_bounds.size.z < 4.9 and swept_bounds.end.y < 5.6, "sampled mechanical envelope fits reserved space")
	print("REACTOR SAMPLED BOUNDS: position=%s size=%s" % [swept_bounds.position, swept_bounds.size])
	past.queue_free()
	future.queue_free()
	await process_frame
	if failures.is_empty(): print("REACTOR VISUAL: PASS (%d checks)" % checks)
	else: print("REACTOR VISUAL: FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
