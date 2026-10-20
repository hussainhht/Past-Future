extends SceneTree
## Exercise every animation in every facing, including one-shot completion and props.
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func signature(rig: Node2D) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for sprite in rig.get_node("IllustratedBody").get_children():
		result.append(sprite.position.x)
		result.append(sprite.position.y)
		result.append(sprite.rotation)
	return result

func anchor_position(rig: Node2D, part: String, endpoint: int) -> Vector2:
	var sprite: Sprite2D = rig._sprites[part]
	var slot: int = rig._textures[rig.facing].find(sprite.texture)
	var anchor: Array = rig.JOINT_ANCHORS[rig.facing][slot][endpoint]
	var point := Vector2(anchor[0], anchor[1]) * sprite.texture.get_size()
	if sprite.flip_h:
		point.x = sprite.texture.get_width() - point.x
	return sprite.global_transform * (point - sprite.texture.get_size() * 0.5)

func check_joints(rig: Node2D, label: String) -> void:
	for side in ["right", "left"]:
		check(anchor_position(rig, side + "_arm", 1).distance_to(anchor_position(rig, side + "_forearm", 0)) < 0.01, "Elbow artwork must meet at its shared joint: " + label + "/" + side)
		check(is_equal_approx(anchor_position(rig, side + "_forearm", 0).distance_to(anchor_position(rig, side + "_forearm", 1)), 96.0), "Reaching must preserve forearm length: " + label + "/" + side)
		check(anchor_position(rig, side + "_thigh", 1).distance_to(anchor_position(rig, side + "_shin", 0)) < 0.01, "Knee artwork must meet at its shared joint: " + label + "/" + side)

func _run() -> void:
	var rig = load("res://scenes/characters/student_paper_rig.tscn").instantiate()
	root.add_child(rig)
	rig.set_process(false)
	check(rig.DIRECTIONS.size() == 8 and rig.CLIPS.size() == 13, "Student must have eight views and the complete thirteen-clip library")
	for facing in rig.DIRECTIONS:
		rig.set_view(facing)
		check(rig._textures[facing].size() == 16, "Every facing must have complete body, hand, and blink artwork")
		for clip in rig.CLIPS:
			rig.play(clip, true)
			var initial := signature(rig)
			rig.advance(float(rig.CLIPS[clip].duration) * 0.23)
			check(signature(rig) != initial, "Animation must move articulated parts: " + facing + "/" + clip)
			check_joints(rig, facing + "/" + clip)
			for sprite in rig.get_node("IllustratedBody").get_children():
				check(sprite.texture is AtlasTexture and sprite.texture.get_height() > 0, "Every body part must have valid raster artwork")
				check(is_finite(sprite.position.x) and is_finite(sprite.position.y) and is_finite(sprite.rotation), "Animated joint transforms must remain finite")
			if clip in ["inspect", "carry_idle", "carry_walk"]:
				check(rig._sprites.document.visible, "Reading and carrying must show the held document")
				if facing == "north":
					check(rig._sprites.document.z_index < rig._sprites.torso.z_index and rig._sprites.left_forearm.z_index < rig._sprites.torso.z_index and rig._sprites.right_forearm.z_index < rig._sprites.torso.z_index, "A back view must occlude hands and a document held in front of the chest")
			if not rig.CLIPS[clip].loop:
				rig.advance(float(rig.CLIPS[clip].duration))
				check(rig.animation_name == "idle", "One-shot animations must finish and recover to idle")
	for sample in [[Vector2.DOWN,"south"], [Vector2(-1,1),"south_west"], [Vector2.LEFT,"west"], [Vector2(-1,-1),"north_west"], [Vector2.UP,"north"], [Vector2(1,-1),"north_east"], [Vector2.RIGHT,"east"], [Vector2(1,1),"south_east"]]:
		rig.set_facing(sample[0])
		check(rig.facing == sample[1], "Movement must select the matching illustrated viewpoint")
	rig.play("walk", true)
	rig.advance(0.31)
	var phase: float = rig.animation_time
	for view in rig.DIRECTIONS:
		rig.set_view(view)
		check(is_equal_approx(rig.animation_time, phase), "Changing direction must preserve the walk cycle phase")
		check_joints(rig, view + "/direction switch")
	rig.play("walk", true)
	rig.paused = true
	var frozen := signature(rig)
	rig.advance(1.0)
	check(signature(rig) == frozen, "Paused animation must keep a stable pose")
	print("STUDENT 2D: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures; 104 animation/view combinations)")
	quit(0 if failures == 0 else 1)
