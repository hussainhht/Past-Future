extends Node3D
## Follows the player with a fixed perspective viewing angle.

@export var target_path: NodePath
@export var distance: float = 20.0
@export var pitch_degrees: float = 35.0
@export var field_of_view: float = 48.0
@export var look_ahead: float = 2.0
## Local presentation offsets; no effect on the followed body or normal view angle.
var cinematic_focus: Vector3
var cinematic_weight: float = 0.0

@onready var target: Node3D = get_node(target_path)
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation.x = -pitch
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = field_of_view
	snap_to_target()


func _process(delta: float) -> void:
	global_position = global_position.lerp(_focus_position(), 1.0 - exp(-8.0 * delta))


func snap_to_target() -> void:
	global_position = _focus_position()


func _focus_position() -> Vector3:
	var normal := target.global_position + Vector3.UP * 0.7 - global_basis.z * look_ahead
	return normal.lerp(cinematic_focus, cinematic_weight)
