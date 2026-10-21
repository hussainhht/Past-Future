class_name TutorialPopup
extends CanvasLayer
## "How to play" overlay for the local player. It opens by itself the first time a player reaches
## the first playable room, and again whenever the pause menu asks for it.
##
## It is purely local: it never touches the network, PuzzleManager or the other player's room. The
## room owns the lock (laboratory_gameplay.has_modal() asks is_open()) and routes input through
## handle_input() before its own pause handling, exactly like the settings overlay.
## Whether it has been dismissed once is stored in user://tutorial.cfg.

signal opened
## `dismissed` is false when the room closed it for the player (a level transition, a lost
## connection), so that does not count as having read it.
signal closed(dismissed: bool)

const TemporalButton := preload("res://scripts/menu/menu_button.gd")

const CONFIG_PATH := "user://tutorial.cfg"
const CONFIG_SECTION := "tutorial"
const CONFIG_KEY := "dismissed"
const TITLE := "WELCOME TO THE OTHER ME"
const SUBTITLE := "Two timelines. One identity. Your choices shape the future."
const BUTTON_TEXT := "GOT IT — LET'S PLAY"
const TIP_TITLE := "WORK TOGETHER"
const TIP_TEXT := "Neither timeline has all the answers. Share what you discover. What changes in the past can transform the future."
const ROLES := {
	"past": {
		"title": "STUDENT — THE PAST",
		"body": "You can change the past. Explore the laboratory, interact with equipment, and help your future self.",
	},
	"future": {
		"title": "PROFESSOR — THE FUTURE",
		"body": "You can uncover the truth. Investigate the ruins, discover clues, and guide your younger self.",
	},
}
## [label, InputManager action] for the essential controls, in reading order.
const CONTROLS: Array = [
	["MOVE", &"move"],
	["INTERACT", &"interact"],
	["INSPECT", &"inspect"],
	["SPRINT", &"sprint"],
	["JOURNAL", &"journal"],
	["PAUSE", &"pause"],
]

const PAST_ACCENT := Typography.PAST_ACCENT
const FUTURE_ACCENT := Typography.FUTURE_ACCENT
const TEXT_COLOR := Color("dbe6e4")
const MUTED_COLOR := Color("8fa5aa")

const FADE_IN := 0.28
const PANEL_IN := 0.34
const FADE_OUT := 0.18
const FADE_REDUCED := 0.12

## Overridable so tests never touch the player's real file.
static var config_path: String = CONFIG_PATH

var role: String = "past"
var from_pause := false
var confirm_button: Button

var _open := false
var _closing := false
var _audio: Node
var _dim: ColorRect
var _panel: PanelContainer
var _role_title: Label
var _role_body: Label
var _role_card: PanelContainer
var _control_chips: Array[Label] = []
var _escape_hint: Label
var _scroll: ScrollContainer
var _tween: Tween
var _pulse: Tween
var _built := false


# --- Remembered state ----------------------------------------------------------------------

static func has_been_shown() -> bool:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return false
	return bool(config.get_value(CONFIG_SECTION, CONFIG_KEY, false))


static func mark_shown() -> void:
	var config := ConfigFile.new()
	config.load(config_path)  # Keep anything else stored in the file; a missing file is fine.
	config.set_value(CONFIG_SECTION, CONFIG_KEY, true)
	var error := config.save(config_path)
	if error != OK:
		push_warning("TutorialPopup: could not save %s (error %d)" % [config_path, error])


static func reset_shown() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return
	config.set_value(CONFIG_SECTION, CONFIG_KEY, false)
	config.save(config_path)


# --- Setup ---------------------------------------------------------------------------------

func _ready() -> void:
	_build()


## `audio` is the room's AudioDirector (optional; the popup is silent without it).
func configure(audio: Node) -> void:
	_audio = audio


