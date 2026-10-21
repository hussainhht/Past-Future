class_name ObjectiveTracker
extends CanvasLayer
## The compact "current objective" card (upper left) and the "objective completed" notice under it.
## It only presents what ObjectiveManager hands it: which objective is current, when one was just
## completed, and whether the Mission Log may be opened. It never decides progress itself.

const CARD_WIDTH := 372.0
const FADE_SPEED := 5.0
const TOAST_HOLD := 2.8
const MAX_QUEUED_TOASTS := 4
const SOUND_ID := &"ui_notification"

## Where the card sits: below the rooms' top bar. A room whose own HUD fills that corner is listed
## here with a lower anchor, so no room needs to know about the tracker.
const DEFAULT_ANCHOR := Vector2(16.0, 78.0)
const ROOM_ANCHORS := {"room_03": Vector2(20.0, 142.0)}

var anchor_offset := DEFAULT_ANCHOR

var _role: String = "past"
var _toasts: Array[String] = []
var _toast_active := false
var _tween: Tween
var _toast_tween: Tween
var _alpha := 0.0
var _player: AudioStreamPlayer
var _stream: AudioStream

var _root: Control
var _anchor: Control
var _card: PanelContainer
var _bar: ColorRect
var _icon: ObjectiveIcon
var _eyebrow: Label
var _title: Label
var _description: Label
var _chapter: Label
var _progress: Label
var _updated: Label
var _log_button: Button
var _log_key: Label
var _toast: PanelContainer
var _toast_head: Label
var _toast_title: Label
var _toast_icon: ObjectiveIcon


func _ready() -> void:
	layer = 8  # Above the rooms' HUD, below their dialogue, modals and the journal.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load_sound()
	ObjectiveManager.state_changed.connect(_refresh)
	ObjectiveManager.objective_activated.connect(_on_activated)
	ObjectiveManager.objective_completed.connect(_on_completed)
	InputManager.get_instance().device_changed_signal.connect(func(_device: int, _controller: int) -> void: _refresh_key())
	_refresh()


func _process(delta: float) -> void:
	# Solo preview can switch which timeline is played; nothing else announces that.
	if ObjectiveManager.get_local_role() != _role:
		_refresh()
	var anchor: Vector2 = ROOM_ANCHORS.get(GameFlowManager.get_current_room_id(), DEFAULT_ANCHOR)
	if anchor != anchor_offset:
		anchor_offset = anchor
		_anchor.position = anchor
	var wanted := 1.0 if _card_wanted() else 0.0
	_alpha = move_toward(_alpha, wanted, delta * FADE_SPEED)
	_card.modulate.a = _alpha
	_card.visible = _alpha > 0.01
	_log_button.disabled = not ObjectiveManager.can_open_log()
	_log_button.modulate.a = 0.45 if _log_button.disabled else 1.0
	_place_toast()
	if not _toast_active and not _toasts.is_empty() and _notices_allowed():
		_show_next_toast()


# --- Visibility ---------------------------------------------------------------------------

func _in_room() -> bool:
	return GameFlowManager.get_current_room_id() != "" and not GameFlowManager.is_transitioning() and not CinematicTransitionManager.is_playing()


## Cards stay out of the way of anything that already owns the screen.
func _card_wanted() -> bool:
	if not _in_room() or not ObjectiveManager.has_content() or ObjectiveManager.is_log_open() or JournalManager.is_open():
		return false
	var room := GameFlowManager.get_current_room_node()
	if room != null and room.has_method("is_gameplay_paused") and room.is_gameplay_paused():
		return false
	return _has_card_content()


func _notices_allowed() -> bool:
	return _in_room() and not ObjectiveManager.is_log_open()


func _has_card_content() -> bool:
	return ObjectiveManager.get_current(_role) != null or ObjectiveManager.is_chapter_done(_role)


# --- Content ------------------------------------------------------------------------------

