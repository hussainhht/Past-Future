extends SceneTree
## Reproducible visual evidence. Requires a rendering device (do not use --headless).
## godot --path . --script res://tools/render_student_review.gd -- --no-game
## Follow with: python tools/assemble_student_review.py
## Optional: --neutral-only, --no-game, --neutral-clip=Reference_Neutral

const MODEL := "res://assets/characters/student_3d/student.glb"
const OUTPUT := "res://assets/characters/student_3d/review"
const CAPTURE_SIZE := Vector2i(1024, 572)
const CLIPS: Array[String] = [
	"Idle_A", "Walking_A", "Running_A", "Interact", "PickUp", "Crouching",
	"Waving", "Jump_Full_Long", "Dodge_Forward", "Death_A", "Crawling"
]
const FRAME_COUNT := 18

var viewport: SubViewport
var stage: Node3D
var model: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var camera: Camera3D
var model_height := 2.28
var neutral_clip := "Reference_Neutral"
var report: Dictionary = {
	"renderer": "Godot", "resolution": [1024, 572],
	"camera": {"projection": "orthographic", "elevation_degrees": 3.0},
	"views": [], "clips": [], "game": [],
	"scope": "Visual evidence; does not certify reference fidelity or collision-free deformation."
}

func _initialize() -> void:
	_run.call_deferred()

func _pose(clip: String, phase: float) -> void:
	animator.stop()
	skeleton.reset_bone_poses()
	if clip == "Reference_Neutral":
		for side in ["l", "r"]:
			var bone := skeleton.find_bone("upperarm." + side)
			var parent := skeleton.get_bone_parent(bone)
			var rest := skeleton.get_bone_global_rest(bone)
			var direction := -1.0 if side == "l" else 1.0
			var rotated := Basis(Vector3.BACK, deg_to_rad(70.0) * direction) * rest.basis
			var local := skeleton.get_bone_global_rest(parent).basis.inverse() * rotated
			skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
		return
	animator.play(clip, 0.0)
	animator.seek(animator.get_animation(clip).length * phase, true)
	animator.advance(0.0)
	animator.pause()
	skeleton.force_update_all_bone_transforms()

func _capture(path: String, capture_viewport: Viewport = null) -> void:
	if capture_viewport == null:
		capture_viewport = viewport
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var rendered := capture_viewport.get_texture().get_image()
	assert(not rendered.is_empty(), "Rendering requires a display/rendering device.")
	assert(rendered.save_png(OUTPUT.path_join(path)) == OK)

func _build_stage() -> void:
	viewport = SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("15171e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e5e8ef")
	environment.environment.ambient_light_energy = 0.26
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_color = Color("fff2e1")
	key.light_energy = 0.65
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_color = Color("c1cbed")
	fill.light_energy = 0.22
	stage.add_child(fill)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(200, 200)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("090a10")
	floor_material.roughness = 1.0
	floor_mesh.material = floor_material
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position.y = -0.008
	stage.add_child(floor_instance)
	model = load(MODEL).instantiate()
	stage.add_child(model)
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = model_height / 0.9
	var target := Vector3(0, model_height * 0.5, 0)
	camera.position = target + Vector3(0, sin(deg_to_rad(3.0)) * 8.0, cos(deg_to_rad(3.0)) * 8.0)
	stage.add_child(camera)
	camera.look_at(target)
	camera.current = true

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var manifest_path := "res://assets/characters/student_3d/manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary:
			model_height = float(manifest.get("height", model_height))
	for arg in args:
		if arg.begins_with("--neutral-clip="):
			neutral_clip = arg.trim_prefix("--neutral-clip=")
	DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("neutral"))
	DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("animation"))
	_build_stage()
	await process_frame
	if animator.has_animation("Reference_Neutral") and not args.has("--neutral-clip=Idle_A"):
		neutral_clip = "Reference_Neutral"
	assert(neutral_clip == "Reference_Neutral" or animator.has_animation(neutral_clip), "Neutral clip is unavailable.")
	report["neutral_clip"] = neutral_clip
	report["neutral_phase"] = 0.0 if neutral_clip == "Reference_Neutral" else 0.1
	report["model_height"] = model_height
	report["camera"]["size"] = camera.size
	# Positive yaw shows the anatomical right side, matching sideview1.png.
	# Negative yaw shows the anatomical left side and bag, matching sideview2.png.
	for view in [
		["front", 0.0, "frontview.png"],
		["back", PI, "backview.png"],
		["right", PI / 2.0, "sideview1.png"],
		["left", -PI / 2.0, "sideview2.png"],
		["three_quarter_right", PI / 4.0, ""],
		["three_quarter_left", -PI / 4.0, ""]
	]:
		model.rotation.y = float(view[1])
		_pose(neutral_clip, float(report["neutral_phase"]))
		var path := "neutral/%s.png" % view[0]
		await _capture(path)
		report["views"].append({"name": view[0], "yaw": view[1], "reference": view[2], "path": path})
	if not args.has("--neutral-only"):
		camera.size = model_height / 0.78
		for clip in CLIPS:
			if not animator.has_animation(clip):
				push_error("Missing required review clip: " + clip)
				continue
			var clip_info := {"clip": clip, "length": animator.get_animation(clip).length, "frames": [], "reverse": []}
			model.rotation.y = -PI / 5.0
			DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("animation").path_join(clip))
			for frame in range(FRAME_COUNT):
				var phase := float(frame) / float(FRAME_COUNT)
				_pose(clip, phase)
				var path := "animation/%s/%02d.png" % [clip, frame]
				await _capture(path)
				clip_info["frames"].append({"path": path, "phase": phase})
			model.rotation.y = PI - PI / 5.0
			for phase in [0.25, 0.5, 0.75]:
				_pose(clip, phase)
				var path := "animation/%s/rear_%02d.png" % [clip, roundi(phase * 100)]
				await _capture(path)
				clip_info["reverse"].append({"path": path, "phase": phase})
			report["clips"].append(clip_info)
			print("VISUAL REVIEW: captured ", clip)
	viewport.queue_free()
	await process_frame
	if not args.has("--no-game") and not args.has("--neutral-only"):
		var lab: Node = load("res://scenes/world/spawn_area.tscn").instantiate()
		lab.pause_when_unfocused = false
		root.add_child(lab)
		current_scene = lab
		lab._set_paused(false)
		await create_timer(0.5).timeout
		await _capture("gameplay_past.png", root)
		report["game"].append("gameplay_past.png")
		lab._switch_preview_timeline()
		await create_timer(0.1).timeout
		await _capture("gameplay_future.png", root)
		report["game"].append("gameplay_future.png")
		lab._open_character_studio()
		await create_timer(0.3).timeout
		await _capture("studio.png", root)
		report["game"].append("studio.png")
	var file := FileAccess.open(OUTPUT.path_join("capture_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("STUDENT VISUAL EVIDENCE: CAPTURED (reference fidelity still requires image review)")
	quit()
