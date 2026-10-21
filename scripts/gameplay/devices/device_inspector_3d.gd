extends Node
## Local close-up of real equipment. All controls are ray-picked 3D parts; progression is external.
## Records stay readable in a compact foreground panel beside the framed equipment.

signal action_requested(action: String, payload: Dictionary)
signal active_changed(open: bool)
signal entry_changed(text: String)
signal dial_changed(parameter: String, value: int)

const PICK_LAYER := 32
var active := false
var controls: Dictionary = {}
var entry := ""
var suspended := false:
	set(value):
		suspended = value
		if _record_layer != null: _record_layer.visible = active and not value
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
var _record_layer: CanvasLayer
var _record_panel: PanelContainer
var _record_title: Label
var _record_body: Label
var _record_scroll: ScrollContainer
var _equipment_points: PackedVector3Array
var _equipment_rect := Rect2()
var _occluders: Dictionary = {}
var _cutaway_bodies: Array[RID] = []
var _view_origin: Vector3
var _view_size := Vector2.ZERO
var _dial_knob: Node3D
var _dial_value := 50.0
var amplitude := 35
var _amplitude_value := 35.0
var _amplitude_knob: Node3D
var _amplitude_readout: Label3D
var _selected_dial := "frequency"
var _dial_enabled := false
var _dragging_dial := false
var _drag_angle := 0.0
var _dial_drag_linear := false
const DIAL_DEGREES_PER_MHZ := 5.0


func open_device(body: Node3D, view: Camera3D, character: Node3D, title: String, text: String, options: Array, bindings: Dictionary = {}, keypad_kind: String = "", future: bool = false) -> void:
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
	_show_record(title, text, not reopening)
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
				if mesh != null:
					var local_bounds := mesh.get_aabb() if mesh == visual else mesh.transform * mesh.get_aabb()
					bounds = local_bounds.size + Vector3.ONE * 0.10
			_attach_control(option.label, visual, option, bounds, not bound)
	for display in mount.find_children("*Readout", "Label3D", true, false):
		display.font = Typography.display_font(future)
	_collect_equipment_points()
	_frame_device(not reopening)
	_cutaway()


func _show_record(title: String, text: String, reset_scroll: bool) -> void:
	if _record_layer == null:
		_record_layer = CanvasLayer.new()
		_record_layer.name = "InspectionRecord"
		_record_layer.layer = 21
		add_child(_record_layer)
		_record_panel = PanelContainer.new()
		_record_panel.name = "RecordPanel"
		_record_layer.add_child(_record_panel)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e5ddbf")
		style.border_color = Color("8b7854")
		style.set_border_width_all(2)
		style.set_content_margin_all(18)
		style.set_corner_radius_all(4)
		_record_panel.add_theme_stylebox_override("panel", style)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 14)
		_record_panel.add_child(content)
		_record_title = Label.new()
		_record_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_record_title.add_theme_font_size_override("font_size", 18)
		_record_title.add_theme_color_override("font_color", Color("253b40"))
		_record_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_record_title)
		_record_scroll = ScrollContainer.new()
		_record_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_record_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(_record_scroll)
		_record_body = Label.new()
		_record_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_record_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_record_body.add_theme_font_size_override("font_size", 16)
		_record_body.add_theme_color_override("font_color", Color("253b40"))
		_record_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_record_scroll.add_child(_record_body)
	_record_title.text = title
	_record_body.text = text
	if reset_scroll: _record_scroll.scroll_vertical = 0
	_record_layer.show()


