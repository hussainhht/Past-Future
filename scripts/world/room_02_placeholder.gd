extends Node3D
## Empty production blockout. Existing managers own transition, session and radio state.

var player: CharacterBody3D
var radio: TemporalRadio
var controller: Node
var role: String
var camera: Camera3D

func _ready() -> void:
	role = PuzzleManager.get_local_role()
	GameFlowManager.attach_room("room_02", self)
	_apply_timeline()
	var character_scene: PackedScene = load("res://scenes/characters/%s_3d_player.tscn" % ("professor" if role == "future" else "student"))
	player = character_scene.instantiate()
	player.name = "Player"
	player.demonstration_items_enabled = false
	$Actors.add_child(player)
	var marker := GameFlowManager.find_spawn_point(GameFlowManager.get_entry_spawn_id(role), self)
	player.global_transform = marker.global_transform
	# The existing fixed-perspective rig is created after its target exists.
	var camera_rig := Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://scripts/world/follow_camera.gd"))
	camera_rig.set("target_path", NodePath("../Actors/Player"))
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera_rig.add_child(camera)
	add_child(camera_rig)
	player.view_camera = camera
	var rig: Node3D = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
	player.add_child(rig)
	controller = rig.get_node("InteractionController")
	controller.detector.set_current_role(role)
	controller.prompt_ui = $InteractionPrompt
	radio = load("res://scenes/gameplay/radio/temporal_radio.tscn").instantiate()
	radio.player_role = role
	player.add_child(radio)
	player.carrying = radio.owns_radio
	var hud: Control = load("res://scenes/gameplay/radio/radio_hud.tscn").instantiate()
	hud.radio = radio
	$HUD/Root.add_child(hud)
	var socket := BoneAttachment3D.new()
	socket.name = "HeldRadioSocket"
	socket.bone_name = "handslot.r"
	player.skeleton.add_child(socket)
	var model: Node3D = load("res://scenes/gameplay/radio/placeholder_radio.tscn").instantiate()
	model.position = Vector3(0, 0.08, 0)
	socket.add_child(model)
	var presenter: Node3D = load("res://scripts/gameplay/radio/radio_model_presenter.gd").new()
	presenter.radio = radio
	presenter.model = model
	socket.add_child(presenter)
	# Reuse movement audio as-is; this placeholder adds no soundscape or audio manager.
	var footsteps: FootstepEmitter3D = load("res://scenes/audio/footstep_emitter_3d.tscn").instantiate()
	player.add_child(footsteps)
	footsteps.set_timeline(StringName(role))
	var listener := AudioListener3D.new()
	listener.position.y = 1.4
	player.add_child(listener)
	listener.make_current()
	$HUD/Root/Title.text = "MAINTENANCE CORRIDOR  /  " + ("FUTURE" if role == "future" else "PAST")
	get_tree().auto_accept_quit = true

func _apply_timeline() -> void:
	var future := role == "future"
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("283e48") if future else Color("b9b7a5")
	floor_material.roughness = 0.9
	$Shell/Floor/Mesh.material_override = floor_material
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("344c58") if future else Color("d6cdb6")
	wall_material.roughness = 0.9
	for body in $Shell.get_children():
		if body.name not in ["Floor", "EntranceDoor"]:
			body.get_node("Mesh").material_override = wall_material
	$KeyLight.light_color = Color("9dcbdc") if future else Color("ffe0ad")
	$KeyLight.light_energy = 0.85 if future else 1.05
	var environment: Environment = $WorldEnvironment.environment
	environment.ambient_light_color = Color("7495a6") if future else Color("e4d6bb")
	environment.ambient_light_energy = 0.65 if future else 0.75
	environment.background_color = Color("101c24") if future else Color("393b38")

func game_flow_suspend() -> void:
	player.velocity = Vector3.ZERO

func is_game_flow_ready() -> bool:
	return is_instance_valid(player) and is_instance_valid(radio) and camera.current
