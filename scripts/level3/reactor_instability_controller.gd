extends Node3D
## Bounded, deterministic presentation for one timeline. No puzzle or physics writes.
## All temporary geometry belongs to this node; imported meshes/materials stay shared.

const RUPTURE := preload("res://shaders/level3/temporal_rupture.gdshader")
const CYAN := Color("69e5ee")
const VIOLET := Color("ba85ef")
var intensity := 0.0
var reduced_motion := false
var elapsed := -1.0
var world: Node3D
var module: Node3D
var _clock := 0.0
var _fractures: MeshInstance3D
var _rifts: MeshInstance3D
var _crack_material: ShaderMaterial
var _rift_material: ShaderMaterial
var _arcs: MultiMeshInstance3D
var _motes: MultiMeshInstance3D
var _debris: MultiMeshInstance3D
var _rays: MultiMeshInstance3D
var _waves: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _props: Array[Dictionary] = []
var _convergence := 0.0
var _wall_dressing: Node3D
var _wall_base: Transform3D
var _tiles: Array[Dictionary] = []


static func urgency(remaining: float) -> float:
	# Continuous value and derivative at each authored countdown threshold.
	if remaining >= 60.0: return lerpf(0.02, 0.12, smoothstep(150.0, 60.0, remaining))
	if remaining >= 30.0: return lerpf(0.12, 0.40, smoothstep(60.0, 30.0, remaining))
	if remaining >= 10.0: return lerpf(0.40, 0.76, smoothstep(30.0, 10.0, remaining))
	return lerpf(0.76, 1.0, smoothstep(10.0, 0.0, remaining))


func setup(room_world: Node3D, reactor: Node3D) -> void:
	world = room_world
	module = reactor
	name = "TemporalCatastrophe"
	_crack_material = ShaderMaterial.new()
	_crack_material.shader = RUPTURE
	_crack_material.set_shader_parameter("fissure", true)
	_rift_material = ShaderMaterial.new()
	_rift_material.shader = RUPTURE
	_rift_material.set_shader_parameter("tint", VIOLET)
	_fractures = _ribbons(false, _crack_material)
	_rifts = _ribbons(true, _rift_material)
	_arcs = _instances("ContainmentArcs", 64, Vector3(0.022, 1, 0.022), _glow(CYAN))
	_motes = _instances("ChrononDust", 64, Vector3(0.025, 0.07, 0.025), _glow(CYAN))
	_debris = _instances("ChamberFragments", 48, Vector3.ONE, _metal())
	_rays = _instances("RuptureSplinters", 64, Vector3(0.045, 1, 0.045), _glow(VIOLET))
	for i in range(3):
		var wave := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.94
		torus.outer_radius = 1.0
		torus.rings = 64
		torus.ring_segments = 6
		wave.mesh = torus
		wave.material_override = _glow(CYAN if i % 2 == 0 else VIOLET)
		wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wave)
		_waves.append(wave)
	_light = OmniLight3D.new()
	_light.position.y = 3
	_light.omni_range = 16
	_light.shadow_enabled = false
	add_child(_light)
	_stage_props()
	if world.environment_art != null:
		_wall_dressing = world.environment_art.find_child("WallDetails", true, false) as Node3D
		if _wall_dressing != null: _wall_base = _wall_dressing.transform
		_stage_tiles()
	update_presentation(0.0, 150.0, false, -1.0)


