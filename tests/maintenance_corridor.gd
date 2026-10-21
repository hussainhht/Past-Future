extends SceneTree
const Rules = preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const Frequency = preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
var room
var puzzles: Node
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func tick(count: int = 3) -> void:
	for i in count: await physics_frame
	await process_frame
func act(action: String, who: String, payload: Dictionary = {}) -> Dictionary:
	return puzzles.submit_action(Rules.ID, action, payload, who)
func state() -> Dictionary: return puzzles.get_state(Rules.ID)
func indicator(path: String) -> Color:
	return room.get_node("Layout/" + path).material_override.albedo_color
func quiet() -> void:
	room.director.stop_dialogue()
	room._pending_lines.clear()
func use(id: String) -> bool:
	room.ui.close_modal()
	quiet()
	room.player.global_position = room.devices[id].global_position + Vector3(0,0,.3)
	room.player.velocity = Vector3.ZERO
	await tick(5)
	room.controller.detector.refresh_target()
	var target: Interactable3D = room.controller.get_current_interactable()
	check(target == room.devices[id], "The real detector must select " + id)
	if target != room.devices[id]: return false
	var ok: bool = room.controller.try_interact()
	await tick(2)
	check(ok and room.ui.is_modal_open(), "The real interaction must open " + id)
	return ok
func pickup(item: String) -> void:
	room.ui.close_modal()
	quiet()
	room.player.global_position = room.devices["Case_" + item].global_position + Vector3(0, 0, 0.3)
	await tick(5)
	room.controller.detector.refresh_target()
	check(room.controller.get_current_interactable() == room.devices["Case_" + item], "Detector finds the distinct equipment case")
	check(room.controller.try_interact(), "Case can be picked up through the real interaction controller")
	await tick(3)
	check(state().storage.past_hand == item and room.player.carrying, "Confirmed pickup carries the actual case")

func press(text: String, settle: bool = true) -> void:
	var inspector = room.ui.inspector
	check(inspector.controls.has(text), "Missing physical control: " + text)
	if not inspector.controls.has(text): return
	var control: Dictionary = inspector.controls[text]
	check(not control.option.get("disabled", false), text + " should be enabled")
	await tick(3)
	var point: Vector2 = room.camera.unproject_position(control.visual.global_position)
	check(inspector.pick_at(point), "The camera ray must operate the real 3D control: " + text)
	await tick(3)
	if settle:
		for index in 3: await wait_lift(index)

func wait_lift(index: int) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while room.storage.busy[index] and Time.get_ticks_msec() < deadline: await process_frame
	check(not room.storage.busy[index], "Independent lift finishes its hatch/platform motion")
	await tick(3)

func switch() -> void:
	room.ui.close_modal()
	quiet()
	room.switch_role()
	for device in room.devices.values(): device.play_interaction_animation = false
	await tick(3)
