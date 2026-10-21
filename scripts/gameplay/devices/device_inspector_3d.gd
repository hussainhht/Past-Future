extends Node
## Local close-up of real equipment. All controls are ray-picked 3D parts; progression is external.
## The only overlay is explicitly labelled player assistance, supplied by the room's LabUI.

signal action_requested(action: String, payload: Dictionary)
signal active_changed(open: bool)
signal entry_changed(text: String)

const PICK_LAYER := 32
var active := false
var controls: Dictionary = {}
var entry := ""
var suspended := false
var mount: Node3D
var camera: Camera3D
var actor: Node3D
var _rig: Node3D
var _rig_processing := true
var _camera_transform: Transform3D
var _camera_fov := 48.0
var _actor_visible := true
var _mouse_mode: int
var _tween: Tween
var _parts: Array[Node] = []
var _readout: Label3D
var _keypad_kind := ""
var _keypad_action: Dictionary = {}
var _surface: Node3D
var _occluders: Dictionary = {}
var _cutaway_bodies: Array[RID] = []
var _view_origin: Vector3
var _view_size := Vector2.ZERO
var _dial_knob: Node3D
var _dial_value := 50.0
var _dial_enabled := false
var _dragging_dial := false
var _drag_angle := 0.0
var _dial_drag_linear := false
const DIAL_DEGREES_PER_MHZ := 5.0


func open_device(body: Node3D, view: Camera3D, character: Node3D, title: String, text: String, options: Array, bindings: Dictionary = {}, keypad_kind: String = "") -> void:
	var reopening := active and mount == body
	if active and not reopening: close()
	_clear_parts()
	mount = body
	_keypad_kind = keypad_kind
	if not reopening:
		camera = view
		actor = character
		_rig = camera.get_parent()
		_rig_processing = _rig.is_processing()
		_camera_transform = camera.global_transform
		_camera_fov = camera.fov
		_actor_visible = actor.visible
		_mouse_mode = Input.mouse_mode
		_rig.set_process(false)
		actor.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		active = true
		active_changed.emit(true)
		_frame_device(true)
	# A hinged service card lives beside the actual controls, in the scene's depth and lighting.
	_surface = Node3D.new()
	_surface.name = "OpenServiceCard"
	mount.add_child(_surface)
	_parts.append(_surface)
	_surface.position = Vector3(1.50, 0.92, 0.95)
	_mesh(_surface, Vector3.ZERO, Vector3(1.90, 1.85, 0.075), Color("253b40"))
	var paper := _mesh(_surface, Vector3(0, 0, 0.047), Vector3(1.76, 1.70, 0.018), Color("e5ddbf"))
	paper.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh(_surface, Vector3(0, 0.86, 0.075), Vector3(0.40, 0.12, 0.035), Color("8b7854"))
	var heading := _letter(_surface, title, Vector3(0, 0.67, 0.075), 0.0016, 38, Color("253b40"), 34)
	var reading := _letter(_surface, text, Vector3(0, 0.47, 0.075), 0.00155, 33, Color("253b40"), 52, true)
	_fit_letter(heading, Vector2(1.60, 0.14))
	_fit_letter(reading, Vector2(1.58, 1.05))
	controls.clear()
	if keypad_kind == "frequency_dial": _build_frequency_dial(options)
	elif not keypad_kind.is_empty(): _build_keypad(options)
	else:
		for index in options.size():
			var option: Dictionary = options[index]
			var bound: bool = bindings.has(option.label) or bindings.has(option.action)
			var visual: Node3D = bindings.get(option.label, bindings.get(option.action))
			if visual == null:
				visual = _mesh(mount, Vector3(-0.30 + (index % 3) * 0.30, 0.64 - (index / 3) * 0.25, 0.44), Vector3(0.25, 0.18, 0.12), Color("496867"))
				_parts.append(visual)
				var stamp: String = option.get("stamp", {"preserve_recording":"EXPORT", "arm_anchor":"LATCH"}.get(option.action, str(index + 1)))
				_letter(visual, stamp, Vector3(0, 0, 0.07), 0.0015, 40 if stamp.length() < 3 else 24, Color("f0e3ba"), 12)
			var bounds := Vector3(0.30, 0.32, 0.32)
			if bound:
				var mesh := visual as MeshInstance3D
				if mesh == null: mesh = visual.get_node_or_null("Mesh") as MeshInstance3D
				if mesh != null: bounds = mesh.get_aabb().size + Vector3.ONE * 0.10
			_attach_control(option.label, visual, option, bounds, not bound)
	_cutaway()


