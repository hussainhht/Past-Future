extends RefCounted
## Level 2 - Maintenance Corridor (actual implementation: SERVICE isolate, emergency cell, preservation vaults,
## archive repair, bypass, recorder export, code 3142, manual release, anchor).

const Rules2 := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const PART_OF := {"r17": "Install Optical archive reader", "k04": "Install Voltage regulator", "m22": "Install Shielded memory module"}
const BAY_ITEMS := ["r17", "k04", "m22"]
var ap


func st() -> Dictionary:
	return PuzzleManager.get_state(Rules2.ID)


func insp() -> Node:
	return ap.scene().ui.inspector


func open_device(device: String) -> bool:
	var target: Node = ap.scene().devices[device]
	if not await ap.use(target):
		return false
	var ok: bool = await ap.wait_for(func() -> bool: return insp().active, 12.0, "device panel " + device)
	await ap.sec(1.6)
	return ok


func click_option(label: String, timeout: float = 40.0) -> bool:
	var i := insp()
	var ok: bool = await ap.wait_for(func() -> bool: return i.active and i.controls.has(label) and not i.controls[label].option.get("disabled", false), timeout, "control enabled: " + label)
	if not ok:
		ap.say("controls available: %s" % str(i.controls.keys()))
		return false
	var visual: Node3D = i.controls[label].visual
	var pos: Vector2 = i.camera.unproject_position(visual.global_position)
	ap.say("CLICK control '%s' at %s" % [label, str(pos)])
	await ap.click(ap.to_window(pos))
	await ap.sec(0.8)
	return true


func close_device() -> void:
	if insp().active:
		await ap.tap(KEY_ESCAPE)
		await ap.wait_for(func() -> bool: return not insp().active, 5.0, "device closed")
		await ap.sec(0.5)


