extends Node3D
## Solo opposite-timeline echo: visual copies anchored to the parked character.

const GHOST_SHADER := preload("res://shaders/temporal_ghost.gdshader")
const RADIUS := 4.5
const CELL_SIZE := RADIUS
const MOTION_MARGIN := 3.0
const CLIP_SIDES := 16

var enabled := true
var echo_position := Vector3.ZERO
var character: Node3D
var _room: Node3D
var _timeline_roots: Dictionary = {}
var _context: Callable
var _sources: Array[MeshInstance3D] = []
var _copies: Dictionary = {}
var _transforms: Dictionary = {}
var _visibility: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _shared_material: ShaderMaterial
var _changed_material: ShaderMaterial
var _character_material: ShaderMaterial
var _role_yaws := {"past": 0.0, "future": 0.0}
var _echo_role := ""
var _elapsed := 0.0
var _nearby: Array[MeshInstance3D] = []
var _neighborhood_position := Vector3.INF
var _last_role := ""
var _last_inspecting := false
var _dirty := true
var _animate_until := 0
var _shown_position := Vector3.INF
var _animator: AnimationPlayer
var _batch_meshes: Dictionary = {}
var _batches: Array[MeshInstance3D] = []
var _batch_dirty := false
var visual_updates := 0
var _spatial_cells: Dictionary = {}
var _clipped_meshes: Dictionary = {}
var _neighborhood_dirty := true
var _camera: Camera3D


func configure(room: Node3D, roots: Array[Node3D], context: Callable) -> void:
	_room = room
	_camera = room.get("camera") as Camera3D
	_context = context
	_timeline_roots = context.call().get("timeline_roots", {})
	name = "TemporalGhost"
	process_priority = 110
	_shared_material = _material(0.19, 10)
	_changed_material = _material(0.42, 11)
	_character_material = _material(0.78, 12)
	for material in [_shared_material, _changed_material]:
		var batch := MeshInstance3D.new()
		batch.name = "EchoGeometry"
		batch.material_override = material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		batch.global_transform = Transform3D.IDENTITY
		_batches.append(batch)
	for root in roots:
		for piece: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if piece.mesh != null: _sources.append(piece)
	PuzzleManager.puzzle_state_changed.connect(_on_puzzle_changed)
	refresh()