func _build() -> void:
	if _built:
		return
	_built = true
	layer = 90  # Above the pause menu (PauseLayer) and the settings overlay (80).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.008, 0.02, 0.03, 0.82)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	TemporalButton.theme_for(_dim)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(1080, 0)
	_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.085, 0.97), PAST_ACCENT, 2, 10))
	center.add_child(_panel)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	_panel.add_child(frame)
	frame.add_child(_timeline_bar())
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := _label(TITLE, 40, TEXT_COLOR, &"chapter_name")
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label(SUBTITLE, 21, MUTED_COLOR, &"settings_value")
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)

	_scroll = ScrollContainer.new()
	_scroll.name = "Body"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)

	_role_card = PanelContainer.new()
	_role_card.name = "RoleCard"
	var role_box := VBoxContainer.new()
	role_box.add_theme_constant_override("separation", 6)
	_role_card.add_child(_pad(role_box, 24, 16))
	_role_title = _label("", 26, PAST_ACCENT, &"button")
	_role_title.name = "RoleTitle"
	role_box.add_child(_role_title)
	_role_body = _label("", 23, TEXT_COLOR, &"dialogue_body")
	_role_body.name = "RoleBody"
	_role_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_box.add_child(_role_body)
	body.add_child(_role_card)

	var controls_title := _label("CONTROLS", 17, MUTED_COLOR, &"button")
	controls_title.name = "ControlsTitle"
	body.add_child(controls_title)
	var grid := GridContainer.new()
	grid.name = "Controls"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for entry in CONTROLS:
		grid.add_child(_control_row(entry[0]))

	body.add_child(_tip_card())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 28)
	column.add_child(footer)
	confirm_button = TemporalButton.apply(Button.new(), &"PrimaryButton")
	confirm_button.name = "ConfirmButton"
	confirm_button.text = BUTTON_TEXT
	confirm_button.custom_minimum_size = Vector2(420, 64)
	confirm_button.pressed.connect(dismiss)
	footer.add_child(confirm_button)
	_escape_hint = _label("", 18, MUTED_COLOR, &"settings_value")
	_escape_hint.name = "CloseHint"
	footer.add_child(_escape_hint)

	_dim.visible = false
	visible = false
	if InputManager.instance != null:
		InputManager.instance.device_changed_signal.connect(_on_device_changed)
	get_viewport().size_changed.connect(_fit_to_viewport)


func _timeline_bar() -> Control:
	# A hairline split between the two timelines: amber for the Past, cyan for the Future.
	var bar := HBoxContainer.new()
	bar.name = "TimelineBar"
	bar.add_theme_constant_override("separation", 0)
	for accent in [PAST_ACCENT, FUTURE_ACCENT]:
		var half := ColorRect.new()
		half.color = accent
		half.custom_minimum_size = Vector2(0, 4)
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(half)
	return bar


func _control_row(action_title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip_panel := PanelContainer.new()
	chip_panel.custom_minimum_size = Vector2(190, 46)
	chip_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.11, 0.13, 1.0), Color("3c5961"), 1, 4))
	var chip := _label("", 21, TEXT_COLOR, &"terminal_log")
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip_panel.add_child(chip)
	_control_chips.append(chip)
	row.add_child(chip_panel)
	var name_label := _label(action_title, 20, TEXT_COLOR, &"settings_label")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	return row


func _tip_card() -> Control:
	var card := PanelContainer.new()
	card.name = "TipCard"
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.085, 0.1, 1.0), Color("45636b"), 1, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(_pad(row, 24, 14))
	var dots := VBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	for accent in [PAST_ACCENT, FUTURE_ACCENT]:
		var dot := ColorRect.new()
		dot.color = accent
		dot.custom_minimum_size = Vector2(10, 10)
		dots.add_child(dot)
	row.add_child(dots)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	text.add_child(_label(TIP_TITLE, 19, PAST_ACCENT.lerp(FUTURE_ACCENT, 0.5), &"button"))
	var tip := _label(TIP_TEXT, 20, TEXT_COLOR, &"settings_value")
	tip.name = "TipText"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(tip)
	row.add_child(text)
	return card


# --- Public API ----------------------------------------------------------------------------

func is_open() -> bool:
	return _open


## Shows the tutorial for `new_role` ("past" or "future"). `opened_from_pause` makes Escape and
## the confirm button hand control back to the pause menu rather than to the game.
func open(new_role: String, opened_from_pause: bool = false) -> void:
	_build()
	if _open:
		return
	_open = true
	_closing = false
	from_pause = opened_from_pause
	role = new_role if ROLES.has(new_role) else "past"
	_apply_role()
	refresh_controls()
	_fit_to_viewport()
	_refit()
	_kill_tweens()
	visible = true
	_dim.visible = true
	_play_sound(&"ui_notification")
	_scroll.scroll_vertical = 0
	_animate_in()
	confirm_button.grab_focus()
	opened.emit()


## The player chose to close it: remember that, then fade out.
func dismiss() -> void:
	if not _open or _closing:
		return
	mark_shown()
	_play_sound(&"ui_confirm")
	_animate_out(true)


## The room closed it (transition, lost connection). Not remembered as read.
func close_silently() -> void:
	if not _open:
		return
	_kill_tweens()
	_finish(false)


## Called first by the room's _input. While the popup is open it owns Escape / controller back
## (and pause), and the room ignores every other key, so nothing leaks through to the game.
func handle_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if not event.is_echo():
			dismiss()
		get_viewport().set_input_as_handled()
	return true