func _frame_device(animate: bool) -> void:
	_view_size = camera.get_viewport().get_visible_rect().size
	var rail_width := clampf(_view_size.x * 0.23, 280.0, 340.0) + 26.0
	var shift := maxf(0.0, rail_width / _view_size.x - 366.0 / 1600.0) * 8.0
	var focus := mount.to_global(Vector3(1.05 + shift, 0.85, 0.32))
	var destination := Transform3D(Basis.IDENTITY, focus + Vector3(0, 0.55, 4.4)).looking_at(focus)
	_view_origin = destination.origin
	if _tween: _tween.kill()
	if animate:
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(camera, "global_transform", destination, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(camera, "fov", 42.0, 0.30)
	else:
		camera.global_transform = destination
		camera.fov = 42.0


func _process(_delta: float) -> void:
	if suspended: _dragging_dial = false
	if active and camera.get_viewport().get_visible_rect().size != _view_size:
		_frame_device(false)
		_cutaway()


func _cutaway() -> void:
	var exclusions: Array[RID] = _cutaway_bodies.duplicate()
	var owner_body := mount.get_meta("occlusion_body", mount) as CollisionObject3D
	if owner_body != null: exclusions.append(owner_body.get_rid())
	for point in [Vector3(0, 0.9, 0.45), Vector3(0.75, 0.40, 0.95), Vector3(2.25, 0.40, 0.95), Vector3(1.5, 1.6, 0.95)]:
		for attempt in 8:
			var query := PhysicsRayQueryParameters3D.create(_view_origin, mount.to_global(point), 1)
			query.exclude = exclusions
			var hit := mount.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): break
			var body: CollisionObject3D = hit.collider
			exclusions.append(body.get_rid())
			_cutaway_bodies.append(body.get_rid())
			for piece in body.find_children("*", "MeshInstance3D", true, false):
				if not _occluders.has(piece): _occluders[piece] = piece.visible
				piece.visible = false


func _mesh(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	piece.mesh = shape
	piece.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	piece.material_override = material
	parent.add_child(piece)
	return piece


func _wrap(text: String, columns: int) -> String:
	var result := ""
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			if line.length() + word.length() > columns:
				result += line.strip_edges() + "\n"
				line = ""
			line += word + " "
		result += line.strip_edges() + "\n"
	return result.strip_edges()


func _letter(parent: Node3D, text: String, at: Vector3, pixel_size: float, font_size: int, color: Color, columns: int, top: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = _wrap(text, columns)
	label.position = at
	label.pixel_size = pixel_size
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.no_depth_test = false
	if top: label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(label)
	return label


func _fit_letter(label: Label3D, maximum: Vector2) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var extent := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size) * label.pixel_size
	while (extent.x > maximum.x or extent.y > maximum.y) and label.font_size > 20:
		label.font_size -= 1
		extent = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size) * label.pixel_size
	if extent.x > maximum.x or extent.y > maximum.y:
		label.pixel_size *= minf(maximum.x / maxf(extent.x, 0.001), maximum.y / maxf(extent.y, 0.001))


func install_keypad(body: Node3D) -> Node3D:
	if body.has_node("MountedKeypad"): return body.get_node("MountedKeypad")
	var panel := Node3D.new()
	panel.name = "MountedKeypad"
	body.add_child(panel)
	panel.position = Vector3(0, 1.0, 0.47)
	_mesh(panel, Vector3.ZERO, Vector3(1.07, 1.55, 0.12), Color("243a40"))
	_mesh(panel, Vector3(0, 0.50, 0.075), Vector3(0.90, 0.29, 0.025), Color("0c2025"))
	var display := _letter(panel, "---", Vector3(0, 0.50, 0.10), 0.0021, 42, Color("91e3bd"), 12)
	display.name = "EntryReadout"
	for index in 12:
		var stamp: String = str(index + 1) if index < 9 else ["DEL", "0", "ENTER"][index - 9]
		var key := _mesh(panel, Vector3(-0.32 + (index % 3) * 0.32, 0.20 - floori(index / 3.0) * 0.25, 0.10), Vector3(0.27, 0.20, 0.12), Color("a7b4a5"))
		key.name = "Key_" + stamp
		_letter(key, stamp, Vector3(0, 0, 0.067), 0.0012, 40 if stamp.length() == 1 else 26, Color("172d32"), 10)
	return panel


func _dial_disk(parent: Node3D, at: Vector3, radius: float, depth: float, color: Color) -> MeshInstance3D:
	var disk := _mesh(parent, at, Vector3.ONE, color)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = depth
	cylinder.radial_segments = 48
	disk.mesh = cylinder
	disk.rotation.x = PI / 2.0
	return disk


