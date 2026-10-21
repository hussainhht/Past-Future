extends SceneTree
## Run: godot --headless --path . --script res://tests/signal_lab.gd
## The Signal Laboratory in the solo preview: both timelines, the asset checklist, and Puzzle 01
## (the frequency puzzle) played in the room through the real interaction rig, its calibration
## terminal, research log and radio pickups. The puzzle's rules have their own suite
## (tests/run_frequency_tests.py); this one checks the room around them.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
## Checklist ids (docs/assets/ASSET_INVENTORY.md) the room must contain. A01, A08, A12 and A14 are
## the original floor and greybox furniture in spawn_area.tscn, outside the room scene.
const REQUIRED := ["A02", "A03", "A04", "A05", "A06", "A07", "A09", "A10", "A11", "A13", "A15", "A16", "A17",
	"A18", "A19", "A20", "A21", "A22", "A23", "A24", "A25", "A26", "F01", "F02", "F03", "F06", "F07", "F10"]

var failures: int = 0
var puzzles: Node
var area
var lab  # SignalLab; untyped so this script compiles before the autoloads exist
var player: CharacterBody3D
var controller  # InteractionController
var completions: int = 0
var sounds: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func tick(count: int = 3) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func wait_until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func state() -> Dictionary:
	return puzzles.get_state(Rules.ID)


func set_timeline(name: String) -> void:
	area.timeline = name
	area._apply_timeline()
	player = area.player
	controller = area.interaction
	await tick(4)


## Put the player at a spot, facing north, and let the detector pick its target.
func stand(at: Vector3) -> Interactable3D:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await tick(6)
	controller.detector.refresh_target()
	return controller.get_current_interactable()


## Use whatever the detector selected, the way the F key does, and wait for any animation.
func use(target_name: String) -> bool:
	var target: Interactable3D = controller.get_current_interactable()
	if target == null or target.name != target_name:
		check(false, "Expected '%s' to be the interaction target, got %s" % [target_name, target.name if target else "nothing"])
		return false
	var used: bool = controller.try_interact()
	await wait_until(func() -> bool: return player._action.is_empty(), 4.0)
	await tick(2)
	return used