func run(a) -> void:
	ap = a
	ap.say("=== LEVEL 2: MAINTENANCE CORRIDOR (role %s) ===" % ap.local_role())
	await ap.sec(2.0)
	await ap.screenshot("20_level2_start")
	await ap.read_dialogue(60.0)
	var host: bool = ap.role == "host"
	# --- Phase 1: isolate SERVICE (Student), then charge the emergency cell (Professor)
	if host:
		await open_device("Service")
		await ap.screenshot("21_student_service_panel")
		await click_option("Flip SERVICE isolator")
		await ap.wait_for(func() -> bool: return st().service_isolated, 20.0, "service isolated")
		await close_device()
	else:
		await open_device("Battery")
		await ap.screenshot("21_professor_battery_panel")
		await close_device()
		await ap.wait_for(func() -> bool: return st().service_isolated, 120.0, "service isolated by Student")
		await open_device("Battery")
		await click_option("Turn charging crank")
		await close_device()
	await ap.wait_for(func() -> bool: return st().battery_ready, 60.0, "battery ready")
	ap.say("EMERGENCY CELL CHARGED")
	await ap.screenshot("22_battery_ready")
	# --- Phase 2: preservation vaults -> archive repair
	if host:
		for i in 3:
			var item: String = BAY_ITEMS[i]
			var case_t: Node = ap.scene().devices["Case_" + item]
			await ap.wait_for(func() -> bool: return case_t.interaction_enabled, 30.0, "case enabled " + item)
			await ap.use(case_t)
			await ap.wait_for(func() -> bool: return st().storage.past_hand == item, 20.0, "carrying " + item)
			var bay_t: Node = ap.scene().devices["StorageBay%d" % i]
			await ap.use(bay_t)
			await ap.wait_for(func() -> bool: return st().storage.bays[i].item == item, 20.0, "loaded " + item)
			await ap.screenshot("23_student_loaded_bay%d" % i)
			await ap.use(bay_t)
			await ap.wait_for(func() -> bool: return insp().active, 12.0, "bay panel")
			await ap.sec(1.2)
			await click_option("Lower tray and store")
			await ap.wait_for(func() -> bool: return st().storage.bays[i].sealed, 20.0, "bay sealed")
			await ap.sec(2.5)
			await close_device()
	else:
		await open_device("Archive")  # reads the maintenance manifest
		await ap.screenshot("23_professor_archive_manifest")
		await close_device()
		for i in 3:
			var item: String = BAY_ITEMS[i]
			await ap.wait_for(func() -> bool: return st().storage.bays[i].sealed and st().storage.bays[i].item == item, 240.0, "bay %d sealed by Student" % i)
			await ap.sec(3.5)
			await open_device("StorageBay%d" % i)
			await click_option("Raise tray")
			await ap.sec(2.5)
			await click_option("Unload item")
			await ap.wait_for(func() -> bool: return st().storage.future_hand == item, 20.0, "retrieved " + item)
			await close_device()
			await open_device("Archive")
			await click_option(PART_OF[item])
			await ap.wait_for(func() -> bool: return st().storage.installed.values().has(item), 20.0, "installed " + item)
			await close_device()
	await ap.wait_for(func() -> bool: return Rules2.Storage.repaired(st()), 240.0, "archive repaired")
	ap.say("ARCHIVE REPAIRED")
	await ap.screenshot("24_archive_repaired")
	# --- Phase 3: archive record, bypass, recording, code, release, anchor
	if not host:
		await open_device("Archive")
		await ap.wait_for(func() -> bool: return st().archive_read, 20.0, "archive read")
		await ap.screenshot("25_professor_archive_record")
		await close_device()
		await open_device("BypassFuture")
		await click_option("Reconnect ground lead")
		await close_device()
	else:
		await open_device("BypassPast")
		await click_option("Seat replacement fuse")
		await close_device()
	await ap.wait_for(func() -> bool: return Rules2.bypass_ready(st()) and st().archive_read, 240.0, "bypass both ends + archive")
	if not host:
		await open_device("Recorder")
		await ap.screenshot("26_professor_recorder")
		await click_option("Press recording export")
		await close_device()
	await ap.wait_for(func() -> bool: return st().recording != "pending", 120.0, "recording resolved")
	ap.say("RECORDING: %s" % st().recording)
	if host:
		await open_device("Keypad")
		await ap.screenshot("27_student_keypad")
		for d in "3142":
			await click_option(d, 10.0)
		await ap.sec(0.8)
		await ap.screenshot("27_student_code_entered")
		await click_option("Authorize service entrance")
		await ap.wait_for(func() -> bool: return st().core_authorized, 20.0, "core authorized")
		await close_device()
	else:
		await ap.wait_for(func() -> bool: return st().core_authorized, 240.0, "core authorized by Student")
		await open_device("Release")
		await click_option("Turn manual release")
		await ap.wait_for(func() -> bool: return st().future_release_open, 20.0, "release open")
		await close_device()
	await ap.wait_for(func() -> bool: return st().core_authorized and st().future_release_open, 240.0, "core entrance open")
	ap.say("CORE ENTRANCE OPEN")
	await ap.screenshot("28_core_entrance_open")
	await open_device("Anchor")
	await click_option("Latch stabilization contact")
	await close_device()
	await ap.wait_for(func() -> bool: return st().anchor_past and st().anchor_future, 240.0, "anchors latched")
	ap.say("LEVEL 2 PUZZLE SOLVED")
	await ap.screenshot("29_level2_solved")
	# The chapter-complete panel: dismiss it, then the host continues with the game's own pause-menu navigation
	# (Level 2 has no wired exit; room_02.tres next_room_id is empty).
	await ap.wait_for(func() -> bool: return ap.button_by_text("INSPECT THE STABILIZED CORE") != null, 30.0, "chapter complete panel")
	await ap.sec(7.0)
	await ap.screenshot("29b_chapter_complete_panel")
	var inspect_btn: BaseButton = ap.button_by_text("INSPECT THE STABILIZED CORE")
	if inspect_btn:
		await ap.click_control(inspect_btn)
	await ap.sec(1.5)
	await ap.read_dialogue(40.0)
	await ap.sec(1.5)
	if host:
		await ap.tap(KEY_ESCAPE)
		await ap.wait_for(func() -> bool: return ap.button_by_text("SKIP TO LEVEL 3") != null, 10.0, "pause menu")
		await ap.sec(1.5)
		await ap.screenshot("30_pause_menu_skip_to_level3")
		await ap.click_control(ap.button_by_text("SKIP TO LEVEL 3"))
	await ap.until(func() -> bool: return GameFlowManager.get_current_room_id() == "room_03", 120.0, "arrive room_03")