func install_frequency_dial(body: Node3D) -> Node3D:
	if body.has_node("MountedFrequencyDial"): return body.get_node("MountedFrequencyDial")
	var panel := Node3D.new()
	panel.name = "MountedFrequencyDial"
	body.add_child(panel)
	# Fit the controls below the console's screen and status readout.
	panel.position = Vector3(0, .72, .47)
	panel.scale = Vector3.ONE * .62
	_mesh(panel, Vector3.ZERO, Vector3(1.15, 1.55, 0.12), Color("243a40"))
	_mesh(panel, Vector3(0, .50, .075), Vector3(.94, .29, .025), Color("0c2025"))
	var display := _letter(panel, "050 MHz", Vector3(0, .50, .10), .0021, 36, Color("91e3bd"), 12)
	display.name = "EntryReadout"
	for index in 36:
		var angle := float(index) * TAU / 36.0
		var tick := _mesh(panel, Vector3(sin(angle) * .43, -.08 + cos(angle) * .43, .115), Vector3(.018, .07 if index % 3 == 0 else .035, .025), Color("b9c8ad"))
		tick.rotation.z = -angle
	_dial_disk(panel, Vector3(0,-.08,.12), .36, .045, Color("95794f"))
	var knob := Node3D.new()
	knob.name = "TuningKnob"
	panel.add_child(knob)
	knob.position = Vector3(0,-.08,.20)
	_dial_disk(knob, Vector3.ZERO, .31, .17, Color("496568"))
	_dial_disk(knob, Vector3(0,0,.095), .26, .025, Color("263e43"))
	for index in 24:
		var angle := float(index) * TAU / 24.0
		var grip := _mesh(knob, Vector3(sin(angle) * .30, cos(angle) * .30, .015), Vector3(.035,.065,.13), Color("68817c"))
		grip.rotation.z = -angle
	_mesh(knob, Vector3(0,.19,.12), Vector3(.045,.15,.025), Color("dfbd73"))
	var button := _mesh(panel, Vector3(0,-.64,.12), Vector3(.78,.17,.12), Color("77ad98"))
	button.name = "CalibrateButton"
	_letter(button, "CALIBRATE", Vector3(0,0,.067), .0015, 28, Color("172d32"), 12)
	return panel


func _build_frequency_dial(options: Array) -> void:
	var panel := install_frequency_dial(mount)
	_readout = panel.get_node("EntryReadout")
	_dial_knob = panel.get_node("TuningKnob")
	_keypad_action = options[0]
	_dial_enabled = not _keypad_action.get("disabled", false)
	_attach_control("Rotate tuning dial", _dial_knob, {"action":"_rotate_dial", "disabled": not _dial_enabled}, Vector3(.70,.70,.32), false)
	_attach_control(_keypad_action.label, panel.get_node("CalibrateButton"), _keypad_action, Vector3(.80,.19,.18))
	set_entry(entry if not entry.is_empty() else "50")


func _update_dial() -> void:
	entry = str(roundi(_dial_value))
	if is_instance_valid(_dial_knob): _dial_knob.rotation.z = -deg_to_rad((_dial_value - 1.0) * DIAL_DEGREES_PER_MHZ)
	if is_instance_valid(_readout): _readout.text = "%03d MHz" % roundi(_dial_value)


func adjust_dial(change: float) -> bool:
	if not active or suspended or _keypad_kind != "frequency_dial" or not _dial_enabled: return false
	var previous := entry
	_dial_value = clampf(_dial_value + change, 1.0, 999.0)
	_update_dial()
	if entry != previous: entry_changed.emit(entry)
	return true


func _build_keypad(options: Array) -> void:
	var panel := install_keypad(mount)
	_readout = panel.get_node("EntryReadout")
	_readout.text = entry + (" MHz" if _keypad_kind == "frequency" else "")
	_keypad_action = options[0] if not options.is_empty() else {}
	for index in 12:
		var stamp: String = str(index + 1) if index < 9 else ["DEL", "0", "ENTER"][index - 9]
		var key: MeshInstance3D = panel.get_node("Key_" + stamp)
		var option := {"action": "_digit", "payload": {"digit": stamp}, "disabled": false}
		if stamp == "ENTER": option = _keypad_action
		_attach_control(_keypad_action.get("label", "ENTER") if stamp == "ENTER" else stamp, key, option, Vector3(0.28, 0.22, 0.18))


func _attach_control(caption: String, visual: Node3D, option: Dictionary, size: Vector3, button: bool = true) -> void:
	var hit := Area3D.new()
	hit.name = "PhysicalControl"
	hit.collision_layer = PICK_LAYER
	hit.collision_mask = 0
	hit.set_meta("control_caption", caption)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	hit.add_child(collision)
	visual.add_child(hit)
	_parts.append(hit)
	controls[caption] = {"visual": visual, "area": hit, "option": option, "button": button, "rest": visual.position}