## Re-reads the glyphs for the active device (keyboard, PlayStation or Xbox).
func refresh_controls() -> void:
	for index in CONTROLS.size():
		_control_chips[index].text = InputManager.get_action_label(CONTROLS[index][1])
	_escape_hint.text = "%s  ·  %s" % [
		InputManager.get_action_label(&"ui_cancel"),
		"BACK TO PAUSE MENU" if from_pause else "CLOSE"]


func accent() -> Color:
	return FUTURE_ACCENT if role == "future" else PAST_ACCENT


## The text currently shown for the role, for tests and screenshots.
func role_text() -> String:
	return _role_title.text + "\n" + _role_body.text


func control_texts() -> Array[String]:
	var result: Array[String] = []
	for chip in _control_chips:
		result.append(chip.text)
	return result


# --- Presentation --------------------------------------------------------------------------

func _apply_role() -> void:
	var data: Dictionary = ROLES[role]
	_role_title.text = data["title"]
	_role_body.text = data["body"]
	var color := accent()
	_role_title.add_theme_color_override("font_color", color)
	var style := _panel_style(Color(color.r, color.g, color.b, 0.09), color, 1, 6)
	style.border_width_left = 6
	_role_card.add_theme_stylebox_override("panel", style)
	_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.085, 0.97), color, 2, 10))


func _on_device_changed(_device_type: int, _controller_type: int) -> void:
	if _open:
		refresh_controls()


## Keeps the panel inside the (always 16:9) virtual viewport: 1600x900 as authored, while 1280x720
## and 960x540 windows are scaled by the canvas_items stretch. The body scrolls if it ever overflows.
func _fit_to_viewport() -> void:
	if _panel == null or not is_inside_tree():
		return
	var screen := get_viewport().get_visible_rect().size
	_panel.custom_minimum_size.x = clampf(screen.x - 120.0, 640.0, 1080.0)
	_scroll.custom_minimum_size.y = 0.0
	var chrome := _panel.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(screen.y - 48.0 - chrome, 120.0, _scroll.get_child(0).get_combined_minimum_size().y)


## Wrapped text only reports its final height after a layout pass, so fit again once it has run.
func _refit() -> void:
	for _pass in 2:
		await get_tree().process_frame
		if not _open:
			return
		_fit_to_viewport()
	_panel.pivot_offset = _panel.size * 0.5


func _reduced_motion() -> bool:
	var manager := get_node_or_null("/root/CinematicTransitionManager")
	return manager != null and manager.has_method("is_reduced_motion") and bool(manager.call("is_reduced_motion"))


func _animate_in() -> void:
	var reduced := _reduced_motion()
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE if reduced else Vector2(0.96, 0.96)
	_tween = create_tween().set_parallel(true)
	if reduced:
		_tween.tween_property(_dim, "modulate:a", 1.0, FADE_REDUCED)
		_tween.tween_property(_panel, "modulate:a", 1.0, FADE_REDUCED)
		return
	_tween.tween_property(_dim, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_panel, "modulate:a", 1.0, PANEL_IN).set_trans(Tween.TRANS_SINE).set_delay(0.06)
	_tween.tween_property(_panel, "scale", Vector2.ONE, PANEL_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.06)
	# A slow breath on the confirm button draws the eye to it without ever moving the layout.
	_pulse = create_tween().set_loops()
	_pulse.tween_property(confirm_button, "modulate", Color(1.14, 1.14, 1.14), 1.1).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(confirm_button, "modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)


func _animate_out(dismissed: bool) -> void:
	_closing = true
	if _pulse != null:
		_pulse.kill()
	confirm_button.modulate = Color.WHITE
	if _tween != null:
		_tween.kill()
	var reduced := _reduced_motion()
	var seconds := FADE_REDUCED if reduced else FADE_OUT
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, seconds)
	_tween.tween_property(_panel, "modulate:a", 0.0, seconds)
	if not reduced:
		_tween.tween_property(_panel, "scale", Vector2(0.98, 0.98), seconds)
	_tween.chain().tween_callback(_finish.bind(dismissed))


func _finish(dismissed: bool) -> void:
	_open = false
	_closing = false
	_kill_tweens()
	confirm_button.modulate = Color.WHITE
	_dim.visible = false
	visible = false
	closed.emit(dismissed)


func _kill_tweens() -> void:
	if _tween != null:
		_tween.kill()
	if _pulse != null:
		_pulse.kill()


func _play_sound(sound_id: StringName) -> void:
	if _audio != null and is_instance_valid(_audio) and _audio.has_method("play_ui"):
		_audio.play_ui(sound_id)


# --- Widgets -------------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, role_name: StringName) -> Label:
	var label := Label.new()
	label.text = text
	Typography.apply(label, role_name, size)
	label.add_theme_color_override("font_color", color)
	return label


func _pad(child: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, horizontal)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, vertical)
	margin.add_child(child)
	return margin


static func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 28
	return style
