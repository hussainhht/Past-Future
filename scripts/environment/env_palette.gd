class_name EnvPalette
extends RefCounted
## Shared, per-timeline materials for environment props.
##
## Imported models name each material after a slot ("wood", "metal", "screen_glow"...). Every slot
## has a Past and a Future look, so the same mesh reads as the intact lab or its ruin 31 years later.
## Materials are cached and shared: one ShaderMaterial per (slot, timeline, texture). Switching a
## timeline swaps references instead of editing a material, so two timelines can never leak into
## each other, and draw calls batch across props.
##
## tools/assets/build_lab_props.py reads the SLOTS table below for the GLB preview colours.

const SHADER: Shader = preload("res://shaders/environment.gdshader")
const TEXTURES := "res://assets/environment/textures/"

## slot: [past albedo, future albedo]
const SLOTS := {
	"wall": ["e9dbbf", "34505b"],
	"wall_panel": ["dccaa4", "2b4651"],
	"wall_dark": ["b9a782", "223a44"],
	"trim": ["575c4a", "15242b"],
	"baseboard": ["70442c", "1b2a30"],
	"wood": ["8a5a3a", "3e3a35"],
	"wood_light": ["c49a62", "5a5a52"],
	"metal": ["889181", "557c86"],
	"metal_dark": ["4b5b55", "223640"],
	"steel": ["b8bdb2", "71909a"],
	"plastic": ["d7ccb1", "7a8c8d"],
	"fabric": ["e4bf7f", "5f6c66"],
	"fabric_dark": ["70442c", "2e3a3d"],
	"rubber": ["2c2e2a", "141c21"],
	"paper": ["f3ebd3", "b3bdb5"],
	"glass": ["b9dcd3", "54747b"],
	"liquid_a": ["7cc4a3", "3a5753"],
	"liquid_b": ["e2b45c", "6a5d44"],
	"plant": ["6f9a4a", "6a5737"],
	"pot": ["b5643c", "4b3c35"],
	"book_a": ["9c3b2e", "4a3a3a"],
	"book_b": ["3d6b5a", "2f4042"],
	"book_c": ["c69a3e", "5b5848"],
	"book_d": ["3e5a7a", "2d3e4e"],
	"coat": ["f2efe6", "9fb0ac"],
	"ceramic": ["ece4d2", "8e9a98"],
	"cardboard": ["c9a46c", "5c5444"],
	"copper": ["c87f4a", "5f4a3a"],
	"concrete": ["c9bfa6", "4a585c"],
	"debris": ["a99c85", "3d4b50"],
	"rust": ["8a5a3a", "6b3f2a"],
	"cable": ["2c2e2a", "151d22"],
	"cable_red": ["9c3b2e", "5a2a24"],
	"cable_blue": ["3e5a7a", "24394a"],
	"hazard": ["d9a441", "8a6a2a"],
	"screen": ["1d4a44", "0b151a"],
	"chalk": ["2e4a3c", "1b2a2b"],
	"lamp_shade": ["e4bf7f", "4f5b58"],
	"crystal_dark": ["3b4f6a", "2a1f45"],
	# Emissive slots: albedo here, glow below.
	"screen_glow": ["2a7a68", "0d1a20"],
	"lamp_bulb": ["fff0c8", "3a3f3f"],
	"led_red": ["c0392b", "c0392b"],
	"led_green": ["5fd08a", "2f4a3c"],
	"led_amber": ["e4a23b", "e48a2b"],
	"emergency": ["8a3a30", "e0503a"],
	"crystal": ["86c9d1", "8c69c1"],
	"crystal_core": ["d9f3f5", "c9a6f0"],
	# State indicators driven by the puzzle (same glow in both timelines once lit).
	"led_off": ["3a302c", "1c2428"],
	"led_go": ["5fd08a", "5fd08a"],
	# Textured slots: albedo multiplies the texture.
	"tex_paper_notes": ["ffffff", "c5cbc3"],
	"tex_paper_graph": ["ffffff", "c5cbc3"],
	"tex_paper_memo": ["ffffff", "c5cbc3"],
	"tex_notebook": ["ffffff", "c9cdc4"],
	"tex_blackboard": ["ffffff", "d0d6d6"],
	"tex_poster_array": ["ffffff", "b9c3c1"],
	"tex_poster_safety": ["ffffff", "b9c3c1"],
	"tex_poster_periodic": ["ffffff", "b9c3c1"],
	"tex_sign_lab": ["ffffff", "b0bcbb"],
	"tex_sign_warning": ["ffffff", "c8c0b0"],
	"tex_clock": ["ffffff", "b9c1bd"],
	"tex_monitor_wave": ["ffffff", "ffffff"],
	"tex_monitor_data": ["ffffff", "ffffff"],
	"tex_keypad": ["ffffff", "c9d2d2"],
	"tex_book_spines": ["ffffff", "a9b0aa"],
	"tex_console_live": ["ffffff", "ffffff"],
	"tex_console_dead": ["ffffff", "ffffff"],
}

## Emission (hex, energy) per timeline for slots that glow.
const EMISSION := {
	"screen_glow": [["7fe0c0", 0.9], ["000000", 0.0]],
	"lamp_bulb": [["ffd890", 2.2], ["000000", 0.0]],
	"led_red": [["ff4a3a", 1.6], ["ff4a3a", 1.4]],
	"led_green": [["7dffad", 1.6], ["1f3a2a", 0.0]],
	"led_amber": [["ffb84a", 1.4], ["ff9a3a", 1.6]],
	"emergency": [["5a1a10", 0.2], ["ff5a3a", 2.4]],
	"crystal": [["86e6f0", 0.85], ["b48cff", 1.15]],
	"crystal_core": [["c8f8ff", 1.5], ["e2c8ff", 1.8]],
	"tex_monitor_wave": [["ffffff", 0.85], ["ffffff", 0.0]],
	"tex_monitor_data": [["ffffff", 0.8], ["ffffff", 0.0]],
	"tex_keypad": [["ffffff", 0.35], ["ffffff", 0.0]],
	"tex_console_live": [["ffffff", 0.9], ["c8f4ff", 0.75]],
	"led_go": [["7dffad", 1.8], ["7dffad", 1.6]],
}

