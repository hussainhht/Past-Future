extends Node
## Room C bindings for the existing physical inspector. Only confirmed snapshots
## drive lamps/readouts. A coil selector issues the existing cycle action, one
## acknowledged step at a time; it never writes puzzle state.

const Rules := preload("res://scripts/level3/core_rules.gd")
const Inspector := preload("res://scripts/level3/core_device_inspector.gd")
const Inputs := preload("res://scripts/input/input_manager.gd")
var room: Node3D
var inspector: Node
var active_id := ""
var mounts: Dictionary = {}
var bindings: Dictionary = {}
var readouts: Dictionary = {}
var lamps: Dictionary = {}
var actions: Array = []
var pending := ""
var _pending_value: Variant
var _pending_attempt := -1
var _coil_target := -1
var _coil_index := -1
var _pending_field := ""


func setup(owner_room: Node3D) -> void:
	room = owner_room
	inspector = Inspector.new()
	inspector.name = "DeviceInspector3D"
	add_child(inspector)
	inspector.action_requested.connect(_on_action)
	inspector.active_changed.connect(func(open: bool) -> void:
		if not open:
			active_id = ""
			room.ui.close_device()
		room._sync_controls())
	for timeline: String in room.worlds:
		_install(room.worlds[timeline], timeline)
	room.ui.device_control_pressed.connect(func(caption: String) -> void: inspector.press_control(caption))
	room.ui.device_close_requested.connect(close)


func _install(world: Node3D, timeline: String) -> void:
	for id: String in world.stations:
		if not is_device(id): continue
		var key := timeline + "/" + id
		var station: Area3D = world.stations[id]
		var mount := Node3D.new()
		mount.name = "PhysicalDevice"
		station.add_child(mount)
		mount.add_to_group("level3_device_assembly")
		_adopt_geometry(world, station, mount)
		# The stock console is a small pedestal. This face projects in front of it.
		_mesh(mount, Vector3(0, 0.83, 0.61), Vector3(1.18, 0.72, 0.12), Color("243a40"))
		_mesh(mount, Vector3(0, 1.03, 0.68), Vector3(1.04, 0.22, 0.025), Color("0c2025"))
		var display := _letter(mount, "IDLE", Vector3(0, 1.03, 0.70), 22, timeline)
		display.name = "StateReadout"
		readouts[key] = display
		var options := _definitions(id)
		var controls := {}
		var lights: Array = []
		for index in options.size():
			var option: Dictionary = options[index]
			var x := (float(index) - (options.size() - 1) * 0.5) * 0.35
			var control := _mesh(mount, Vector3(x, 0.70, 0.74), Vector3(0.29, 0.20, 0.13), Color("8b9989"))
			control.name = "Control%d" % index
			_letter(control, option.stamp, Vector3(0, 0, 0.075), 24, timeline)
			controls[option.label] = control
			var led := _mesh(mount, Vector3(x, 0.54, 0.70), Vector3(0.13, 0.035, 0.025), Color("dba45a"))
			if id.begins_with("sync_"):
				_mesh(control, Vector3(0, 0, 0.13), Vector3(0.045, 0.05, 0.20), Color("d2d4bc"))
				_mesh(control, Vector3(0, 0, 0.25), Vector3(0.20, 0.10, 0.08), Color("e3b75c"))
			lights.append(led)
		mounts[key] = mount
		bindings[key] = controls
		lamps[key] = lights
		# Show the station name only when targeted; dense floating labels obscure
		# the room. The full name and state remain readable in the inspector.
		var title: Label3D = station.get_meta("title")
		title.hide()
		station.highlight_changed.connect(func(on: bool) -> void: title.visible = on and not inspector.active)


func _adopt_geometry(world: Node3D, station: Area3D, mount: Node3D) -> void:
	# Frame the entire existing machine, not just its new control face. The
	# original geometry remains untouched on disk and retains all collision.
	for child in world.get_children():
		if not child is Node3D or child is Area3D or child is Label3D: continue
		var offset: Vector3 = child.position - station.position
		if Vector2(offset.x, offset.z).length() > 0.76: continue
		var meshes: Array[Node] = child.find_children("*", "MeshInstance3D", true, false)
		if child is MeshInstance3D: meshes.append(child)
		if meshes.is_empty(): continue
		var small := true
		for mesh: MeshInstance3D in meshes:
			if (mesh.get_aabb().size * mesh.global_basis.get_scale()).length() > 4.0: small = false
		if small: child.reparent(mount)


func is_device(id: String) -> bool:
	return id == "start" or id.begins_with("coil_") or id in ["receiver", "anchor", "origin", "sync_past", "sync_future", "terminal_past", "terminal_future"]


func _option(label: String, action: String, stamp: String, payload: Dictionary = {}) -> Dictionary:
	return {"label": label, "action": action, "stamp": stamp, "payload": payload, "disabled": false}


