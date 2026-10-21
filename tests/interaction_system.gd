extends SceneTree
## Automated tests for the 3D Interaction System.
## Run with: godot --headless --path . --script res://tests/interaction_system.gd

const Interactable3D := preload("res://scripts/interaction/interactable_3d.gd")
const InteractionDetector := preload("res://scripts/interaction/interaction_detector.gd")
const InteractionController := preload("res://scripts/interaction/interaction_controller.gd")
const PuzzleInteractable3D := preload("res://scripts/interaction/puzzle_interactable_3d.gd")
const InteractionPrompt := preload("res://scripts/ui/interaction_prompt.gd")
const PowerSwitchPuzzle := preload("res://scripts/puzzles/implementations/power_switch_puzzle.gd")

var failures: int = 0
var checks: int = 0
var puzzle_manager: Node = null


func _initialize() -> void:
	# Ensure NetworkManager and PuzzleManager exist on root for headless test execution
	if not root.has_node("NetworkManager"):
		var net: Node = load("res://scripts/network/network_manager.gd").new()
		net.name = "NetworkManager"
		root.add_child(net)
	
	if not root.has_node("PuzzleManager"):
		puzzle_manager = load("res://scripts/puzzles/puzzle_manager.gd").new()
		puzzle_manager.name = "PuzzleManager"
		puzzle_manager.log_rejections = false
		root.add_child(puzzle_manager)
	else:
		puzzle_manager = root.get_node("PuzzleManager")

	_run_all_tests.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
		print("  [FAIL] " + message)
	else:
		print("  [PASS] " + message)


