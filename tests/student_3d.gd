extends SceneTree
## Validate imported animation playback, per-player resources, and action recovery.

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/characters/student_3d_player.tscn")
	var player = scene.instantiate()
	var other = scene.instantiate()
	root.add_child(player)
	root.add_child(other)
	player.set_physics_process(false)
	other.set_physics_process(false)
	var ap: AnimationPlayer = player.animator
	var sk: Skeleton3D = player.skeleton
	check(sk.get_bone_count() == 23 and player.skinned_mesh.skin.get_bind_count() == 23, "The custom mesh must be bound to the complete KayKit skeleton")
	check(ap.get_animation_list().size() == 77, "All selected genuine KayKit clips must import")
	for clip in ap.get_animation_list():
		ap.play(clip, 0.0)
		ap.advance(0.0)
		var start := sk.get_bone_pose(sk.find_bone("upperarm.r"))
		ap.advance(ap.get_animation(clip).length * 0.37)
		var changed := false
		for bone in range(sk.get_bone_count()):
			var transform := sk.get_bone_global_pose(bone)
			check(transform.origin.is_finite() and transform.basis.is_finite(), "Animation transforms must stay finite: " + clip)
		changed = not start.is_equal_approx(sk.get_bone_pose(sk.find_bone("upperarm.r")))
		if clip in ["Walking_A", "Running_A", "Interact", "PickUp"]:
			check(changed, "Core clips must animate the skeleton: " + clip)
	var other_color: Color = other._materials.jacket.material.albedo_color
	player.body_color = Color("89ccd4")
	check(other._materials.jacket.material.albedo_color == other_color, "Timeline tint must be independent per player")
	check(ap.get_animation("Idle_A") != other.animator.get_animation("Idle_A"), "Animation resources must be independent per player")
	for action in ["interact", "inspect", "pick_up", "put_down"]:
		check(player.play_action(action), "Action must start: " + action)
		check(not player.play_action("interact"), "Overlapping actions must be rejected")
		ap.advance(ap.current_animation_length + 0.1)
		check(player._action.is_empty(), "One-shot clip must release the action lock: " + action)
		if action in ["pick_up", "put_down"]:
			check(player.carrying == (action == "pick_up") and player._held_document.visible == player.carrying, "Pickup/drop completion must update the demonstration prop")
	player._play("Walking_A")
	ap.advance(0.2)
	player.controls_enabled = false
	var frozen := ap.current_animation_position
	await create_timer(0.1).timeout
	check(is_equal_approx(ap.current_animation_position, frozen), "Pause must freeze the skeleton animation")
	check(not player.play_action("interact"), "Paused gameplay must not accept actions")
	player.controls_enabled = true
	print("STUDENT 3D: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures; 77 animation clips)")
	quit(0 if failures == 0 else 1)
