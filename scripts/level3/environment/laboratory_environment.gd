extends Node3D
## Decorative Room C layer. Ground-rooted, deterministic and entirely collision-free.
## Boxes are instanced by section/material; curved floor sectors are merged by material.
## No reactor, station, input, state, network or shared palette resources are mutated.

const SURFACE := preload("res://shaders/level3/laboratory_surface.gdshader")
const TimelineMaterials := preload("res://scripts/environment/timeline_prop.gd")
const Rules := preload("res://scripts/level3/core_rules.gd")
const COLORS := {
	"frame": ["414e49", "1b2b38"], "seam": ["303c38", "101c28"],
	"floor": ["818a78", "3a5360"], "floor_alt": ["737f72", "304652"],
	"inset": ["647365", "293e4c"], "wall": ["c4c7ad", "435867"],
	"sage": ["879b87", "304957"], "steel": ["b4bcaa", "70848a"],
	"warning": ["d0a753", "9f8250"], "copper": ["a77b51", "765746"],
	"light": ["d9bc7c", "68aabb"], "emergency": ["d69957", "bc7965"],
	"violet": ["9dba9a", "88759f"], "paper": ["d6cead", "8d9b97"]
}

var future := false
var materials: Dictionary = {}
var _boxes: Dictionary = {}
var _sectors: Dictionary = {}
var _sections: Dictionary = {}
var _unit_box := BoxMesh.new()
var _effects_enabled := true
var triangle_count := 0
var instance_count := 0


func build(is_future: bool, existing_gate: Node3D = null) -> void:
	assert(get_child_count() == 0, "Environment must be built once per timeline")
	future = is_future
	_unit_box.size = Vector3.ONE
	for id: String in COLORS:
		var mat := ShaderMaterial.new()
		mat.shader = SURFACE
		mat.resource_name = "core_%s_%s" % ["future" if future else "past", id]
		mat.set_shader_parameter("paint", Color(COLORS[id][int(future)]))
		mat.set_shader_parameter("aged", 0.85 if future else 0.0)
		if id in ["light", "emergency", "violet"]:
			mat.set_shader_parameter("glow", 0.48 if id == "light" else 0.25)
			mat.set_shader_parameter("flicker", 0.7 if future and id == "emergency" else 0.0)
		materials[id] = mat
	for section: String in ["FloorDetails", "ReactorSurroundings", "WallDetails", "LaboratoryProps"]:
		var group := Node3D.new()
		group.name = section
		add_child(group)
		_sections[section] = group
	_floor()
	_reactor_surroundings()
	_walls()
	_props()
	_flush()
	if future and existing_gate != null:
		# Reparent only the decorative casing. The existing gate owns its motion.
		_sections.GateDressing.reparent(existing_gate)
	set_meta("decorative_only", true)
	set_meta("triangle_count", triangle_count)
	set_meta("instance_count", instance_count)


func set_effects_enabled(enabled: bool) -> void:
	if enabled == _effects_enabled: return
	_effects_enabled = enabled
	materials.emergency.set_shader_parameter("effects_enabled", enabled)


