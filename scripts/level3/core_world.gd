extends Node3D
## Room-C-only assembly; existing props are instantiated, never edited on disk.

const Rules := preload("res://scripts/level3/core_rules.gd")
const Interactable := preload("res://scripts/interaction/interactable_3d.gd")
const Palette := preload("res://scripts/environment/env_palette.gd")
const EnvironmentArt := preload("res://scenes/level3/environment/laboratory_environment.tscn")

var role: String
var stations: Dictionary = {}
var indicators: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var rifts: Array[MeshInstance3D] = []
var conduits: Array[MeshInstance3D] = []
var gate: StaticBody3D
var gate_shape: CollisionShape3D
var waveform: Label3D
var core: MeshInstance3D
var reactor_light: OmniLight3D
var future: bool
var effects_enabled: bool = true
var age: float = 0.0
var stage: String = "DISCOVERY"
var ending: String = ""
var accent: Color
var _coil_materials: Array[StandardMaterial3D] = []
var environment_art: Node3D


func build(timeline: String, operate: Callable, decorate: bool = true) -> void:
	role = timeline
	future = role == "future"
	accent = Color("74deed") if future else Color("efc077")
	var wall := Color("324b60") if future else Color("d4c4a2")
	var floor_color := Color("243b4b") if future else Color("979480")
	var architecture_color := Color("304653") if future else Color("889584")
	box(Vector3(0, -0.15, 0), Vector3(18.4, 0.3, 14.4), floor_color, true)
	# The new plate layer is cosmetic; this original slab remains the Y=0 contact plane.
	for x in [-9.2, 9.2]:
		box(Vector3(x, 0.48, 0), Vector3(0.3, 0.96, 14.6), architecture_color, true)
	for z in [-7.2, 7.2]:
		box(Vector3(0, 0.4, z), Vector3(18.6, 0.8, 0.3), architecture_color, true)
	for x in [-8.5, -4.5, 4.5, 8.5]:
		var column := box(Vector3(x, 1.2, -6.6), Vector3(0.6, 2.4, 0.65), architecture_color, true)
		if future:
			column.rotation.z = 0.12 if x < 0 else -0.18
			column.scale.y = 0.6
	for x in [-1.8, 1.8]:
		box(Vector3(x, 0.08, 0), Vector3(0.12, 0.16, 3.4), Color("d9a441"))
	cylinder(Vector3(0, 0.3, 0), 1.5, 0.6, Color("32434b"), true)
	cylinder(Vector3(0, 0.75, 0), 1.12, 0.3, Color("647c83"))
	core = cylinder(Vector3(0, 1.7, 0), 0.48, 1.4, accent)
	core.material_override = material(accent, true)
	for i in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.12 + i * 0.28
		torus.outer_radius = 1.24 + i * 0.28
		torus.rings = 24
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position.y = 1.8
		ring.rotation.x = PI / 3.0 + i * 0.8
		ring.material_override = material(accent, true)
		add_child(ring)
		rings.append(ring)
	label("TEMPORAL CORE\nTWO VERSIONS. ONE IDENTITY. ONE SURVIVOR.", Vector3(0, 3.5, -0.3), 22)
	reactor_light = OmniLight3D.new()
	reactor_light.position = Vector3(0, 3, 0)
	reactor_light.omni_range = 8
	reactor_light.light_color = accent
	reactor_light.light_energy = 0.8
	add_child(reactor_light)
	for i in range(3):
		var cable := box(Vector3(-3.6, 0.035, -2.0 + i * 2), Vector3(4.3, 0.055, 0.1), Color("463f32"))
		conduits.append(cable)
		var glow := box(Vector3(3.6, 0.045, -2.0 + i * 2), Vector3(4.3, 0.06, 0.1), Color("293c49"))
		conduits.append(glow)
		var led := box(Rules.STATIONS["coil_%d" % i] + Vector3(0, 1.25, 0), Vector3(0.5, 0.14, 0.4), Color("a75e37"))
		led.material_override = material(Color("a75e37"), true)
		indicators.append(led)
		_coil_materials.append(led.material_override)
	if future:
		# The collapsed conduit closes the only north path until Past restores power.
		box(Vector3(-5.35, 0.45, -1.2), Vector3(7.3, 0.9, 0.4), wall, true)
		gate = box(Vector3(5.35, 0.65, -1.2), Vector3(7.3, 1.3, 0.55), Color("57546d"), true)
		gate_shape = gate.get_node("Collision")
		label("COLLAPSED CONDUIT / POWER REQUIRED", Vector3(5.2, 1.7, -1.2), 20)
		for i in range(9):
			var crack := box(Vector3(-7.7 + i * 1.7, 0.019, -5.5 + (i % 3) * 0.4), Vector3(0.04, 0.02, 1.4), Color("9d76c9"))
			crack.rotation.y = 0.4 + i * 0.17
		for i in range(4):
			var shard := box(Vector3(-0.8 + i * 0.6, 1.3 + (i % 2) * 0.6, -0.4), Vector3(0.08, 0.8, 0.12), Color("bf92ee"))
			shard.material_override = material(Color("bf92ee"), true)
			rifts.append(shard)
		prop("debris_a", Vector3(7.8, 0, -6), 0.65)
		prop("debris_b", Vector3(-7.7, 0, -6), 0.7)
		prop("wall_panel_damaged", Vector3(-2, 0, -6.8), 0.7)
		prop("pipe_broken", Vector3(8, 0, -5), 0.7)
	else:
		prop("potted_plant", Vector3(8, 0, -6), 0.8)
		prop("cabinet_low", Vector3(-7.8, 0, -6), 0.8)
	# Recognizable evidence desks, papers, cables and machinery reuse current assets.
	prop("reading_table", Vector3(-7, 0, 4.8), 0.9)
	prop("reading_table", Vector3(7, 0, 4.8), 0.9)
	prop("paper_stack", Vector3(-7, 0.8, 4.7), 0.8)
	prop("paper_notes", Vector3(7, 0.8, 4.7), 0.8)
	prop("cable_reel", Vector3(-8, 0, 6.2), 0.75)
	prop("signal_rack", Vector3(8, 0, -6), 0.6)
	for i in range(5):
		prop("paper_crumpled" if future else "paper_graph", Vector3(-6 + i * 2.5, 0.025, 6), 0.5)
	var specs := {
		"start": "ARM REACTOR / 150s",
		"coil_0": "COIL 1 / 0", "coil_1": "COIL 2 / 0", "coil_2": "COIL 3 / 0",
		"receiver": "RESTORE RECEIVER", "anchor": "SIGNAL ANCHOR",
		"origin": "ORIGIN CORE", "sync_past": "PAST PHASE SWITCH", "sync_future": "FUTURE PHASE SWITCH",
		"terminal_past": "ORIGIN TERMINAL", "terminal_future": "CONTINUITY TERMINAL",
		"evidence_past": "AUTHORIZATION SHEET", "warning": "HANDWRITTEN WARNING",
		"evidence_future": "CONTINUITY RECORDING", "routing": "DAMAGED ROUTING DIAGRAM"
	}
	for id: String in specs:
		var station_role := ""
		if id.begins_with("coil") or id in ["origin", "sync_past", "terminal_past", "evidence_past", "warning"]: station_role = "past"
		if id in ["receiver", "anchor", "sync_future", "terminal_future", "evidence_future", "routing"]: station_role = "future"
		if station_role != "" and station_role != role: continue
		var area := Interactable.new()
		area.name = id
		area.position = Rules.STATIONS[id]
		area.interaction_distance = 1.65
		area.interaction_name = specs[id]
		area.allowed_timeline = 1 if role == "past" else 2
		area.timing = Interactable.Timing.IMMEDIATE
		area.play_interaction_animation = false
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.65
		shape.shape = sphere
		area.add_child(shape)
		add_child(area)
		stations[id] = area
		area.interacted.connect(func(_actor: Node, _role: String) -> void: operate.call(id))
		var plate := box(area.position + Vector3(0, 0.03, 0.65), Vector3(0.75, 0.045, 0.3), accent)
		plate.material_override = material(accent.darkened(0.45), true)
		area.highlight_changed.connect(func(on: bool) -> void: plate.material_override.albedo_color = accent if on else accent.darkened(0.45))
		var title := label(specs[id], area.position + Vector3(0, 1.65, 0), 22)
		area.set_meta("title", title)
		if id.begins_with("coil") or id.begins_with("terminal"):
			title.font = Typography.display_font(future)
		if not id.begins_with("evidence") and not id in ["warning", "routing"]:
			if id.begins_with("coil"):
				cylinder(area.position + Vector3(0, 0.45, 0), 0.45, 0.9, wall, true)
				for n in range(4):
					cylinder(area.position + Vector3(0, 0.35 + n * 0.22, 0), 0.48, 0.08, Color("ae7945"))
			else:
				var visual: Node3D = load("res://scenes/props/console_visual.tscn").instantiate()
				visual.position = area.position
				visual.scale = Vector3.ONE * 0.43
				add_child(visual)
				box(area.position + Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 0.45), wall, true)
	waveform = label("", Vector3(6 if future else -3, 2, -3), 24)
	waveform.font = Typography.display_font(future)
	var chapter_sign := label("III / THE FINAL FRACTURE\n" + ("31 YEARS LATER" if future else "PROJECT CONTINUITY"), Vector3(0, 1.5, -6.7), 32)
	chapter_sign.visible = not decorate
	if decorate:
		environment_art = EnvironmentArt.instantiate()
		add_child(environment_art)
		environment_art.build(future, gate)


