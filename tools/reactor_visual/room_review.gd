extends SceneTree
## Read-only use of the current room builder for camera/context verification.
## Only this temporary scene instance is changed; nothing is saved to the room.
const World := preload("res://scripts/level3/core_world.gd")
const REACTOR := preload("res://scenes/level3/reactor_visual/reactor_visual.tscn")
const OUT := "res://assets/environments/level3/reactor_visual/review"
var stage: Node3D
var camera: Camera3D
var key: DirectionalLight3D


func _initialize() -> void: run.call_deferred()


func hide_original(world: Node3D) -> void:
	world.core.hide()
	world.reactor_light.hide()
	for mesh in world.rings: mesh.hide()
	for mesh in world.rifts: mesh.hide()
	for node in world.get_children():
		if node is Label3D and node.text.begins_with("TEMPORAL CORE"): node.hide()
		if node is MeshInstance3D and node.mesh is CylinderMesh and node.position.is_equal_approx(Vector3(0, 0.75, 0)):
			node.hide()
		if node is StaticBody3D and node.position.is_equal_approx(Vector3.ZERO):
			for child in node.get_children():
				if child is MeshInstance3D and child.mesh is CylinderMesh and is_equal_approx(child.mesh.top_radius, 1.5): child.hide()


func shot(label: String) -> void:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT.path_join(label+".png")) == OK)


func run() -> void:
	create_timer(60.0).timeout.connect(func() -> void: push_error("REACTOR ROOM: FAIL watchdog"); quit(1))
	root.size = Vector2i(1600, 900)
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("15212c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b7cad0")
	environment.ambient_light_energy = 0.75
	env.environment = environment
	stage.add_child(env)
	key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -32, 0)
	key.light_energy = 1.05
	stage.add_child(key)
	camera = Camera3D.new()
	camera.fov = 48
	camera.current = true
	stage.add_child(camera)
	var pitch := deg_to_rad(35.0)
	for timeline: String in ["past", "future"]:
		var world := World.new()
		stage.add_child(world)
		world.build(timeline, func(_id: String) -> void: pass)
		world.set_process(false)
		key.light_color = Color("b5d9ec") if timeline == "future" else Color("ffe2b8")
		var avatar: Node3D = load("res://scenes/characters/%s_3d_player.tscn" % ("student" if timeline == "past" else "professor")).instantiate()
		stage.add_child(avatar)
		avatar.set_process(false)
		avatar.set_physics_process(false)
		avatar.position = Vector3(0, 0, 5.9)
		camera.position = avatar.position+Vector3(0, 0.7, -2)+Vector3(0, sin(pitch)*20, cos(pitch)*20)
		camera.rotation = Vector3(-pitch, 0, 0)
		await shot("room_"+timeline+"_original")
		hide_original(world)
		var reactor := REACTOR.instantiate()
		reactor.set_timeline(timeline)
		world.add_child(reactor)
		reactor.set_process(false)
		for i in range(180): reactor._update_visuals(1.0/60.0)
		await shot("room_"+timeline+"_replacement")
		avatar.position = Vector3(-3.3 if timeline == "past" else 3.3, 0, 0.8)
		camera.position = avatar.position+Vector3(0, 0.7, -2)+Vector3(0, sin(pitch)*20, cos(pitch)*20)
		await shot("room_"+timeline+"_switch_approach")
		world.queue_free()
		avatar.queue_free()
		await process_frame
	print("REACTOR ROOM: PASS (6 actual-room camera captures; no saved changes)")
	stage.queue_free()
	await process_frame
	quit()
