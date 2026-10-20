extends SceneTree
## Rendered smoke test for the transition visuals; needs a real renderer (see run_game_flow_render.py).
## It reads back actual frames to prove the fade darkens the room, the black screen carries the loading
## text, the readiness panel and notices appear, and the screen is clear again afterwards.
## FLOW_RENDER_DIR chooses where the screenshots go.

const RoomDef := preload("res://scripts/game_flow/room_definition.gd")
const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const FREQ := "puzzle_01_frequency"

var flow: Node
var puzzles: Node
var checks: int = 0
var failures: int = 0
var directory: String = ""


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)


func wait_for(predicate: Callable, message: String, seconds: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func tick(frames: int = 4) -> void:
	for i in range(frames):
		await physics_frame
	await process_frame


## The whole frame as the player sees it, saved as a PNG.
func shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not directory.is_empty():
		image.save_png(directory.path_join(label + ".png"))
	return image


func luminance(image: Image) -> float:
	var small := image.duplicate() as Image
	small.resize(64, 36, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	for y in range(36):
		for x in range(64):
			var c := small.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return total / (64.0 * 36.0)


func brightest(image: Image, region: Rect2i) -> float:
	var crop := image.get_region(region)
	var best := 0.0
	for y in range(crop.get_height()):
		for x in range(crop.get_width()):
			var c := crop.get_pixel(x, y)
			best = maxf(best, 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	return best


func difference(a: Image, b: Image, region: Rect2i) -> float:
	var ca := a.get_region(region)
	var cb := b.get_region(region)
	var total := 0.0
	for y in range(0, ca.get_height(), 2):
		for x in range(0, ca.get_width(), 2):
			total += absf(ca.get_pixel(x, y).get_luminance() - cb.get_pixel(x, y).get_luminance())
	return total / (ca.get_width() * ca.get_height() / 4.0)


func _run() -> void:
	flow = root.get_node("GameFlowManager")
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	flow.log_problems = false
	directory = OS.get_environment("FLOW_RENDER_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	flow.load_room_directory("res://resources/levels/test")
	puzzles.offline_role = "past"
	puzzles.begin_session()
	check(flow.start_room("test_room_a"), "Test Room A starts")
	await tick(8)
	current_scene.dev_establish_link()
	await tick(6)
	var idle := await shot("01_room_a_idle")
	# Regions come from the captured image, which is the window size, not the 1600 x 900 canvas.
	var size := Vector2(idle.get_size())
	var scale := size.x / 1600.0
	var center := Rect2i(int(size.x * 0.5) - 260, int(size.y * 0.5) - 70, 520, 140)
	var panel := Rect2i(int(size.x) - int(318 * scale), int(318 * scale), int(296 * scale), int(100 * scale))
	var notice_area := Rect2i(int(size.x) - int(318 * scale), int(318 * scale), int(296 * scale), int(60 * scale))
	var idle_luminance := luminance(idle)
	check(idle_luminance > 0.03, "Room A is visible, not black (%.3f)" % idle_luminance)

	# Fade out: sample the frame half way down.
	flow.fade_out_seconds = 1.2
	flow.fade_in_seconds = 1.2
	check(flow.request_transition("test_room_b") == "", "The transition starts")
	await wait_for(func() -> bool: return flow.overlay.fade.modulate.a > 0.45, "The fade never reached half")
	var mid_out := await shot("02_fade_out_half")
	check(luminance(mid_out) < idle_luminance * 0.85, "Half way through the fade-out the frame is darker (%.3f vs %.3f)" % [luminance(mid_out), idle_luminance])
	check(flow.overlay.is_covering() and flow.is_input_locked(), "The overlay covers and input is locked")
	await wait_for(func() -> bool: return flow.overlay.is_fully_black(), "The screen never went fully black")
	var black := await shot("03_black_loading")
	check(luminance(black) < 0.05, "The black screen is black (%.3f)" % luminance(black))
	check(brightest(black, center) > 0.15, "The loading text is drawn on the black screen")

	# Fade in on the new room.
	await wait_for(func() -> bool: return flow.get_phase() == flow.Phase.FADING_IN and flow.overlay.fade.modulate.a < 0.55, "The fade-in never reached half")
	var mid_in := await shot("04_fade_in_half")
	check(luminance(mid_in) > luminance(black) and luminance(mid_in) < 0.9, "Half way through the fade-in the room is partly revealed")
	await wait_for(func() -> bool: return not flow.is_transitioning(), "The transition never finished", 15.0)
	await tick(4)
	var room_b := await shot("05_room_b")
	check(luminance(room_b) > 0.03 and not flow.overlay.is_covering(), "Room B is visible and the cover is gone (%.3f)" % luminance(room_b))
	check(flow.get_current_room_id() == "test_room_b" and current_scene.player.controls_enabled, "The players are in Room B and can move")

	# The readiness panel and notices, over a live room.
	flow.overlay.show_readiness("Signal Laboratory", true, false)
	await tick(2)
	var waiting := await shot("06_ready_waiting")
	check(difference(waiting, room_b, panel) > 0.01, "The readiness panel changes the frame where it should")
	flow.overlay.show_departing()
	await tick(2)
	await shot("07_both_ready")
	flow.overlay.hide_readiness()
	flow.overlay.show_notice("Establish the temporal radio link first.", 5.0)
	await tick(2)
	var notice := await shot("08_notice")
	check(difference(notice, room_b, notice_area) > 0.01, "The notice changes the frame in the right-hand column")
	flow.overlay.hide_notice()
	flow.overlay.show_notice("A notice must not outstay its welcome.", 0.5)
	await create_timer(1.4).timeout
	check(not flow.overlay.notice_panel.visible, "A notice disappears after its lifetime")

	# A room that cannot become ready: black with text, then the previous room is restored.
	var stuck := RoomDef.new()
	stuck.room_id = "stuck_room"
	stuck.shared_scene = "res://tests/fixtures/never_ready_room.tscn"
	flow.get_room("test_room_b").allowed_exits = PackedStringArray(["stuck_room"])
	check(flow.register_room(stuck), "The stuck room registers")
	flow.transition_timeout_seconds = 3.0
	flow.fade_out_seconds = 0.3
	flow.fade_in_seconds = 0.6
	check(flow.request_transition("stuck_room") == "", "The stuck transition starts")
	await wait_for(func() -> bool: return flow.get_current_room_id() == "stuck_room", "The stuck room never entered")
	await create_timer(0.8).timeout
	var stuck_shot := await shot("09_waiting_black")
	check(luminance(stuck_shot) < 0.05 and brightest(stuck_shot, center) > 0.15, "While waiting the screen stays black and says so")
	await wait_for(func() -> bool: return flow.get_phase() == flow.Phase.FADING_IN, "The rollback never began fading in", 8.0)
	await wait_for(func() -> bool: return not flow.is_transitioning(), "The rollback never finished", 8.0)
	await tick(4)
	var restored := await shot("10_restored_room_b")
	check(flow.get_current_room_id() == "test_room_b" and luminance(restored) > 0.03 and not flow.overlay.is_covering(), "After the timeout the previous room is back and the screen is clear")

	# The real laboratory with its corridor exit.
	flow.transition_timeout_seconds = 20.0
	flow.fade_out_seconds = 0.2
	flow.fade_in_seconds = 0.2
	puzzles.begin_session()
	check(flow.start_room("room_01"), "The laboratory starts")
	await tick(10)
	var lab := current_scene
	lab.pause_when_unfocused = false
	lab._set_paused(false)
	for radio_role in ["past", "future"]:
		puzzles.submit_action(FREQ, "acquire_radio", {"radio_role": radio_role}, radio_role)
	puzzles.submit_action(FREQ, "tune_frequency", {"frequency": Rules.DEFAULT_FREQUENCY}, "past")
	await tick(6)
	for i in range(32):
		if not lab.gameplay.director.is_dialogue_active():
			break
		lab.gameplay.director.skip_typewriter()
		lab.gameplay.director.advance_dialogue()
		await process_frame
	await create_timer(2.6).timeout  # the door finishes opening
	var exit: Area3D = lab.gameplay.get_node("Props/LevelExit")
	lab.player.global_position = exit.global_position
	lab.get_node("CameraRig").snap_to_target()
	await tick(8)
	await create_timer(0.4).timeout
	var lab_exit := await shot("11_lab_exit_prompt")
	check(lab.gameplay.controller.get_current_interactable() == exit, "The lab's corridor exit is selected")
	check(luminance(lab_exit) > 0.02, "The laboratory is visible")
	flow.overlay.show_readiness("Maintenance Corridor", false, true)
	await tick(2)
	await shot("12_lab_ready_panel")
	flow.overlay.hide_readiness()
	lab.free()
	await process_frame
	print("GAME FLOW RENDER: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