func run() -> void:
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	room = load(Rules.DESTINATION).instantiate()
	room.pause_when_unfocused = false
	root.add_child(room)
	current_scene = room
	await tick(8)
	for device in room.devices.values(): device.play_interaction_animation = false
	quiet()
	check(room.radio.has_established_link() and room.radio.owns_radio, "Direct F6 preview creates a working local radio link")
	var session: int = puzzles.get_session_id()
	var original_frequency: Dictionary = puzzles.get_state(Frequency.ID)
	check(room.devices.size() == 22, "Only power/story devices, seven portable items and three storage bays exist")
	check(not room.get_node("Layout/Shared/ReserveFutureLabel").visible, "Distant and other-role station labels do not clutter the entry")
	check(indicator("Shared/ServiceStand/Indicator/Mesh") != indicator("Shared/BatteryStand/Indicator/Mesh"), "Local and other-role equipment are visually distinct before power is restored")
	await use("Service")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await tick(2)
	escape.pressed = false
	Input.parse_input_event(escape)
	check(not room.ui.is_modal_open() and not room._paused and room.player.controls_enabled, "Escape closes the terminal without pausing or leaving controls locked")
	await use("Service")
	await press("Flip SERVICE isolator")
	check(state().service_isolated, "Service button commits confirmed state")
	await switch()
	check(room.role == "future" and room.player.scene_file_path.ends_with("professor_3d_player.tscn"), "Solo role switch loads the real Professor")
	check(not room.devices.ReservePast.is_timeline_allowed("future"), "Private Past panel is unavailable to Future")
	await use("Battery")
	await press("Turn charging crank")
	check(state().battery_ready, "Crank interaction supplies local emergency power")
	check(indicator("Shared/PowerRoutes/PastFeed/Current0/Mesh") == Color("76c9b3") and indicator("Shared/PowerRoutes/FutureFeed/Current0/Mesh") == Color("76c9b3"), "Both circuit runs show the confirmed shared supply")
	room.ui.close_modal()
	check(not room.devices.has("Apply") and not room.devices.has("Diagnostic") and not room.devices.has("Support_circle"), "Removed puzzle has no interactable controls")
	check(room.get_node_or_null("Layout/Shared/Support_circle") == null and room.get_node_or_null("Layout/FutureOnly/GapBarrier") == null, "Support props and blocked crossing are removed from the actual map")
	room.player.position = Vector3(1.2,.02,2.8)
	Input.action_press("move_up")
	await tick(160)
	Input.action_release("move_up")
	check(room.player.position.z < -3.3 and room.player.position.y > -.1, "The Professor can walk directly to storage after power restoration")
	await use("Archive")
	check(not state().archive_read and state().storage.manifest_read, "Damaged terminal reveals the Future shipping record, not its archive")
	room.ui.close_modal()
	await switch()
	await pickup("v09")
	await use("StorageBay0")
	await press("Place carried object")
	await press("Lower and store tray", false)
	check(room.storage.busy[0], "Storage command starts a physical hatch/lift sequence")
	await create_timer(.45).timeout
	check(room.storage.doors[0].get_node("LeftHinge").rotation_degrees.z > 80, "Floor hatch opens before the item descends")
	check(room.storage.lifts[0].position.y < room.storage.TOP, "Loaded platform physically moves below its loading position")
	await wait_lift(0)
	check(is_equal_approx(room.storage.lifts[0].position.y, room.storage.BOTTOM), "Stored case reaches the bottom of the underground shaft")
	check(is_zero_approx(room.storage.doors[0].get_node("LeftHinge").rotation_degrees.z), "Floor doors close after the tray reaches the bottom")
	var shaft_center: Vector3 = room.storage.bays[0].global_position
	var ray := PhysicsRayQueryParameters3D.create(shaft_center + Vector3(0, -0.15, 0), shaft_center + Vector3(0, -3, 0), 1)
	var shaft_hit: Dictionary = room.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not shaft_hit.is_empty() and shaft_hit.position.y < -2.0, "Shaft has a real floor opening and a physical bottom below the lowered tray")
	await switch()
	await use("StorageBay0")
	await press("Raise preserved tray", false)
	check(state().storage.bays[0].raised and room.storage.busy[0], "Future computer starts the reverse lift sequence")
	check(room.ui.inspector.controls["Collect raised contents"].option.disabled, "Collection stays disabled while the platform is moving")
	await wait_lift(0)
	check(is_equal_approx(room.storage.lifts[0].position.y, room.storage.TOP), "Preserved equipment is raised to the surface")
	await press("Collect raised contents")
	check(state().storage.future_hand == "v09", "Wrong equipment survives in Future exactly like a replacement")
	await use("Archive")
	await press("Install " + Rules.Storage.PARTS.reader)
	check(state().storage.installed.reader.is_empty() and state().storage.future_hand == "v09", "Wrong component stays in hand after the Professor reports the mismatch")
	await use("StorageBay0")
	await press("Return and lower contents")
	await switch()
	await use("StorageBay0")
	await press("Raise loading tray")
	await press("Remove stored object")
	room.ui.close_modal()
	quiet()
	var drop_event := InputEventKey.new()
	drop_event.pressed = true
	drop_event.physical_keycode = KEY_E
	Input.parse_input_event(drop_event)
	await tick(3)
	check(state().storage.floor_items.has("v09") and state().storage.past_hand.is_empty(), "E puts the returned object back on the storage-room floor")
	for index in 3:
		var item: String = ["r17", "k04", "m22"][index]
		await pickup(item)
		await use("StorageBay%d" % index)
		await press("Place carried object")
		check(room.storage.screens[index].text == ["4.8 kg", "2.6 kg", "7.2 kg"][index], "Past screen only reports the measured shipping weight")
		await press("Lower and store tray")
		await switch()
		await use("StorageBay%d" % index)
		check(room.storage.screens[index].text == "OCCUPIED", "Future sees preserved contents as soon as one bay is sealed")
		await press("Raise preserved tray")
		await press("Collect raised contents")
		await use("Archive")
		await press("Install " + Rules.Storage.PARTS[["reader", "regulator", "memory"][index]])
		if index < 2: await switch()
	check(Rules.Storage.repaired(state()), "Three physical socket installations restore the archive")
	await use("Archive")
	check(state().archive_read, "Archive acquisition is confirmed through the actual interaction")
	await use("Recorder")
	await press("Pull backup cell")
	check(state().recording == "erased" and not Rules.has_power(state(), "past"), "Cell extraction changes evidence and interrupts the Past feed")
	check(not room.get_node("Layout/Shared/RecorderStand/Cell").visible, "Extracted recorder cell disappears from the actual machine")
	check(indicator("Shared/PowerRoutes/PastFeed/Current0/Mesh") == Color("c96a53") and indicator("Shared/PowerRoutes/FutureFeed/Current0/Mesh") == Color("76c9b3"), "The affected circuit shows a fault while the other side remains powered")
	await use("Release")
	await press("Turn manual release")
	check(state().future_release_open and not state().core_authorized, "Extracted battery opens the Professor's gate early")
	await use("BypassFuture")
	await press("Reconnect ground lead")
	await switch()
	check("identity" in room._pending_lines or room.director.get_current_sequence_id() == "maintenance.identity", "Solo role switching retains an unseen identity conversation for the other role")
	await use("BypassPast")
	await press("Seat replacement fuse")
	check(Rules.has_power(state(), "past"), "The Student can recover the disconnected auxiliary feed")
	check(indicator("Shared/PowerRoutes/PastFeed/Current0/Mesh") == Color("76c9b3") and indicator("Shared/PowerRoutes/Bypass/Current0/Mesh") == Color("76c9b3"), "Both repaired bypass ends visibly restore the shared route")
	await use("Keypad")
	room.ui.inspector.set_entry("3142")
	await press("Authorize service entrance")
	check(state().core_authorized, "The real code input opens the Student gate")
	await use("Anchor")
	await press("Latch stabilization contact")
	await switch()
	await use("Anchor")
	await press("Latch stabilization contact")
	check(puzzles.is_solved(Rules.ID) and room.ending_screen.visible, "Both anchors display the completed chapter")
	check(indicator("Shared/CoreMachine/PylonCurrent1/Mesh") == Color("76c9b3"), "The physical Core indicates confirmed stabilization")
	check("BUFFER ERASED" in room._audit_text() and "Operator: THE PROFESSOR" not in room._audit_text(), "Destroyed evidence changes the actual ending")
	check(puzzles.get_session_id() == session and puzzles.get_state(Frequency.ID) == original_frequency, "All role changes retain session and Level 01 radio state")
	var saved := state()
	room.queue_free()
	await tick(2)
	room = load(Rules.DESTINATION).instantiate()
	room.pause_when_unfocused = false
	root.add_child(room)
	current_scene = room
	await tick(5)
	check(state() == saved and room.ending_screen.visible, "Reload restores collision, choices and completion without resetting the session")
	check(not room.get_node("Layout/Shared/RecorderStand/Cell").visible and indicator("Shared/PowerRoutes/Bypass/Current0/Mesh") == Color("76c9b3"), "Reload restores visible evidence removal and repaired circuit state")
	room.queue_free()
	await tick(3)
	# Verify the actual laboratory exit uses the new destination and retains the frequency.
	puzzles.begin_session()
	puzzles.submit_action(Frequency.ID, "acquire_radio", {"radio_role":"past"}, "past")
	puzzles.submit_action(Frequency.ID, "acquire_radio", {"radio_role":"future"}, "future")
	puzzles.submit_action(Frequency.ID, "tune_frequency", {"frequency":67}, "past")
	puzzles.submit_action(Frequency.ID, "tune_amplitude", {"amplitude": 70}, "past")
	puzzles.offline_role = "past"
	var lab = load("res://scenes/world/spawn_area.tscn").instantiate()
	lab.pause_when_unfocused = false
	root.add_child(lab)
	current_scene = lab
	await tick(8)
	lab.gameplay.close_overlays()
	lab.gameplay.get_node("StudentDiscovery").enabled = false
	lab.player.position = Vector3(6.2,0,-6.4)
	Input.action_press("move_up")
	await tick(75)
	Input.action_release("move_up")
	await tick(15)
	var deadline := Time.get_ticks_msec() + 8000
	while root.get_node("GameFlowManager").is_transitioning() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not root.get_node("GameFlowManager").is_transitioning(), "The laboratory transition completes its fade and releases input")
	check(is_instance_valid(current_scene) and current_scene.scene_file_path == Rules.DESTINATION, "Walking through the real laboratory door loads Level 02")
	check(puzzles.is_solved(Frequency.ID) and current_scene.radio.owns_radio, "Actual room travel preserves the established link")
	current_scene.queue_free()
	await tick(4)
	print("MAINTENANCE SCENE: %s (%d checks; %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
