extends SceneTree
## Real solo rooms: parked character positions, both timelines, live changes and visual-only safety.

const Rules := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
var checks := 0
var failures := 0
var room
var puzzles: Node

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func tick(count: int = 6) -> void:
	for index in count:
		await physics_frame
		await process_frame
	# Rendered startup can consume several physics ticks before a single process pass.
	# Wait through a complete frame so assertions observe the late ghost update.
	await process_frame

func quiet() -> void:
	if room.has_method("switch_role"):
		room.director.stop_dialogue()
		room._pending_lines.clear()
	else:
		room.gameplay.director.stop_dialogue()

func capture(name: String) -> void:
	var directory := OS.get_environment("TEMPORAL_GHOST_REVIEW_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await create_timer(.2).timeout
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "Capture " + name)

func toggle() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_G
		event.physical_keycode = KEY_G
		event.pressed = down
		Input.parse_input_event(event)
		await tick(2)

func act(action: String, who: String, payload: Dictionary = {}) -> void:
	var result: Dictionary = puzzles.submit_action(Rules.ID, action, payload, who)
	check(result.status != puzzles.Status.REJECTED, "Prepare real puzzle state: " + action)

func check_local_geometry(ghost: Node3D) -> void:
	var vertices := 0
	var outside := 0
	for batch: MeshInstance3D in ghost._batches:
		if batch.mesh == null: continue
		for surface in batch.mesh.get_surface_count():
			for vertex: Vector3 in batch.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				vertices += 1
				var offset: Vector3 = batch.global_transform * vertex - ghost.echo_position
				if Vector2(offset.x, offset.z).length() > ghost.RADIUS + .001: outside += 1
	check(vertices > 0, "The local echo contains actual uploaded surroundings geometry")
	check(outside == 0, "Every uploaded surroundings vertex stays within the parked character's radius, including large floors and walls")

