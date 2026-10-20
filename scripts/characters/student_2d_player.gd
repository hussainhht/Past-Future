@tool
extends CharacterBody3D
## Illustrated eight-direction student on a grounded 3D collision body.

signal action_finished(action: String)

@export var speed: float = 4.8
@export var run_multiplier: float = 1.55
@export var visual_height: float = 2.15:
	set(value):
		visual_height = value
		if is_node_ready():
			$Visual.pixel_size = value / 512.0
@export var body_color: Color = Color("e4bf7f"):
	set(value):
		body_color = value
		if is_node_ready():
			_apply_tint()

var controls_enabled: bool = true
var view_camera: Camera3D
var carrying: bool = false
var _action: String = ""
var _action_remaining: float = 0.0

@onready var rig = $CharacterViewport/StudentPaperRig


func _ready() -> void:
	$Visual.texture = $CharacterViewport.get_texture()
	$Visual.pixel_size = visual_height / 512.0
	_apply_tint()
	rig.animation_finished.connect(_on_animation_finished)


func _apply_tint() -> void:
	$CharacterViewport/StudentPaperRig.palette_tint = Color.WHITE.lerp(body_color, 0.12)


func play_action(action: String) -> bool:
	if not controls_enabled or not _action.is_empty() or action not in rig.CLIPS:
		return false
	_action = action
	_action_remaining = float(rig.CLIPS[action].duration)
	velocity.x = 0.0
	velocity.z = 0.0
	rig.play(action, true)
	return true


func _on_animation_finished(action: String) -> void:
	if action != _action:
		return
	if action == "pick_up":
		carrying = true
	elif action == "put_down":
		carrying = false
	_action = ""
	_action_remaining = 0.0
	rig.holding_object = carrying
	action_finished.emit(action)


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not controls_enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	var action := ""
	match event.physical_keycode:
		KEY_F: action = "interact"
		KEY_I: action = "inspect"
		KEY_E: action = "put_down" if carrying else "pick_up"
	if not action.is_empty() and play_action(action):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	rig.paused = not controls_enabled
	if controls_enabled and not _action.is_empty() and rig.CLIPS[_action].loop:
		_action_remaining -= delta
		if _action_remaining <= 0.0:
			_on_animation_finished(_action)
	var direction := Vector2.ZERO
	if controls_enabled and _action.is_empty():
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
	var running := controls_enabled and not carrying and Input.is_physical_key_pressed(KEY_SHIFT)
	var movement_speed := speed * (run_multiplier if running else 1.0)
	var ground_direction := right * direction.x + down * direction.y
	velocity.x = ground_direction.x * movement_speed
	velocity.z = ground_direction.z * movement_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	rig.set_facing(direction)
	rig.holding_object = carrying
	if _action.is_empty():
		var moving := Vector2(velocity.x, velocity.z).length() > 0.1
		rig.play(("carry_walk" if moving else "carry_idle") if carrying else (("run" if running else "walk") if moving else "idle"))
