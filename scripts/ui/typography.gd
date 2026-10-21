class_name Typography
extends RefCounted
## One place that knows which font belongs to which piece of text. The font resources live in
## res://assets/themes/typography/ (FontVariation .tres wrapping the files in res://assets/fonts/);
## the game-wide default lives in res://assets/themes/game_ui_theme.tres. See docs/TYPOGRAPHY_SYSTEM.md.
##
## Broken is bundled for the main-menu game name; Oxanium supplies general UI.
## To The Point handwriting remains optional, with a system handwriting fallback.

const TYPOGRAPHY_DIR := "res://assets/themes/typography/"
const TO_THE_POINT_PATH := "res://assets/fonts/handwriting/ToThePoint.ttf"
const BROKEN_PATH := "res://assets/fonts/menu/Broken.otf"

const PAST_ACCENT := Color("e4bf7f")
const FUTURE_ACCENT := Color("86c9d1")

## Role -> [font id, starting size at 1600x900]. Font ids resolve through font().
const ROLES := {
	&"game_title": [&"menu_title", 76],
	&"menu_button": [&"menu_button", 27],
	&"settings_heading": [&"heading", 36],
	&"settings_label": [&"ui_label", 22],
	&"settings_value": [&"ui_regular", 21],
	&"settings_note": [&"ui_regular", 18],
	&"button": [&"ui_button", 20],
	&"tooltip": [&"ui_regular", 19],
	&"chapter_name": [&"heading", 30],
	&"dialogue_speaker": [&"dialogue_speaker", 22],
	&"dialogue_body": [&"dialogue_body", 26],
	&"past_journal": [&"past_journal", 26],
	&"past_note": [&"past_journal", 26],
	&"future_journal_header": [&"future_journal_title", 22],
	&"future_journal_body": [&"future_journal_body", 22],
	&"terminal_log": [&"terminal_log", 20],
	&"digital_display": [&"digital_display", 30],
}

static var _cache: Dictionary = {}


## The Font for a font id (a file name in assets/themes/typography without "_font.tres", or one of
## the special ids menu_title, menu_button, past_journal).
static func font(id: StringName) -> Font:
	if _cache.has(id):
		return _cache[id]
	var result: Font
	match id:
		&"menu_title":
			result = _broken_or(&"display_title")
		&"menu_button":
			result = font(&"ui_button")
		&"past_journal":
			result = _handwriting()
		_:
			result = load(TYPOGRAPHY_DIR + String(id) + "_font.tres") as Font
	_cache[id] = result
	return result


## Electronic screen text follows the era; ordinary UI keeps Oxanium.
static func display_font(future: bool, numeric: bool = false) -> Font:
	if future:
		return font(&"terminal_log")
	return font(&"digital_display" if numeric else &"past_display")


## The font of a role.
static func role_font(role: StringName) -> Font:
	return font(ROLES[role][0])


## The starting size of a role.
static func role_size(role: StringName) -> int:
	return ROLES[role][1]


## Gives a Label, Button, LineEdit, CheckButton... or RichTextLabel the font and size of a role.
## `size` below zero keeps the role's own size.
static func apply(control: Control, role: StringName, size: int = -1) -> void:
	var px := size if size > 0 else role_size(role)
	var f := role_font(role)
	if control is RichTextLabel:
		style_rich(control as RichTextLabel, role, px)
		return
	control.add_theme_font_override("font", f)
	control.add_theme_font_size_override("font_size", px)


## RichTextLabel needs one font per style. Dialogue and journal roles bring their own bold/italic.
static func style_rich(label: RichTextLabel, role: StringName, size: int = -1) -> void:
	var px := size if size > 0 else role_size(role)
	var normal := role_font(role)
	var bold: Font = normal
	var italic: Font = normal
	var bold_italic: Font = normal
	match ROLES[role][0]:
		&"dialogue_body":
			bold = font(&"dialogue_bold")
			italic = font(&"dialogue_italic")
			bold_italic = font(&"dialogue_bold_italic")
		&"future_journal_body":
			bold = font(&"future_journal_bold")
			italic = normal
			bold_italic = bold
		&"past_journal":
			# The handwriting has no bold or italic: keep one natural hand and let colour carry emphasis.
			pass
	label.add_theme_font_override("normal_font", normal)
	label.add_theme_font_override("bold_font", bold)
	label.add_theme_font_override("italics_font", italic)
	label.add_theme_font_override("bold_italics_font", bold_italic)
	label.add_theme_font_override("mono_font", font(&"terminal_log"))
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		label.add_theme_font_size_override(key, px)


## Largest size from `wanted` down to `minimum` at which `text` fits in `max_width`.
static func fit_size(f: Font, text: String, wanted: int, max_width: float, minimum: int = 12) -> int:
	var px := wanted
	while px > minimum and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_width:
		px -= 1
	return px


static func has_handwriting() -> bool:
	return ResourceLoader.exists(TO_THE_POINT_PATH)


static func has_broken() -> bool:
	return ResourceLoader.exists(BROKEN_PATH)


static func _broken_or(fallback_id: StringName) -> Font:
	if has_broken():
		var broken := load(BROKEN_PATH) as Font
		if broken != null:
			var variation := FontVariation.new()
			variation.base_font = broken
			variation.fallbacks = [font(&"ui_button")]
			return variation
	return font(fallback_id)


static func _handwriting() -> Font:
	if has_handwriting():
		var hand := load(TO_THE_POINT_PATH) as Font
		if hand != null:
			# To The Point has a small glyph set: anything missing comes from a plain, readable face.
			var variation := FontVariation.new()
			variation.base_font = hand
			variation.fallbacks = [font(&"dialogue_body")]
			return variation
	# File not installed yet: the handwriting the journal used before this system.
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Segoe Print", "Bradley Hand", "Noteworthy", "Purisa", "Comic Sans MS", "cursive"])
	return system