func _glow(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func _metal() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("465863") if world.future else Color("8b9389")
	mat.roughness = 0.82
	return mat


func _instances(id: String, count: int, size: Vector3, mat: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Godot cannot infer moving procedural bounds from the shared unit mesh.
	node.custom_aabb = AABB(Vector3(-24, -8, -24), Vector3(48, 30, 48))
	add_child(node)
	return node


func _ribbons(vertical: bool, mat: Material) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for ray in range(9 if vertical else 18):
		var angle := ray * TAU / (9.0 if vertical else 18.0) + 0.19
		var previous := Vector3.ZERO
		for step in range(9):
			var fraction := step / 8.0
			var radius := (2.1 + fraction * 0.9) if vertical else (1.3 + fraction * (5.0 + sin(ray * 3.1)))
			var a := angle + sin(step * 2.8 + ray) * (0.12 if vertical else 0.08)
			var point := Vector3(cos(a) * radius, 0.065, sin(a) * radius)
			if vertical: point.y = 0.8 + fraction * (3.4 + sin(ray))
			if step > 0:
				var side := Vector3(cos(angle), 0, sin(angle)) * 0.09 if vertical else Vector3(-sin(angle), 0, cos(angle)) * 0.055
				var vertices := [previous - side, previous + side, point + side, previous - side, point + side, point - side]
				var uvs := [Vector2(0, (step-1)/8.0), Vector2(1, (step-1)/8.0), Vector2(1, fraction), Vector2(0, (step-1)/8.0), Vector2(1, fraction), Vector2(0, fraction)]
				for index in range(6):
					mesh.surface_set_uv(uvs[index])
					mesh.surface_add_vertex(vertices[index])
			previous = point
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.name = "TemporalRifts" if vertical else "FloorFractures"
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _stage_props() -> void:
	# Visual copies of actual desks, equipment, papers and rear structural columns.
	# Gameplay collision and original root transforms are never changed.
	var sources := world.get_children()
	for station: Node3D in world.stations.values():
		if station.has_node("PhysicalDevice"): sources.append(station.get_node("PhysicalDevice"))
	for source in sources:
		if source == self or not source is Node3D: continue
		var structural: bool = source is StaticBody3D and source.position.z < -6.0 and absf(source.position.x) < 9.0
		if not source.scene_file_path.begins_with("res://scenes/environment/props/") and not structural and source.name != &"PhysicalDevice": continue
		var copy := Node3D.new()
		copy.transform = world.global_transform.affine_inverse() * source.global_transform
		add_child(copy)
		var originals: Array[MeshInstance3D] = []
		for original: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			if not _visible_within(original, source): continue
			var visual := MeshInstance3D.new()
			visual.mesh = original.mesh
			visual.material_override = original.material_override
			for surface in range(original.mesh.get_surface_count()):
				visual.set_surface_override_material(surface, original.get_surface_override_material(surface))
			copy.add_child(visual)
			visual.global_transform = original.global_transform
			originals.append(original)
		copy.hide()
		_props.append({"copy": copy, "base": copy.transform, "originals": originals, "active": false, "structural": structural})


func _stage_tiles() -> void:
	var floor_details: Node = world.environment_art.get_node("FloorDetails")
	for node in floor_details.get_children():
		if not node is MultiMeshInstance3D or not node.name in [&"Floor", &"FloorAlt"]: continue
		for index in range(node.multimesh.instance_count):
			var base: Transform3D = node.multimesh.get_instance_transform(index)
			var radius := base.origin.length()
			if index % 3 != 0 or radius < 2.0 or radius > 7.5: continue
			_tiles.append({"mesh": node.multimesh, "index": index, "base": base})


func _visible_within(mesh: Node3D, source: Node3D) -> bool:
	var current: Node3D = mesh
	while current != source:
		if not current.visible: return false
		current = current.get_parent() as Node3D
		if current == null: return false
	return true


func update_presentation(delta: float, remaining: float, armed: bool, cinematic_time: float) -> void:
	_clock += delta
	elapsed = cinematic_time
	var target := urgency(remaining) if armed else 0.0
	_convergence = smoothstep(3.0, 0.0, remaining) if armed else 0.0
	if elapsed >= 0: target = 1.0
	intensity = lerpf(intensity, target, 1.0 - exp(-delta * 5.0))
	var critical := smoothstep(0.30, 0.95, intensity)
	var blast := maxf(0.0, elapsed - 0.8)
	var exploded := elapsed >= 0.8
	var collapse := smoothstep(3.3, 4.5, elapsed)
	if module != null and module.has_method("set_instability"):
		module.set_instability(intensity, elapsed, reduced_motion)
	for mat in [_crack_material, _rift_material]:
		mat.set_shader_parameter("clock", _clock * (0.15 if reduced_motion else 1.0))
		mat.set_shader_parameter("strength", critical * (1.5 + float(exploded) * 2.0))
		mat.set_shader_parameter("reveal", clampf(critical + blast * 0.35, 0.0, 1.0))
	_fractures.visible = critical > 0.01
	_rifts.visible = critical > 0.05
	_light.light_color = VIOLET.lerp(CYAN, 0.5 + sin(_clock * 1.7) * 0.3)
	_light.light_energy = intensity * 0.8 + (3.2 * exp(-blast * 1.9) if exploded else 0.0) + collapse * 2
	_update_arcs(critical, exploded)
	_update_particles(critical, blast, exploded)
	for i in range(3):
		var wave_time := blast - i * 0.18
		var wave := _waves[i]
		wave.visible = exploded and wave_time > 0 and wave_time < 1.5
		if wave.visible:
			var radius := 0.6 + wave_time * (14.0 + i * 2)
			wave.scale = Vector3(radius, 0.5 + wave_time * 0.5, radius)
			wave.position.y = 0.25 + i * 1.25
			wave.rotation.x = (i - 1) * 0.14
	_update_props(critical, blast, exploded)
	_update_tiles(blast, exploded)
	if _wall_dressing != null:
		_wall_dressing.transform = _wall_base
		if exploded:
			var fold := smoothstep(0.5, 3.0, blast)
			_wall_dressing.position.y -= fold * 0.8
			_wall_dressing.rotation.x = fold * 0.22


func _update_tiles(blast: float, exploded: bool) -> void:
	if not exploded: return
	for item in _tiles:
		var base: Transform3D = item.base
		var outward := Vector3(base.origin.x, 0, base.origin.z).normalized()
		var flight := maxf(0.0, blast - base.origin.length() / 22.0)
		var axis := outward.cross(Vector3.UP).normalized()
		var angle := smoothstep(0.0, 1.8, flight) * (0.55 + sin(float(item.index)) * 0.2)
		var at := base.origin + outward * flight * 0.4
		at.y += sin(minf(flight, 1.6) * PI * 0.5) * 0.8
		item.mesh.set_instance_transform(item.index, Transform3D(Basis(axis, angle) * base.basis, at))


func _update_arcs(critical: float, exploded: bool) -> void:
	_arcs.visible = intensity > 0.15 and elapsed < 2.3
	if not _arcs.visible: return
	_arcs.multimesh.visible_instance_count = mini(8, 2 + int(critical * 6)) * 8
	for arc in range(8):
		var angle := arc * TAU / 8.0 + sin(_clock * 0.7 + arc) * 0.2
		var length := 1.5 + critical * 4.3
		var start := Vector3(0, 3, 0)
		var finish := Vector3(cos(angle) * length, 0.6 + sin(arc * 2.4) * 0.5, sin(angle) * length)
		finish = finish.lerp(start, _convergence * 0.6)
		if elapsed >= 0 and not exploded: finish = finish.lerp(start, elapsed * 0.8)
		for part in range(8):
			var a := start.lerp(finish, part / 8.0)
			var b := start.lerp(finish, (part + 1) / 8.0)
			var speed := 1.5 if reduced_motion else 12.0
			a += Vector3(sin(part * 7.3 + arc + _clock * speed), cos(part * 4.7 + arc + _clock * speed), 0) * sin(part / 8.0 * PI) * 0.24 * critical
			b += Vector3(sin((part+1) * 7.3 + arc + _clock * speed), cos((part+1) * 4.7 + arc + _clock * speed), 0) * sin((part+1) / 8.0 * PI) * 0.24 * critical
			_arcs.multimesh.set_instance_transform(arc * 8 + part, _segment(a, b))


func _segment(a: Vector3, b: Vector3) -> Transform3D:
	var direction := b - a
	var y := direction.normalized()
	var reference := Vector3.RIGHT if absf(y.dot(Vector3.FORWARD)) > 0.95 else Vector3.FORWARD
	var x := y.cross(reference).normalized()
	return Transform3D(Basis(x, y * maxf(0.001, direction.length()), x.cross(y)), (a + b) * 0.5)


func _update_particles(critical: float, blast: float, exploded: bool) -> void:
	_motes.multimesh.visible_instance_count = 10 + int(intensity * 54)
	for i in range(64):
		var phase := fposmod(i * 0.618 + _clock * (0.12 + intensity * 0.18), 1.0)
		var angle := i * 2.39996 + _clock * (0.2 + intensity)
		var radius := 0.7 + phase * (1.2 + critical * 3.2)
		radius *= 1.0 - _convergence * 0.75
		if elapsed >= 0 and elapsed < 0.8: radius *= maxf(0.08, 1.0 - elapsed)
		var at := Vector3(cos(angle)*radius, 1.1 + phase * 3.5, sin(angle)*radius)
		_motes.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	_debris.visible = critical > 0.05 or exploded
	for i in range(48):
		var angle := i * 2.39996
		var radius := 1.7 + fposmod(i * 0.71, 1.0) * 4.0
		var at := Vector3(cos(angle)*radius, 0.12 + critical * (0.2 + fposmod(i * 0.37, 1.0)) * (1.2 + sin(_clock * 1.8 + i) * 0.2), sin(angle)*radius)
		var flight := maxf(0.0, blast - radius / 22.0)
		if exploded:
			at += Vector3(cos(angle) * flight * 5, flight * (4 + sin(i)*2) - 3.5 * flight * flight, sin(angle) * flight * 5)
			at.y = maxf(0.06, at.y)
		var spin := _clock * critical * 0.4 + flight * 3
		var size := Vector3(0.09 + (i % 3)*0.045, 0.035 + (i % 4)*0.015, 0.12 + (i % 5)*0.055)
		_debris.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(spin, i, spin*0.7)).scaled(size), at))
	_rays.visible = exploded and blast < 2.7
	if _rays.visible:
		for i in range(64):
			var angle := i * 2.39996
			var elevation := -0.15 + fposmod(i * 0.371, 1.0) * 1.3
			var direction := Vector3(cos(angle), elevation, sin(angle)).normalized()
			var radius := blast * (5 + fposmod(i * 0.17, 1.0) * 13)
			var at := Vector3(0, 3, 0) + direction * radius
			_rays.multimesh.set_instance_transform(i, _segment(at, at + direction * maxf(0.03, (1.8 - blast) * 1.6)))


