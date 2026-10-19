@tool
extends StaticBody3D
## Painted 3D furniture with a grounded, world-aligned collision footprint.

const MODELS: Array[PackedScene] = [preload("res://scenes/props/table_visual.tscn"), preload("res://scenes/props/cabinet_visual.tscn"), preload("res://scenes/props/console_visual.tscn")]
const PAINT: Shader = preload("res://shaders/painted_prop.gdshader")
const PAST_COLORS: Dictionary = {"body": Color("889181"), "top": Color("bbb693"), "frame": Color("4b5b55"), "drawer": Color("748475"), "handle": Color("d6cfaa"), "paper": Color("e3dbb6"), "screen": Color("192f36"), "signal": Color("c0ddbb")}
const FUTURE_COLORS: Dictionary = {"body": Color("557c86"), "top": Color("90b7bd"), "frame": Color("304c59"), "drawer": Color("496d7b"), "handle": Color("adcdd3"), "paper": Color("becfd0"), "screen": Color("102a36"), "signal": Color("80d9e4")}

@export_enum("Table", "Cabinet", "Console") var kind: int = 0:
	set(value):
		kind = value
		if is_node_ready():
			_configure()
@export var future: bool = false:
	set(value):
		future = value
		if is_node_ready():
			_apply_tint()


func _ready() -> void:
	_configure()


func _configure() -> void:
	for child in $Visual.get_children():
		$Visual.remove_child(child)
		child.queue_free()
	$Visual.add_child(MODELS[kind].instantiate())
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.32, 1.5, 0.8) if kind == 0 else Vector3(1.65, 3.2 if kind == 1 else 2.45, 0.8)
	$Footprint.shape = shape
	$Footprint.position.y = shape.size.y / 2.0
	$Shadow.scale = Vector3(2.3, 1, 0.60) if kind == 0 else Vector3(1.0, 1, 0.60)
	_apply_tint()


func _apply_tint() -> void:
	var palette := FUTURE_COLORS if future else PAST_COLORS
	for piece in $Visual.find_children("*", "MeshInstance3D", true, false):
		var material := piece.material_override as ShaderMaterial
		if material == null:
			material = ShaderMaterial.new()
			material.shader = PAINT
			piece.material_override = material
		material.set_shader_parameter("paint_color", palette[piece.get_meta("palette_slot", "body")])