func _refresh() -> void:
	_role = ObjectiveManager.get_local_role()
	var accent := ObjectiveStyle.accent(_role)
	_card.add_theme_stylebox_override("panel", ObjectiveStyle.box(ObjectiveStyle.PANEL, Color(accent, 0.38), 1, 8, Vector2(14, 11)))
	_bar.color = accent
	_eyebrow.add_theme_color_override("font_color", accent)
	_updated.add_theme_color_override("font_color", accent)
	_progress.add_theme_color_override("font_color", accent)
	_log_key.add_theme_color_override("font_color", accent)
	var current := ObjectiveManager.get_current(_role)
	if current != null:
		_icon.kind = current.icon
		_icon.color = accent
		_eyebrow.text = "CURRENT OBJECTIVE"
		_title.text = current.title
		_description.text = current.summary if not current.summary.is_empty() else current.description
		_chapter.text = ObjectiveManager.get_chapter_name(current.chapter).to_upper()
		var progress := ObjectiveManager.get_progress(current, _role)
		_progress.visible = progress.y > 0
		_progress.text = "%d / %d" % [progress.x, progress.y]
	elif ObjectiveManager.is_chapter_done(_role):
		_icon.kind = &"check"
		_icon.color = ObjectiveStyle.DONE
		_eyebrow.text = "OBJECTIVES"
		_title.text = "All objectives complete"
		_description.text = "New objectives appear as you advance."
		_chapter.text = ""
		_progress.visible = false
	_refresh_key()


func _refresh_key() -> void:
	if _log_key != null:
		_log_key.text = InputManager.get_action_label(ObjectiveManager.ACTION)
		_log_button.tooltip_text = "Open the Mission Log"


func _on_activated(_role_id: String, _objective_id: String) -> void:
	if not _card.visible and _alpha <= 0.01:
		return
	_pulse_change()


## A subtle cue that the task changed: the accent bar flares and an "UPDATED" tag fades out.
func _pulse_change() -> void:
	if _tween != null:
		_tween.kill()
	_updated.visible = true
	_updated.modulate.a = 1.0
	if ObjectiveStyle.reduced_motion():
		_card.position.x = 0.0
		_bar.modulate = Color.WHITE
		_tween = create_tween()
		_tween.tween_interval(2.2)
		_tween.tween_property(_updated, "modulate:a", 0.0, 0.12)
		_tween.tween_callback(_updated.hide)
		return
	_card.position.x = -10.0
	_bar.modulate = Color(1.9, 1.9, 1.9)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "position:x", 0.0, 0.32)
	_tween.tween_property(_bar, "modulate", Color.WHITE, 1.1)
	_tween.chain().tween_interval(1.4)
	_tween.chain().tween_property(_updated, "modulate:a", 0.0, 0.5)
	_tween.chain().tween_callback(_updated.hide)


# --- Completion notice --------------------------------------------------------------------

func _on_completed(role: String, objective_id: String) -> void:
	var definition := ObjectiveManager.get_definition(objective_id)
	if definition == null or role != ObjectiveManager.get_local_role():
		return
	if _toasts.size() < MAX_QUEUED_TOASTS:
		_toasts.append(definition.title)
	_play_sound()


func _show_next_toast() -> void:
	_toast_active = true
	_toast_title.text = _toasts.pop_front()
	var accent := ObjectiveStyle.DONE
	_toast.add_theme_stylebox_override("panel", ObjectiveStyle.box(Color(0.03, 0.07, 0.06, 0.94), Color(accent, 0.55), 1, 8, Vector2(14, 9)))
	_toast.show()
	_toast.reset_size()
	_toast.modulate.a = 0.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	var reduced := ObjectiveStyle.reduced_motion()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12 if reduced else 0.25)
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.12 if reduced else 0.4)
	_toast_tween.tween_callback(func() -> void:
		_toast.hide()
		_toast_active = false)


## The notice sits under the card (or where the card would be), not in the middle of the screen.
func _place_toast() -> void:
	_toast.position = Vector2(0.0, _card.size.y + 8.0 if _card.visible else 0.0)


