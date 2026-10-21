extends Node3D
## Physical storage, carried props and repair sockets; all mutations go through PuzzleManager.
const Rules := preload("res://scripts/gameplay/storage/storage_rules.gd")
var room: Node3D
var cases := {}
var targets := {}
var bays: Array[Node3D] = []
var screens: Array[Label3D] = []
var doors: Array[Node3D] = []
var stored: Array[Node3D] = []
var lifts: Array[Node3D] = []
var motions: Array[Tween] = []
var busy: Array[bool] = []
var poses: Array[String] = []
var _display_role := ""
const TOP := 0.10
const BOTTOM := -2.10
var sockets := {}
var modules := {}
var archive_display: Label3D
var _materials := {}

func configure(owner_room: Node3D) -> void:
	room = owner_room
	name = "PreservationStorage"
	for index in 3: _build_bay(index)
	for id in Rules.ITEMS:
		var item: Dictionary = Rules.ITEMS[id]
		var visual := _case_model(id)
		visual.name = "Item_" + id
		add_child(visual)
		cases[id] = visual
		var target := _target("Case_" + id, item.home, 1)
		target.interaction_name = "Carry " + item.label
		target.interacted.connect(func(_actor: Node, _role: String) -> void: room._request("pickup_storage_item", {"item": id}))
		targets[id] = target
	_build_archive()