func _definitions(id: String) -> Array:
	if id == "start": return [_option("ARM REACTOR...", "_arm", "ARM")]
	if id.begins_with("coil_"):
		var result: Array = []
		for value in 3: result.append(_option("SET POSITION %d" % value, "_coil", str(value), {"value": value}))
		return result
	if id == "receiver": return [_option("RECONNECT BATTERY", "receiver", "LINK")]
	if id == "anchor": return [_option("CALIBRATE SIGNAL ANCHOR", "anchor", "CAL")]
	if id == "origin": return [_option("STABILIZE ORIGIN CORE", "origin", "HOLD")]
	if id.begins_with("sync_"): return [_option("ENGAGE PHASE SWITCH", "sync", "SYNC")]
	var result: Array = []
	for command: String in Rules.COMMANDS["past" if id == "terminal_past" else "future"]:
		result.append(_option(command, "_choose", "GROUND" if command == "GROUND THE CORE" else ("CLAIM" if command == "CLAIM ORIGIN" else ("RELEASE" if command == "RELEASE THE ECHO" else "KEEP")), {"command": command}))
	return result


func open(id: String) -> void:
	if not is_device(id) or not room.worlds[room.role].stations.has(id): return
	if not room._near_station(room.role, id): return
	active_id = id
	actions = _definitions(id)
	var key: String = room.role + "/" + id
	inspector.open_device(mounts[key], room.camera, room.player, _title(id), _body(id), actions, bindings[key], "", room.role == "future")
	room.ui.open_device(_title(id), actions)
	refresh()
	room._sync_controls()


func close() -> void:
	inspector.close()


func _title(id: String) -> String:
	if id.begins_with("coil_"): return "POWER COIL %d / THREE POSITION RELAY" % (int(id.trim_prefix("coil_")) + 1)
	return {"start": "REACTOR ARMING CONSOLE", "receiver": "RECEIVER / BATTERY CONTACTS", "anchor": "SIGNAL ANCHOR / PROFESSOR", "origin": "ORIGIN STABILIZER / STUDENT", "sync_past": "PAST / PHASE SWITCH", "sync_future": "FUTURE / PHASE SWITCH", "terminal_past": "ORIGIN TERMINAL", "terminal_future": "CONTINUITY TERMINAL"}.get(id, id)


func _body(id: String) -> String:
	var s: Dictionary = room.state
	var text := "CONFIRMED REACTOR PHASE: " + String(s.stage).replace("_", " ") + "\n\n"
	if id == "start":
		text += "REACTOR IDLE\nThe 150-second clock starts only after explicit confirmation. Investigate and compare records first.\n\nArming starts Stage A: restore the power coils and receiver."
	elif id.begins_with("coil_"):
		var index := int(id.trim_prefix("coil_"))
		text += "CONFIRMED POSITION: %d\nSELECTABLE STOPS: 0 / 1 / 2\n\nEach physical relay advances 0 > 1 > 2 > 0. Select a stop to cycle to it. The Professor's restored routing diagram gives the required configuration.\n\nGreen: circuit aligned. Amber: adjust this relay." % s.coils[index]
	elif id == "receiver":
		text += "BATTERY: " + ("CONNECTED / RECEIVER ONLINE" if s.receiver else "DISCONNECTED / RECEIVER OFFLINE")
		text += "\n\nReconnect and latch the battery contacts to recover the routing diagram. A confirmed connection stays latched for this attempt."
	elif id == "anchor":
		text += "SIGNAL: " + ("CALIBRATED / ORIGIN WAVEFORM EXPOSED" if s.anchor else "UNCALIBRATED")
		text += "\n\nCalibrate this anchor after both timelines restore power. The Student can then stabilize the exposed Origin waveform."
	elif id == "origin":
		text += "ORIGIN: " + ("STABLE / CONTACT LATCHED" if s.origin else ("READY TO STABILIZE" if s.anchor else "WAITING FOR PROFESSOR'S SIGNAL ANCHOR"))
		text += "\n\nStabilization latches for this attempt. When both devices are aligned, meet at your respective phase switches."
	elif id.begins_with("sync_"):
		text += "STUDENT: %s\nPROFESSOR: %s\n\n" % ["HELD" if s.sync_past else "READY", "HELD" if s.sync_future else "READY"]
		text += "Both calibrated contacts are required. The first switch starts a five-second window. A missed window releases both switches so you can retry."
	else:
		text += "PRIVATE IDENTITY COMMAND\n\n"
		if room.role == "past": text += "GROUND THE CORE preserves you and the world; the Professor's echo ends.\n\nCLAIM ORIGIN forcibly takes ownership using the forbidden protocol."
		else: text += "RELEASE THE ECHO lets the stable protocol preserve the Student; your echo and memories end.\n\nPRESERVE ECHO forcibly anchors your identity, displacing the Student if he grounds the core."
		text += "\n\nConflicting overrides cause a paradox. Select a command to review it. A separate confirmation locks it for this attempt. Your exact command stays private until both terminals resolve."
	if not pending.is_empty(): text += "\n\nREQUEST SENT / WAITING FOR HOST CONFIRMATION"
	return text


