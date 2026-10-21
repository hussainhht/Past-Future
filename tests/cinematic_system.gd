extends SceneTree
## Room introduction checks on the real rooms. Needs a renderer (see run_cinematic_tests.py).
## CINEMA_DIR chooses where screenshots go. Prints "CINEMATIC: PASS" when every check holds.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const FREQ := "puzzle_01_frequency"

var flow: Node
var puzzles: Node
var cinema: Node
var checks: int = 0
var failures: int = 0
var directory: String = ""
var started: Array = []
var finished: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)


func tick(frames: int = 4) -> void:
	for i in range(frames):
		await process_frame


func wait_until(predicate: Callable, message: String, seconds: float = 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not directory.is_empty():
		image.save_png(directory.path_join(label + ".png"))
	return image


func mean_color(image: Image, rect: Rect2i) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for y in range(rect.position.y, rect.end.y, 4):
		for x in range(rect.position.x, rect.end.x, 4):
			total += image.get_pixel(x, y)
			count += 1
	return total / maxf(count, 1)


func _run() -> void:
	flow = root.get_node("GameFlowManager")
	puzzles = root.get_node("PuzzleManager")
	cinema = root.get_node("CinematicTransitionManager")
	puzzles.log_rejections = false
	directory = OS.get_environment("CINEMA_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	cinema.intro_started.connect(func(room: String, side: String) -> void: started.append([room, side]))
	cinema.intro_finished.connect(func(room: String, completed: bool) -> void: finished.append([room, completed]))

	# --- Data ---
	check(cinema.has_intro("room_01") and cinema.has_intro("room_02") and cinema.has_intro("room_03"), "Rooms 01 to 03 have introductions")
	check(cinema.get_intro("room_03").room_title == "TEMPORAL CORE", "Room 03 title")
	for preset in ["past_memory", "future_signal", "neutral", "finale"]:
		check(cinema.get_style(preset).preset_id == preset, "Preset %s loads" % preset)
	check(not cinema.show_room_intro("missing_room"), "An unknown room plays nothing")
	var bad := RoomIntroData.new()
	check(not cinema.register_intro(bad), "An empty intro is rejected")

	# --- Real room entry (Past) ---
	puzzles.offline_role = "past"
	puzzles.begin_session()
	cinema.reduced_motion_override = false
	check(flow.start_room("room_01"), "Room 01 starts")
	await wait_until(func() -> bool: return cinema.is_playing(), "Entering Room 01 starts the introduction")
	check(started.size() == 1 and started[0] == ["room_01", "past"], "One Past introduction for Room 01: %s" % [started])
	var lab := current_scene
	lab.pause_when_unfocused = false
	lab._set_paused(false)
	check(not flow.is_input_locked(), "The introduction does not lock input")
	await create_timer(0.45).timeout
	await shot("past_a_chapter")
	await create_timer(0.5).timeout
	await shot("past_b_title")
	await create_timer(0.6).timeout
	var past_hold := await shot("past_c_hold")
	await create_timer(1.1).timeout
	await shot("past_d_fadeout")
	await wait_until(func() -> bool: return not cinema.is_playing(), "The introduction ends")
	check(finished.size() == 1 and finished[0][1] == true, "It completed")
	check(cinema.get_child_count() == 0, "The overlay freed itself")
	check(not cinema.show_room_intro("room_01"), "The same room entry does not replay")
	await tick(10)
	check(started.size() == 1, "No unexpected replay after the animation")
	check(lab.player != null and lab.player.has_method("is_action_active"), "The player exists")

	# --- Journal pause: the intro waits for it ---
	var journal := root.get_node("JournalManager")
	check(not journal.is_open(), "Journal closed")

	# --- Real transition Room 01 -> Room 02 ---
	flow.fade_out_seconds = 0.2
	flow.fade_in_seconds = 0.2
	for radio_role in ["past", "future"]:
		puzzles.submit_action(FREQ, "acquire_radio", {"radio_role": radio_role}, radio_role)
	puzzles.submit_action(FREQ, "tune_frequency", {"frequency": Rules.DEFAULT_FREQUENCY}, "past")
	await tick(6)
	check(flow.begin_transition("room_02") == "", "The transition to Room 02 starts")
	await wait_until(func() -> bool: return flow.get_current_room_id() == "room_02" and not flow.is_transitioning(), "Room 02 is entered", 15.0)
	await wait_until(func() -> bool: return cinema.is_playing(), "Room 02 introduces itself after the fade")
	check(started.size() == 2 and started[1] == ["room_02", "past"], "Room 02 introduction: %s" % [started])
	check(not flow.is_input_locked(), "Input is free during the Room 02 introduction")
	await create_timer(1.6).timeout
	await shot("room02_past_hold")
	await wait_until(func() -> bool: return not cinema.is_playing(), "Room 02 introduction ends")

	# --- Future theme, explicit timeline, forced replay ---
	puzzles.offline_role = "future"
	check(cinema.show_room_intro("room_02", "", true), "A forced replay starts for the Future role")
	check(started.back() == ["room_02", "future"], "The local role picks the Future style")
	var times := [0.3, 0.6, 0.8, 1.6]
	var spent := 0.0
	for t in times:
		await create_timer(t - spent).timeout
		spent = t
		await shot("future_%03d" % int(t * 100))
	await wait_until(func() -> bool: return not cinema.is_playing(), "The Future introduction ends")

	# --- Long title, finale preset and Room 03 ---
	var long_data := RoomIntroData.new()
	long_data.room_id = "room_long"
	long_data.room_title = "SUBBASEMENT TEMPORAL STABILISATION CORE CHAMBER"
	long_data.chapter_title = "THE FIRST FRACTURE"
	long_data.location_index = 4
	check(cinema.register_intro(long_data), "A runtime intro registers")
	check(cinema.show_room_intro("room_long", "past", true), "The long title plays")
	await create_timer(1.8).timeout
	await shot("long_title_past")
	cinema.dismiss()
	await wait_until(func() -> bool: return not cinema.is_playing(), "Dismiss ends the introduction")
	check(finished.back()[1] == false, "A dismissed introduction reports it was not completed")
	var core: RoomIntroData = cinema.get_intro("room_03")
	core.past_preset = &"finale"
	check(cinema.show_room_intro("room_03", "past", true), "Room 03 plays with the finale preset")
	await create_timer(1.9).timeout
	await shot("room03_finale")
	await wait_until(func() -> bool: return not cinema.is_playing(), "The finale introduction ends", 8.0)
	core.past_preset = &"past_memory"

	# --- Reduced motion ---
	cinema.reduced_motion_override = true
	check(cinema.show_room_intro("room_03", "future", true), "Reduced motion plays")
	await create_timer(1.2).timeout
	var reduced := await shot("reduced_future")
	await wait_until(func() -> bool: return not cinema.is_playing(), "Reduced introduction ends")
	cinema.reduced_motion_override = null

	# --- Resolutions (Future title card at the end of the title reveal) ---
	cinema.reduced_motion_override = false
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		await tick(4)
		puzzles.offline_role = "past"
		check(cinema.show_room_intro("room_01", "past", true), "Plays at %s" % [size])
		await create_timer(1.7).timeout
		await shot("res_%dx%d_past" % [size.x, size.y])
		cinema.dismiss()
		await wait_until(func() -> bool: return not cinema.is_playing(), "Ends at %s" % [size])
		check(cinema.show_room_intro("room_03", "future", true), "Plays Future at %s" % [size])
		await create_timer(1.7).timeout
		await shot("res_%dx%d_future" % [size.x, size.y])
		cinema.dismiss()
		await wait_until(func() -> bool: return not cinema.is_playing(), "Ends at %s" % [size])

	# --- Entry the way the menu does it: change_scene, then the room attaches itself ---
	root.size = Vector2i(1280, 720)
	cinema.reset_history()
	var before := started.size()
	puzzles.offline_role = "future"
	change_scene_to_file("res://scenes/world/spawn_area.tscn")
	await wait_until(func() -> bool: return cinema.is_playing(), "A scene entered with change_scene introduces itself")
	check(started.size() == before + 1 and started.back() == ["room_01", "future"], "Menu-style entry plays the Future card: %s" % [started.back()])
	await shot("menu_entry_future")
	await wait_until(func() -> bool: return not cinema.is_playing(), "Menu-style introduction ends", 6.0)
	check(not flow.is_input_locked(), "Input is free after the introduction")

	check(past_hold.get_width() > 0 and reduced.get_width() > 0, "Frames captured")

	print("CINEMATIC checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("CINEMATIC: PASS")
	quit(1 if failures > 0 else 0)