func _load_sound() -> void:
	var definitions := SoundCatalog.definitions()
	if not definitions.has(String(SOUND_ID)):
		return
	var entry := SoundCatalog.load_entry(definitions[String(SOUND_ID)])
	_stream = entry.get("stream")
	_player = AudioStreamPlayer.new()
	_player.bus = &"UI" if AudioServer.get_bus_index(&"UI") != -1 else &"Master"
	_player.volume_db = float(entry.get("volume_db", -17.0)) + 4.0
	add_child(_player)


func _play_sound() -> void:
	# The headless Dummy driver cannot play sound; the notice itself still works.
	if _player != null and _stream != null and AudioServer.get_driver_name() != "Dummy":
		_player.stream = _stream
		_player.play()


# --- Layout -------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# The anchor holds the card and the notice at the HUD corner; the card slides inside it.
	_anchor = Control.new()
	_anchor.name = "Anchor"
	_anchor.position = anchor_offset
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_anchor)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	_card.visible = false
	_anchor.add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)

	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(3.0, 0.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_bar)

	_icon = ObjectiveIcon.new(&"document", Color.WHITE, 30.0)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_icon)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	_eyebrow = ObjectiveStyle.label("CURRENT OBJECTIVE", &"settings_label", 12, Color.WHITE, 1.5)
	header.add_child(_eyebrow)
	_updated = ObjectiveStyle.label("UPDATED", &"settings_label", 11, Color.WHITE, 1.0)
	_updated.visible = false
	header.add_child(_updated)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_log_button = _make_log_button()
	header.add_child(_log_button)

	_title = ObjectiveStyle.label("", &"button", 18, ObjectiveStyle.TEXT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_description = ObjectiveStyle.label("", &"settings_note", 14, ObjectiveStyle.SOFT)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.max_lines_visible = 3
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_description)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	_chapter = ObjectiveStyle.label("", &"settings_label", 11, ObjectiveStyle.MUTED, 1.2)
	_chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter.clip_text = true
	_chapter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(_chapter)
	_progress = ObjectiveStyle.label("", &"settings_label", 12, Color.WHITE, 1.0)
	_progress.visible = false
	footer.add_child(_progress)

	_toast = PanelContainer.new()
	_toast.name = "CompletedNotice"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.hide()
	_anchor.add_child(_toast)
	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 10)
	toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(toast_row)
	_toast_icon = ObjectiveIcon.new(&"check", ObjectiveStyle.DONE, 26.0)
	toast_row.add_child(_toast_icon)
	var toast_column := VBoxContainer.new()
	toast_column.add_theme_constant_override("separation", 0)
	toast_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_row.add_child(toast_column)
	_toast_head = ObjectiveStyle.label("OBJECTIVE COMPLETED", &"settings_label", 12, ObjectiveStyle.DONE, 1.5)
	toast_column.add_child(_toast_head)
	_toast_title = ObjectiveStyle.label("", &"button", 16, ObjectiveStyle.TEXT)
	toast_column.add_child(_toast_title)


func _make_log_button() -> Button:
	var button := Button.new()
	button.name = "MissionLogButton"
	button.focus_mode = Control.FOCUS_NONE  # Gameplay owns the controller; the shortcut opens the log.
	button.custom_minimum_size = Vector2(70.0, 22.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("audio_event", &"")
	var normal := ObjectiveStyle.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.16), 1, 4, Vector2(6, 2))
	var hover := ObjectiveStyle.box(Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.4), 1, 4, Vector2(6, 2))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.pressed.connect(func() -> void: ObjectiveManager.open_log())
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6.0
	content.offset_right = -6.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var glyph := ObjectiveIcon.new(&"book", ObjectiveStyle.SOFT, 14.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(glyph)
	content.add_child(ObjectiveStyle.label("LOG", &"settings_label", 11, ObjectiveStyle.SOFT, 1.0))
	_log_key = ObjectiveStyle.label("", &"settings_label", 11, Color.WHITE, 0.0)
	content.add_child(_log_key)
	return button