func tick(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
	await process_frame


func _run_all_tests() -> void:
	print("\n=== STARTING INTERACTION SYSTEM TEST SUITE ===")

	await _test_interactable_base()
	await _test_detector_proximity_and_selection()
	await _test_priority_and_hysteresis()
	await _test_timeline_restrictions()
	await _test_controller_execution()
	await _test_animation_locking_and_recovery()
	await _test_puzzle_interactable_integration()
	await _test_interaction_prompt_ui()
	await _test_sandbox_scene_instantiation()

	print("\n==============================================")
	if failures == 0:
		print("INTERACTION SYSTEM: PASS (%d checks, 0 failures)" % checks)
		quit(0)
	else:
		print("INTERACTION SYSTEM: FAIL (%d failures out of %d checks)" % [failures, checks])
		quit(1)


# ------------------------------------------------------------------------------
# 1. Base Interactable3D Tests
# ------------------------------------------------------------------------------
func _test_interactable_base() -> void:
	print("\n--- Test Suite 1: Interactable3D Base Component ---")

	var interactable := Interactable3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	interactable.add_child(shape)
	root.add_child(interactable)
	await tick(1)

	# Verify default physics layer (Layer 4 = bit 8)
	check(interactable.collision_layer == 8, "Interactable3D defaults to collision layer 4 (bit 8)")
	check(interactable.collision_mask == 0, "Interactable3D collision mask defaults to 0")
	check(interactable.monitorable == true, "Interactable3D is monitorable")

	# Actor proximity validation
	var actor := Node3D.new()
	root.add_child(actor)
	actor.global_position = Vector3(0, 0, 0)
	interactable.global_position = Vector3(1.0, 0, 0)
	interactable.interaction_distance = 1.5

	check(interactable.can_interact(actor), "Actor at 1.0m is within 1.5m interaction distance")

	interactable.global_position = Vector3(2.5, 0, 0)
	check(not interactable.can_interact(actor), "Actor at 2.5m is outside 1.5m interaction distance")

	# Enable / Disable state
	interactable.global_position = Vector3(1.0, 0, 0)
	var availability_emitted := [false]
	interactable.availability_changed.connect(func(avail: bool): availability_emitted[0] = not avail)
	interactable.set_interaction_enabled(false)
	check(availability_emitted[0], "availability_changed signal emitted on disabling")
	check(not interactable.can_interact(actor), "Disabled interactable cannot be interacted with")

	interactable.set_interaction_enabled(true)
	check(interactable.can_interact(actor), "Re-enabled interactable can be interacted with")

	# Contextual Prompt Updates
	var prompt_emitted := [false]
	interactable.prompt_changed.connect(func(p: String): prompt_emitted[0] = (p == "Open Drawer"))
	interactable.set_interaction_name("Open Drawer")
	check(prompt_emitted[0], "prompt_changed signal emitted on setting name")
	check(interactable.get_interaction_prompt() == "Open Drawer", "Prompt returns updated name")

	# Interaction Signal Lifecycle
	var lifecycle := [false, false, false] # started, interacted, finished
	interactable.interaction_started.connect(func(_a, _r): lifecycle[0] = true)
	interactable.interacted.connect(func(_a, _r): lifecycle[1] = true)
	interactable.interaction_finished.connect(func(_a, _r): lifecycle[2] = true)

	interactable.interact(actor, "past")
	check(lifecycle[0] and lifecycle[1] and lifecycle[2], "interact() triggers started -> interacted -> finished lifecycle")

	# One-shot interaction
	interactable.one_shot = true
	interactable.interact(actor, "past")
	check(not interactable.interaction_enabled, "One-shot interaction automatically disables interactable")

	# Clean up
	interactable.queue_free()
	actor.queue_free()
	await tick(2)


# ------------------------------------------------------------------------------
# 2. Detector Proximity & Nearest Target Selection
# ------------------------------------------------------------------------------
func _test_detector_proximity_and_selection() -> void:
	print("\n--- Test Suite 2: InteractionDetector Proximity & Target Selection ---")

	var actor := Node3D.new()
	root.add_child(actor)
	actor.global_position = Vector3.ZERO

	var detector := InteractionDetector.new()
	detector.actor = actor
	actor.add_child(detector)

	# Object A at 1.2m
	var obj_a := Interactable3D.new()
	obj_a.name = "ObjectA"
	obj_a.interaction_name = "Use Object A"
	obj_a.interaction_distance = 1.5
	var shape_a := CollisionShape3D.new()
	var sph_a := SphereShape3D.new()
	sph_a.radius = 1.0
	shape_a.shape = sph_a
	obj_a.add_child(shape_a)
	root.add_child(obj_a)
	obj_a.global_position = Vector3(1.2, 0, 0)

	await tick(3)

	check(detector.get_current_target() == obj_a, "Detector selects Object A within proximity")

	# Object B at 0.6m (closer than A)
	var obj_b := Interactable3D.new()
	obj_b.name = "ObjectB"
	obj_b.interaction_name = "Use Object B"
	obj_b.interaction_distance = 1.5
	var shape_b := CollisionShape3D.new()
	var sph_b := SphereShape3D.new()
	sph_b.radius = 1.0
	shape_b.shape = sph_b
	obj_b.add_child(shape_b)
	root.add_child(obj_b)
	obj_b.global_position = Vector3(0.6, 0, 0)

	await tick(3)

	check(detector.get_current_target() == obj_b, "Detector switches to closer Object B")

	# Move actor away beyond detection range
	actor.global_position = Vector3(10.0, 0, 0)
	await tick(3)

	check(detector.get_current_target() == null, "Target clears when actor moves out of range")

	# Move actor back
	actor.global_position = Vector3(0.6, 0, 0)
	await tick(3)
	check(detector.get_current_target() == obj_b, "Target re-acquired when moving back into range")

	# Delete focused object - detector handles safely
	obj_b.queue_free()
	await tick(3)

	check(detector.get_current_target() == obj_a, "Target safely falls back to Object A after Object B is deleted")

	# Clean up
	obj_a.queue_free()
	actor.queue_free()
	await tick(2)


# ------------------------------------------------------------------------------
# 3. Priority and Hysteresis Stability
# ------------------------------------------------------------------------------
func _test_priority_and_hysteresis() -> void:
	print("\n--- Test Suite 3: Priority & Hysteresis Stability ---")

	var actor := Node3D.new()
	root.add_child(actor)
	actor.global_position = Vector3.ZERO

	var detector := InteractionDetector.new()
	detector.actor = actor
	detector.hysteresis = 0.2
	actor.add_child(detector)

	var low_prio := Interactable3D.new()
	low_prio.interaction_distance = 2.0
	low_prio.interaction_priority = 0
	var col1 := CollisionShape3D.new()
	col1.shape = SphereShape3D.new()
	low_prio.add_child(col1)
	root.add_child(low_prio)
	low_prio.global_position = Vector3(0.8, 0, 0)

	var high_prio := Interactable3D.new()
	high_prio.interaction_distance = 2.0
	high_prio.interaction_priority = 5
	var col2 := CollisionShape3D.new()
	col2.shape = SphereShape3D.new()
	high_prio.add_child(col2)
	root.add_child(high_prio)
	high_prio.global_position = Vector3(1.2, 0, 0)

	await tick(3)

	check(detector.get_current_target() == high_prio, "Higher priority object selected even if slightly further")

	# Clean up
	low_prio.queue_free()
	high_prio.queue_free()
	actor.queue_free()
	await tick(2)


# ------------------------------------------------------------------------------
# 4. Timeline Restrictions
# ------------------------------------------------------------------------------
func _test_timeline_restrictions() -> void:
	print("\n--- Test Suite 4: Timeline Restrictions ---")

	var actor := Node3D.new()
	root.add_child(actor)
	actor.global_position = Vector3.ZERO

	var past_only := Interactable3D.new()
	past_only.allowed_timeline = Interactable3D.TimelineRestriction.PAST
	past_only.interaction_distance = 2.0
	root.add_child(past_only)
	past_only.global_position = Vector3.ZERO

	var future_only := Interactable3D.new()
	future_only.allowed_timeline = Interactable3D.TimelineRestriction.FUTURE
	future_only.interaction_distance = 2.0
	root.add_child(future_only)
	future_only.global_position = Vector3.ZERO

	var both_timelines := Interactable3D.new()
	both_timelines.allowed_timeline = Interactable3D.TimelineRestriction.BOTH
	both_timelines.interaction_distance = 2.0
	root.add_child(both_timelines)
	both_timelines.global_position = Vector3.ZERO

	# Test Past player permissions
	check(past_only.can_interact(actor, "past"), "Past-only object allows Past role")
	check(not past_only.can_interact(actor, "future"), "Past-only object blocks Future role")

	# Test Future player permissions
	check(not future_only.can_interact(actor, "past"), "Future-only object blocks Past role")
	check(future_only.can_interact(actor, "future"), "Future-only object allows Future role")

	# Test Both permissions
	check(both_timelines.can_interact(actor, "past"), "Both-timeline object allows Past role")
	check(both_timelines.can_interact(actor, "future"), "Both-timeline object allows Future role")

	past_only.queue_free()
	future_only.queue_free()
	both_timelines.queue_free()
	actor.queue_free()
	await tick(1)


# ------------------------------------------------------------------------------
# 5. Controller Interaction Execution
# ------------------------------------------------------------------------------
func _test_controller_execution() -> void:
	print("\n--- Test Suite 5: InteractionController Execution ---")

	var actor := CharacterBody3D.new()
	root.add_child(actor)
	actor.global_position = Vector3.ZERO

	var detector := InteractionDetector.new()
	detector.actor = actor
	actor.add_child(detector)

	var controller := InteractionController.new()
	controller.actor = actor
	controller.detector = detector
	actor.add_child(controller)

	var target := Interactable3D.new()
	target.interaction_distance = 2.0
	target.play_interaction_animation = false
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	target.add_child(col)
	root.add_child(target)
	target.global_position = Vector3(0.5, 0, 0)

	await tick(3)

	var interacted := [false]
	target.interacted.connect(func(_a, _r): interacted[0] = true)

	check(controller.is_interaction_available(), "Interaction is available when target is in range")
	var consumed := controller.try_interact()
	check(consumed, "try_interact() consumes input and returns true")
	check(interacted[0], "target.interacted signal triggered by controller")

	# Block interaction
	controller.set_interaction_blocked(true)
	check(not controller.is_interaction_available(), "Interaction unavailable while blocked")
	var blocked_consumed := controller.try_interact()
	check(not blocked_consumed, "try_interact() returns false when blocked")

	controller.set_interaction_blocked(false)
	check(controller.is_interaction_available(), "Interaction restored after unblocking")

	target.queue_free()
	actor.queue_free()
	await tick(2)


# ------------------------------------------------------------------------------
# 6. Character Animation Locking and Movement Recovery
# ------------------------------------------------------------------------------
func _test_animation_locking_and_recovery() -> void:
	print("\n--- Test Suite 6: Animation Locking & Recovery ---")

	var player = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	root.add_child(player)
	await tick(3)

	# Test initial unlocked state
	check(player._action.is_empty(), "Character initially has no active locking action")

	# Start interact action
	var started = player.play_action("interact")
	check(started, "play_action('interact') starts successfully")
	check(player._action == "interact", "Character _action set to 'interact' (movement locked)")

	# Complete action simulation
	player._on_animation_finished("Interact")
	check(player._action.is_empty(), "Character _action cleared after animation finishes (movement unlocked)")

	player.queue_free()
	await tick(2)


# ------------------------------------------------------------------------------
# 7. PuzzleInteractable3D Integration with PuzzleManager
# ------------------------------------------------------------------------------
func _test_puzzle_interactable_integration() -> void:
	print("\n--- Test Suite 7: PuzzleInteractable3D & PuzzleManager Integration ---")

	# Register reference power switch puzzle
	if not puzzle_manager.is_registered("test_power_puzzle"):
		puzzle_manager.register_puzzle("test_power_puzzle", PowerSwitchPuzzle.new())

	puzzle_manager.begin_session()
	check(not puzzle_manager.is_solved("test_power_puzzle"), "Puzzle starts unsolved")

	var puzzle_obj := PuzzleInteractable3D.new()
	puzzle_obj.puzzle_id = "test_power_puzzle"
	puzzle_obj.puzzle_action = "activate_power"
	puzzle_obj.allowed_timeline = Interactable3D.TimelineRestriction.PAST
	puzzle_obj.disable_on_complete = true
	puzzle_obj.interaction_distance = 2.0
	root.add_child(puzzle_obj)
	puzzle_obj.global_position = Vector3.ZERO

	var actor := Node3D.new()
	root.add_child(actor)
	actor.global_position = Vector3(0.5, 0, 0)

	# Future role rejected by timeline
	check(not puzzle_obj.can_interact(actor, "future"), "Future player cannot interact with Past-only switch")

	# Past role accepted
	var accepted_fired := [false]
	puzzle_obj.puzzle_action_accepted.connect(func(_pid, _act): accepted_fired[0] = true)
	puzzle_obj.interact(actor, "past")

	check(accepted_fired[0], "puzzle_action_accepted signal fired")
	check(puzzle_manager.is_solved("test_power_puzzle"), "PuzzleManager confirms puzzle solved")
	check(not puzzle_obj.interaction_enabled, "disable_on_complete disabled interactable after solution")

	puzzle_obj.queue_free()
	actor.queue_free()
	await tick(2)


# ------------------------------------------------------------------------------
# 8. InteractionPrompt UI Tests
# ------------------------------------------------------------------------------
func _test_interaction_prompt_ui() -> void:
	print("\n--- Test Suite 8: InteractionPrompt UI Presentation ---")

	var prompt_scene = load("res://scenes/ui/interaction_prompt.tscn").instantiate()
	root.add_child(prompt_scene)
	await tick(2)

	prompt_scene.show_prompt("Use Computer", "Past")
	check(prompt_scene.action_label.text == "Use Computer", "Prompt text reflects target action")
	check(prompt_scene.root_control.visible, "Prompt becomes visible on show_prompt")

	prompt_scene.show_prompt("Examine Temporal Rift", "Future")
	check(prompt_scene.action_label.text == "Examine Temporal Rift", "Prompt updates text dynamically")

	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 2, 5)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var target := Interactable3D.new()
	world.add_child(target)
	prompt_scene.set_target(target)
	await tick(2)
	check(prompt_scene.panel.get_global_rect().get_center().distance_to(camera.unproject_position(target.get_prompt_position())) < 1.0, "Prompt is centered on the targeted object")
	camera.position.x += 1.0
	await tick(2)
	check(prompt_scene.panel.get_global_rect().get_center().distance_to(camera.unproject_position(target.get_prompt_position())) < 1.0, "Prompt follows the object as the camera moves")
	target.position = camera.position + camera.basis.z * 2.0
	await tick(2)
	check(not prompt_scene.panel.visible, "Targets behind the camera do not show a floating prompt")
	world.queue_free()
	await tick(2)
	check(not prompt_scene._is_visible, "Deleting the target dismisses its prompt safely")

	prompt_scene.hide_prompt()
	check(not prompt_scene._is_visible, "Prompt internal state updates to hidden on hide_prompt")

	prompt_scene.queue_free()
	await tick(2)


