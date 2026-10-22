extends RefCounted

const FreqRules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
var ap


func run(a) -> void:
	ap = a
	await ap.sec(2.0)
	await menu()
	await ap.sec(4.0)
	await level1()
	await level2()
	var l3 = load("res://tools/recording/ap_level3.gd").new()
	await l3.run(ap)
	await ap.sec(float(ap.args.get("linger", "5")))


func type_text(text: String) -> void:
	for ch in text:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = ch.unicode_at(0)
		e.keycode = ch.unicode_at(0) if ch != "." else KEY_PERIOD
		e.physical_keycode = e.keycode
		Input.parse_input_event(e)
		await ap.sec(0.05)
		e = e.duplicate()
		e.pressed = false
		Input.parse_input_event(e)
		await ap.sec(0.05)


func menu() -> void:
	await ap.screenshot("01_menu_title")
	await ap.sec(1.5)
	await ap.click_control(ap.button_by_text("PLAY"))
	await ap.sec(1.2)
	if ap.role == "host":
		await ap.click_control(ap.button_by_text("HOST"))
		await ap.sec(1.0)
		await ap.screenshot("02_host_waiting")
		await ap.until(func() -> bool: return NetworkManager.state == NetworkManager.State.CONNECTED, 180.0, "professor to join")
		await ap.sec(1.0)
		await ap.until(func() -> bool: return NetworkManager.guest_ready, 180.0, "professor ready")
		await ap.sec(1.5)
		await ap.screenshot("03_host_both_ready")
		await ap.click_control(ap.button_by_text("START"))
	else:
		await ap.sec(3.0)
		await ap.click_control(ap.button_by_text("JOIN"))
		await ap.sec(1.0)
		var field: LineEdit = ap.scene().get_node("%HostAddress")
		await ap.click(ap.to_window(field.get_global_rect().get_center()))
		field.text = ""
		await type_text("127.0.0.1")
		await ap.screenshot("02_client_join_address")
		await ap.click_control(ap.button_by_text("JOIN GAME"))
		await ap.until(func() -> bool: return NetworkManager.state == NetworkManager.State.CONNECTED, 20.0, "connected")
		await ap.sec(1.0)
		await ap.click_control(ap.button_by_text("READY"))
		await ap.screenshot("03_client_ready")
	await ap.until(func() -> bool: return NetworkManager.in_game, 30.0, "game started")


# ------------------------------------------------------------------ helpers

func room_id() -> String:
	return GameFlowManager.get_current_room_id()


func settle() -> void:
	## Wait for cinematic title cards / transitions / dialogue / first-time popups to finish.
	await ap.until(func() -> bool: return not GameFlowManager.is_transitioning() and not CinematicTransitionManager.is_playing(), 30.0, "transition done")
	await ap.sec(0.5)


func close_modal() -> void:
	await ap.tap(KEY_ESCAPE)
	await ap.sec(0.4)


func gameplay_open() -> bool:
	var room: Node = ap.scene()
	return room.get("gameplay") != null


func use_named(needle: String, timeout: float = 30.0) -> bool:
	var i: Node = ap.find_int(needle)
	if i == null:
		ap.say("use_named: no usable interactable matching '%s'" % needle)
		return false
	return await ap.use(i)


func exit_room(next_room: String) -> void:
	var exit_i: Node = ap.find_int("LevelExit")
	if exit_i == null:
		ap.say("no LevelExit found")
		return
	# Walk onto the exit zone itself (through the opened door); the zone is also usable with F.
	var a: Vector3 = exit_i.get_interaction_position()
	await ap.walk_to(Vector3(a.x, 0, a.z), 0.3, 40.0)
	await ap.sec(0.6)
	if ap.current_target_of_player() == exit_i:
		await ap.press_f()
	ap.say("at exit zone (target=%s); waiting for partner / transition" % str(ap.current_target_of_player()))
	await ap.until(func() -> bool: return room_id() == next_room and not GameFlowManager.is_transitioning(), 150.0, "arrive " + next_room)


# ------------------------------------------------------------------ LEVEL 1

func level1() -> void:
	ap.say("=== LEVEL 1: SIGNAL LABORATORY (role %s) ===" % ap.local_role())
	await settle()
	await ap.screenshot("10_level1_start")
	ap.dump_interactables()
	var room: Node = ap.scene()
	var radio_name := "PastRadio" if ap.role == "host" else "FutureRadio"
	# documents give story context
	if ap.role == "host":
		await use_named("LabMemo")
		await ap.sec(2.5)
		await ap.screenshot("11_student_memo")
		await close_modal()
		await use_named("ResearchNotebook")
		await ap.sec(2.5)
		await ap.screenshot("12_student_notebook")
		await close_modal()
	await use_named(radio_name)
	await ap.sec(1.0)
	await ap.read_dialogue(30.0)
	await ap.until(func() -> bool: return FreqRules.radios_ready(PuzzleManager.get_state(FreqRules.ID)), 120.0, "both radios acquired")
	await ap.screenshot("13_radios_acquired")
	if ap.role == "client":
		await use_named("RecoveredLog")
		await ap.sec(1.0)
		await ap.screenshot("14_professor_receiver")
	else:
		await use_named("Computer")
		var devices: Node = room.gameplay.physical_devices
		var insp: Node = devices.inspector
		await ap.until(func() -> bool: return insp.active, 10.0, "inspector open")
		await ap.sec(2.0)
		await ap.screenshot("14_student_dials")
		await tune_dials(insp)
	await ap.until(func() -> bool: return FreqRules.link_established(PuzzleManager.get_state(FreqRules.ID)), 180.0, "radio link established")
	ap.say("RADIO LINK ESTABLISHED")
	await ap.sec(1.0)
	await ap.screenshot("15_link_established")
	await close_modal()
	await ap.read_dialogue(60.0)
	await ap.sec(1.0)
	await exit_room("room_02")


func tune_dials(insp: Node) -> void:
	var cam: Camera3D = insp.camera
	# select the tuning dial with a real mouse click on the knob, then turn it with the arrow keys
	var knob_pos: Vector2 = cam.unproject_position(insp._dial_knob.global_position)
	await ap.click(ap.to_window(knob_pos))
	for n in 1:
		await ap.tap(KEY_UP, 0.05, true)
		await ap.sec(0.15)
	for n in 7:
		await ap.tap(KEY_UP, 0.05)
		await ap.sec(0.15)
	ap.say("frequency dial now %s" % insp.entry)
	var amp_pos: Vector2 = cam.unproject_position(insp._amplitude_knob.global_position)
	await ap.click(ap.to_window(amp_pos))
	for n in 3:
		await ap.tap(KEY_UP, 0.05, true)
		await ap.sec(0.15)
	for n in 5:
		await ap.tap(KEY_UP, 0.05)
		await ap.sec(0.15)
	ap.say("amplitude dial now %s" % insp.amplitude)


# ------------------------------------------------------------------ LEVEL 2

func level2() -> void:
	await settle()
	var l2 = load("res://tools/recording/ap_level2.gd").new()
	await l2.run(ap)