func _layout_record() -> void:
	var width := clampf(_view_size.x * 0.25, 250.0, 350.0)
	var font := ThemeDB.fallback_font
	var title_height := maxf(_record_title.get_minimum_size().y, font.get_multiline_string_size(_record_title.text, HORIZONTAL_ALIGNMENT_LEFT, width - 36.0, 18).y)
	var body_height := maxf(_record_body.get_minimum_size().y, font.get_multiline_string_size(_record_body.text, HORIZONTAL_ALIGNMENT_LEFT, width - 52.0, 16).y)
	# Leave the lower part of the view free for character thoughts and the footer.
	var available_height := maxf(180.0, _view_size.y - 300.0)
	_record_panel.position = Vector2(26, 26)
	_record_panel.size = Vector2(width, minf(available_height, maxf(180.0, title_height + body_height + 58.0)))
	var guide_left := _view_size.x - clampf(_view_size.x * 0.23, 280.0, 340.0) - 26.0
	var equipment_left := _record_panel.get_rect().end.x + 24.0
	_equipment_rect = Rect2(equipment_left, 26, guide_left - 24.0 - equipment_left, available_height)


func _collect_equipment_points() -> void:
	_equipment_points.clear()
	var root := mount.get_meta("occlusion_body", mount) as Node3D
	if root.has_meta("inspection_bounds"):
		var bounds: AABB = root.get_meta("inspection_bounds")
		for x in [0, 1]:
			for y in [0, 1]:
				for z in [0, 1]:
					_equipment_points.append(root.global_transform * (bounds.position + bounds.size * Vector3(x, y, z)))
		return
	var pieces := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: pieces.append(root)
	# Laboratory controls live on the environment console, separate from its furniture body.
	if root != mount: pieces.append_array(mount.find_children("*", "MeshInstance3D", true, false))
	for piece: MeshInstance3D in pieces:
		if not piece.is_visible_in_tree() or piece.is_queued_for_deletion(): continue
		var bounds := piece.get_aabb()
		for x in [0, 1]:
			for y in [0, 1]:
				for z in [0, 1]:
					_equipment_points.append(piece.global_transform * (bounds.position + bounds.size * Vector3(x, y, z)))
	if _equipment_points.is_empty(): _equipment_points.append(mount.global_position)


func equipment_screen_rect() -> Rect2:
	var bounds := Rect2(camera.unproject_position(_equipment_points[0]), Vector2.ZERO)
	for point in _equipment_points: bounds = bounds.expand(camera.unproject_position(point))
	return bounds


