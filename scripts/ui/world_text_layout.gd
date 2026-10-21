extends RefCounted
## Cull crowded floating captions in screen space. Printed labels stay attached to their objects.

static func screen_rect(label: Label3D, camera: Camera3D) -> Rect2:
	var bounds := label.get_aabb()
	var scale := label.global_basis.get_scale()
	var center := label.global_position
	var right := camera.global_basis.x * bounds.size.x * scale.x * 0.5
	var up := camera.global_basis.y * bounds.size.y * scale.y * 0.5
	var rect := Rect2(camera.unproject_position(center - right - up), Vector2.ZERO)
	for point in [center - right + up, center + right - up, center + right + up]:
		rect = rect.expand(camera.unproject_position(point))
	return rect.grow(5.0)


static func arrange(labels: Array[Label3D], camera: Camera3D, focus: Vector3, reserved: Array[Rect2]) -> void:
	var candidates: Array[Label3D] = []
	for label in labels:
		if label.is_visible_in_tree(): candidates.append(label)
	candidates.sort_custom(func(a: Label3D, b: Label3D) -> bool:
		return a.global_position.distance_squared_to(focus) < b.global_position.distance_squared_to(focus))
	var occupied: Array[Rect2] = reserved.duplicate()
	var viewport := camera.get_viewport().get_visible_rect()
	for label in candidates:
		if camera.is_position_behind(label.global_position):
			label.hide()
			continue
		var rect := screen_rect(label, camera)
		var clear := viewport.encloses(rect)
		for other in occupied:
			if rect.intersects(other):
				clear = false
				break
		label.visible = clear
		if clear: occupied.append(rect)
