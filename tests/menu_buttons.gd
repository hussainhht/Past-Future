extends SceneTree
## Verifies the redesigned main-menu buttons: theme wiring, layout hierarchy, hover / press / focus
## states, keyboard and mouse navigation, and that the existing menu connections are untouched.
## Input is pushed through the viewport, so these are real button interactions, not signal emits.

const MAIN_BUTTONS: Array[String] = ["PlayButton", "SettingsButton", "CreditsButton", "QuitButton"]
const WIRED_BUTTONS: Array[String] = [
	"PlayButton", "SettingsButton", "CreditsButton", "QuitButton", "BackButton", "ConfirmQuit",
	"HostButton", "JoinButton", "ConnectButton", "CopyAddress", "ReadyButton", "StartGameButton", "PreviewButton",
]

var failures: int = 0
var checks: int = 0
var menu: Control


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func btn(node_name: String) -> Button:
	return menu.get_node("%" + node_name)


func lit(button: Button, property: String) -> float:
	return float(button.get(property))


func pointer(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)


func mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event)


func click(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	pointer(center)
	await process_frame
	mouse_button(center, true)
	await process_frame
	mouse_button(center, false)
	await process_frame


func tap(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event)
		await process_frame


func _run() -> void:
	print("--- BEGIN MENU BUTTON TESTS ---")
	root.size = Vector2i(1600, 900)
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.settings_path = "user://menu_buttons_test.cfg"
	root.add_child(menu)
	await wait(0.4)

	test_structure()
	await test_hover_and_focus_states()
	await test_pressed_state()
	await test_keyboard_navigation()
	await test_mouse_navigation()
	await test_disabled_button()
	await test_toggles()
	await test_resize()

	menu.queue_free()
	await wait(0.2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://menu_buttons_test.cfg"))
	print("MENU BUTTONS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func test_structure() -> void:
	check(menu.theme != null and menu.theme.resource_path == "res://resources/ui/menu_theme.tres", "Menu uses the shared theme resource")
	for variation: String in ["PrimaryButton", "SecondaryButton", "TertiaryButton", "ToggleButton"]:
		check(menu.theme.get_type_variation_base(variation) != &"", "Theme defines the %s variation" % variation)
	check(btn("PlayButton").theme_type_variation == &"PrimaryButton", "Play is the primary button")
	check(btn("SettingsButton").theme_type_variation == &"SecondaryButton", "Settings is secondary")
	check(btn("CreditsButton").theme_type_variation == &"SecondaryButton", "Credits is secondary")
	check(btn("QuitButton").theme_type_variation == &"TertiaryButton", "Quit is tertiary")
	check(btn("PlayButton").text == "PLAY TOGETHER", "Play label no longer carries padding spaces or a text arrow")
	for node_name in WIRED_BUTTONS:
		check(btn(node_name).pressed.get_connections().size() >= 1, "%s keeps its pressed connection" % node_name)
	check(btn("PlayButton").has_focus(), "Play grabs focus when the menu opens")
	check(btn("PreviewButton").text == "PLAY THE LAB     /     SOLO TEST", "Submenu labels are unchanged")
	check(menu.get_node("Overlay/Center/Panel/Margin/Pages/PlayPage/LocalButton").disabled, "Split-screen stays disabled (coming soon)")

	var play := btn("PlayButton")
	var settings := btn("SettingsButton")
	var credits := btn("CreditsButton")
	var quit_button := btn("QuitButton")
	check(play.size.y > settings.size.y and settings.size.y > quit_button.size.y, "Height steps down primary > secondary > tertiary")
	check(is_equal_approx(settings.size.y, credits.size.y) and is_equal_approx(settings.size.x, credits.size.x), "Secondary pair is identical in size")
	check(is_equal_approx(play.size.x, settings.size.x + credits.size.x + 12.0), "Secondary pair spans exactly the primary's width")
	check(is_equal_approx(play.global_position.x, settings.global_position.x) and is_equal_approx(play.global_position.x, quit_button.global_position.x), "Group shares one left edge")
	check(play.global_position.x < 400.0, "Group stays on the left side")
	var gap_one := settings.global_position.y - (play.global_position.y + play.size.y)
	var gap_two := quit_button.global_position.y - (settings.global_position.y + settings.size.y)
	check(is_equal_approx(gap_one, gap_two), "Vertical spacing is even (%s vs %s)" % [gap_one, gap_two])
	check(quit_button.global_position.y + quit_button.size.y < 698.0, "Quit clears the floor line in the background art")
	check(quit_button.size.y >= 36.0, "Quit keeps a comfortable click target")
	for node_name in MAIN_BUTTONS:
		var button := btn(node_name)
		check(not button.is_processing() and not button.is_physics_processing(), "%s runs no per-frame processing while idle" % node_name)
		check(button.focus_mode == Control.FOCUS_ALL, "%s remains keyboard-focusable" % node_name)


func test_hover_and_focus_states() -> void:
	var settings := btn("SettingsButton")
	var center := settings.get_global_rect().get_center()
	check(lit(settings, "_hover") == 0.0, "Rest state is neutral")
	pointer(center)
	await wait(0.05)
	var mid := lit(settings, "_hover")
	check(mid > 0.0 and mid < 1.0, "Hover eases in rather than snapping (mid-transition %.2f)" % mid)
	await wait(0.3)
	check(lit(settings, "_hover") > 0.99, "Hover settles fully lit")
	pointer(Vector2(900, 800))
	await wait(0.4)
	check(lit(settings, "_hover") < 0.01, "Hover releases back to rest")

	settings.grab_focus()
	await wait(0.3)
	check(lit(settings, "_focus") > 0.99, "Keyboard focus lights the button")
	btn("QuitButton").grab_focus()
	await wait(0.3)
	check(lit(settings, "_focus") < 0.01 and lit(btn("QuitButton"), "_focus") > 0.99, "Focus hands over cleanly")
	btn("PlayButton").grab_focus()


func test_pressed_state() -> void:
	var settings := btn("SettingsButton")
	var center := settings.get_global_rect().get_center()
	pointer(center)
	await wait(0.3)
	mouse_button(center, true)
	await process_frame
	check(lit(settings, "_press") == 1.0, "Press registers on the very next frame")
	check(not menu.get_node("Overlay").visible, "Holding the button does not activate it")
	pointer(Vector2(900, 800))
	await process_frame
	mouse_button(Vector2(900, 800), false)
	await wait(0.3)
	check(lit(settings, "_press") == 0.0, "Press relaxes after release")
	check(not menu.get_node("Overlay").visible, "Releasing off the button does not activate it")
	btn("PlayButton").grab_focus()


func test_keyboard_navigation() -> void:
	btn("PlayButton").grab_focus()
	await tap(KEY_DOWN)
	var second := menu.get_viewport().gui_get_focus_owner()
	check(second == btn("SettingsButton") or second == btn("CreditsButton"), "Down from Play reaches the secondary row")
	await tap(KEY_DOWN)
	check(btn("QuitButton").has_focus(), "Down again reaches Quit")
	await tap(KEY_UP)
	await tap(KEY_UP)
	check(btn("PlayButton").has_focus(), "Up twice returns to Play")

	await tap(KEY_ENTER)
	await wait(0.1)
	check(menu.get_node("Overlay").visible and menu.get_node("Overlay/Center/Panel/Margin/Pages/PlayPage").visible, "Enter activates Play")
	check(btn("PreviewButton").has_focus(), "Submenu focus starts on the first live option")
	await tap(KEY_DOWN)
	check(btn("HostButton").has_focus(), "Down skips the disabled split-screen entry and moves through the list")
	await tap(KEY_ESCAPE)
	await wait(0.1)
	check(not menu.get_node("Overlay").visible and btn("PlayButton").has_focus(), "Escape closes the page and returns focus to Play")
	await wait(0.3)
	check(lit(btn("PlayButton"), "_focus") > 0.99, "Focus indicator is restored on return")


func test_mouse_navigation() -> void:
	await click(btn("SettingsButton"))
	await wait(0.1)
	check(menu.get_node("Overlay/Center/Panel/Margin/Pages/SettingsPage").visible, "Clicking Settings opens Settings")
	await click(btn("BackButton"))
	await wait(0.1)
	check(not menu.get_node("Overlay").visible, "Clicking Back closes it")
	await click(btn("CreditsButton"))
	await wait(0.1)
	check(menu.get_node("Overlay/Center/Panel/Margin/Pages/CreditsPage").visible, "Clicking Credits opens Credits")
	await tap(KEY_ESCAPE)
	await click(btn("QuitButton"))
	await wait(0.1)
	check(menu.get_node("Overlay/Center/Panel/Margin/Pages/QuitPage").visible and btn("BackButton").text == "STAY", "Clicking Quit opens the confirmation (Stay is the safe default)")
	await click(btn("BackButton"))
	await wait(0.1)
	check(not menu.get_node("Overlay").visible, "Stay returns to the title")
	await click(btn("PlayButton"))
	await wait(0.1)
	check(menu.get_node("Overlay/Center/Panel/Margin/Pages/PlayPage").visible, "Clicking Play opens the mode list")
	await tap(KEY_ESCAPE)
	await wait(0.1)


func test_disabled_button() -> void:
	btn("PlayButton").pressed.emit()
	await wait(0.1)
	var local: Button = menu.get_node("Overlay/Center/Panel/Margin/Pages/PlayPage/LocalButton")
	pointer(local.get_global_rect().get_center())
	await wait(0.35)
	check(local.disabled and lit(local, "_hover") == 0.0, "Disabled button shows no hover response")
	await click(local)
	check(menu.get_node("Overlay/Center/Panel/Margin/Pages/PlayPage").visible and not menu._entering_game, "Clicking a disabled button does nothing")
	var preview := btn("PreviewButton")
	pointer(preview.get_global_rect().get_center())
	await wait(0.35)
	check(lit(preview, "_hover") > 0.99, "Enabled list entry lights on hover")
	preview.disabled = true
	await wait(0.2)
	check(lit(preview, "_hover") == 0.0, "Disabling a hovered button clears its lit state")
	preview.disabled = false
	pointer(preview.get_global_rect().get_center() + Vector2(4, 0))
	await wait(0.35)
	check(lit(preview, "_hover") > 0.99, "Re-enabled button responds to hover again")
	var live: Button = btn("HostButton")
	check(live.theme_type_variation == &"SecondaryButton" and not live.disabled, "Enabled sibling keeps the secondary look")
	await tap(KEY_ESCAPE)
	await wait(0.1)


func test_toggles() -> void:
	btn("SettingsButton").pressed.emit()
	await wait(0.1)
	var motion: CheckButton = menu.get_node("%MotionToggle")
	check(motion.theme_type_variation == &"ToggleButton", "Settings toggles use the toggle variation")
	var was_on := motion.button_pressed
	await click(motion)
	check(motion.button_pressed != was_on and menu.backdrop.motion_enabled == motion.button_pressed, "Toggle still drives the backdrop setting")
	await click(motion)
	check(motion.button_pressed == was_on and menu.backdrop.motion_enabled == was_on, "Toggle returns to its original state")
	var mutes := menu.get_node("Overlay/Center/Panel/Margin/Pages/SettingsPage").find_children("*", "CheckButton", true, false)
	check(mutes.size() >= 7, "Fullscreen, Ambient motion and the volume mutes are all present (%d)" % mutes.size())
	for mute in mutes:
		check((mute as Button).theme_type_variation == &"ToggleButton", "%s uses the toggle variation" % mute.name)
	await tap(KEY_ESCAPE)
	await wait(0.1)


func test_resize() -> void:
	for size_option: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 900)]:
		root.size = size_option
		await wait(0.15)
		var play := btn("PlayButton")
		var visible_area := Rect2(Vector2.ZERO, Vector2(1600, 900))
		check(visible_area.encloses(play.get_global_rect()) and visible_area.encloses(btn("QuitButton").get_global_rect()), "Button group stays inside the canvas at %s" % size_option)
		check(play.size.x >= 360.0 and play.size.y >= 66.0, "Primary keeps its size at %s" % size_option)