func set_entry(text: String) -> void:
	if _keypad_kind == "frequency_dial":
		_dial_value = clampf(float(text.to_int()), 1.0, 999.0)
		_update_dial()
		entry_changed.emit(entry)
		return
	entry = text.left(3 if _keypad_kind == "frequency" else 8)
	if is_instance_valid(_readout): _readout.text = entry + (" MHz" if _keypad_kind == "frequency" else "")
	entry_changed.emit(entry)


func press_control(caption: String) -> bool:
	if not active or suspended or not controls.has(caption): return false
	var control: Dictionary = controls[caption]
	var option: Dictionary = control.option
	if option.get("disabled", false): return false
	if option.get("action") == "_rotate_dial": return true
	if control.button:
		var press: Tween = control.visual.create_tween()
		press.tween_property(control.visual, "position", control.rest - Vector3(0,0,0.035), 0.055)
		press.tween_property(control.visual, "position", control.rest, 0.10)
	if option.get("action", "") == "_digit":
		var digit: String = option.payload.digit
		set_entry(entry.left(-1) if digit == "DEL" else entry + digit)
	else:
		var payload: Dictionary = option.get("payload", {}).duplicate()
		if _keypad_kind in ["frequency", "frequency_dial"]: payload = {"frequency": entry.to_int()}
		elif _keypad_kind == "code": payload = {"code": entry}
		action_requested.emit(option.action, payload)
	return true


func _input(event: InputEvent) -> void:
	if not active or suspended: return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pick_at(event.position)
		else: _dragging_dial = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_dial:
		var offset: Vector2 = event.position - camera.unproject_position(_dial_knob.global_position)
		if not _dial_drag_linear and offset.length() > 8.0:
			var angle: float = offset.angle()
			adjust_dial(rad_to_deg(wrapf(angle - _drag_angle, -PI, PI)) / DIAL_DEGREES_PER_MHZ)
			_drag_angle = angle
		else:
			adjust_dial((event.relative.x - event.relative.y) / 5.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and _keypad_kind == "frequency_dial" and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if control_at(event.position) == "Rotate tuning dial":
			adjust_dial((1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0) * (10.0 if event.shift_pressed else 1.0))
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if _keypad_kind == "frequency_dial":
			if key in [KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_UP]:
				adjust_dial((-1.0 if key in [KEY_LEFT, KEY_DOWN] else 1.0) * (10.0 if event.shift_pressed else 1.0))
			elif key == KEY_ENTER or key == KEY_KP_ENTER: press_control(_keypad_action.label)
		elif not _keypad_kind.is_empty():
			if key >= KEY_0 and key <= KEY_9: press_control(str(key - KEY_0))
			elif key == KEY_BACKSPACE: press_control("DEL")
			elif key == KEY_ENTER or key == KEY_KP_ENTER: press_control(_keypad_action.get("label", "ENTER"))
		elif key >= KEY_1 and key <= KEY_9:
			var index: int = key - KEY_1
			if index < controls.size(): press_control(controls.keys()[index])
		get_viewport().set_input_as_handled()


func pick_at(screen_position: Vector2) -> bool:
	if not active or suspended: return false
	var caption := control_at(screen_position)
	if caption == "Rotate tuning dial":
		if not _dial_enabled: return false
		_dragging_dial = true
		var offset := screen_position - camera.unproject_position(_dial_knob.global_position)
		_drag_angle = offset.angle()
		_dial_drag_linear = offset.length() < 12.0
	return press_control(caption)


func control_at(screen_position: Vector2) -> String:
	if not active: return ""
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 20.0, PICK_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := mount.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return ""
	return hit.collider.get_meta("control_caption", "")


func close() -> void:
	if not active: return
	active = false
	if _tween: _tween.kill()
	if is_instance_valid(camera):
		camera.global_transform = _camera_transform
		camera.fov = _camera_fov
	if is_instance_valid(_rig): _rig.set_process(_rig_processing)
	if is_instance_valid(actor): actor.visible = _actor_visible
	Input.mouse_mode = _mouse_mode
	for piece in _occluders:
		if is_instance_valid(piece): piece.visible = _occluders[piece]
	_occluders.clear()
	_cutaway_bodies.clear()
	_clear_parts()
	active_changed.emit(false)


func _clear_parts() -> void:
	_dragging_dial = false
	_dial_enabled = false
	for part in _parts:
		if is_instance_valid(part) and not part.is_queued_for_deletion():
			if part is Area3D: part.collision_layer = 0
			part.queue_free()
	_parts.clear()
	controls.clear()
	_readout = null


func _exit_tree() -> void:
	close()
