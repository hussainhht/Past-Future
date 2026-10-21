class_name ObjectiveStyle
extends RefCounted
## Colours, panel styles and label helpers shared by the objective HUD and the Mission Log, so the
## two read as one design: dark translucent panels, amber for the Past, cyan for the Future.

const DONE := Color("7fcf9a")
const TEXT := Color("e6eeec")
const SOFT := Color("a9bbbe")
const MUTED := Color("6f8589")
const PANEL := Color(0.028, 0.052, 0.068, 0.88)
const PANEL_SOLID := Color(0.03, 0.055, 0.072, 0.97)


static func accent(role: String) -> Color:
	return Typography.FUTURE_ACCENT if role == "future" else Typography.PAST_ACCENT


## "STUDENT · PAST" / "PROFESSOR · FUTURE"
static func role_name(role: String) -> String:
	return "PROFESSOR · FUTURE" if role == "future" else "STUDENT · PAST"


static func reduced_motion() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var manager: Node = tree.root.get_node_or_null("CinematicTransitionManager")
	return manager != null and manager.has_method("is_reduced_motion") and bool(manager.call("is_reduced_motion"))


static func box(background: Color, border: Color, border_width: int = 1, radius: int = 8, margin: Vector2 = Vector2(14, 10)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	return style


## A label in one of Typography's roles. `tracking` adds letter spacing (capitals read better spaced).
static func label(text: String, role: StringName, size: int, color: Color, tracking: float = 0.0) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override("font_color", color)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_font_override("font", font(role, tracking))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func font(role: StringName, tracking: float = 0.0) -> Font:
	var base := Typography.role_font(role)
	if tracking == 0.0 or base == null:
		return base
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = int(round(tracking))
	return variation
