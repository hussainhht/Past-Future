@tool
extends CharacterBody3D
## Original skinned student driven by the authored KayKit Rig_Medium clips.

signal action_finished(action: String)

const ACTIONS: Dictionary = {"interact": "Interact", "inspect": "Use_Item", "pick_up": "PickUp", "put_down": "PickUp", "wave": "Waving"}
const LOOP_CLIPS: Array[String] = ["Idle_A", "Idle_B", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B", "Holding_A", "Holding_B", "Holding_C", "Working_A", "Working_B", "Working_C", "Crouching", "Sneaking", "Crawling"]
const InputManager := preload("res://scripts/input/input_manager.gd")

@export var speed: float = 2.8
@export var run_multiplier: float = 1.55
@export var acceleration: float = 20.0
@export var deceleration: float = 28.0
@export var turn_speed: float = 12.0
## Studios keep the demonstration paper/actions. Integrated gameplay supplies real items.
@export var demonstration_items_enabled: bool = true
@export var visual_height: float = 2.15:
	set(value):
		visual_height = value
		if is_node_ready():
			$Visual.scale = Vector3.ONE * value / _model_height()
@export var body_color: Color = Color("e4bf7f"):
	set(value):
		body_color = value
		if is_node_ready():
			_apply_tint()

var controls_enabled: bool = true:
	set(value):
		controls_enabled = value
		if is_node_ready():
			animator.active = value
var view_camera: Camera3D
var carrying: bool = false
var animation_name: String = "Idle_A"
var _action: String = ""
var _materials: Dictionary = {}
var _held_document: MeshInstance3D

@onready var model: Node3D = $Visual/Student
@onready var animator: AnimationPlayer = model.get_node("AnimationPlayer")
@onready var skeleton: Skeleton3D = model.get_node("Rig_Medium/Skeleton3D")
@onready var skinned_mesh: MeshInstance3D = skeleton.get_node("Student_SkinnedMesh")

func _ready() -> void:
	$Visual.scale = Vector3.ONE * visual_height / _model_height()
	# Imported resources are shared. Give each player independent playback flags
	# and palette materials so the two timelines cannot alter each other.
	var library: AnimationLibrary = animator.get_animation_library("").duplicate(true)
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	for clip in library.get_animation_list():
		library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in LOOP_CLIPS else Animation.LOOP_NONE
	for surface in range(skinned_mesh.mesh.get_surface_count()):
		var material: StandardMaterial3D = skinned_mesh.mesh.surface_get_material(surface).duplicate()
		_materials[material.resource_name] = {"material": material, "base": material.albedo_color}
		skinned_mesh.set_surface_override_material(surface, material)
	_apply_tint()
	_create_document()
	animator.animation_finished.connect(_on_animation_finished)
	_play("Idle_A")
	if Engine.is_editor_hint():
		animator.advance(0.1)
		animator.pause()

func _apply_tint() -> void:
	for name in _materials:
		var entry: Dictionary = _materials[name]
		entry.material.albedo_color = entry.base.lerp(body_color, 0.16) if str(name).begins_with("jacket") else entry.base

func _model_height() -> float:
	return maxf(skinned_mesh.mesh.get_aabb().size.y, 0.001)

func _create_document() -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = "HeldDocumentSocket"
	attachment.bone_name = "handslot.l"
	skeleton.add_child(attachment)
	_held_document = MeshInstance3D.new()
	_held_document.name = "DemonstrationDocument"
	var paper := BoxMesh.new()
	paper.size = Vector3(0.16, 0.012, 0.21)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("eee2c6")
	material.roughness = 1.0
	paper.material = material
	_held_document.mesh = paper
	attachment.add_child(_held_document)
	_held_document.visible = false

func _play(clip: String, blend: float = 0.12, restart: bool = false) -> void:
	animator.speed_scale = 2 if clip == "Walking_A" else 1.0
	if animator.current_animation == clip and animator.is_playing() and not restart:
		return
	animation_name = clip
	animator.play(clip, blend)

func play_action(action: String) -> bool:
	if not controls_enabled or not _action.is_empty() or action not in ACTIONS:
		return false
	_action = action
	velocity.x = 0.0
	velocity.z = 0.0
	_play(ACTIONS[action], 0.1, true)
	return true


func is_action_active() -> bool:
	return not _action.is_empty()

func _on_animation_finished(_clip: StringName) -> void:
	if _action.is_empty():
		return
	var finished := _action
	if finished == "pick_up":
		carrying = true
	elif finished == "put_down":
		carrying = false
	_held_document.visible = carrying and demonstration_items_enabled
	_action = ""
	# A confirmed interaction can start blocking dialogue inside action_finished.
	# Select the resting/holding pose first so it cannot freeze the final pickup frame.
	_play("Holding_A" if carrying else "Idle_A", 0.0)
	animator.advance(0.0)
	action_finished.emit(finished)

func _get_interaction_controller() -> Node:
	var controller := get_node_or_null("InteractionRig/InteractionController")
	if controller == null:
		controller = find_child("InteractionController", true, false)
	return controller

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not controls_enabled or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.physical_keycode == KEY_F):
		var controller := _get_interaction_controller()
		if controller != null and controller.has_method("is_interaction_available") and controller.is_interaction_available():
			if controller.try_interact():
				get_viewport().set_input_as_handled()
				InputManager.trigger_haptic(&"interaction")
				return
	if not demonstration_items_enabled:
		return
	var action := ""
	if event.is_action_pressed("interact") or (event is InputEventKey and event.physical_keycode == KEY_F):
		action = "interact"
	elif event.is_action_pressed("inspect") or (event is InputEventKey and event.physical_keycode == KEY_I):
		action = "inspect"
	elif event.is_action_pressed("use_item") or (event is InputEventKey and event.physical_keycode == KEY_E):
		action = "put_down" if carrying else "pick_up"
	if not action.is_empty() and play_action(action):
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var direction := Vector2.ZERO
	var can_move := controls_enabled and _action.is_empty()
	if can_move:
		var move_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var ui_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if move_vec.length_squared() > 0.0:
			direction = move_vec.limit_length(1.0)
		else:
			direction = ui_vec.limit_length(1.0)
	var right := Vector3.RIGHT
	var down := Vector3.BACK
	if is_instance_valid(view_camera):
		right = view_camera.global_basis.x
		right.y = 0.0
		right = right.normalized()
		down = view_camera.global_basis.z
		down.y = 0.0
		down = down.normalized()
	var running := controls_enabled and not carrying and (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint"))
	var ground_direction := right * direction.x + down * direction.y
	var movement_speed := speed * (run_multiplier if running else 1.0)
	var ground_velocity := Vector2(velocity.x, velocity.z)
	var target_velocity := Vector2(ground_direction.x, ground_direction.z) * movement_speed
	# Steer through intermediate headings instead of instantly changing velocity
	# with digital inputs. Preserve the full direction and strength of analog input.
	var response := deceleration if direction.is_zero_approx() else acceleration
	ground_velocity = ground_velocity.move_toward(target_velocity, response * delta) if can_move else Vector2.ZERO
	velocity.x = ground_velocity.x
	velocity.z = ground_velocity.y
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		$Visual.rotation.y = rotate_toward($Visual.rotation.y, atan2(velocity.x, velocity.z), delta * turn_speed)
	if _action.is_empty():
		var moving := Vector2(velocity.x, velocity.z).length() > 0.1
		_play(("Running_A" if running else "Walking_A") if moving else ("Holding_A" if carrying else "Idle_A"))