func _enabled(id: String, option: Dictionary) -> bool:
	var s: Dictionary = room.state
	if not pending.is_empty() or not room._can_operate(): return false
	if id == "start": return s.stage == "DISCOVERY"
	if id.begins_with("coil_"): return s.stage == "STAGE_A" and s.coils[int(id.trim_prefix("coil_"))] != option.payload.value
	if id == "receiver": return s.stage == "STAGE_A" and not s.receiver
	if id == "anchor": return s.stage == "STAGE_B" and not s.anchor
	if id == "origin": return s.stage == "STAGE_B" and s.anchor and not s.origin
	if id.begins_with("sync_"): return s.stage == "STAGE_B" and s.anchor and s.origin and not s[id]
	return s.stage == "STAGE_C" and not s["locked_" + room.role]


func refresh() -> void:
	if room.state.is_empty(): return
	var s: Dictionary = room.state
	if not pending.is_empty():
		var value: Variant = s.coils[_coil_index] if pending == "coil" else s.get(_pending_field)
		if s.attempt != _pending_attempt or not s.stage in ["STAGE_A", "STAGE_B", "STAGE_C"]:
			pending = ""
			_coil_target = -1
		elif value != _pending_value:
			pending = ""
			if _coil_target >= 0: _advance_coil.call_deferred()
	for key: String in mounts:
		var id: String = key.get_slice("/", 1)
		var lit := false
		var text: String = s.stage.replace("STAGE_", "PHASE ")
		if id.begins_with("coil_"):
			var index := int(id.trim_prefix("coil_"))
			text = "POSITION %d" % s.coils[index]
			for n in 3: _light(lamps[key][n], s.coils[index] == n, Color("72dca8") if n == Rules.COIL_TARGET[index] else Color("dba45a"))
		else:
			if id in ["receiver", "anchor", "origin"]:
				lit = s[id]
				text = ("CONNECTED" if id == "receiver" else ("CALIBRATED" if id == "anchor" else "STABLE")) if lit else "OFFLINE"
			elif id.begins_with("sync_"):
				lit = s[id]
				text = "HELD" if lit else "OPEN"
				bindings[key]["ENGAGE PHASE SWITCH"].rotation.x = -0.32 if lit else 0.32
			elif id.begins_with("terminal_"): lit = s["locked_" + key.get_slice("/", 0)]; text = "LOCKED" if lit else "AWAIT IDENTITY"
			for lamp: MeshInstance3D in lamps[key]: _light(lamp, lit, Color("72dca8"))
		readouts[key].text = text
		# Inspection remains available while the action is locked or premature.
		var station: Area3D = room.worlds[key.get_slice("/", 0)].stations[id]
		station.interaction_enabled = not s.stage in ["ENDING", "OVERLOAD"]
		station.interaction_name = "INSPECT / " + _title(id) + " / " + text
	if not inspector.active: return
	for option: Dictionary in actions:
		option.disabled = not _enabled(active_id, option)
		inspector.controls[option.label].option.disabled = option.disabled
	inspector._record_body.text = _body(active_id)
	room.ui.refresh_device(actions, s, room.role, not pending.is_empty())


func _on_action(action: String, payload: Dictionary) -> void:
	if active_id.is_empty() or inspector.suspended: return
	var allowed := false
	for option: Dictionary in actions:
		if option.action == action and option.payload == payload and _enabled(active_id, option): allowed = true
	if not allowed: return
	room.sound.get_node("AudioSystem").play_sfx(&"switch_toggle")
	Inputs.trigger_haptic(&"interaction")
	match action:
		"_arm": close(); room.confirm_arming()
		"_choose": close(); room._confirm_command(payload.command)
		"_coil":
			_coil_index = int(active_id.trim_prefix("coil_"))
			_coil_target = payload.value
			_advance_coil.call_deferred()
		_: _submit(action)


func _advance_coil() -> void:
	if _coil_target < 0 or not pending.is_empty(): return
	if room.state.stage != "STAGE_A" or room.state.coils[_coil_index] == _coil_target:
		_coil_target = -1
		refresh()
		return
	_submit("coil", {"index": _coil_index})


func _submit(action: String, payload: Dictionary = {}) -> void:
	pending = action
	_pending_field = "sync_" + room.role if action == "sync" else action
	_pending_attempt = room.state.attempt
	_pending_value = room.state.coils[_coil_index] if action == "coil" else room.state.get(_pending_field)
	var result: Dictionary = room.request_action(action, payload)
	if result.get("status") == PuzzleManager.Status.REJECTED: reject()
	refresh()


func reject() -> void:
	pending = ""
	_coil_target = -1
	refresh()


func _light(lamp: MeshInstance3D, on: bool, color: Color) -> void:
	var mat: StandardMaterial3D = lamp.material_override
	mat.albedo_color = color if on else Color("35464a")
	mat.emission_enabled = on
	mat.emission = color


func _mesh(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh


func _letter(parent: Node3D, text: String, at: Vector3, size: int, timeline: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font = Typography.display_font(timeline == "future")
	label.font_size = size
	label.pixel_size = 0.0021
	label.outline_size = 0
	label.modulate = Color("c2eed1")
	parent.add_child(label)
	return label