func run() -> void:
	root.size = Vector2i(1600,900)
	root.get_node("CinematicTransitionManager").enabled = false
	puzzles = root.get_node("PuzzleManager")
	room = load(Rules.DESTINATION).instantiate()
	room.pause_when_unfocused = false
	root.add_child(room)
	current_scene = room
	await tick()
	quiet()
	var ghost = room.temporal_ghost
	check(ghost != null and ghost.visible, "Solo Past starts with the Future echo enabled")
	check(ghost.echo_position.is_equal_approx(room.get_node("future_entry").global_position), "Unvisited Professor stays at his entry point")
	check(ghost.find_children("*", "CollisionObject3D", true, false).is_empty(), "Ghosts have no collisions or interaction areas")
	check(ghost.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(), "Ghosts do not duplicate world audio")
	check(room.get_node("Actors").find_children("*", "CharacterBody3D", true, false).size() == 1, "There remains exactly one gameplay character")
	check(ghost.character.get_node("AnimationPlayer").is_playing(), "The parked Professor has an animated visual model")
	var draw_surfaces := 0
	for piece: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
		if piece.is_visible_in_tree() and piece.layers != 0 and piece.mesh != null: draw_surfaces += piece.mesh.get_surface_count()
	check(draw_surfaces <= 4, "The visible ghost uses at most four render surfaces, including the skinned Professor")
	var updates: int = ghost.visual_updates
	await tick(12)
	check(ghost.visual_updates == updates, "Settled ghost geometry does not rescan or rebuild while the world is unchanged")
	room.player.global_position = Vector3(-1.2,.05,1.6)
	room.player.get_node("Visual").rotation.y = .8
	await tick()
	var past_position: Vector3 = room.player.global_position
	room.switch_role()
	await tick()
	quiet()
	check(ghost.visible and ghost._echo_role == "past", "The Future sees a Past echo after switching roles")
	check(ghost.character.name == "StudentEcho" and ghost._animator.is_playing(), "The Past hologram uses the animated Student model")
	check(ghost.echo_position.is_equal_approx(past_position) and ghost.character.global_position.is_equal_approx(past_position), "Student hologram stays at the parked Past position")
	check(is_equal_approx(ghost.character.global_rotation.y, .8), "Student hologram remembers the Past facing")
	var walkway: MeshInstance3D = room.get_node("Layout/PastOnly/IntactWalkway/Mesh")
	check(ghost._copies.has(walkway) and ghost._copies[walkway].is_visible_in_tree(), "The Future sees the intact Past walkway")
	check(not room.get_node("Layout/PastOnly").visible, "The real Future keeps the Past branch hidden")
	check(not ghost._echo_visible(room.get_node("Layout/FutureOnly/BlockedSlab/Mesh")), "The Past hologram excludes Future rubble")
	check_local_geometry(ghost)
	await capture("corridor_past_ghost")
	var past_revision: int = puzzles.get_revision(Rules.ID)
	await toggle()
	check(not ghost.visible and not ghost._animator.active, "G hides the Past echo and suspends its animation")
	await toggle()
	check(ghost.visible and puzzles.get_revision(Rules.ID) == past_revision, "G restores the Past echo without changing gameplay")
	room.set_paused(true)
	await tick()
	check(not ghost.visible, "Pause suppresses the Past echo")
	room.set_paused(false)
	await tick()
	check(ghost.visible, "Resume restores the Past echo")
	room.player.global_position = Vector3(1.2,.05,1.6)
	room.player.get_node("Visual").rotation.y = -1.2
	await tick()
	var future_position: Vector3 = room.player.global_position
	check(ghost.echo_position.is_equal_approx(past_position), "Moving the Professor leaves the Past hologram anchored")
	room.switch_role()
	await tick()
	quiet()
	room.player.global_position = Vector3(-2.5,.05,3.8)
	room.get_node("CameraRig").snap_to_target()
	await tick()
	check(ghost.visible and ghost.echo_position.is_equal_approx(future_position), "The echo follows the parked Professor rather than the Student")
	check(ghost.character.global_position.is_equal_approx(future_position), "Professor model occupies the remembered world position")
	check(is_equal_approx(ghost.character.global_rotation.y, -1.2), "Professor keeps his facing when roles change")
	var slab: MeshInstance3D = room.get_node("Layout/FutureOnly/BlockedSlab/Mesh")
	var bridge: MeshInstance3D = room.get_node("Layout/FutureOnly/SecuredBridge/Deck/Mesh")
	check(ghost._copies.has(slab) and ghost._copies[slab].is_visible_in_tree(), "Future rubble is visible inside the local echo while the Past remains intact")
	check(not room.get_node("Layout/FutureOnly").visible, "The real Past never switches to the Future branch")
	check(not ghost._echo_visible(room.get_node("Layout/PastOnly/IntactWalkway/Mesh")), "Past-only geometry is excluded from the Future echo")
	var far_mesh: MeshInstance3D = room.get_node("Layout/Shared/ServiceStand/Mesh")
	check(not ghost._copies.has(far_mesh) or not ghost._copies[far_mesh].visible, "Distant equipment stays outside the Professor's local echo")
	check_local_geometry(ghost)
	# Small moves must recut boundary surfaces even if the same source objects remain visible.
	room._positions.future = future_position + Vector3(.02,0,0)
	ghost.refresh()
	check_local_geometry(ghost)
	room._positions.future = future_position
	ghost.refresh()
	check_local_geometry(ghost)
	await capture("corridor_blocked")
	var revision: int = puzzles.get_revision(Rules.ID)
	await toggle()
	check(not ghost.visible and not ghost.enabled, "G turns the overlay off")
	await capture("corridor_without_ghost")
	await toggle()
	check(ghost.visible and ghost.enabled and puzzles.get_revision(Rules.ID) == revision, "G restores the overlay without submitting a puzzle action")
	for down in [true, false]:
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_RIGHT_SHOULDER
		button.pressed = down
		Input.parse_input_event(button)
		await tick(2)
	check(not ghost.enabled, "R1 / RB toggles the same overlay on a controller")
	await toggle()
	room.player.position.x -= 1.0
	await tick()
	check(ghost.echo_position.is_equal_approx(future_position), "Moving the Student leaves the Future area anchored")
	act("isolate_service", "past")
	act("charge_battery", "future")
	act("set_support", "past", {"support":"circle", "stage":3})
	act("set_support", "past", {"support":"triangle", "stage":2})
	act("set_support", "past", {"support":"square", "stage":1})
	await tick()
	var piston: MeshInstance3D = room.get_node("Layout/Shared/Support_triangle/Piston/Mesh")
	check(ghost._copies[piston].global_transform.is_equal_approx(piston.global_transform), "Support extension changes appear in the echo without switching roles")
	var camera_rig: Node3D = room.get_node("CameraRig")
	var camera_transform: Transform3D = room.camera.global_transform
	camera_rig.set_process(false)
	room.camera.global_position += Vector3(1000,0,0)
	await tick()
	check(not ghost.visible and not ghost._animator.active, "An offscreen Future area hides the entire ghost and suspends its animation")
	updates = ghost.visual_updates
	act("apply_supports", "past")
	await tick()
	quiet()
	check(ghost.visual_updates == updates, "Puzzle changes do not rebuild offscreen ghost geometry")
	room.camera.global_transform = camera_transform
	camera_rig.set_process(true)
	await tick()
	check(ghost.visible and ghost._animator.active, "Returning to the Future area restores the ghost and animation")
	check(not ghost._copies[slab].visible and ghost._copies[bridge].is_visible_in_tree(), "Securing supports replaces the blocked slab with the Future bridge live")
	check_local_geometry(ghost)
	await capture("corridor_secured")
	room._show_device("Support_triangle")
	await create_timer(.4).timeout
	check(ghost.visible and room.ui.inspector.active, "The world echo remains available during physical equipment inspection")
	await toggle()
	check(not ghost.visible and room.ui.inspector.active, "G can hide the echo without closing equipment inspection")
	await toggle()
	check(ghost.visible and room.ui.inspector.active, "G can restore the echo while inspecting equipment")
	room.ui.close_modal()
	room.set_paused(true)
	await tick()
	check(not ghost.visible, "Pause suppresses the echo")
	room.set_paused(false)
	await tick()
	check(ghost.visible, "Resume restores the echo")
	room.switch_role()
	await tick()
	quiet()
	room.player.global_position = Vector3(4,.05,6)
	await tick()
	future_position = room.player.global_position
	room.switch_role()
	await tick()
	quiet()
	check(ghost.echo_position.is_equal_approx(future_position), "Repositioning the Professor relocates the entire echo")
	check_local_geometry(ghost)
	# Visit the opposite end to verify old neighborhoods are released rather than accumulated.
	var previous_sources: Array = ghost._copies.keys()
	room.switch_role()
	await tick()
	quiet()
	room.player.global_position = Vector3(-5,.05,-6)
	await tick()
	room.switch_role()
	await tick()
	quiet()
	var distant := 0
	var retained := 0
	for previous: MeshInstance3D in previous_sources:
		var bounds: AABB = ghost._echo_transform(previous) * previous.get_aabb()
		if not ghost._within_radius(bounds, ghost.RADIUS + ghost.MOTION_MARGIN):
			distant += 1
			if ghost._copies.has(previous): retained += 1
	check(distant > 0 and retained == 0, "Moving away releases cached copies from the previous neighborhood")
	check_local_geometry(ghost)
	var saved: Dictionary = puzzles.get_state(Rules.ID)
	room.queue_free()
	await tick()
	check(puzzles.get_state(Rules.ID) == saved, "Removing the visual overlay preserves authoritative progression")

	# Laboratory future-offset props must match the actual Future, not the Past's transforms.
	puzzles.begin_session()
	puzzles.offline_role = "past"
	room = load("res://scenes/world/spawn_area.tscn").instantiate()
	room.pause_when_unfocused = false
	room.level_travel_enabled = false
	root.add_child(room)
	current_scene = room
	room.gameplay.get_node("StudentDiscovery").enabled = false
	room.gameplay.get_node("FutureDiscovery").enabled = false
	await tick()
	quiet()
	ghost = room.temporal_ghost
	check(ghost.visible, "The same solo echo is available in Level 01")
	future_position = ghost.echo_position
	room.player.global_position = Vector3(-4,0,4)
	await tick()
	check(ghost.echo_position.is_equal_approx(future_position), "The unvisited Professor remains stationary when the Student moves")
	room._switch_preview_timeline()
	await tick()
	quiet()
	check(room.player.global_position.distance_to(future_position) < .1, "First role switch enters at the position shown by the echo")
	var prop: TimelineProp
	for candidate in room.lab.timeline_props():
		if candidate.future_offset != Vector3.ZERO:
			prop = candidate
			break
	check(prop != null, "Laboratory includes authored displaced Future props")
	var source := prop.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var actual_future_transform := source.global_transform
	room.player.global_position = Vector3(prop.global_position.x, .05, prop.global_position.z + 1.5)
	await tick()
	room._switch_preview_timeline()
	await tick()
	quiet()
	check(ghost.visible and ghost._copies.has(source), "A nearby displaced Future prop appears after returning to the Past")
	check(ghost._copies[source].global_transform.is_equal_approx(actual_future_transform), "Echo applies the true Future displacement and rotation")
	check(not source.global_transform.is_equal_approx(actual_future_transform), "Echo leaves the real Past prop unchanged")
	check_local_geometry(ghost)
	await capture("laboratory_ghost")
	var actual_past_transform := source.global_transform
	room.player.global_position = Vector3(actual_past_transform.origin.x, .05, actual_past_transform.origin.z + 1.5)
	room.player.get_node("Visual").rotation.y = 1.1
	await tick()
	past_position = room.player.global_position
	room._switch_preview_timeline()
	await tick()
	quiet()
	check(ghost.visible and ghost._echo_role == "past" and ghost._copies.has(source), "Laboratory Future sees nearby Past props")
	check(ghost._copies[source].global_transform.is_equal_approx(actual_past_transform), "Past hologram restores authored prop position and rotation")
	check(source.global_transform.is_equal_approx(actual_future_transform), "Past hologram leaves the actual Future prop displaced")
	check(ghost.echo_position.is_equal_approx(past_position) and is_equal_approx(ghost.character.global_rotation.y, 1.1), "Laboratory Past hologram remembers Student position and facing")
	check_local_geometry(ghost)
	await capture("laboratory_past_ghost")
	room.queue_free()
	await tick()
	# Starting directly in the Future must also show the unvisited Student at entry.
	puzzles.begin_session()
	puzzles.offline_role = "future"
	room = load("res://scenes/world/spawn_area.tscn").instantiate()
	room.pause_when_unfocused = false
	room.level_travel_enabled = false
	root.add_child(room)
	current_scene = room
	await tick()
	quiet()
	ghost = room.temporal_ghost
	check(ghost.visible and ghost._echo_role == "past", "A Future-first solo session starts with a Past hologram")
	check(ghost.echo_position.is_equal_approx(room.get_node("SpawnPoint").global_position), "The unvisited Student stays at the laboratory entry")
	room.queue_free()
	await tick()
	await create_timer(.15).timeout
	print("TEMPORAL GHOST: %s (%d checks; %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
