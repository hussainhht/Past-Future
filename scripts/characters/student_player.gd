@tool
extends CharacterBody3D
## Original student mesh with smooth turning and articulated procedural locomotion.

const PAINT: Shader = preload("res://shaders/painted_prop.gdshader")
const COLORS: Dictionary = {
	"jacket": Color("b18c52"), "jacket_trim": Color("c49b5e"), "jacket_shadow": Color("856439"),
	"shirt": Color("eee0bd"), "skin": Color("d7a179"), "skin_shadow": Color("b97b59"),
	"hair": Color("392c28"), "hair_mid": Color("49362d"), "hair_light": Color("5a4030"),
	"pants": Color("354655"), "pants_seam": Color("455769"), "boots": Color("4b3930"),
	"sole": Color("262e33"), "bag": Color("805838"), "bag_edge": Color("a27a4b"),
	"metal": Color("d8b56b"), "eye_white": Color("f5e9d3"), "eyes": Color("202a2d"), "badge": Color("82b9b6")
}

@export var speed: float = 4.8
@export var visual_height: float = 2.15:
	set(value):
		visual_height = value
		if is_node_ready():
			_update_visual_size()
@export var body_color: Color = Color("e4bf7f"):
	set(value):
		body_color = value
		if is_node_ready():
			_apply_tint()

var controls_enabled: bool = true
var view_camera: Camera3D
var _walk_phase: float = 0.0
var _walk_amount: float = 0.0


func _ready() -> void:
	_update_visual_size()
	_apply_tint()


func _apply_tint() -> void:
	for piece in $Visual.find_children("*", "MeshInstance3D", true, false):
		var material := piece.material_override as ShaderMaterial
		if material == null:
			material = ShaderMaterial.new()
			material.shader = PAINT
			piece.material_override = material
		var source := piece.mesh.surface_get_material(0) as StandardMaterial3D
		var slot: String = source.resource_name if source != null else "jacket"
		var color: Color = COLORS.get(slot, Color.WHITE)
		if slot.begins_with("jacket"):
			var shade := 0.25 if slot == "jacket" else (0.15 if slot == "jacket_trim" else 0.42)
			color = body_color.darkened(shade)
		material.set_shader_parameter("paint_color", color)


func _update_visual_size() -> void:
	$Visual.scale = Vector3.ONE * (visual_height / 2.11)


func _animate(ground_direction: Vector3, delta: float) -> void:
	if not ground_direction.is_zero_approx():
		var target_yaw := atan2(ground_direction.x, ground_direction.z)
		$Visual.rotation.y = rotate_toward($Visual.rotation.y, target_yaw, delta * 14.0)
	var moving := controls_enabled and Vector2(velocity.x, velocity.z).length() > 0.1
	_walk_amount = move_toward(_walk_amount, 1.0 if moving else 0.0, delta * 10.0)
	if moving:
		_walk_phase += delta * 11.0
	var stride := sin(_walk_phase) * _walk_amount
	$Visual/StudentModel/LeftLeg.rotation.x = stride * 0.48
	$Visual/StudentModel/RightLeg.rotation.x = -stride * 0.48
	$Visual/StudentModel/LeftArm.rotation.x = -stride * 0.40
	$Visual/StudentModel/RightArm.rotation.x = stride * 0.40
	$Visual/StudentModel/LeftLeg/LeftKnee.rotation.x = maxf(0.0, -stride) * 0.65
	$Visual/StudentModel/RightLeg/RightKnee.rotation.x = maxf(0.0, stride) * 0.65
	$Visual/StudentModel/LeftArm/LeftElbow.rotation.x = -0.12 - maxf(0.0, stride) * 0.25
	$Visual/StudentModel/RightArm/RightElbow.rotation.x = -0.12 - maxf(0.0, -stride) * 0.25
	$Visual.position.y = absf(sin(_walk_phase)) * 0.025 * _walk_amount


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var direction := Vector2.ZERO
	if controls_enabled:
		direction = (Input.get_vector("move_left", "move_right", "move_up", "move_down") + Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")).limit_length(1.0)
	var right := Vector3.RIGHT
	var down := Vector3.BACK
	if is_instance_valid(view_camera):
		right = view_camera.global_basis.x
		right.y = 0.0
		right = right.normalized()
		down = view_camera.global_basis.z
		down.y = 0.0
		down = down.normalized()
	var ground_direction := right * direction.x + down * direction.y
	velocity.x = ground_direction.x * speed
	velocity.z = ground_direction.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_animate(ground_direction, delta)
