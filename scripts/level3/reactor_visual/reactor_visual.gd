extends Node3D
## Presentation only. No autoloads, puzzle authority, input, RPCs or interaction areas.
## Every mutable material belongs to this instance; imported meshes remain shared.

const ASSEMBLY := preload("res://assets/environments/level3/reactor_visual/temporal_assembly.glb")
const METAL := preload("res://shaders/level3/reactor_visual/temporal_metal.gdshader")
const ENERGY := preload("res://shaders/level3/reactor_visual/temporal_energy.gdshader")
const CURRENT := preload("res://shaders/level3/reactor_visual/temporal_current.gdshader")
const PHASES := ["discovery", "armed", "power", "alignment", "synchronization", "ending", "overload"]
const ENDINGS := ["trust", "student_override", "professor_override", "paradox"]
const PAST := {"armor": "889181", "frame": "283a40", "steel": "bfc9b7", "copper": "b47f4c", "rubber": "15252c", "warning": "e2ad4b"}
const FUTURE := {"armor": "496a76", "frame": "1b303e", "steel": "91b5c0", "copper": "795d50", "rubber": "111c2b", "warning": "b99b65"}
const ENERGIES := {"cyan": Color("65dfe5"), "amber": Color("efb85e"), "violet": Color("aa82ed")}
const TILTS := [Vector3(62, 0, 12), Vector3(-48, 0, -28), Vector3(78, 0, 42)]

@export_enum("past", "future") var timeline: String = "past"
@export_enum("discovery", "armed", "power", "alignment", "synchronization", "ending", "overload") var reactor_phase: String = "discovery"
@export_range(0.0, 1.0) var charge_ratio: float = 0.0
@export var effects_enabled: bool = true
@export var motion_enabled: bool = true
## Off by default: retain the gameplay room's original central collision instead.
@export var collision_enabled: bool = false

var ending_id: String = ""
var assembly: Node3D
var rings: Array[Node3D] = []
var axes: Array[Node3D] = []
var _materials: Dictionary = {}
var _shell_material: ShaderMaterial
var _shell: MeshInstance3D
var _plasma: MeshInstance3D
var _plasma_material: StandardMaterial3D
var _hoops: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _arcs: MultiMeshInstance3D
var _arc_material: StandardMaterial3D
var _body: StaticBody3D
var _covers: Array[Node3D] = []
var _damage: Node3D
var _clock: float = 0.0
var _speed: float = 0.12
var _energy: float = 0.35
var _charge: float = 0.0
var _instability: float = 0.0
var _color: Color = Color("efb85e")
var _startup_progress: float = 1.0
var _sequence: Tween
var _built: bool = false
var _failure_intensity := 0.0
var _failure_time := -1.0
var _reduced_motion := false


func _ready() -> void:
	assembly = ASSEMBLY.instantiate()
	assembly.name = "Assembly"
	add_child(assembly)
	_assign_materials(assembly)
	for id: String in ["Outer", "Inner", "Focus"]:
		var axis := assembly.find_child(id + "Axis", true, false) as Node3D
		axes.append(axis)
		rings.append(axis.get_node(id + "Rotor"))
	for i in range(4): _covers.append(assembly.find_child("Cover%d" % i, true, false))
	_damage = assembly.find_child("FutureDamage", true, false)
	_build_effects()
	_build_collision()
	_built = true
	set_timeline(timeline)
	set_reactor_phase(reactor_phase)
	set_charge_ratio(charge_ratio)
	# An ending can be configured before add_child just like the other API calls.
	if not ending_id.is_empty(): play_ending(ending_id)
	_update_visuals(0.0)