# ------------------------------------------------------------------------------
# 9. Sandbox Scene Full Instantiation Test
# ------------------------------------------------------------------------------
func _test_sandbox_scene_instantiation() -> void:
	print("\n--- Test Suite 9: Sandbox Scene Instantiation ---")

	var sandbox = load("res://scenes/testing/interaction_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	await tick(3)

	check(sandbox.has_node("Player"), "Sandbox contains Player instance")
	check(sandbox.has_node("CameraRig/Camera3D"), "Sandbox contains fixed Camera3D")
	check(sandbox.has_node("InteractionPrompt"), "Sandbox contains InteractionPrompt UI")
	check(sandbox.has_node("World/Computer/Interactable3D"), "Sandbox contains Computer interactable")
	check(sandbox.has_node("World/Document/Interactable3D"), "Sandbox contains Document interactable")
	check(sandbox.has_node("World/Switch/PuzzleInteractable3D"), "Sandbox contains Switch puzzle interactable")
	check(sandbox.has_node("World/Door/Interactable3D"), "Sandbox contains Door interactable")
	check(sandbox.has_node("World/TemporalRift/Interactable3D"), "Sandbox contains Temporal Rift interactable")

	# Verify player has InteractionRig
	var player_rig: Node = sandbox.get_node("Player/InteractionRig")
	check(player_rig != null, "Player has InteractionRig child")
	check(player_rig.has_node("InteractionDetector"), "InteractionRig has detector")
	check(player_rig.has_node("InteractionController"), "InteractionRig has controller")

	sandbox.queue_free()
	await tick(2)

