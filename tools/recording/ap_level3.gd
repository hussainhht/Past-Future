extends RefCounted
## Level 3 - The Final Fracture. TRUST ending: Student = GROUND THE CORE, Professor = RELEASE THE ECHO.

const Rules3 := preload("res://scripts/level3/core_rules.gd")
var ap


func st() -> Dictionary:
	return PuzzleManager.get_state(Rules3.ID)


func room() -> Node:
	return ap.scene()


func insp() -> Node:
	return room().devices.inspector


func station(id: String) -> Node:
	return room().worlds[ap.local_role()].stations[id]


func wait_ui_button(text: String, timeout: float = 10.0) -> Button:
	await ap.wait_for(func() -> bool: return ap.button_by_text(text) != null, timeout, "ui button " + text)
	return ap.button_by_text(text)


func press_ui_button(text: String) -> bool:
	var b: Button = await wait_ui_button(text)
	if b == null:
		return false
	ap.say("CLICK ui button '%s'" % b.text)
	await ap.sec(0.4)
	await ap.click_control(b)
	await ap.sec(0.4)
	return true


## Opens a station's inspection. Documents show a modal panel; devices open the physical inspector.
func operate(id: String, dwell: float = 0.5) -> bool:
	var s: Node = station(id)
	if not await ap.use(s, 0.15):
		return false
	await ap.sec(dwell)
	return true


func read_document(id: String, shot: String = "") -> void:
	await operate(id)
	await ap.wait_for(func() -> bool: return room().ui.visible_modal, 8.0, "document modal " + id)
	await ap.sec(3.0)
	if shot != "":
		await ap.screenshot(shot)
	await ap.sec(1.5)
	await press_ui_button("CLOSE")
	await ap.sec(0.5)


func click_control(label: String, timeout: float = 20.0) -> bool:
	var i := insp()
	var ok: bool = await ap.wait_for(func() -> bool: return i.active and i.controls.has(label) and not i.controls[label].option.get("disabled", false), timeout, "control enabled: " + label)
	if not ok:
		ap.say("controls available: %s" % str(i.controls.keys()))
		return false
	var visual: Node3D = i.controls[label].visual
	var pos: Vector2 = i.camera.unproject_position(visual.global_position)
	ap.say("CLICK control '%s' at %s" % [label, str(pos)])
	await ap.click(ap.to_window(pos))
	await ap.sec(0.5)
	return true


func close_device() -> void:
	if insp().active:
		await ap.tap(KEY_ESCAPE)
		await ap.wait_for(func() -> bool: return not insp().active, 5.0, "device closed")
		await ap.sec(0.3)


func run(a) -> void:
	ap = a
	var host: bool = ap.role == "host"
	ap.say("=== LEVEL 3: THE FINAL FRACTURE (role %s) ===" % ap.local_role())
	await ap.until(func() -> bool: return GameFlowManager.get_current_room_id() == "room_03" and not GameFlowManager.is_transitioning() and not st().is_empty() and not CinematicTransitionManager.is_playing(), 120.0, "room_03 ready")
	await ap.sec(3.0)
	await ap.screenshot("30_level3_start")
	await ap.read_dialogue(60.0)
	ap.dump_interactables()
	# ---- Discovery (no clock yet): read the evidence
	if host:
		await read_document("evidence_past", "31_student_authorization")
		await read_document("warning", "32_student_warning")
	else:
		await read_document("evidence_future", "31_professor_continuity")
	await ap.screenshot("33_discovery_done")
	# ---- Arm the reactor (Student), starting the 150-second challenge
	if host:
		await operate("start", 0.8)
		await ap.wait_for(func() -> bool: return insp().active, 8.0, "arming console")
		await ap.sec(1.2)
		await ap.screenshot("34_arming_console")
		await click_control("ARM REACTOR...")
		await press_ui_button("CONFIRM / ARM")
	await ap.wait_for(func() -> bool: return st().stage != "DISCOVERY", 120.0, "reactor armed")
	var armed_at := Time.get_ticks_msec()
	ap.say("REACTOR ARMED - 150 s challenge running")
	await ap.screenshot("35_reactor_armed")
	ap.sprint_default = true
	# ---- Stage A: coils (Student) / receiver battery (Professor)
	if host:
		for i in 3:
			var target: int = Rules3.COIL_TARGET[i]
			if st().coils[i] == target:
				continue
			await operate("coil_%d" % i, 0.2)
			await click_control("SET POSITION %d" % target)
			await ap.wait_for(func() -> bool: return st().coils[i] == target, 15.0, "coil %d = %d" % [i, target])
			await close_device()
	else:
		await operate("receiver", 0.2)
		await click_control("RECONNECT BATTERY")
		await ap.wait_for(func() -> bool: return st().receiver, 15.0, "receiver repaired")
		await close_device()
	await ap.wait_for(func() -> bool: return st().stage == "STAGE_B", 90.0, "stage B")
	ap.say("STAGE A COMPLETE after %.1fs" % ((Time.get_ticks_msec() - armed_at) / 1000.0))
	await ap.screenshot("36_stage_a_complete")
	# ---- Stage B: anchor (Professor) -> origin (Student) -> phase switches within 5 s
	if host:
		await ap.wait_for(func() -> bool: return st().anchor, 90.0, "anchor calibrated")
		await operate("origin", 0.2)
		await click_control("STABILIZE ORIGIN CORE")
		await ap.wait_for(func() -> bool: return st().origin, 15.0, "origin stable")
		await close_device()
		await operate("sync_past", 0.2)
		await ap.wait_for(func() -> bool: return insp().active, 8.0, "sync device")
		await ap.sec(0.3)
		await click_control("ENGAGE PHASE SWITCH")
	else:
		await operate("anchor", 0.2)
		await click_control("CALIBRATE SIGNAL ANCHOR")
		await ap.wait_for(func() -> bool: return st().anchor, 15.0, "anchor calibrated")
		await close_device()
		await ap.wait_for(func() -> bool: return st().origin, 90.0, "origin stable")
		await operate("sync_future", 0.2)
		await ap.wait_for(func() -> bool: return insp().active, 8.0, "sync device")
		await click_control("ENGAGE PHASE SWITCH")
	await ap.wait_for(func() -> bool: return st().stage == "STAGE_C", 30.0, "stage C (phase sync)")
	ap.say("PHASE SWITCHES SYNCHRONIZED; stage C after %.1fs" % ((Time.get_ticks_msec() - armed_at) / 1000.0))
	await ap.screenshot("37_phase_sync")
	await close_device()
	# ---- Stage C: identity terminals. TRUST ending.
	var command: String = "GROUND THE CORE" if host else "RELEASE THE ECHO"
	await operate("terminal_past" if host else "terminal_future", 0.4)
	await ap.wait_for(func() -> bool: return insp().active, 8.0, "terminal")
	await ap.sec(1.5)
	await ap.screenshot("38_identity_terminal")
	await click_control(command)
	await press_ui_button("CONFIRM / " + command)
	ap.sprint_default = false
	await ap.wait_for(func() -> bool: return st().stage == "ENDING", 60.0, "ending")
	ap.say("ENDING REACHED: %s" % st().ending)
	await ap.sec(3.0)
	await ap.screenshot("40_ending_begins")
	for n in 6:
		await ap.sec(4.0)
		await ap.screenshot("41_ending_%d" % n)
	await ap.sec(float(ap.args.get("end_hold", "8")))
	ap.say("FINAL SCREEN HELD; playthrough complete")