func _frame_device(animate: bool) -> void:
	_view_size = camera.get_viewport().get_visible_rect().size
	_layout_record()
	var bounds := AABB(_equipment_points[0], Vector3.ZERO)
	for point in _equipment_points: bounds = bounds.expand(point)
	var focus := bounds.get_center()
	var basis := Basis.looking_at(mount.get_meta("inspection_direction", Vector3(0, -0.55, -4.4)))
	var start := camera.global_transform
	var start_fov := camera.fov
	var destination := start
	var distance := 3.4
	camera.fov = 42.0
	# Fit the complete machine, including its controls, into the space between record and guide.
	for attempt in 24:
		var units_per_pixel := 2.0 * distance * tan(deg_to_rad(21.0)) / _view_size.y
		var offset := _view_size * 0.5 - _equipment_rect.get_center()
		var origin := focus + basis.z * distance + (basis.x * offset.x - basis.y * offset.y) * units_per_pixel
		destination = Transform3D(basis, origin)
		camera.global_transform = destination
		if _equipment_rect.encloses(equipment_screen_rect().grow(12.0)): break
		distance *= 1.12
	_view_origin = destination.origin
	if _tween: _tween.kill()
	if animate:
		camera.global_transform = start
		camera.fov = start_fov
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(camera, "global_transform", destination, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(camera, "fov", 42.0, 0.30)
	else:
		camera.global_transform = destination
		camera.fov = 42.0


func _process(_delta: float) -> void:
	if suspended: _dragging_dial = false
	if _record_layer != null: _record_layer.visible = active and not suspended
	if active: _layout_record()
	if active and camera.get_viewport().get_visible_rect().size != _view_size:
		_frame_device(false)
		_cutaway()


func _cutaway() -> void:
	var exclusions: Array[RID] = _cutaway_bodies.duplicate()
	var owner_body := mount.get_meta("occlusion_body", mount) as CollisionObject3D
	if owner_body != null: exclusions.append(owner_body.get_rid())
	for body: CollisionObject3D in mount.find_children("*", "CollisionObject3D", true, false):
		exclusions.append(body.get_rid())
	for point in _equipment_points:
		for attempt in 8:
			var query := PhysicsRayQueryParameters3D.create(_view_origin, point, 1)
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
	label.font = Typography.font(&"ui_label")
	label.modulate = color
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.no_depth_test = false
	if top: label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(label)
	return label


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
	display.font = Typography.display_font(false)
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
	_mesh(panel, Vector3.ZERO, Vector3(2.12, 1.32, 0.12), Color("243a40"))
	for parameter in ["frequency", "amplitude"]:
		var x := -.52 if parameter == "frequency" else .52
		var display := _letter(panel, "050 MHz" if parameter == "frequency" else "35%", Vector3(x, .47, .10), .003, 40, Color("91e3bd"), 12)
		display.name = "EntryReadout" if parameter == "frequency" else "AmplitudeReadout"
		display.font = Typography.display_font(false)
		var caption := _letter(panel, parameter.to_upper(), Vector3(x, -.52, .10), .0028, 32, Color("dfbd73"), 12)
		caption.name = parameter.capitalize() + "Caption"
		for index in 36:
			var angle := float(index) * TAU / 36.0
			var tick := _mesh(panel, Vector3(x + sin(angle) * .43, -.02 + cos(angle) * .43, .115), Vector3(.018, .05 if index % 3 == 0 else .025, .025), Color("b9c8ad"))
			tick.rotation.z = -angle
		_dial_disk(panel, Vector3(x,-.02,.12), .36, .045, Color("95794f"))
		var knob := Node3D.new()
		knob.name = "TuningKnob" if parameter == "frequency" else "AmplitudeKnob"
		panel.add_child(knob)
		knob.position = Vector3(x,-.02,.20)
		_dial_disk(knob, Vector3.ZERO, .31, .17, Color("496568"))
		_dial_disk(knob, Vector3(0,0,.095), .26, .025, Color("263e43"))
		for index in 24:
			var angle := float(index) * TAU / 24.0
			var grip := _mesh(knob, Vector3(sin(angle) * .30, cos(angle) * .30, .015), Vector3(.035,.065,.13), Color("68817c"))
			grip.rotation.z = -angle
		_mesh(knob, Vector3(0,.19,.12), Vector3(.045,.15,.025), Color("dfbd73"))
	return panel


func _build_frequency_dial(options: Array) -> void:
	var panel := install_frequency_dial(mount)
	_readout = panel.get_node("EntryReadout")
	_dial_knob = panel.get_node("TuningKnob")
	_amplitude_knob = panel.get_node("AmplitudeKnob")
	_amplitude_readout = panel.get_node("AmplitudeReadout")
	_dial_enabled = not options[0].get("disabled", false)
	_attach_control("Rotate tuning dial", _dial_knob, {"action":"_rotate_dial", "disabled": not _dial_enabled}, Vector3(.70,.70,.32), false)
	_attach_control("Rotate amplitude dial", _amplitude_knob, {"action":"_rotate_dial", "disabled": not _dial_enabled}, Vector3(.70,.70,.32), false)
	set_signal_values(entry.to_int() if not entry.is_empty() else 50, amplitude, _dial_enabled)


func set_signal_values(frequency: int, strength: int, enabled: bool) -> void:
	# Preserve fractional drag movement when a confirmed integer update echoes back.
	if roundi(_dial_value) != frequency: _dial_value = frequency
	if roundi(_amplitude_value) != strength: _amplitude_value = strength
	_dial_enabled = enabled
	for caption in ["Rotate tuning dial", "Rotate amplitude dial"]:
		if controls.has(caption): controls[caption].option.disabled = not enabled
	if not enabled: _dragging_dial = false
	_update_dial()


func _update_dial() -> void:
	entry = str(roundi(_dial_value))
	amplitude = roundi(_amplitude_value)
	if is_instance_valid(_dial_knob): _dial_knob.rotation.z = -deg_to_rad((_dial_value - 1.0) * DIAL_DEGREES_PER_MHZ)
	if is_instance_valid(_amplitude_knob): _amplitude_knob.rotation.z = -deg_to_rad((_amplitude_value - 1.0) * DIAL_DEGREES_PER_MHZ)
	if is_instance_valid(_readout): _readout.text = "%03d MHz" % roundi(_dial_value)
	if is_instance_valid(_amplitude_readout): _amplitude_readout.text = "%02d%%" % amplitude
	if is_instance_valid(mount) and mount.has_node("MountedFrequencyDial"):
		var panel := mount.get_node("MountedFrequencyDial")
		for parameter in ["frequency", "amplitude"]:
			panel.get_node(parameter.capitalize() + "Caption").text = ("> " if _selected_dial == parameter else "") + parameter.to_upper()


func adjust_dial(change: float, parameter: String = "") -> bool:
	if not active or suspended or _keypad_kind != "frequency_dial" or not _dial_enabled: return false
	if not parameter.is_empty(): _selected_dial = parameter
	var previous := amplitude if _selected_dial == "amplitude" else entry.to_int()
	if _selected_dial == "amplitude": _amplitude_value = clampf(_amplitude_value + change, 1.0, 100.0)
	else: _dial_value = clampf(_dial_value + change, 1.0, 999.0)
	_update_dial()
	var value := amplitude if _selected_dial == "amplitude" else entry.to_int()
	if value != previous:
		dial_changed.emit(_selected_dial, value)
	return true


func _selected_knob() -> Node3D:
	return _amplitude_knob if _selected_dial == "amplitude" else _dial_knob


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
		return
	entry = text.left(3 if _keypad_kind == "frequency" else 8)
	if is_instance_valid(_readout): _readout.text = entry + (" MHz" if _keypad_kind == "frequency" else "")
	entry_changed.emit(entry)


func press_control(caption: String) -> bool:
	if not active or suspended or not controls.has(caption): return false
	var control: Dictionary = controls[caption]
	var option: Dictionary = control.option
	if option.get("disabled", false): return false
	if option.get("action") == "_rotate_dial":
		_selected_dial = "amplitude" if caption == "Rotate amplitude dial" else "frequency"
		_update_dial()
		return true
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging_dial = false
	# Let the record's scrollbar receive mouse events without operating the machine behind it.
	if event is InputEventMouse and _record_panel.get_global_rect().has_point(event.position): return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pick_at(event.position)
		else: _dragging_dial = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_dial:
		var offset: Vector2 = event.position - camera.unproject_position(_selected_knob().global_position)
		if not _dial_drag_linear and offset.length() > 8.0:
			var angle: float = offset.angle()
			adjust_dial(rad_to_deg(wrapf(angle - _drag_angle, -PI, PI)) / DIAL_DEGREES_PER_MHZ)
			_drag_angle = angle
		else:
			adjust_dial((event.relative.x - event.relative.y) / 5.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and _keypad_kind == "frequency_dial" and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var caption := control_at(event.position)
		if caption in ["Rotate tuning dial", "Rotate amplitude dial"]:
			_selected_dial = "amplitude" if caption == "Rotate amplitude dial" else "frequency"
			adjust_dial((1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0) * (10.0 if event.shift_pressed else 1.0))
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if _keypad_kind == "frequency_dial":
			if key in [KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_UP]:
				adjust_dial((-1.0 if key in [KEY_LEFT, KEY_DOWN] else 1.0) * (10.0 if event.shift_pressed else 1.0))
			elif key == KEY_TAB:
				_selected_dial = "amplitude" if _selected_dial == "frequency" else "frequency"
				_update_dial()
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
	if caption in ["Rotate tuning dial", "Rotate amplitude dial"]:
		_selected_dial = "amplitude" if caption == "Rotate amplitude dial" else "frequency"
		if not _dial_enabled: return false
		_dragging_dial = true
		var offset := screen_position - camera.unproject_position(_selected_knob().global_position)
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
	if _record_layer != null: _record_layer.hide()
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