func apply_state(state: Dictionary) -> void:
	stage = state.stage
	ending = state.ending
	for i in range(3):
		_coil_materials[i].albedo_color = Color("72dca8") if state.coils[i] == Rules.COIL_TARGET[i] else Color("dba45a")
		var id := "coil_%d" % i
		if stations.has(id):
			var text := "COIL %d / %d" % [i + 1, state.coils[i]]
			stations[id].interaction_name = text + " / CYCLE"
			stations[id].get_meta("title").text = text
	for i in range(conduits.size()):
		var lit: bool = state.coils[i / 2] == Rules.COIL_TARGET[i / 2]
		conduits[i].material_override = material(Color("73cfa9") if lit else Color("393d3e"), lit)
	if future:
		var opened: bool = state.receiver and state.coils == Rules.COIL_TARGET
		gate.position.y = -1.6 if opened else 0.0
		gate_shape.set_deferred("disabled", opened)
		gate.get_child(0).visible = not opened
	waveform.text = ""
	if state.anchor:
		waveform.text = ("ECHO PHASE / 142.8" if future else "ORIGIN PHASE / 142.8 / ALIGNMENT EXPOSED")
		if state.origin:
			waveform.text += "\nI: %s  /  II: %s" % ["HELD" if state.sync_past else "READY", "HELD" if state.sync_future else "READY"]
	for id: String in stations:
		var enabled := true
		if id == "start": enabled = stage == "DISCOVERY"
		elif id.begins_with("coil"): enabled = stage == "STAGE_A"
		elif id == "receiver": enabled = stage == "STAGE_A" and not state.receiver
		elif id == "anchor": enabled = stage == "STAGE_B" and not state.anchor
		elif id == "origin": enabled = stage == "STAGE_B" and state.anchor and not state.origin
		elif id.begins_with("sync_"): enabled = stage == "STAGE_B" and state.anchor and state.origin and not state[id]
		elif id.begins_with("terminal_"): enabled = stage == "STAGE_C" and not state["locked_" + role]
		stations[id].interaction_enabled = enabled and not stage in ["ENDING", "OVERLOAD"]
	if ending != "":
		var colors := {"trust": Color("8ee5bb"), "student_override": Color("efb851"), "professor_override": Color("84a8ee"), "paradox": Color("b584e8")}
		core.material_override = material(colors[ending], true)
		reactor_light.light_color = colors[ending]
	else:
		core.material_override = material(accent, true)
		reactor_light.light_color = Color("e48f65") if stage == "OVERLOAD" else accent


