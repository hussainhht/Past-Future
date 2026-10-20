extends Node3D
## Highlight target for an Interactable3D: while the interactable is the current target, every mesh
## under `target` gets a pulsing rim overlay in the timeline accent (shaders/interaction_highlight).
## Overlays sit on top of the shared palette materials, so nothing shared is edited.

const SHADER := preload("res://shaders/interaction_highlight.gdshader")
const PAST := Color("e4bf7f")
const FUTURE := Color("86c9d1")

## Node whose meshes glow. Defaults to the parent device.
@export var target: Node3D

static var _overlays: Dictionary = {}


func set_highlighted(highlighted: bool) -> void:
	var root := target if target != null else get_parent().get_parent() as Node3D
	if root == null:
		return
	var overlay := _overlay(_is_future(root)) if highlighted else null
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree() or not highlighted:
			(mesh as MeshInstance3D).material_overlay = overlay


func _is_future(root: Node) -> bool:
	var node := root
	while node != null:
		if node is TimelineProp:
			return node.future
		node = node.get_parent()
	return false


static func _overlay(future: bool) -> ShaderMaterial:
	if not _overlays.has(future):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("rim_color", FUTURE if future else PAST)
		material.set_shader_parameter("strength", 0.5)
		_overlays[future] = material
	return _overlays[future]
