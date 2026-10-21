extends "res://scripts/gameplay/devices/device_inspector_3d.gd"
## Preserve the shared inspector's picking, camera and cancel behavior. Native UI
## focus supplies the same controls to keyboard, DualSense and Xbox users.


func _input(event: InputEvent) -> void:
	if not active or suspended: return
	if not event is InputEventMouse:
		for action in ["ui_accept", "ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
			if event.is_action(action): return
	super._input(event)


func _cutaway() -> void:
	super._cutaway()
	# Nearby relays sit directly in front of this close-up camera. Treat each
	# complete machine as a cutaway, including its non-colliding copper rings.
	for assembly: Node3D in get_tree().get_nodes_in_group("level3_device_assembly"):
		if assembly == mount: continue
		if not _occluders.has(assembly): _occluders[assembly] = assembly.visible
		assembly.hide()
	var world: Node = mount.get_parent().get_parent()
	for label: Label3D in world.find_children("*", "Label3D", true, false):
		if mount.is_ancestor_of(label): continue
		if not _occluders.has(label): _occluders[label] = label.visible
		label.hide()


func press_control(caption: String) -> bool:
	var visual: Node3D
	var rest := Vector3.ZERO
	if controls.has(caption):
		visual = controls[caption].visual
		rest = controls[caption].rest
	var accepted := super.press_control(caption)
	if accepted and is_instance_valid(visual):
		var press := visual.create_tween()
		press.tween_property(visual, "position", rest - Vector3(0, 0, 0.035), 0.055)
		press.tween_property(visual, "position", rest, 0.10)
	return accepted
