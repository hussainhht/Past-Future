@tool
class_name TimelineProp
extends Node3D
## An environment prop that exists in the Past, the Future, or both.
##
## The same layout serves both timelines. A prop can be displaced in the Future (a tipped chair,
## a fallen poster), and children named "PastOnly" / "FutureOnly" swap geometry variants (an intact
## shelf for a broken one). Materials come from EnvPalette by slot name, so the Future look is a
## different shared material rather than an edited one. Collision follows visibility.
## Works on any Node3D, including StaticBody3D roots.

enum Presence { BOTH, PAST, FUTURE }

## Which timeline shows this prop.
@export var presence: Presence = Presence.BOTH:
	set(value):
		presence = value
		_apply()
## Added to the authored position in the Future (parent space).
@export var future_offset: Vector3 = Vector3.ZERO:
	set(value):
		future_offset = value
		_apply()
## Added to the authored rotation in the Future, in degrees (local axes).
@export var future_rotation: Vector3 = Vector3.ZERO:
	set(value):
		future_rotation = value
		_apply()
## Replace imported materials with the timeline palette.
@export var apply_palette: bool = true
## Checklist id from docs/assets/ASSET_INVENTORY.md (A01-A26, F01-F11), for audits and tests.
@export var asset_id: String = ""
## Current timeline. Set by the room; can be toggled in the editor to preview.
@export var future: bool = false:
	set(value):
		future = value
		_apply()

var _base: Transform3D
var _captured: bool = false


func _ready() -> void:
	add_to_group("timeline_prop")
	_capture()
	_apply()


func _capture() -> void:
	if not _captured:
		_base = transform
		_captured = true


## Re-read the authored transform, after moving the prop in code while it is in the Past.
func rebase() -> void:
	_captured = false
	var was := future
	future = false
	_capture()
	future = was


func is_present() -> bool:
	return presence == Presence.BOTH or (presence == Presence.FUTURE) == future


func _apply() -> void:
	if not is_inside_tree():
		return
	_capture()
	var shown := is_present()
	visible = shown
	_set_collision(self, shown)
	for child in get_children():
		if child.name == "PastOnly" or child.name == "FutureOnly":
			var variant_shown := shown and ((child.name == "FutureOnly") == future)
			child.visible = variant_shown
			_set_collision(child, variant_shown)
	for nested in find_children("*", "Node3D", true, false):
		if nested is TimelineProp:
			nested._apply()
	var target := _base
	if future and (future_offset != Vector3.ZERO or future_rotation != Vector3.ZERO):
		var turn := Basis.from_euler(future_rotation * (PI / 180.0))
		target = Transform3D(_base.basis * turn, _base.origin + future_offset)
	transform = target
	if apply_palette:
		apply_materials(self, future)


## Hiding switches off every shape beneath root; showing only switches on this prop's own shapes,
## because a nested prop decides its own presence (it re-applies right after).
func _set_collision(root: Node, enabled: bool) -> void:
	for shape in root.find_children("*", "CollisionShape3D", true, false):
		if enabled and _nearest_prop(shape) != self:
			continue
		shape.set_deferred("disabled", not enabled)


static func _nearest_prop(node: Node) -> Node:
	var current := node.get_parent()
	while current != null:
		if current is TimelineProp:
			return current
		current = current.get_parent()
	return null


## Swap every imported surface material under root for its shared timeline material.
static func apply_materials(root: Node, is_future: bool) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.is_in_group("keep_materials"):
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			var shared := EnvPalette.material_for(source, is_future)
			if shared != source:
				mesh_instance.set_surface_override_material(surface, shared)