## Broken-light flicker amount per timeline (0 = steady). See shaders/environment.gdshader.
const FLICKER := {
	"emergency": [0.0, 0.7],
	"led_amber": [0.0, 0.5],
	"led_red": [0.0, 0.35],
}

## Textures for textured slots: [past file, future file] under TEXTURES.
const TEXTURE_FILES := {
	"tex_paper_notes": ["paper_notes.png", "paper_notes_aged.png"],
	"tex_paper_graph": ["paper_graph.png", "paper_graph_aged.png"],
	"tex_paper_memo": ["paper_memo.png", "paper_memo_aged.png"],
	"tex_notebook": ["notebook_past.png", "notebook_future.png"],
	"tex_blackboard": ["blackboard_past.png", "blackboard_future.png"],
	"tex_poster_array": ["poster_array.png", "poster_array_aged.png"],
	"tex_poster_safety": ["poster_safety.png", "poster_safety_aged.png"],
	"tex_poster_periodic": ["poster_resonance.png", "poster_resonance_aged.png"],
	"tex_sign_lab": ["sign_lab.png", "sign_lab_aged.png"],
	"tex_sign_warning": ["sign_warning.png", "sign_warning_aged.png"],
	"tex_clock": ["clock_face.png", "clock_face_cracked.png"],
	"tex_monitor_wave": ["monitor_wave.png", "monitor_dead.png"],
	"tex_monitor_data": ["monitor_data.png", "monitor_cracked.png"],
	"tex_keypad": ["keypad_display.png", "keypad_display.png"],
	"tex_book_spines": ["book_spines.png", "book_spines.png"],
	"tex_console_live": ["monitor_wave.png", "monitor_data.png"],
	"tex_console_dead": ["monitor_dead.png", "monitor_cracked.png"],
}

## How strongly the Future grime, desaturation and cold cast apply. Imported (textured) models
## that have no slot of their own get these too.
const FUTURE_AGE := 0.75
const FUTURE_DESATURATE := 0.45
const FUTURE_COLD := Color("9fb8c0")
## Imported (KayKit) textures are brighter and more saturated than the hand-built props; this
## settles them into the warm academic Past palette.
const PAST_DESATURATE := 0.22
const PAST_WARM := Color("f4e8d2")

static var _cache: Dictionary = {}
static var _textures: Dictionary = {}


## The shared material for an imported material in the given timeline.
static func material_for(source: Material, future: bool) -> Material:
	var slot := slot_of(source)
	var texture: Texture2D = null
	if slot.is_empty():
		if source is BaseMaterial3D:
			texture = (source as BaseMaterial3D).albedo_texture
		if texture == null:
			return source
		slot = "imported"
	var key := "%s|%s|%d" % [slot, "f" if future else "p", texture.get_rid().get_id() if texture != null else 0]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.resource_name = "env_%s_%s" % [slot, "future" if future else "past"]
	_configure(material, slot, future, texture)
	_cache[key] = material
	return material


## A palette material by slot name, for meshes built in code.
static func material(slot: String, future: bool) -> Material:
	var key := "%s|%s|0" % [slot, "f" if future else "p"]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.resource_name = "env_%s_%s" % [slot, "future" if future else "past"]
	_configure(material, slot, future, null)
	_cache[key] = material
	return material


## Slot name from an imported material ("wood", "wood.001" -> "wood"), or "" if unknown.
static func slot_of(source: Material) -> String:
	if source == null:
		return ""
	var name := source.resource_name.to_lower()
	var dot := name.find(".")
	if dot > 0:
		name = name.substr(0, dot)
	return name if SLOTS.has(name) else ""


static func color(slot: String, future: bool) -> Color:
	return Color(SLOTS[slot][1 if future else 0]) if SLOTS.has(slot) else Color.WHITE


static func _configure(material: ShaderMaterial, slot: String, future: bool, texture: Texture2D) -> void:
	var albedo := color(slot, future) if SLOTS.has(slot) else (FUTURE_COLD if future else PAST_WARM)
	material.set_shader_parameter("paint_color", albedo)
	if TEXTURE_FILES.has(slot):
		texture = _load_texture(TEXTURE_FILES[slot][1 if future else 0])
	material.set_shader_parameter("use_texture", texture != null)
	if texture != null:
		material.set_shader_parameter("albedo_texture", texture)
	if EMISSION.has(slot):
		var glow: Array = EMISSION[slot][1 if future else 0]
		material.set_shader_parameter("emission_color", Color(glow[0]))
		material.set_shader_parameter("emission_energy", float(glow[1]))
		material.set_shader_parameter("emission_from_texture", TEXTURE_FILES.has(slot))
		material.set_shader_parameter("flicker", float(FLICKER.get(slot, [0.0, 0.0])[1 if future else 0]))
	var aged := future and not EMISSION.has(slot)
	material.set_shader_parameter("age", FUTURE_AGE if aged else 0.0)
	var desaturate := 0.0
	if slot == "imported":
		desaturate = FUTURE_DESATURATE if future else PAST_DESATURATE
	material.set_shader_parameter("desaturate", desaturate)


static func _load_texture(file: String) -> Texture2D:
	if not _textures.has(file):
		var path := TEXTURES + file
		_textures[file] = load(path) if ResourceLoader.exists(path) else null
	return _textures[file]