func _assign_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(mesh_node.mesh.get_surface_count()):
			var source := mesh_node.mesh.surface_get_material(i)
			var slot := String(source.resource_name)
			if not _materials.has(slot):
				if ENERGIES.has(slot):
					var luminous := ShaderMaterial.new()
					luminous.shader = CURRENT
					luminous.set_shader_parameter("current_color", ENERGIES[slot])
					_materials[slot] = luminous
				else:
					var metal := ShaderMaterial.new()
					metal.shader = METAL
					_materials[slot] = metal
			mesh_node.set_surface_override_material(i, _materials[slot])
	for child in node.get_children(): _assign_materials(child)


func _build_effects() -> void:
	_shell_material = ShaderMaterial.new()
	_shell_material.shader = ENERGY
	_shell = MeshInstance3D.new()
	_shell.name = "TemporalChamber"
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.54
	shell_mesh.height = 2.12
	shell_mesh.radial_segments = 32
	shell_mesh.rings = 16
	_shell.mesh = shell_mesh
	_shell.material_override = _shell_material
	_shell.position.y = 3.0
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	_plasma = MeshInstance3D.new()
	_plasma.name = "PlasmaHeart"
	var heart := CylinderMesh.new()
	heart.top_radius = 0.12
	heart.bottom_radius = 0.23
	heart.height = 1.56
	heart.radial_segments = 8
	_plasma.mesh = heart
	_plasma.position.y = 3.0
	_plasma_material = StandardMaterial3D.new()
	_plasma_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plasma.material_override = _plasma_material
	_plasma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_plasma)
	for i in range(3):
		var hoop := MeshInstance3D.new()
		hoop.name = "EnergyOrbit%d" % i
		var torus := TorusMesh.new()
		torus.inner_radius = 0.45 + i*0.035
		torus.outer_radius = 0.47 + i*0.035
		torus.rings = 32
		torus.ring_segments = 6
		hoop.mesh = torus
		hoop.material_override = _materials[["cyan", "amber", "violet"][i]]
		hoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hoop)
		_hoops.append(hoop)
	_light = OmniLight3D.new()
	_light.name = "CoreLight"
	_light.position.y = 3.0
	_light.omni_range = 5.0
	_light.omni_attenuation = 1.8
	_light.shadow_enabled = false
	add_child(_light)
	# Exactly 18 short discharge segments, one draw, no spawning or mesh allocation.
	_arcs = MultiMeshInstance3D.new()
	_arcs.name = "ElectricalDischarges"
	var segment := BoxMesh.new()
	segment.size = Vector3(0.016, 1.0, 0.016)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = segment
	mm.instance_count = 18
	_arcs.multimesh = mm
	_arc_material = StandardMaterial3D.new()
	_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arcs.material_override = _arc_material
	_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arcs)


func _build_collision() -> void:
	_body = StaticBody3D.new()
	_body.name = "OptionalCentralCollision"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.48
	cylinder.height = 1.15
	shape.shape = cylinder
	shape.position.y = 0.575
	_body.add_child(shape)
	add_child(_body)
	set_collision_enabled(collision_enabled)


## Returns false for unknown inputs without changing the current presentation.
func set_reactor_phase(phase: String) -> bool:
	phase = phase.to_lower()
	if not phase in PHASES: return false
	if reactor_phase == phase and phase == "ending": return true
	reactor_phase = phase
	if phase != "ending": ending_id = ""
	return true


func set_charge_ratio(value: float) -> void:
	if not is_finite(value): return
	charge_ratio = clampf(value, 0.0, 1.0)


func set_instability(value: float, cinematic_time: float, reduced: bool) -> void:
	_failure_intensity = clampf(value, 0.0, 1.0)
	_failure_time = cinematic_time
	_reduced_motion = reduced


func trigger_overload() -> void:
	set_reactor_phase("overload")
	charge_ratio = 1.0
	play_startup(0.8)


func play_ending(id: String) -> bool:
	id = id.to_lower()
	if not id in ENDINGS: return false
	ending_id = id
	reactor_phase = "ending"
	charge_ratio = 0.25 if id == "trust" else 1.0
	return true