func _material(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = 0.78
		_materials[color] = material
	return _materials[color]

func _box(parent: Node3D, id: String, pos: Vector3, size: Vector3, color: String, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		mesh.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return mesh

func _label(parent: Node3D, pos: Vector3, text: String, size: int = 32) -> Label3D:
	var label := Label3D.new()
	label.position = pos
	label.text = text
	label.font_size = size
	label.pixel_size = 0.003
	label.modulate = Color("e9dfbb")
	label.outline_size = 4
	parent.add_child(label)
	return label

func _target(id: String, pos: Vector3, timeline: int = 0) -> Interactable3D:
	var target := Interactable3D.new()
	target.name = id
	target.position = pos
	target.allowed_timeline = timeline
	target.interaction_distance = 1.65
	target.play_interaction_animation = true
	target.timing = Interactable3D.Timing.AFTER_ANIMATION
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.27
	collision.shape = shape
	collision.position.y = 0.35
	target.add_child(collision)
	add_child(target)
	room.devices[id] = target
	return target

func _case_model(id: String) -> Node3D:
	var root := Node3D.new()
	var item: Dictionary = Rules.ITEMS[id]
	var size := Vector3(0.66, 0.42, 0.44)
	if id in ["m22", "t31"]: size = Vector3(0.76, 0.48, 0.48)
	if id == "h08": size = Vector3(0.5, 0.32, 0.38)
	if id == "spool":
		for x in [-0.25, 0.25]: _box(root, "Flange", Vector3(x, 0.28, 0), Vector3(0.07, 0.55, 0.55), "815d43")
		_box(root, "Cable", Vector3(0, 0.28, 0), Vector3(0.46, 0.38, 0.38), "273b40")
	else:
		_box(root, "Shell", Vector3(0, size.y / 2, 0), size, item.color)
		for x in [-0.22, 0.22]:
			_box(root, "Band", Vector3(x, size.y / 2, 0), Vector3(0.055, size.y + 0.025, size.z + 0.025), "263b42")
		_box(root, "Handle", Vector3(0, size.y + 0.035, 0), Vector3(0.24, 0.07, 0.12), "bdac82")
	_label(root, Vector3(0, size.y / 2, size.z / 2 + 0.012), id.to_upper(), 34)
	return root

func _build_bay(index: int) -> void:
	var bay := Node3D.new()
	bay.name = "Bay%d" % index
	bay.position = Vector3((index - 1) * 1.75, 0, -6.25)
	bay.set_meta("inspection_bounds", AABB(Vector3(-0.85, -0.05, -1.20), Vector3(1.7, 1.65, 2.1)))
	bay.set_meta("inspection_direction", Vector3(0, -3.6, -4.4))
	add_child(bay)
	bays.append(bay)
	motions.append(null)
	busy.append(false)
	poses.append("")
	# The map has a real cutout beneath each hatch. Shaft walls and a bottom sit below it.
	_box(bay, "ShaftBottom", Vector3(0, BOTTOM - 0.12, 0), Vector3(1.36, 0.18, 1.36), "172a30", true)
	for x in [-0.72, 0.72]:
		_box(bay, "ShaftWall", Vector3(x, -1.10, 0), Vector3(0.08, 2.2, 1.5), "263b42", true)
		_box(bay, "LiftRail", Vector3(x * 0.8, -1.10, -0.59), Vector3(0.06, 2.2, 0.08), "b0a886")
		_box(bay, "GuardRail", Vector3(x, 0.35, 0), Vector3(0.06, 0.08, 1.6), "a89963", true)
	for z in [-0.72, 0.72]:
		_box(bay, "ShaftWall", Vector3(0, -1.10, z), Vector3(1.36, 2.2, 0.08), "394d54", true)
		_box(bay, "Rim", Vector3(0, 0.025, z), Vector3(1.5, 0.05, 0.10), "bd9a54")
	# A low front guard keeps the player outside the machinery while the shaft is open.
	_box(bay, "FrontGuard", Vector3(0, 0.30, 0.79), Vector3(1.5, 0.60, 0.07), "506164", true)
	var hatch := Node3D.new()
	hatch.name = "FloorHatch"
	bay.add_child(hatch)
	doors.append(hatch)
	for side in [-1, 1]:
		var hinge := Node3D.new()
		hinge.name = "LeftHinge" if side == -1 else "RightHinge"
		hinge.position = Vector3(side * 0.68, 0.04, 0)
		hatch.add_child(hinge)
		_box(hinge, "HatchDoor", Vector3(-side * 0.335, 0, 0), Vector3(0.67, 0.06, 1.34), "6d7973")
		_box(hinge, "DoorStripe", Vector3(-side * 0.335, 0.035, 0), Vector3(0.08, 0.008, 1.20), "c89b4c")
	var lift := Node3D.new()
	lift.name = "LiftPlatform"
	bay.add_child(lift)
	lifts.append(lift)
	_box(lift, "PressurePlate", Vector3.ZERO, Vector3(1.17, 0.08, 1.17), "a3a896")
	_box(lift, "PlateEdge", Vector3(0, 0.05, 0.55), Vector3(1.15, 0.025, 0.04), "76b3ae")
	var content := Node3D.new()
	lift.add_child(content)
	content.position.y = 0.05
	stored.append(content)
	# Each bay has its own computer; no shared three-bay commit.
	_box(bay, "ComputerPedestal", Vector3(0, 0.48, -1.00), Vector3(0.60, 0.96, 0.38), "394d54", true)
	_box(bay, "ComputerScreen", Vector3(0, 1.13, -0.96), Vector3(1.12, 0.52, 0.15), "172a30")
	screens.append(_label(bay, Vector3(0, 1.20, -0.875), "0.0 kg", 44))
	_label(bay, Vector3(0, 1.50, -0.96), "VAULT / %s" % ["A", "B", "C"][index], 34)
	_label(bay, Vector3(0, 0.88, -0.86), "UNDERGROUND / DRY / SHIELDED", 18)
	_box(bay, "ComputerKey", Vector3(0, 0.78, -0.69), Vector3(0.27, 0.13, 0.16), "d6ac63")
	_box(bay, "LowerKey", Vector3(0.36, 0.78, -0.69), Vector3(0.22, 0.13, 0.16), "ae7e58")
	_box(bay, "PlaceHandle", Vector3(-0.31, 0.61, 0.81), Vector3(0.26, 0.10, 0.12), "76b3ae")
	_box(bay, "TakeHandle", Vector3(0.31, 0.61, 0.81), Vector3(0.26, 0.10, 0.12), "ae7e58")
	var id := "StorageBay%d" % index
	var target := _target(id, bay.position + Vector3(0, 0, 1.10))
	target.interaction_name = "Use underground storage computer " + ["A", "B", "C"][index]
	target.interacted.connect(func(_actor: Node, _role: String) -> void: room._show_device(id))

func _build_archive() -> void:
	var archive: Node3D = room.get_node("Layout/Shared/ArchiveStand")
	var hidden := ["ArchiveShelf", "ArchivePapers", "ShelfDark"]
	for i in 6:
		hidden.append("Folder%d" % i)
		hidden.append("FolderTab%d" % i)
	for id in hidden:
		var old := archive.get_node_or_null(id)
		if old != null: old.hide()
	_box(archive, "ArchiveScreen", Vector3(0, 0.94, 0.14), Vector3(1.1, 0.63, 0.12), "172a30")
	archive_display = _label(archive, Vector3(0, 1.02, 0.22), "ARCHIVE / SERVICE", 28)
	for index in 3:
		var part: String = Rules.PARTS.keys()[index]
		var socket := _box(archive, "Socket_" + part, Vector3((index - 1) * 0.35, 0.63, 0.35), Vector3(0.29, 0.22, 0.18), "b65e4a")
		sockets[part] = socket
		var module := _box(socket, "ReplacementModule", Vector3(0, 0, 0.04), Vector3(0.19, 0.14, 0.20), "b8c8bc")
		_box(module, "Contacts", Vector3(0, -0.08, 0.03), Vector3(0.15, 0.025, 0.1), "d6ac63")
		modules[part] = module
		_label(socket, Vector3(0, 0, 0.10), str(index + 1), 34)

func handles(id: String) -> bool:
	return id.begins_with("StorageBay")

func open_archive() -> void:
	if room.state.battery_ready and not room.state.storage.manifest_read:
		room._request("read_manifest")
	var s: Dictionary = room.state.storage
	var body := "TERMINAL SELF-TEST / THREE DAMAGED COMPONENTS\n"
	if s.manifest_read:
		body += "SURVIVING MAINTENANCE RECORD / SHIPPING WEIGHT (sealed case)\n1 Optical archive reader: 4.8 kg\n2 Voltage regulator: 2.6 kg\n3 Shielded memory module: 7.2 kg\n\nStore replacements in the dry, shielded underground vault. Seat each preserved component in its matching socket.\n"
	else: body += "Restore power to read the maintenance record.\n"
	var options: Array = []
	for part in Rules.PARTS:
		var installed: bool = not s.installed[part].is_empty()
		body += "\n%s: %s" % [Rules.PARTS[part], "INSTALLED" if installed else "DAMAGED"]
		options.append(room._option("Install " + Rules.PARTS[part], "install_component", {"part": part}, installed or s.future_hand.is_empty() or not s.manifest_read))
	if not s.future_hand.is_empty(): body += "\n\nCarrying: " + Rules.ITEMS[s.future_hand].contents
	_open(room.get_node("Layout/Shared/ArchiveStand"), "ARCHIVE / REPAIR", body, options, {
		"Install " + Rules.PARTS.reader: sockets.reader, "Install " + Rules.PARTS.regulator: sockets.regulator, "Install " + Rules.PARTS.memory: sockets.memory})

func open_device(id: String) -> void:
	var index := int(id.trim_prefix("StorageBay"))
	var bay: Dictionary = room.state.storage.bays[index]
	var s: Dictionary = room.state.storage
	var options: Array = []
	var body := "UNDERGROUND PRESERVATION LIFT\nDry atmosphere / radiation shielding / independent floor hatch.\n"
	if busy[index]: body += "\nLIFT MOVING / STAND CLEAR\n"
	if room.role == "past":
		body += "\nPRESSURE PLATE: " + _weight(bay) + "\n" + ("STORED BELOW FLOOR" if bay.sealed else "LOADING TRAY AT SURFACE")
		body += "\nLoad any object. The computer opens the floor hatch, lowers the tray and seals the vault."
		options = [room._option("Place carried object", "place_storage_item", {"bay": index}, bay.sealed or not bay.item.is_empty() or s.past_hand.is_empty()),
			room._option("Remove stored object", "remove_storage_item", {"bay": index}, bay.sealed or bay.item.is_empty() or not s.past_hand.is_empty()),
			room._option("Raise loading tray" if bay.sealed else "Lower and store tray", "unseal_bay" if bay.sealed else "seal_bay", {"bay": index}, bay.retrieved or bay.raised)]
		if bay.retrieved or bay.raised:
			body += "\nPreserved component installed. Keep this source sealed." if bay.item in s.installed.values() else "\nFuture tray is in use. Return or lower it there before changing this source."
	else:
		var occupied: bool = bay.sealed and not bay.item.is_empty() and not bay.retrieved
		body += "\n" + ("PRESERVED EQUIPMENT BELOW" if occupied and not bay.raised else ("EQUIPMENT AT SURFACE" if occupied else "NO STORED EQUIPMENT"))
		body += "\nUse the computer to open the hatch and raise the preserved tray. Collect the equipment once the lift stops."
		options = [room._option("Raise preserved tray", "raise_storage_tray", {"bay": index}, not occupied or bay.raised),
			room._option("Collect raised contents", "retrieve_storage_item", {"bay": index}, not occupied or not bay.raised or not s.future_hand.is_empty()),
			room._option("Return and lower contents", "return_storage_item", {"bay": index}, s.future_hand.is_empty() or s.future_hand != bay.item),
			room._option("Lower preserved tray", "lower_storage_tray", {"bay": index}, not bay.raised or bay.retrieved)]
		if not s.future_hand.is_empty():
			body += "\n\nProfessor: Inside this case — " + Rules.ITEMS[s.future_hand].contents + "."
			if Rules.ITEMS[s.future_hand].part.is_empty(): body += " This is the wrong equipment. I'll return it so you can replace it."
	var bindings := {}
	for option in options:
		option.disabled = option.disabled or busy[index] or not room.state.battery_ready
		var control := "ComputerKey"
		if option.action in ["place_storage_item", "return_storage_item"]: control = "PlaceHandle"
		elif option.action in ["remove_storage_item", "retrieve_storage_item"]: control = "TakeHandle"
		elif option.action == "lower_storage_tray": control = "LowerKey"
		bindings[option.label] = bays[index].get_node(control)
	_open(bays[index], "UNDERGROUND VAULT " + ["A", "B", "C"][index], body, options, bindings)

func _open(mount: Node3D, title: String, body: String, options: Array, bindings: Dictionary) -> void:
	room.ui.device_mount = mount
	room.ui.device_bindings = bindings
	room.ui.camera = room.camera
	room.ui.actor = room.player
	room._rebuilding_panel = true
	room.ui.open_device(title, body, options)
	room._rebuilding_panel = false

func _weight(bay: Dictionary) -> String:
	return "%.1f kg" % (0.0 if bay.item.is_empty() else Rules.ITEMS[bay.item].kg)

func refresh(animate: bool = false) -> void:
	var s: Dictionary = room.state.storage
	for id in cases:
		var floor_item: bool = s.floor_items.has(id) and room.role == "past"
		cases[id].visible = floor_item
		if floor_item: cases[id].position = s.floor_items[id]
		targets[id].position = s.floor_items.get(id, Rules.ITEMS[id].home)
		targets[id].interaction_enabled = floor_item and s.past_hand.is_empty() and room.state.battery_ready
	for index in 3:
		var bay: Dictionary = s.bays[index]
		var future: bool = room.role == "future"
		screens[index].text = ("OCCUPIED" if bay.sealed and not bay.item.is_empty() and not bay.retrieved else "EMPTY") if future else _weight(bay)
		var pose := "up_open" if future and bay.raised else ("down" if future or bay.sealed else "up_closed")
		if poses[index] != pose or _display_role != room.role:
			_move_lift(index, pose, animate and _display_role == room.role)
		var content: Node3D = stored[index]
		var shown: String = bay.item if (not future or bay.sealed and not bay.retrieved) else ""
		if content.get_meta("item", "") != shown:
			for child in content.get_children():
				content.remove_child(child)
				child.queue_free()
			if not shown.is_empty(): content.add_child(_case_model(shown))
			content.set_meta("item", shown)
	_display_role = room.role
	for part in sockets:
		var installed: bool = not s.installed[part].is_empty()
		sockets[part].material_override = _material("76c9b3" if installed else "b65e4a")
		modules[part].visible = installed
	archive_display.text = "ARCHIVE / ONLINE" if Rules.repaired(room.state) else "FAULT / %d OF 3 FITTED" % (3 - s.installed.values().count(""))
	update_carry()

func _move_lift(index: int, pose: String, animate: bool) -> void:
	poses[index] = pose
	if motions[index] != null: motions[index].kill()
	var left: Node3D = doors[index].get_node("LeftHinge")
	var right: Node3D = doors[index].get_node("RightHinge")
	var height := BOTTOM if pose == "down" else TOP
	if not animate:
		busy[index] = false
		lifts[index].position.y = height
		left.rotation_degrees.z = 100.0 if pose == "up_open" else 0.0
		right.rotation_degrees.z = -left.rotation_degrees.z
		return
	busy[index] = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motions[index] = tween
	# Open the floor doors before the platform passes through the floor plane.
	tween.tween_callback(room.sound.on_lift.bind(&"maint_hatch_open", index))
	tween.tween_property(left, "rotation_degrees:z", 100.0, 0.35)
	tween.parallel().tween_property(right, "rotation_degrees:z", -100.0, 0.35)
	tween.tween_callback(room.sound.on_lift.bind(&"maint_lift_move", index))
	tween.tween_property(lifts[index], "position:y", height, 1.15)
	tween.tween_callback(room.sound.on_lift.bind(&"maint_lift_stop", index))
	if pose != "up_open":
		tween.tween_callback(room.sound.on_lift.bind(&"maint_hatch_close", index))
		tween.tween_property(left, "rotation_degrees:z", 0.0, 0.35)
		tween.parallel().tween_property(right, "rotation_degrees:z", 0.0, 0.35)
	tween.finished.connect(func() -> void:
		busy[index] = false
		motions[index] = null
		if room._active_device == "StorageBay%d" % index: room._refresh_panel.call_deferred())

func update_carry() -> void:
	if room.state.is_empty(): return
	var held: String = room.state.storage[room.role + "_hand"]
	room.player.carrying = not held.is_empty()
	if held.is_empty(): return
	var visual: Node3D = cases[held]
	visual.visible = not room.ui.inspector.active
	visual.global_transform = room.player.get_node("Visual").global_transform
	visual.global_position += visual.global_basis * Vector3(0, 0.85, 0.48)