func _run() -> void:
	puzzles = root.get_node("PuzzleManager")
	area = load("res://scenes/world/spawn_area.tscn").instantiate()
	area.pause_when_unfocused = false
	area.level_travel_enabled = false  # This suite inspects/reset the lab after its exit; travel has its own suite.
	root.add_child(area)
	current_scene = area
	await create_timer(0.4).timeout
	await tick()
	area._set_paused(false)
	lab = area.lab
	player = area.player
	controller = area.interaction
	# Room assertions are independent of story pacing; the gameplay suite covers dialogue.
	area.gameplay.get_node("StudentDiscovery").enabled = false
	area.gameplay.get_node("FutureDiscovery").enabled = false
	area.gameplay.adapter.link_sequence_id = &""
	puzzles.log_rejections = false
	lab.audio.sound_played.connect(func(id: StringName, _is_3d: bool, _at: Vector3) -> void: sounds.append(id))
	puzzles.puzzle_completed.connect(func(id: String) -> void:
		if id == Rules.ID:
			completions += 1
	)
	_check_layout()
	await _check_timelines()
	await _check_documents()
	await _check_door_blocks()
	await _check_puzzle()
	await _check_exit()
	await _check_reset()
	await create_timer(1.5).timeout  # let the last one-shot sounds finish before the engine shuts down
	area.queue_free()
	await tick(3)
	await create_timer(.2).timeout
	print("SIGNAL LAB: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)


func _check_layout() -> void:
	check(puzzles.is_registered(Rules.ID), "The room must register the frequency puzzle")
	var ids := {}
	for prop in lab.timeline_props():
		if not prop.asset_id.is_empty():
			ids[prop.asset_id] = true
	for id in REQUIRED:
		check(ids.has(id), "The room is missing checklist item %s" % id)
	for name in ["SecurityDoor", "DoorKeypad", "JunctionBox", "ConsoleTerminal", "ResearchNotebook", "LabMemo", "PastRadio", "FutureRadio"]:
		check(lab.get_node_or_null("Layout/Interactive/" + name) != null, "Interactive device %s must be in the layout" % name)
	var door = lab.door
	check(door.get_node("Leaf") is Node3D and door.find_child("StatusLight", true, false) != null, "The door leaf and status light must be separate nodes")
	var keypad: Node = lab.get_node("Layout/Interactive/DoorKeypad")
	check(keypad.find_children("Button_*", "MeshInstance3D", true, false).size() == 12, "The keypad must have 12 separate buttons")
	for interactable in lab.find_children("*", "Area3D", true, false):
		if interactable is Interactable3D:
			# The room's own interactables stand on floor anchors; the frequency puzzle's parts keep their own.
			if interactable.get_script().resource_path == "res://scripts/interaction/interactable_3d.gd":
				check(interactable.interaction_anchor != null and is_zero_approx(interactable.get_interaction_position().y), "%s must stand on a floor-level anchor" % interactable.get_path())
			check(interactable.highlight_target != null and interactable.highlight_target.has_method("set_highlighted"), "%s must have a rim highlight" % interactable.get_path())
	check(lab.world_environment != null and lab.key_light != null, "The room must be wired to the scene's environment and key light")
	var rift: Node = lab.get_node("Layout/RiftArea/TemporalRift")
	check(rift.get_node("Fragments").get_child_count() >= 6, "The rift must have separate crystal fragments")
	check(rift.get_node("Motes") is CPUParticles3D, "The rift must use CPU particles (GL Compatibility)")


func _check_timelines() -> void:
	var debris: TimelineProp = lab.get_node("Layout/FutureDamage/DebrisNorth")
	var panel_intact: TimelineProp = lab.get_node("Layout/Architecture/North/Panel1")
	var panel_damaged: TimelineProp = lab.get_node("Layout/Architecture/North/Panel1Damaged")
	var chair: TimelineProp = lab.get_node("Layout/ResearchStation/Chair")
	check(not debris.visible and panel_intact.visible and not panel_damaged.visible, "The Past must hide Future damage and show intact walls")
	var debris_shape: CollisionShape3D = debris.find_child("Collision", true, false)
	check(debris_shape.disabled, "Hidden Future debris must not collide in the Past")
	var past_chair := chair.transform
	var wall_mesh: MeshInstance3D = panel_intact.find_children("*", "MeshInstance3D", true, false)[0]
	var past_material := wall_mesh.get_surface_override_material(0)
	await set_timeline("Future")
	check(lab.future and debris.visible and panel_damaged.visible and not panel_intact.visible, "The Future must show the ruin")
	check(not debris_shape.disabled, "Future debris must collide in the Future")
	check(not chair.transform.is_equal_approx(past_chair), "The research chair must be knocked over in the Future")
	var other_wall: MeshInstance3D = lab.get_node("Layout/Architecture/North/Panel0").find_children("*", "MeshInstance3D", true, false)[0]
	var future_material := other_wall.get_surface_override_material(0)
	check(future_material != past_material and future_material is ShaderMaterial, "Each timeline must use its own wall material")
	check(future_material.get_shader_parameter("paint_color") != past_material.get_shader_parameter("paint_color"), "Future walls must differ in colour, not just in light")
	check(lab.get_node("Lighting/Future").visible and not lab.get_node("Lighting/Past").visible, "Future lighting rig must replace the Past rig")
	var future_ambient: Color = lab.world_environment.environment.ambient_light_color
	await set_timeline("Past")
	check(lab.world_environment.environment.ambient_light_color != future_ambient, "Each timeline must light the room differently")
	check(chair.transform.is_equal_approx(past_chair), "Returning to the Past must restore the authored layout")
	check(wall_mesh.get_surface_override_material(0) == past_material, "Returning to the Past must restore the shared Past material")


func _check_documents() -> void:
	var ui = lab.ui
	var texts := {}
	for timeline in ["Past", "Future"]:
		await set_timeline(timeline)
		for spot in [Vector3(6.9, 0, 1.55), Vector3(-7.2, 0, 1.55)]:
			var target := await stand(spot)
			check(target != null and target.get_parent().name in ["ResearchNotebook", "LabMemo"], "A desk document must be readable at %s" % spot)
			if target == null:
				continue
			var highlight_on: bool = target.get_parent().find_children("*", "MeshInstance3D", true, false)[0].material_overlay != null
			check(highlight_on, "The selected document must show the rim highlight")
			await use(target.name)
			check(ui.modal_kind() == "document", "Reading must open the document viewer")
			var body := ""
			for label in ui.find_children("*", "Label", true, false):
				body += label.text
			texts[timeline + target.get_parent().name] = body
			ui.close_modal()
			await tick()
	check(texts.get("PastResearchNotebook", "") != texts.get("FutureResearchNotebook", ""), "The notebook must read differently thirty-one years later")
	check("recovered log" in texts.get("FutureResearchNotebook", ""), "The Future notebook must point at the recovered log")
	check("temporal link" in texts.get("PastLabMemo", ""), "The Past memo must explain how the door releases")
	await set_timeline("Past")


func _check_door_blocks() -> void:
	player.global_position = Vector3(6.2, 0, -6.2)
	Input.action_press("move_up")
	await tick(40)
	Input.action_release("move_up")
	await tick()
	check(player.global_position.z > -7.75, "The sealed door must block the exit")


func _check_puzzle() -> void:
	var console: Node = lab.get_node("Layout/Interactive/ConsoleTerminal")
	var terminal = lab.terminal
	var console_spot := Vector3(0, 0, -5.6)

	# Past: the calibration computer is on the console; it needs the Student's radio first.
	var target := await stand(console_spot)
	check(target != null and target.name == "Computer", "In the Past the console must offer the calibration computer")
	await use("Computer")
	check(terminal.visible and not player.controls_enabled, "The calibration terminal must open and hold the player still")
	terminal.frequency_input.text = "67"
	var early: Dictionary = terminal.submit_frequency()
	check(early.status == Status.REJECTED and early.reason == "student_radio_required", "Calibrating before taking the radio must be refused")
	terminal.close()
	await tick()
	check(player.controls_enabled, "Closing the terminal must give control back")

	# Past: the Student's radio is on the science bench.
	target = await stand(Vector3(-4.85, 0, 1.6))
	check(target != null and target.get_parent().name == "PastRadio", "The Student's radio must be on the science bench")
	await use(target.name)
	check(state().student_radio, "Taking the radio must be confirmed by PuzzleManager")
	check(area.radio.owns_radio and player.skeleton.get_node("HeldRadioSocket/PlaceholderRadio").visible, "The Student must now hold a radio")
	check(not lab.get_node("Layout/Interactive/PastRadio/Pickup/Model").visible, "The radio must leave the bench")

	# Past: a wrong frequency is not found; 67 locks the array but the link still needs the other radio.
	await stand(console_spot)
	await use("Computer")
	terminal.frequency_input.text = "66"
	var miss: Dictionary = terminal.submit_frequency()
	check(miss.status == Status.NO_CHANGE and not state().frequency_calibrated, "A wrong frequency must not calibrate the array")
	check(console.readout.text == "SIGNAL UNSTABLE" and not lab.door.is_open, "A wrong frequency changes nothing in the room")
	terminal.frequency_input.text = "67"
	var hit: Dictionary = terminal.submit_frequency()
	check(hit.status == Status.CHANGED and state().frequency_calibrated, "67 MHz must calibrate the array")
	check(completions == 0 and console.readout.text == "SIGNAL LOCKED" and not lab.door.is_open, "Calibration alone must not open the door")
	terminal.close()

	# Future: the damaged console's recovered log gives the frequency; the Professor's radio is in the reading corner.
	await set_timeline("Future")
	target = await stand(console_spot)
	check(target != null and target.name == "RecoveredLog", "In the Future the console must offer the recovered log")
	await use("RecoveredLog")
	check(lab.reader.visible and "67 MHz" in lab.reader.document_label.text, "The recovered log must show 67 MHz")
	lab.reader.close()
	target = await stand(Vector3(-8.45, 0, 4.2))
	check(target != null and target.get_parent().name == "FutureRadio", "The Professor's radio must be in the reading corner")
	await use(target.name)
	check(Rules.link_established(state()) and completions == 1, "The second radio must establish the link, once")
	check("Radio connection established" in lab.ui.toast_text(), "Connection guidance appears as explicitly separated player feedback")
	check(lab.door.opening or lab.door.is_open, "The link must start opening the door")
	check(await wait_until(func() -> bool: return lab.door.is_open, 4.0), "The door must finish opening")
	check(&"door_open" in sounds and &"computer_success" in sounds, "The door and console must sound through the AudioDirector")
	check(console.readout.text == "TEMPORAL LINK", "The console readout must confirm the link")
	var leaf_open: Vector3 = lab.door.leaf.position
	check(leaf_open.x > 1.9, "The leaf must slide clear of the opening")
	await set_timeline("Past")
	check(lab.door.is_open and lab.door.leaf.position.is_equal_approx(leaf_open), "The door must be open in the Past too")
	check(lab.get_node("Layout/Interactive/DoorKeypad").display.text == "OPEN", "The keypad must report the open door")
	check(puzzles.submit_action(Rules.ID, "tune_frequency", {"frequency": 67}, "past").status == Status.NO_CHANGE and completions == 1, "Repeating the calibration must not repeat the unlock")


func _check_exit() -> void:
	var exits := [0]
	lab.player_exited.connect(func(_body: Node3D) -> void: exits[0] += 1)
	player.global_position = Vector3(6.2, 0, -6.4)
	Input.action_press("move_up")
	await tick(70)
	Input.action_release("move_up")
	await tick()
	check(player.global_position.z < -9.0 and absf(player.global_position.y) < 0.05, "The open door must let the player walk into the corridor")
	check(lab.exited and exits[0] == 1, "Reaching the corridor must clear the room once")


## A host-side reset seals the room again and puts both radios back.
func _check_reset() -> void:
	check(puzzles.reset_puzzle(Rules.ID), "The host must be able to reset the frequency puzzle")
	await tick(4)
	check(not state().student_radio and not state().frequency_calibrated, "A reset must start over")
	check(not lab.door.is_open and lab.door.leaf.position.x < 0.1, "A reset must seal the door again")
	check(lab.get_node("Layout/Interactive/PastRadio/Pickup/Model").visible, "A reset must put the Student's radio back")
	var console: Node = lab.get_node("Layout/Interactive/ConsoleTerminal")
	check(console.readout.text == "SIGNAL UNSTABLE", "A reset must clear the console readout")