func _process(delta: float) -> void:
	age += delta
	if environment_art != null: environment_art.set_effects_enabled(effects_enabled)
	var speed := 0.2 if stage == "DISCOVERY" else 0.8
	if stage == "STAGE_C": speed = 1.4
	if ending == "trust": speed = 0.06
	if ending == "student_override": speed = -0.6
	if ending == "professor_override": speed = 0.4
	if ending == "paradox": speed = -2.0
	for i in range(rings.size()):
		rings[i].rotation.z += delta * speed * (1 if i == 0 else -1)
		rings[i].scale = Vector3.ONE * (0.65 if ending == "trust" else 1.0)
	for i in range(rifts.size()):
		rifts[i].visible = effects_enabled and ending != "trust"
		rifts[i].position.y = 1.3 + sin(age * 0.8 + i) * 0.25
		rifts[i].rotation.z += delta * 0.3
	reactor_light.light_energy = 0.65 + sin(age * 1.5) * 0.1


func material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if luminous:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color
	return m


func box(at: Vector3, size: Vector3, color: Color, collision: bool = false) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return geometry(mesh, at, color, collision)


func cylinder(at: Vector3, radius: float, height: float, color: Color, collision: bool = false) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return geometry(mesh, at, color, collision)


func geometry(mesh: Mesh, at: Vector3, color: Color, collision: bool) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	if not collision:
		instance.position = at
		add_child(instance)
		return instance
	var body := StaticBody3D.new()
	# Collision/prop roots remain on their ground plane; offsets live on children.
	body.position = Vector3(at.x, 0, at.z)
	instance.position.y = at.y
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var footprint := BoxShape3D.new()
	footprint.size = mesh.get_aabb().size
	shape.shape = footprint
	shape.position.y = at.y
	body.add_child(shape)
	add_child(body)
	return body


func label(text: String, at: Vector3, font_size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.font_size = font_size
	l.font = Typography.font(&"ui_label")
	l.pixel_size = 0.006
	l.outline_size = 6
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("f5ecd8")
	add_child(l)
	return l


func prop(id: String, at: Vector3, size: float) -> void:
	var packed: PackedScene = load("res://scenes/environment/props/%s.tscn" % id)
	var p: Node3D = packed.instantiate()
	p.position = at
	p.scale = Vector3.ONE * size
	add_child(p)
	if "future" in p: p.future = future
