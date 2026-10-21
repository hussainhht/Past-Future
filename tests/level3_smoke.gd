extends SceneTree
## Brief final integration check. No long suite or network setup.
const Rules := preload("res://scripts/level3/core_rules.gd")
var failures := 0
var room: Node3D


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("LEVEL3 SMOKE: " + label)


func tick() -> void:
	for i in 4: await physics_frame
	await process_frame


func use(station: String, caption: String) -> void:
	room._close()
	room.player.position = room.worlds[room.role].position + Rules.STATIONS[station] + Vector3(0, 0, 0.8)
	room.camera_rig.snap_to_target()
	await tick()
	room.operate(station)
	check(room.devices.inspector.active, "inspection opens: " + station)
	check(room.devices.inspector.press_control(caption), "control works: " + caption)
	await tick()
	if station == "coil_0" and "--render-review" in OS.get_cmdline_user_args():
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/assets/screenshots/level3/integrated_coil.png")


func run() -> void:
	create_timer(20).timeout.connect(func() -> void: push_error("LEVEL3 SMOKE: watchdog"); quit(1))
	root.get_node("GameFlowManager").start_room("room_03")
	await tick()
	room = current_scene
	room.player.set_physics_process(false)
	var pm: Node = root.get_node("PuzzleManager")
	check(room.reactor_bridge.modules.size() == 2, "completed visual module mounts in both timelines")
	check(not room.worlds.past.core.visible and not room.worlds.past.rings[0].visible, "stock reactor assembly hidden")
	check(not room.reactor_bridge.modules.future.is_processing(), "inactive reactor is culled")
	check(room.reactor_bridge.modules.past.reactor_phase == "discovery", "confirmed discovery maps to visual API")
	await use("start", "ARM REACTOR...")
	check(room.state.stage == "DISCOVERY", "arming still requires confirmation")
	room.ui.modal_box.find_children("*", "Button", true, false)[1].pressed.emit()
	await tick()
	check(room.reactor_bridge.modules.past.reactor_phase == "armed", "arming drives completed visual API")
	await use("coil_0", "SET POSITION 2")
	check(room.state.coils[0] == 2 and room.reactor_bridge.modules.past.reactor_phase == "power", "physical selection and power phase agree")
	room._close()
	room.switch_debug_role()
	room.player.set_physics_process(false)
	await tick()
	check(room.reactor_bridge.modules.future.is_processing() and not room.reactor_bridge.modules.past.is_processing(), "role switch selects correct reactor")
	await use("receiver", "RECONNECT BATTERY")
	check(room.state.receiver and room.devices.readouts["future/receiver"].text == "CONNECTED", "Professor battery action is real")
	room._close()
	# Exercise adapter events only with an isolated local snapshot; this does
	# not submit or mutate any canonical gameplay state.
	var sample: Dictionary = room.state.duplicate(true)
	sample.stage = "OVERLOAD"
	room.reactor_bridge.apply_state(sample)
	check(room.reactor_bridge.modules.future.reactor_phase == "overload", "overload event reaches module")
	sample.stage = "ENDING"
	sample.ending = "trust"
	room.reactor_bridge.apply_state(sample)
	check(room.reactor_bridge.modules.future.ending_id == "trust", "ending ID reaches module")
	sample.stage = "DISCOVERY"
	sample.attempt += 1
	sample.ending = ""
	room.reactor_bridge.apply_state(sample)
	check(room.reactor_bridge.modules.future.reactor_phase == "discovery" and room.reactor_bridge.modules.future.ending_id == "", "retry clears presentation outcome")
	room.reactor_bridge.apply_state(room.state)
	if "--render-review" in OS.get_cmdline_user_args():
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/assets/screenshots/level3/integrated_reactor_future.png")
	room.queue_free()
	await tick()
	print("LEVEL3 SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
