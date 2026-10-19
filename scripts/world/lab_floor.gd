@tool
extends Node3D

@export var future: bool = false:
	set(value):
		future = value
		if is_node_ready():
			_apply_tint()

var spawn_position := Vector3(0, 0, 3.7):
	set(value):
		spawn_position = value
		if is_node_ready():
			$SpawnRing.position = Vector3(value.x, 0.018, value.z)


func _ready() -> void:
	$Surface.material_override = $Surface.material_override.duplicate()
	_apply_tint()
	$SpawnRing.position = Vector3(spawn_position.x, 0.018, spawn_position.z)


func _apply_tint() -> void:
	$Surface.material_override.set_shader_parameter("future", future)
	$SpawnRing.modulate = Color("86c9d1") if future else Color("e5c68e")
	for rim in $Rim.get_children():
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("49656b") if future else Color("83866d")
		rim.material_override = material