func _box(section: String, mat: String, at: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var key := section + "/" + mat
	if not _boxes.has(key): _boxes[key] = []
	_boxes[key].append(Transform3D(Basis(Vector3.UP, yaw).scaled(size), at))


func _line(section: String, mat: String, a: Vector3, b: Vector3, width: float, height: float = 0.008) -> void:
	var d := b - a
	var key := section + "/" + mat
	if not _boxes.has(key): _boxes[key] = []
	var up := Vector3.RIGHT if absf(d.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	_boxes[key].append(Transform3D(Basis.looking_at(d.normalized(), up).scaled(Vector3(width, height, d.length())), (a + b) * 0.5))


func _floor() -> void:
	var s := "FloorDetails"
	# 3m service bays, alternating 1m / 2m plate widths. Maximum top = 18mm.
	for row in range(7):
		var z := -6.0 + row * 2.0
		for col in range(6):
			var x := -7.5 + col * 3.0
			_box(s, "frame", Vector3(x, 0.005, z), Vector3(2.97, 0.010, 1.97))
			var split := (row + col) % 3 == 0
			var sizes: Array = [1.04, 1.80] if split else [2.88]
			var offset := -1.44
			for w: float in sizes:
				var center := x + offset + w * 0.5
				_box(s, "floor_alt" if (row * 7 + col) % 4 == 0 else "floor", Vector3(center, 0.012, z), Vector3(w - 0.018, 0.012, 1.88))
				offset += w + 0.04
			# Just four large corner fasteners per bay; all in one MultiMesh.
			for dx in [-1.30, 1.30]:
				for dz in [-0.78, 0.78]:
					_box(s, "steel", Vector3(x + dx, 0.021, z + dz), Vector3(0.065, 0.006, 0.065))
	# Two continuous maintenance drains, with sparse grille teeth.
	for x in [-7.95, 7.95]:
		_box(s, "seam", Vector3(x, 0.023, 0), Vector3(0.30, 0.012, 12.8))
		for i in range(64):
			_box(s, "steel", Vector3(x, 0.032, -6.3 + i * 0.2), Vector3(0.27, 0.012, 0.045))
	# Deliberately quiet walking lanes. Lines are paint, not raised obstacles.
	for x in [-4.65, 4.65]:
		_box(s, "steel", Vector3(x, 0.026, 0.6), Vector3(0.045, 0.008, 10.9))
		for z in [-4.4, -2.9, 0.4, 2.0, 3.6, 5.6]:
			_box(s, "light", Vector3(x, 0.034, z), Vector3(0.055, 0.007, 0.48))
	for x in [-2.2, 2.2]:
		_box(s, "steel", Vector3(x, 0.026, 5.25), Vector3(0.045, 0.008, 2.5))
	# Entry direction chevrons, with generous empty space around the arm console.
	for z in [5.7, 6.1, 6.5]:
		for side in [-1, 1]:
			_line(s, "warning", Vector3(side * 0.17, 0.030, z), Vector3(0, 0.030, z - 0.14), 0.045)
	for at in [Vector3(-2.8, 0, -5.4), Vector3(2.8, 0, -5.4), Vector3(-6.2, 0, 5.9), Vector3(6.2, 0, 5.9)]:
		_hatch(at, future and at.x > 0 and at.z < 0)
	# Functional stations get open painted corner brackets, never new controls.
	for id: String in Rules.STATIONS:
		if id.begins_with("evidence") or id in ["routing", "warning"]: continue
		if id.begins_with("coil") or id in ["origin", "sync_past", "terminal_past"]:
			if future: continue
		elif id in ["receiver", "anchor", "sync_future", "terminal_future"]:
			if not future: continue
		var at: Vector3 = Rules.STATIONS[id]
		for side in [-1, 1]:
			for end in [-0.40, 1.05]:
				_box(s, "warning", at + Vector3(side * 0.80, 0.034, end), Vector3(0.30, 0.007, 0.045))
				_box(s, "warning", at + Vector3(side * 0.93, 0.034, end + (0.12 if end < 0 else -0.12)), Vector3(0.045, 0.007, 0.28))
	if future:
		# Closed cosmetic fractures: dark lines over intact collision, only at the edges.
		for origin in [Vector3(-7.0, 0.038, -5.4), Vector3(7.6, 0.038, 1.5), Vector3(5.5, 0.038, 5.9)]:
			var points := [origin, origin + Vector3(0.3, 0, 0.24), origin + Vector3(0.13, 0, 0.61), origin + Vector3(0.5, 0, 0.83)]
			for i in range(3): _line(s, "seam", points[i], points[i+1], 0.038)
			_line(s, "violet", points[1] + Vector3(0.05, 0, 0), points[2] + Vector3(0.05, 0, 0), 0.012)


func _hatch(at: Vector3, broken: bool) -> void:
	var s := "FloorDetails"
	_box(s, "seam", at + Vector3(0, 0.025, 0), Vector3(1.14, 0.012, 0.80))
	_box(s, "inset", at + Vector3(0, 0.033, 0), Vector3(1.04, 0.008, 0.70), 0.035 if broken else 0.0)
	for x in [-0.4, 0.4]:
		_box(s, "steel", at + Vector3(x, 0.041, 0), Vector3(0.05, 0.008, 0.22))
	for i in range(5):
		_box(s, "seam", at + Vector3(-0.25 + i * 0.125, 0.041, 0), Vector3(0.04, 0.008, 0.34))


func _sector(mat: String, inner: float, outer: float, a: float, b: float, y: float) -> void:
	if not _sectors.has(mat): _sectors[mat] = PackedVector3Array()
	var v: PackedVector3Array = _sectors[mat]
	var p := Vector3(sin(a) * inner, y, cos(a) * inner)
	var q := Vector3(sin(a) * outer, y, cos(a) * outer)
	var r := Vector3(sin(b) * outer, y, cos(b) * outer)
	var t := Vector3(sin(b) * inner, y, cos(b) * inner)
	# Clockwise viewed from above, as required by Godot front faces.
	v.append_array(PackedVector3Array([p, r, q, p, t, r]))
	_sectors[mat] = v


func _reactor_surroundings() -> void:
	var s := "ReactorSurroundings"
	# 16 radial plates form a segmented octagonal service apron below the module.
	for i in range(16):
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		_sector("seam", 1.50, 2.27, a, b, 0.045)
		_sector("inset" if i % 2 == 0 else "floor_alt", 1.54, 2.21, a + 0.012, b - 0.012, 0.049)
		_sector("steel", 2.22, 2.28, a + 0.005, b - 0.005, 0.052)
		# Outer segmented hazard band: black gaps are quiet and readable at distance.
		_sector("warning" if i % 2 == 0 else "seam", 2.29, 2.39, a + 0.025, b - 0.025, 0.054)
		_sector("light", 1.64, 1.69, a + 0.09, b - 0.09, 0.055)
	# Anchor shoes remain outside the reactor's animated clearance, behind its sides.
	for side in [-1, 1]:
		for z in [-1.25, 1.25]:
			var at := Vector3(side * 1.58, 0, z)
			_box(s, "frame", at + Vector3(0, 0.065, 0), Vector3(0.30, 0.10, 0.38))
			_box(s, "steel", at + Vector3(0, 0.125, 0), Vector3(0.22, 0.02, 0.30))
			for dz in [-0.10, 0.10]:
				_box(s, "copper", at + Vector3(0, 0.145, dz), Vector3(0.07, 0.02, 0.06))
	# Embedded cable trenches follow existing coil runs, with an east collector.
	for side in [-1, 1]:
		for z in [-2.0, 0.0, 2.0]:
			_box(s, "seam", Vector3(side * 3.75, 0.030, z), Vector3(3.30, 0.014, 0.28))
			for dz in [-0.105, 0.105]:
				_box(s, "steel", Vector3(side * 3.75, 0.041, z + dz), Vector3(3.30, 0.012, 0.035))
			for i in range(5):
				_box(s, "light", Vector3(side * (2.4 + i * 0.6), 0.043, z + 0.065), Vector3(0.31, 0.008, 0.025))
			for x in [2.5, 3.8, 5.0]:
				_box(s, "frame", Vector3(side * x, 0.065, z), Vector3(0.10, 0.04, 0.33))
	_box(s, "frame", Vector3(5.35, 0.029, -0.1), Vector3(0.18, 0.014, 5.7))
	for z in [-2.6, -1.8, 0.6, 1.4, 2.2]:
		_box(s, "copper", Vector3(5.35, 0.044, z), Vector3(0.20, 0.012, 0.15))


func _walls() -> void:
	var s := "WallDetails"
	# All tall architecture sits on the rear boundary. Side/front caps stay <1.0m.
	_box(s, "frame", Vector3(0, 0.14, -6.99), Vector3(18, 0.25, 0.12))
	for i in range(9):
		var x := -8.0 + i * 2.0
		_box(s, "frame", Vector3(x, 1.24, -7.11), Vector3(1.97, 2.48, 0.18))
		_box(s, "wall", Vector3(x, 1.38, -6.99), Vector3(1.77, 1.91, 0.12))
		_box(s, "sage", Vector3(x, 0.49, -6.88), Vector3(1.77, 0.33, 0.11))
		_box(s, "steel", Vector3(x, 2.40, -6.92), Vector3(1.76, 0.055, 0.18))
		_box(s, "frame", Vector3(x - 0.96, 1.30, -6.83), Vector3(0.13, 2.6, 0.30))
		# Separate subpanel and a wide louver unit, large enough for the play camera.
		if i % 3 != 1:
			_box(s, "inset", Vector3(x, 1.27, -6.90), Vector3(1.17, 0.62, 0.13))
			for n in range(5):
				_box(s, "steel", Vector3(x, 1.05 + n * 0.10, -6.81), Vector3(0.98, 0.035, 0.08))
		if i in [0, 2, 6, 8]:
			_box(s, "frame", Vector3(x, 2.10, -6.80), Vector3(0.83, 0.21, 0.24))
			_box(s, "emergency", Vector3(x, 2.10, -6.66), Vector3(0.64, 0.09, 0.045))
			var light := OmniLight3D.new()
			light.position = Vector3(x, 1.9, -6.1)
			light.light_color = Color("89b9d1") if future else Color("f6d39a")
			light.light_energy = 0.24
			light.omni_range = 3.4
			light.shadow_enabled = false
			_sections[s].add_child(light)
		if future and i in [1, 6]:
			_line(s, "seam", Vector3(x - 0.5, 1.9, -6.905), Vector3(x + 0.13, 0.8, -6.905), 0.065, 0.028)
	# Horizontal utility spine and clamps; no overhead roof to hide the room.
	for y in [0.26, 2.66]:
		_box(s, "frame", Vector3(0, y, -6.93), Vector3(18.0, 0.11, 0.20))
		_box(s, "copper", Vector3(0, y, -6.79), Vector3(17.6, 0.045, 0.045))
		for x in [-8, -6, -4, -2, 0, 2, 4, 6, 8]:
			_box(s, "steel", Vector3(x, y, -6.76), Vector3(0.09, 0.16, 0.06))
	for side in [-1, 1]:
		var x: float = side * 9.01
		_box(s, "frame", Vector3(x, 0.99, 0), Vector3(0.37, 0.055, 14.3))
		_box(s, "steel", Vector3(x - side * 0.02, 0.78, 0), Vector3(0.12, 0.065, 14.0))
		for z in [-5, -3, -1, 1, 3, 5]:
			_box(s, "sage", Vector3(x - side * 0.035, 0.44, z), Vector3(0.13, 0.51, 1.76))
			_box(s, "frame", Vector3(x - side * 0.1, 0.47, z - 0.9), Vector3(0.20, 0.89, 0.10))
			_box(s, "light", Vector3(x - side * 0.12, 0.86, z), Vector3(0.08, 0.05, 0.35))
	_box(s, "frame", Vector3(0, 0.83, 7.20), Vector3(18.6, 0.055, 0.39))
	_box(s, "steel", Vector3(0, 0.67, 7.02), Vector3(18.0, 0.07, 0.06))
	for x in [-8, -6, -4, 4, 6, 8]:
		_box(s, "sage", Vector3(x, 0.42, 7.025), Vector3(1.80, 0.38, 0.07))
		_box(s, "warning", Vector3(x, 0.78, 7.0), Vector3(0.30, 0.05, 0.045))
	# The stock rear columns retain their exact collision and gain metal shoes/caps.
	for x in [-8.5, -4.5, 4.5, 8.5]:
		_box(s, "frame", Vector3(x, 0.14, -6.6), Vector3(0.73, 0.28, 0.76))
		_box(s, "steel", Vector3(x, 1.20 if future else 2.36, -6.6), Vector3(0.68, 0.12, 0.71))
	# Physical wall lettering has no billboard and no interaction highlight.
	_sign("CONTINUITY  /  03", Vector3(0, 2.03, -6.81), 0.0075)
	_sign("TEMPORAL RESEARCH DIVISION", Vector3(0, 1.68, -6.80), 0.003)


func _props() -> void:
	var s := "LaboratoryProps"
	# Matched silhouettes tell the room's history; all clusters hug the perimeter.
	for side in [-1, 1]:
		var x: float = side * 6.15
		_box(s, "frame", Vector3(x, 0.10, -6.25), Vector3(2.15, 0.20, 0.76))
		_box(s, "sage", Vector3(x, 0.55, -6.25), Vector3(2.05, 0.76, 0.67))
		_box(s, "steel", Vector3(x, 0.98, -6.25), Vector3(2.20, 0.10, 0.82))
		for dx in [-0.65, 0, 0.65]:
			_box(s, "wall", Vector3(x + dx, 0.56, -5.89), Vector3(0.58, 0.63, 0.06))
			_box(s, "frame", Vector3(x + dx, 0.77, -5.84), Vector3(0.26, 0.045, 0.035))
		_box(s, "frame", Vector3(side * 8.60, 0.64, 2.1), Vector3(0.53, 1.28, 1.10))
		_box(s, "sage", Vector3(side * 8.60, 0.72, 2.1), Vector3(0.55, 0.96, 0.94))
		for z in [1.8, 2.4]:
			_box(s, "steel", Vector3(side * 8.29, 0.78, z), Vector3(0.05, 0.30, 0.07))
	# Existing original laboratory models, loaded as visuals without prop bodies.
	_model("res://assets/environment/models/electronics/lab_oscilloscope.glb", Vector3(-6.65, 1.04, -6.23), 0.50)
	_model("res://assets/environment/models/laboratory/lab_microscope.glb", Vector3(6.1, 1.04, -6.24), 0.45)
	_model("res://assets/environment/models/laboratory/lab_flask_set.glb", Vector3(6.80, 1.04, -6.24), 0.40)
	_model("res://assets/environment/models/documents/lab_paper_graph.glb", Vector3(-5.65, 1.04, -6.16), 0.60)
	# Maintenance trolley tucked into the west alcove; no luminous controls.
	var cart := Vector3(-8.35, 0, -3.5)
	for y in [0.18, 0.78]:
		_box(s, "steel", cart + Vector3(0, y, 0), Vector3(0.84, 0.065, 1.05))
	for dx in [-0.35, 0.35]:
		for dz in [-0.43, 0.43]:
			_box(s, "frame", cart + Vector3(dx, 0.47, dz), Vector3(0.06, 0.78, 0.06))
			_box(s, "seam", cart + Vector3(dx, 0.08, dz), Vector3(0.13, 0.13, 0.13))
	_box(s, "copper", cart + Vector3(0, 0.88, 0.10), Vector3(0.52, 0.16, 0.40))
	_box(s, "frame", cart + Vector3(0, 0.99, 0.10), Vector3(0.27, 0.08, 0.08))
	# Spare ceramic couplers sit on the lower cart shelf.
	for dz in [-0.25, 0.05, 0.35]:
		_box(s, "wall", cart + Vector3(0.05, 0.31, dz), Vector3(0.34, 0.16, 0.17))
	# Distribution units and paired cable risers on the rear wall.
	for x in [-3.0, 3.0]:
		_box(s, "frame", Vector3(x, 1.3, -6.76), Vector3(0.72, 1.12, 0.32))
		_box(s, "sage", Vector3(x, 1.3, -6.57), Vector3(0.61, 0.99, 0.08))
		_box(s, "warning", Vector3(x, 1.46, -6.51), Vector3(0.28, 0.23, 0.025))
		for dx in [-0.13, 0.13]:
			_box(s, "copper", Vector3(x + dx, 0.47, -6.64), Vector3(0.055, 0.70, 0.065))
	# Passive fire equipment: red enclosure, no screen, key or button silhouette.
	_box(s, "frame", Vector3(8.1, 0.97, -6.24), Vector3(0.52, 1.20, 0.35))
	_box(s, "copper", Vector3(8.1, 0.96, -6.01), Vector3(0.35, 0.68, 0.18))
	_box(s, "wall", Vector3(8.1, 1.02, -5.90), Vector3(0.09, 0.30, 0.02))
	_box(s, "wall", Vector3(8.1, 1.02, -5.89), Vector3(0.24, 0.09, 0.02))
	_sign("AUXILIARY / SERVICE", Vector3(-6.15, 1.83, -6.73), 0.003)
	_sign("SPECIMEN / ANALYSIS", Vector3(6.15, 1.83, -6.73), 0.003)
	# Future damage stays around the maintenance edge, never in walking lanes.
	if future:
		_conduit_casing()
		for i in range(8):
			_box(s, "inset" if i % 2 else "copper", Vector3(8.3 - (i % 3) * 0.21, 0.055, -4.6 + i * 0.17), Vector3(0.20, 0.045, 0.13), i * 0.7)
		for x in [-5.0, 5.0]:
			_line(s, "seam", Vector3(x, 1.9, -6.65), Vector3(x + 0.17, 1.4, -6.50), 0.055, 0.055)
			_line(s, "copper", Vector3(x + 0.17, 1.4, -6.50), Vector3(x - 0.05, 0.94, -6.56), 0.03, 0.03)
		_box(s, "paper", Vector3(-6.05, 1.046, -6.12), Vector3(0.24, 0.005, 0.18), 0.5)


func _conduit_casing() -> void:
	var moving := Node3D.new()
	moving.name = "GateDressing"
	add_child(moving)
	_sections.GateDressing = moving
	for side in [-1, 1]:
		var s := "GateDressing" if side > 0 else "LaboratoryProps"
		var height := 1.3 if side > 0 else 0.9
		for i in range(6):
			var x: float = side * (2.32 + i * 1.20)
			_box(s, "frame", Vector3(x, height * 0.50, -0.895 if side > 0 else -0.965), Vector3(1.13, height * 0.78, 0.055))
			_box(s, "inset", Vector3(x, height * 0.53, -0.855 if side > 0 else -0.925), Vector3(0.94, height * 0.59, 0.035))
			_box(s, "steel", Vector3(x - 0.53, height * 0.50, -0.81 if side > 0 else -0.88), Vector3(0.07, height * 0.84, 0.07))
			_box(s, "copper", Vector3(x, height + 0.025, -1.20), Vector3(1.13, 0.05, 0.20))
			for n in range(3):
				_box(s, "steel", Vector3(x - 0.23 + n * 0.22, height * 0.58, -0.82 if side > 0 else -0.89), Vector3(0.06, height * 0.26, 0.025))
			if i % 2 == 0:
				_box(s, "warning", Vector3(x + 0.30, height * 0.79, -0.81 if side > 0 else -0.88), Vector3(0.21, 0.10, 0.028))


func _model(path: String, at: Vector3, size: float) -> void:
	var packed := load(path) as PackedScene
	assert(packed != null, "Missing existing laboratory model: " + path)
	var model := packed.instantiate() as Node3D
	model.position = at
	model.scale = Vector3.ONE * size
	_sections.LaboratoryProps.add_child(model)
	TimelineMaterials.apply_materials(model, future)


func _sign(text: String, at: Vector3, size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font = Typography.font(&"ui_label")
	label.font_size = 48
	label.pixel_size = size
	label.outline_size = 0
	label.modulate = Color("b6c6c8") if future else Color("354a43")
	label.no_depth_test = false
	_sections.WallDetails.add_child(label)


func _flush() -> void:
	for key: String in _boxes:
		var parts := key.split("/")
		var transforms: Array = _boxes[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _unit_box
		mm.instance_count = transforms.size()
		for i in transforms.size(): mm.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = parts[1].to_pascal_case()
		instance.multimesh = mm
		instance.material_override = materials[parts[1]]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sections[parts[0]].add_child(instance)
		triangle_count += transforms.size() * 12
		instance_count += transforms.size()
	for mat: String in _sectors:
		var vertices: PackedVector3Array = _sectors[mat]
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for v: Vector3 in vertices:
			normals.append(Vector3.UP)
			uvs.append(Vector2(v.x, v.z) * 0.2 + Vector2(0.5, 0.5))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.name = "Apron" + mat.to_pascal_case()
		instance.mesh = mesh
		instance.material_override = materials[mat]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sections.ReactorSurroundings.add_child(instance)
		triangle_count += vertices.size() / 3
	_boxes.clear()
	_sectors.clear()