func set_timeline(value: String) -> bool:
	value = value.to_lower()
	if not value in ["past", "future"]: return false
	timeline = value
	if not _built: return true
	var palette: Dictionary = FUTURE if timeline == "future" else PAST
	for slot: String in palette:
		var mat := _materials.get(slot) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("paint_color", Color(palette[slot]))
			mat.set_shader_parameter("weathering", 1.0 if timeline == "future" else 0.0)
	_damage.visible = timeline == "future"
	for i in range(_covers.size()):
		var cover := _covers[i]
		cover.position = Vector3(0, 3.0, 0)
		cover.rotation = Vector3.ZERO
		cover.visible = true
		if timeline == "future":
			# Two missing shields expose the internals, two remain torn out of plane.
			cover.visible = i % 2 == 0
			cover.position += Vector3(0.12 if i == 0 else -0.16, -0.18, 0.10)
			cover.rotation_degrees = Vector3(16, -8, 19 if i == 0 else -24)
	return true


func play_startup(duration: float = 2.4) -> void:
	_sequence_to(1.0, duration)


func play_shutdown(duration: float = 3.0) -> void:
	_sequence_to(0.0, duration)


func _sequence_to(value: float, duration: float) -> void:
	if not is_inside_tree():
		_startup_progress = value
		return
	if is_instance_valid(_sequence): _sequence.kill()
	_sequence = create_tween()
	_sequence.tween_property(self, "_startup_progress", value, maxf(0.05, duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_effects_enabled(enabled: bool) -> void:
	effects_enabled = enabled
	if _built: _update_visuals(0.0)


func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled


func set_collision_enabled(enabled: bool) -> void:
	collision_enabled = enabled
	if is_instance_valid(_body):
		_body.collision_layer = 1 if enabled else 0
		_body.collision_mask = 0


## Optional room adapter can call this on the inactive timeline to save all process cost.
func set_active(active: bool) -> void:
	visible = active
	set_process(active)


func _process(delta: float) -> void:
	# No motion or shader-time discontinuity after a stalled frame.
	_update_visuals(minf(delta, 0.1))


func _update_visuals(delta: float) -> void:
	if not _built: return
	var motion_delta := delta if motion_enabled else 0.0
	_clock += motion_delta
	var smoothing := 1.0 - exp(-delta * 2.6)
	_charge = lerpf(_charge, charge_ratio, smoothing)
	var target_speed := 0.10
	var target_energy := 0.32
	var instability := 0.15 if timeline == "future" else 0.0
	var target_color := Color("72dce8") if timeline == "future" else Color("efbd75")
	match reactor_phase:
		"armed":
			target_speed = 0.24
			target_energy = 0.55
		"power":
			target_speed = 0.38 + _charge*0.28
			target_energy = 0.65 + _charge*0.35
		"alignment":
			target_speed = 0.54
			target_energy = 0.95
			target_color = Color("77d8f2")
		"synchronization":
			target_speed = 0.82
			target_energy = 1.1
			target_color = Color("b7b6ee")
		"overload":
			target_speed = 1.2
			target_energy = 1.3
			instability = 1.0
			target_color = Color("f2a35e")
		"ending":
			match ending_id:
				"trust":
					target_speed = 0.035
					target_energy = 0.42
					instability = 0.0
					target_color = Color("8ee5bb")
				"student_override":
					target_speed = -0.72
					target_energy = 1.05
					instability = 0.36
					target_color = Color("efb851")
				"professor_override":
					target_speed = 0.26
					target_energy = 0.95
					instability = 0.16
					target_color = Color("84a8ee")
				"paradox":
					target_speed = -1.08
					target_energy = 1.20
					instability = 0.85
					target_color = Color("bd88ef")
	if reactor_phase != "ending" and _failure_intensity > 0.0:
		target_speed = maxf(target_speed, 0.22 + pow(_failure_intensity, 1.7) * 5.8)
		target_energy = maxf(target_energy, 0.55 + _failure_intensity * 1.6)
		instability = maxf(instability, _failure_intensity)
		target_color = Color("69e5ee").lerp(Color("b79aff"), smoothstep(0.3, 1.0, _failure_intensity))
	_speed = lerpf(_speed, target_speed, smoothing)
	_energy = lerpf(_energy, target_energy, smoothing)
	_instability = lerpf(_instability, instability, smoothing)
	_color = _color.lerp(target_color, smoothing)
	var brightness := _energy * _startup_progress
	var mechanical_speed := _speed * _startup_progress
	var pulse := 0.94 + sin(_clock*1.8)*0.06
	for i in range(3):
		var sign_speed: float = [1.0, -1.43, 2.05][i]
		# Each rotor spins around its own bearing axis; tilt never accumulates drift.
		rings[i].rotate_y(motion_delta*mechanical_speed*sign_speed)
		var tilt: Vector3 = TILTS[i]
		var lift := 0.0
		if reactor_phase == "alignment": tilt *= 0.78
		if reactor_phase == "synchronization": tilt = Vector3(32+i*21, 0, i*35-25)
		if ending_id == "trust": tilt = Vector3(12+i*18, 0, i*15)
		if ending_id == "student_override": lift = (i-1)*0.18
		if ending_id == "professor_override": tilt = Vector3(82, 0, i*32-32)
		if ending_id == "paradox":
			tilt.z += sin(_clock*0.7+i)*12.0
			lift = sin(_clock*0.8+i)*0.12
		if _failure_intensity > 0.0 and reactor_phase != "ending":
			var motion_scale := 0.12 if _reduced_motion else 1.0
			tilt += Vector3(sin(_clock*4+i), 0, cos(_clock*3+i))*_failure_intensity*9.0*motion_scale
		if _failure_time >= 0.0:
			lift += sin(_clock*8+i)*0.12*minf(_failure_time, 0.8)
			var disruption := maxf(0.0, _failure_time - 0.8)
			lift += disruption * (i - 0.5) * 1.4
			tilt.z += disruption * (i - 1) * 32
		axes[i].rotation = axes[i].rotation.lerp(tilt*PI/180.0, smoothing)
		axes[i].position.y = lerpf(axes[i].position.y, 3.05+lift, smoothing)
		_hoops[i].position.y = 2.25+i*0.65+sin(_clock*1.2+i)*0.12
		_hoops[i].rotation_degrees = Vector3(sin(_clock*0.4+i)*12, 0, cos(_clock*0.4+i)*12)
		_hoops[i].visible = effects_enabled and brightness > 0.025
	var wobble := _instability * (0.008 if _reduced_motion else 0.07) if motion_enabled else 0.0
	assembly.position = Vector3(sin(_clock*7.0)*wobble, 0, cos(_clock*5.0)*wobble)
	for i in range(_covers.size()):
		var separation := maxf(0.0, _failure_time - 0.85)
		if separation > 0.0:
			var angle := i * TAU / 4.0
			_covers[i].position = Vector3(cos(angle)*separation*2, 3 + separation*1.8 - separation*separation, sin(angle)*separation*2)
			_covers[i].rotation = Vector3(separation, angle, separation*0.7)
	for slot: String in ENERGIES:
		var luminous := _materials[slot] as ShaderMaterial
		var base: Color = ENERGIES[slot]
		# Physical channels keep three current families until an outcome takes over.
		var mix_color := base.lerp(_color, 0.78 if reactor_phase == "ending" else 0.22)
		luminous.set_shader_parameter("current_color", mix_color)
		luminous.set_shader_parameter("brightness", clampf(brightness*pulse, 0.0, 1.4))
		luminous.set_shader_parameter("clock", _clock)
		luminous.set_shader_parameter("flow_speed", mechanical_speed*1.5)
	_shell_material.set_shader_parameter("clock", _clock)
	_shell_material.set_shader_parameter("primary_color", _color)
	_shell_material.set_shader_parameter("secondary_color", Color("aa80ed") if ending_id.is_empty() else _color.lightened(0.15))
	var shell_energy := brightness
	if _failure_time >= 0.8: shell_energy *= (1.0 - smoothstep(1.05, 2.6, _failure_time)) * 0.7
	_shell_material.set_shader_parameter("intensity", shell_energy if effects_enabled else 0.0)
	_shell_material.set_shader_parameter("instability", _instability)
	_shell_material.set_shader_parameter("flow_speed", -1.4 if ending_id in ["student_override", "paradox"] else 1.0)
	_shell.visible = effects_enabled and brightness > 0.025
	_plasma_material.albedo_color = _color.lightened(0.18) * brightness*pulse
	_plasma_material.albedo_color.a = 1.0
	_plasma.visible = brightness > 0.025
	_plasma.rotation.y += motion_delta*mechanical_speed*0.35
	var heart_scale := 0.92+_charge*0.15+sin(_clock*1.8)*0.035
	heart_scale += _failure_intensity * pow(maxf(0.0, sin(_clock*5)), 6.0) * 0.22
	if _failure_time < 0.0:
		heart_scale *= 1.0 - smoothstep(0.945, 1.0, _failure_intensity) * (0.28 + sin(_clock*3)*0.12)
	if _failure_time >= 0.0:
		if _failure_time < 0.8: heart_scale *= lerpf(1.0, 0.12, smoothstep(0.0, 0.8, _failure_time))
		else: heart_scale *= 0.1 + sin(clampf((_failure_time-0.8)/1.0, 0, 1)*PI)*4.5
	_plasma.scale = Vector3.ONE*heart_scale
	if _failure_time >= 0.8: _plasma.scale.y *= 0.35
	var shell_scale := 1.0 + _failure_intensity*0.12
	if _failure_time >= 0.0:
		shell_scale = lerpf(1.0, 0.18, smoothstep(0.0, 0.8, _failure_time)) if _failure_time < 0.8 else 0.3 + (_failure_time-0.8)*8.0
	_shell.scale = Vector3(shell_scale, minf(shell_scale, 2.2), shell_scale)
	_plasma.position.y = 3.0 + (0.22 if ending_id == "professor_override" else -0.18 if ending_id == "student_override" else 0.0)
	_light.light_color = _color
	_light.light_energy = brightness*0.85*pulse if effects_enabled else 0.0
	_arcs.visible = effects_enabled and brightness > 0.05 and _instability > 0.20
	if _arcs.visible: _update_arcs(brightness)


func _update_arcs(brightness: float) -> void:
	# Three bounded, gently modulated discharges inside the ring envelope.
	_arc_material.albedo_color = _color.lightened(0.32)*brightness*(0.35+0.20*sin(_clock*2.0))
	_arc_material.albedo_color.a = 1.0
	for arc_index in range(3):
		var angle := arc_index*TAU/3.0+_clock*0.12
		var start := Vector3(cos(angle)*0.50, 2.5+arc_index*0.40, sin(angle)*0.50)
		var finish := Vector3(cos(angle+0.3)*1.5, 3.05, sin(angle+0.3)*1.5)
		for j in range(6):
			var a := start.lerp(finish, j/6.0)
			var b := start.lerp(finish, (j+1)/6.0)
			a.y += sin(j*2.8+_clock*3.0)*0.06*sin(j/6.0*PI)
			b.y += sin((j+1)*2.8+_clock*3.0)*0.06*sin((j+1)/6.0*PI)
			var direction := b-a
			var basis_y := direction.normalized()
			var basis_x := basis_y.cross(Vector3.FORWARD).normalized()
			var basis_z := basis_x.cross(basis_y).normalized()
			_arcs.multimesh.set_instance_transform(arc_index*6+j, Transform3D(Basis(basis_x, basis_y*direction.length(), basis_z), (a+b)*0.5))