func _material(opacity: float, priority: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GHOST_SHADER
	material.render_priority = priority
	material.set_shader_parameter("echo_radius", RADIUS)
	material.set_shader_parameter("opacity", opacity)
	_materials.append(material)
	return material


func _select_timeline(role: String) -> void:
	_echo_role = role
	# Timeline changes invalidate poses, visibility, clipping and neighborhood membership.
	for copy: MeshInstance3D in _copies.values(): copy.queue_free()
	_copies.clear()
	_batch_meshes.clear()
	_clipped_meshes.clear()
	_visibility.clear()
	_neighborhood_position = Vector3.INF
	_shown_position = Vector3.INF
	_neighborhood_dirty = true
	_batch_dirty = true
	_build_spatial_index()
	if is_instance_valid(character):
		remove_child(character)
		character.queue_free()
	_build_character()


func _build_character() -> void:
	# Import only the animated model: no player controller, collisions, audio or interactions.
	var model := "professor" if _echo_role == "future" else "student"
	character = load("res://assets/characters/%s_3d/%s.glb" % [model, model]).instantiate()
	character.name = "ProfessorEcho" if _echo_role == "future" else "StudentEcho"
	add_child(character)
	for piece: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		# Every ghost surface uses one material, so keep the skin but combine its draw calls.
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface in piece.mesh.get_surface_count(): builder.append_from(piece.mesh, surface, Transform3D.IDENTITY)
		piece.mesh = builder.commit()
		piece.material_override = _character_material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if piece.skin != null:
			character.scale = Vector3.ONE * 2.15 / maxf(piece.mesh.get_aabb().size.y, 0.001)
	var animator := character.get_node("AnimationPlayer") as AnimationPlayer
	_animator = animator
	var idle := animator.get_animation("Idle_A").duplicate() as Animation
	idle.loop_mode = Animation.LOOP_LINEAR
	var library := AnimationLibrary.new()
	library.add_animation("idle", idle)
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	animator.play("idle")


func _input(event: InputEvent) -> void:
	if _context.is_null() or event.is_echo() or not event.is_action_pressed("temporal_ghost"): return
	var context: Dictionary = _context.call()
	if NetworkManager.in_game or context.get("blocked", false): return
	enabled = not enabled
	refresh()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _context.is_null(): return
	var context: Dictionary = _context.call()
	_camera = _room.get("camera") as Camera3D
	_role_yaws[context.role] = context.player.get_node("Visual").global_rotation.y
	var opposite := "past" if context.role == "future" else "future"
	if _echo_role != opposite: _select_timeline(opposite)
	echo_position = context[opposite + "_position"]
	var inspecting: bool = context.get("inspecting", false)
	if context.role != _last_role or inspecting != _last_inspecting:
		_dirty = true
		_last_role = context.role
		_last_inspecting = inspecting
	var shown: bool = enabled and not context.get("blocked", false) and not NetworkManager.in_game and _patch_in_view()
	if visible != shown:
		visible = shown
		_dirty = shown
		if shown: _elapsed = 0.05
	if _animator.active != shown: _animator.active = shown
	if not visible: return
	if not echo_position.is_equal_approx(_neighborhood_position): _dirty = true
	_elapsed += delta
	if _elapsed >= 0.05 and (_dirty or Time.get_ticks_msec() < _animate_until):
		_elapsed = 0.0
		_sync_visuals()
		_dirty = false


func refresh() -> void:
	if _context.is_null(): return
	_elapsed = 0.05
	_dirty = true
	_process(0.0)


func _on_puzzle_changed(_id: String, _state: Dictionary, _revision: int) -> void:
	_dirty = true
	_neighborhood_dirty = true
	# Follow the existing lever and slab tweens, then leave settled geometry alone.
	_animate_until = Time.get_ticks_msec() + 1400


func _patch_in_view() -> bool:
	if _camera == null: return true
	var center := echo_position + Vector3.UP
	var radius := sqrt(RADIUS * RADIUS + 9.0)
	var interior := _camera.global_position - _camera.global_basis.z * (_camera.near + _camera.far) * 0.5
	for plane: Plane in _camera.get_frustum():
		var distance := plane.distance_to(center)
		if plane.distance_to(interior) < 0.0: distance = -distance
		if distance < -radius: return false
	return true


func _build_spatial_index() -> void:
	# Static cell membership plus the motion margin covers the authored equipment tweens.
	_transforms.clear()
	_spatial_cells.clear()
	for source in _sources:
		var bounds: AABB = _echo_transform(source) * source.get_aabb()
		var first := Vector2i(floori(bounds.position.x / CELL_SIZE), floori(bounds.position.z / CELL_SIZE))
		var last := Vector2i(floori(bounds.end.x / CELL_SIZE), floori(bounds.end.z / CELL_SIZE))
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var cell := Vector2i(x, z)
				if not _spatial_cells.has(cell): _spatial_cells[cell] = []
				_spatial_cells[cell].append(source)
	_transforms.clear()


func _rebuild_neighborhood() -> void:
	_nearby.clear()
	if not echo_position.is_equal_approx(_neighborhood_position): _clipped_meshes.clear()
	_neighborhood_position = echo_position
	_neighborhood_dirty = false
	var extent := RADIUS + MOTION_MARGIN
	var first := Vector2i(floori((echo_position.x - extent) / CELL_SIZE), floori((echo_position.z - extent) / CELL_SIZE))
	var last := Vector2i(floori((echo_position.x + extent) / CELL_SIZE), floori((echo_position.z + extent) / CELL_SIZE))
	var candidates: Dictionary = {}
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			for source in _spatial_cells.get(Vector2i(x, z), []): candidates[source] = true
	for source in candidates:
		if not is_instance_valid(source) or source.is_queued_for_deletion(): continue
		var bounds: AABB = _echo_transform(source) * source.get_aabb()
		if _within_radius(bounds, extent): _nearby.append(source)
	for source in _copies.keys():
		if source not in _nearby:
			_clipped_meshes.erase(_copies[source])
			_copies[source].queue_free()
			_copies.erase(source)
			_batch_dirty = true
	var used_meshes: Dictionary = {}
	for copy: MeshInstance3D in _copies.values(): used_meshes[copy.mesh] = true
	for mesh in _batch_meshes.keys():
		if not used_meshes.has(mesh): _batch_meshes.erase(mesh)


func _within_radius(bounds: AABB, radius: float) -> bool:
	var dx := maxf(maxf(bounds.position.x - echo_position.x, echo_position.x - bounds.end.x), 0.0)
	var dz := maxf(maxf(bounds.position.z - echo_position.z, echo_position.z - bounds.end.z), 0.0)
	return dx * dx + dz * dz < radius * radius


func _sync_visuals() -> void:
	visual_updates += 1
	_transforms.clear()
	_visibility.clear()
	if _neighborhood_dirty or not echo_position.is_equal_approx(_neighborhood_position): _rebuild_neighborhood()
	if not echo_position.is_equal_approx(_shown_position):
		for material in _materials: material.set_shader_parameter("echo_center", echo_position)
		character.global_position = echo_position
		_shown_position = echo_position
		_batch_dirty = true
	if not is_equal_approx(character.global_rotation.y, _role_yaws[_echo_role]): character.global_rotation.y = _role_yaws[_echo_role]
	for source in _nearby:
		if not is_instance_valid(source) or source.is_queued_for_deletion(): continue
		var shown := _echo_visible(source)
		var transform := _echo_transform(source)
		var bounds: AABB = transform * source.get_aabb()
		shown = shown and _within_radius(bounds, RADIUS)
		var copy: MeshInstance3D = _copies.get(source)
		if shown and copy == null:
			copy = MeshInstance3D.new()
			copy.name = "Echo_" + source.name
			copy.mesh = source.mesh
			copy.material_override = _changed_material if _is_timeline_change(source) else _shared_material
			# Retain per-object poses for updates; render their geometry in two shared batches.
			copy.layers = 0
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(copy)
			_copies[source] = copy
			_batch_dirty = true
		if copy != null:
			if copy.visible != shown:
				copy.visible = shown
				_batch_dirty = true
			if shown and not copy.global_transform.is_equal_approx(transform):
				copy.global_transform = transform
				_batch_dirty = true
	if _batch_dirty: _rebuild_batches()


func _batch_source(mesh: Mesh) -> ArrayMesh:
	if _batch_meshes.has(mesh): return _batch_meshes[mesh]
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var original := mesh.surface_get_arrays(surface)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = original[Mesh.ARRAY_VERTEX]
		arrays[Mesh.ARRAY_NORMAL] = original[Mesh.ARRAY_NORMAL]
		arrays[Mesh.ARRAY_INDEX] = original[Mesh.ARRAY_INDEX]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_batch_meshes[mesh] = result
	return result


func _rebuild_batches() -> void:
	for index in _batches.size():
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := 0
		for copy: MeshInstance3D in _copies.values():
			if not copy.visible or copy.material_override != _batches[index].material_override: continue
			var bounds: AABB = copy.global_transform * copy.get_aabb()
			var dx := maxf(absf(bounds.position.x - echo_position.x), absf(bounds.end.x - echo_position.x))
			var dz := maxf(absf(bounds.position.z - echo_position.z), absf(bounds.end.z - echo_position.z))
			var inner_radius := RADIUS * cos(PI / CLIP_SIDES)
			if dx * dx + dz * dz <= inner_radius * inner_radius:
				var mesh := _batch_source(copy.mesh)
				for surface in mesh.get_surface_count(): builder.append_from(mesh, surface, copy.global_transform)
				count += 1
			else:
				var mesh := _clip_mesh(copy)
				if mesh != null:
					builder.append_from(mesh, 0, Transform3D.IDENTITY)
					count += 1
		_batches[index].mesh = builder.commit() if count > 0 else null
	_batch_dirty = false


func _clip_mesh(copy: MeshInstance3D) -> ArrayMesh:
	# Clip triangles before upload: shader fading alone still submits entire room-sized surfaces.
	# An inscribed polygon keeps every vertex within the circular shader boundary.
	var cached: Dictionary = _clipped_meshes.get(copy, {})
	if not cached.is_empty() and cached.transform.is_equal_approx(copy.global_transform): return cached.mesh
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_count := 0
	var normal_basis := copy.global_basis.inverse().transposed()
	var limit := RADIUS * cos(PI / CLIP_SIDES)
	var planes := PackedVector3Array()
	for side in CLIP_SIDES:
		var angle := (side + 0.5) * TAU / CLIP_SIDES
		planes.append(Vector3(cos(angle), 0, sin(angle)))
	for surface in copy.mesh.get_surface_count():
		var arrays := copy.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for start in range(0, count, 3):
			var polygon := PackedVector3Array()
			var directions := PackedVector3Array()
			for corner in 3:
				var index := indices[start + corner] if not indices.is_empty() else start + corner
				polygon.append(copy.global_transform * vertices[index])
				directions.append((normal_basis * normals[index]).normalized())
			for plane_normal in planes:
				if polygon.is_empty(): break
				var clipped := PackedVector3Array()
				var clipped_normals := PackedVector3Array()
				var previous := polygon.size() - 1
				var previous_distance := plane_normal.dot(polygon[previous] - echo_position) - limit
				for current in polygon.size():
					var distance := plane_normal.dot(polygon[current] - echo_position) - limit
					if (distance <= 0.0) != (previous_distance <= 0.0):
						var weight := previous_distance / (previous_distance - distance)
						clipped.append(polygon[previous].lerp(polygon[current], weight))
						clipped_normals.append(directions[previous].lerp(directions[current], weight).normalized())
					if distance <= 0.0:
						clipped.append(polygon[current])
						clipped_normals.append(directions[current])
					previous = current
					previous_distance = distance
				polygon = clipped
				directions = clipped_normals
			for corner in range(1, polygon.size() - 1):
				for index in [0, corner, corner + 1]:
					builder.set_normal(directions[index])
					builder.add_vertex(polygon[index])
					vertex_count += 1
	var mesh := builder.commit() if vertex_count > 0 else null
	_clipped_meshes[copy] = {"transform": copy.global_transform, "mesh": mesh}
	return mesh


func _echo_transform(node: Node3D) -> Transform3D:
	if node in _timeline_roots.values():
		return _timeline_roots["past" if _echo_role == "future" else "future"].global_transform
	if node == _room: return _room.global_transform
	if _transforms.has(node): return _transforms[node]
	var local := node.transform
	if node is TimelineProp:
		local = node._base
		if _echo_role == "future":
			local.origin += node.future_offset
			local.basis *= Basis.from_euler(node.future_rotation * PI / 180.0)
	var parent := node.get_parent() as Node3D
	var result := _echo_transform(parent) * local if parent != null else local
	_transforms[node] = result
	return result


func _echo_visible(node: Node3D) -> bool:
	if node in _timeline_roots.values(): return node == _timeline_roots[_echo_role]
	if node == _room: return true
	if _visibility.has(node): return _visibility[node]
	var shown := node.visible
	if node.name == "PastOnly": shown = _echo_role == "past"
	elif node.name == "FutureOnly": shown = _echo_role == "future"
	elif node is TimelineProp:
		shown = node.presence == TimelineProp.Presence.BOTH or (node.presence == TimelineProp.Presence.FUTURE) == (_echo_role == "future")
	var parent := node.get_parent() as Node3D
	if parent != null: shown = shown and _echo_visible(parent)
	_visibility[node] = shown
	return shown


func _is_timeline_change(node: Node) -> bool:
	while node != null and node != _room:
		if node.name == ("FutureOnly" if _echo_role == "future" else "PastOnly"): return true
		if node is TimelineProp and (node.presence != TimelineProp.Presence.BOTH or node.future_offset != Vector3.ZERO or node.future_rotation != Vector3.ZERO): return true
		node = node.get_parent()
	return false
