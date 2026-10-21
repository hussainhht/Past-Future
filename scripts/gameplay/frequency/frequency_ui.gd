extends RefCounted
## Shared appearance for the independent terminal, log reader and radio overlay.

const AMBER := Color("e4bf7f")
const CYAN := Color("86c9d1")


static func panel(accent: Color = AMBER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c28f5")
	style.border_color = accent.darkened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style


## Terminal text: Departure Mono for headings and readouts, role &"future_journal_body" for sentences.
static func label(text: String, size: int = 20, color: Color = AMBER, role: StringName = &"terminal_log") -> Label:
	var result := Label.new()
	result.text = text
	Typography.apply(result, role, size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	Typography.apply(result, &"terminal_log", 20)
	result.add_theme_stylebox_override("normal", panel(AMBER))
	result.add_theme_stylebox_override("hover", panel(CYAN))
	result.add_theme_stylebox_override("focus", panel(CYAN))
	return result