func _update_props(critical: float, blast: float, exploded: bool) -> void:
	for i in range(_props.size()):
		var item := _props[i]
		var copy: Node3D = item.copy
		if critical <= 0.02 and not exploded: continue
		if not item.active:
			item.active = true
			copy.show()
			for original: MeshInstance3D in item.originals: original.hide()
		var base: Transform3D = item.base
		var outward := Vector3(base.origin.x, 0, base.origin.z).normalized()
		var flight := maxf(0.0, blast - base.origin.length() / 22.0)
		copy.transform = base
		var tremor := 0.004 if reduced_motion else 0.025
		copy.position += Vector3(sin(_clock * 18 + i), 0, cos(_clock * 15 + i)) * critical * tremor
		if not item.structural: copy.position.y += critical * 0.1 * (0.6 + sin(_clock * 2 + i) * 0.4)
		if exploded:
			if item.structural:
				copy.rotate_z(-signf(base.origin.x) * smoothstep(0.1, 2.4, flight) * 1.25)
				copy.position.y -= flight * 0.6
			else:
				copy.position += outward * flight * 3.8 + Vector3.UP * maxf(-base.origin.y, flight * 3.2 - 3 * flight * flight)
				copy.rotate(outward.cross(Vector3.UP).normalized(), flight * (1.8 + sin(i) * 0.8))


func _exit_tree() -> void:
	if is_instance_valid(_wall_dressing): _wall_dressing.transform = _wall_base
	for item in _tiles: item.mesh.set_instance_transform(item.index, item.base)
	for item in _props:
		for original in item.originals:
			if is_instance_valid(original): original.show()
