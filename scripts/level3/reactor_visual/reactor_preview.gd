extends Node3D
## Standalone art review. Does not instantiate the room or submit puzzle actions.
const REACTOR := preload("res://scenes/level3/reactor_visual/reactor_visual.tscn")
const PHASES := ["discovery", "armed", "power", "alignment", "synchronization", "ending", "overload"]
const ENDINGS := ["trust", "student_override", "professor_override", "paradox"]
var reactor: Node3D
var camera: Camera3D
var _status: Label
var _ending_index: int = 0
var _game_camera: bool = false
var _key: DirectionalLight3D
var _floor_material: StandardMaterial3D
var _environment: Environment
var _controls: CanvasLayer
var _charge_slider: HSlider


func _ready() -> void:
	var env := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("151e25")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("b7cad0")
	_environment.ambient_light_energy = 0.65
	env.environment = _environment
	add_child(env)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-40, -32, 0)
	_key.light_color = Color("ffe2b8")
	_key.light_energy = 1.05
	add_child(_key)
	_floor_material = StandardMaterial3D.new()
	_floor_material.albedo_color = Color("666b61")
	_floor_material.roughness = 0.95
	box(Vector3(0, -0.09, 0), Vector3(18.4, 0.16, 14.4), _floor_material)
	var grid_mat := StandardMaterial3D.new()
	grid_mat.albedo_color = Color("3d4948")
	for x in range(-9, 10): box(Vector3(x, -0.006, 0), Vector3(0.014, 0.008, 14.4), grid_mat)
	for z in range(-7, 8): box(Vector3(0, -0.006, z), Vector3(18.4, 0.008, 0.014), grid_mat)
	# Exact nearby station positions from core_rules, drawn as low clearance proxies.
	var proxy_mat := StandardMaterial3D.new()
	proxy_mat.albedo_color = Color("778680")
	for at: Vector3 in [Vector3(-2.5, 0, 0), Vector3(2.5, 0, 0), Vector3(-3, 0, -3), Vector3(-3.5, 0, 3), Vector3(3.5, 0, 3), Vector3(0, 0, 4.5)]:
		box(at+Vector3(0, 0.37, 0), Vector3(0.70, 0.74, 0.45), proxy_mat)
		box(at+Vector3(0, 0.77, -0.02), Vector3(0.70, 0.06, 0.50), grid_mat)
	reactor = REACTOR.instantiate()
	add_child(reactor)
	camera = Camera3D.new()
	camera.fov = 48
	camera.current = true
	add_child(camera)
	set_gameplay_camera(false)
	_build_ui()
	refresh()


func box(at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)


func set_gameplay_camera(enabled: bool, player_at: Vector3 = Vector3(0, 0, 5.9)) -> void:
	_game_camera = enabled
	var focus := player_at+Vector3(0, 0.7, -2) if enabled else Vector3(0, 2.0, 0)
	var distance := 20.0 if enabled else 13.8
	var pitch := deg_to_rad(35.0)
	camera.position = focus+Vector3(0, sin(pitch)*distance, cos(pitch)*distance)
	camera.rotation = Vector3(-pitch, 0, 0)
	if is_instance_valid(_status): refresh()


func set_timeline(value: String) -> void:
	reactor.set_timeline(value)
	_key.light_color = Color("b5d9ec") if value == "future" else Color("ffe2b8")
	_floor_material.albedo_color = Color("243b4b") if value == "future" else Color("666b61")
	refresh()


func _build_ui() -> void:
	_controls = CanvasLayer.new()
	_controls.name = "PreviewControls"
	add_child(_controls)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	_controls.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.085, 0.92)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	stack.add_child(_status)
	var keys := Label.new()
	keys.text = "1-7  phases    T  timeline    E  ending\nC  gameplay camera    M  motion    V  effects\nS  shutdown/startup    Up/Down  charge"
	keys.add_theme_font_size_override("font_size", 14)
	stack.add_child(keys)
	var slider := HSlider.new()
	_charge_slider = slider
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = reactor.charge_ratio
	slider.value_changed.connect(func(value: float) -> void: reactor.set_charge_ratio(value); refresh())
	stack.add_child(slider)


func refresh() -> void:
	if not is_instance_valid(_status): return
	if is_instance_valid(_charge_slider): _charge_slider.set_value_no_signal(reactor.charge_ratio)
	_status.text = "THE OTHER ME / TEMPORAL ASSEMBLY\n%s   /   %s   /   charge %d%%\n%s%s" % [reactor.timeline.to_upper(), reactor.reactor_phase.to_upper(), roundi(reactor.charge_ratio*100), reactor.ending_id.to_upper()+"   " if reactor.ending_id != "" else "", "GAMEPLAY 35° / 20 m" if _game_camera else "DETAIL 35° / 13.8 m"]


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var code: int = event.keycode
	if code >= KEY_1 and code <= KEY_7:
		reactor.set_reactor_phase(PHASES[code-KEY_1])
	elif code == KEY_T: set_timeline("future" if reactor.timeline == "past" else "past")
	elif code == KEY_E:
		reactor.play_ending(ENDINGS[_ending_index])
		_ending_index = (_ending_index+1)%ENDINGS.size()
	elif code == KEY_C: set_gameplay_camera(not _game_camera)
	elif code == KEY_M: reactor.set_motion_enabled(not reactor.motion_enabled)
	elif code == KEY_V: reactor.set_effects_enabled(not reactor.effects_enabled)
	elif code == KEY_S:
		if reactor._startup_progress > 0.5: reactor.play_shutdown()
		else: reactor.play_startup()
	elif code == KEY_UP: reactor.set_charge_ratio(reactor.charge_ratio+0.1)
	elif code == KEY_DOWN: reactor.set_charge_ratio(reactor.charge_ratio-0.1)
	refresh()
