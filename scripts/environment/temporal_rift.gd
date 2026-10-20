extends LabDevice
## The temporal rift at the heart of the Signal Laboratory: a fractured crystal held in a
## containment emitter. Past: contained, fragments orbit in a tidy ring and the field breathes
## in cyan. Future: the field has broken open, fragments drift and tumble at random heights, the
## glow turns violet and flickers. When Puzzle 01 establishes the temporal radio link, the field
## flashes in both timelines and settles towards cyan, and in the Future the fragments are pulled
## back towards the core. The frequency puzzle's TemporalLinkPresenter drives the link lamp on the
## emitter (purple until linked, cyan after), exactly as it does everywhere else.

const LightBehaviour := preload("res://scripts/environment/light_behaviour.gd")
const FRAGMENT_COUNT := 9
const Catalog := preload("res://scripts/audio/sound_catalog.gd")

@onready var core: Node3D = $Core
@onready var fragments: Node3D = $Fragments
@onready var energy: MeshInstance3D = $Energy
@onready var motes: CPUParticles3D = $Motes
@onready var glow: LightBehaviour = $Glow
@onready var hum: AudioStreamPlayer3D = $Hum
@onready var ring: Node3D = find_child("Ring", true, false)

var _time: float = 0.0
var _burst: float = 0.0
var _calm: float = 0.0  # 0 = wild, 1 = settled by the echo lock (Future only)
var _seeds: Array[Vector4] = []
var _energy_material: ShaderMaterial


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3108
	for index in FRAGMENT_COUNT:
		# x: orbit phase, y: future radius, z: future height, w: tumble speed
		_seeds.append(Vector4(TAU * index / FRAGMENT_COUNT, rng.randf_range(0.7, 1.75), rng.randf_range(0.7, 3.5), rng.randf_range(0.4, 1.6)))
	_energy_material = energy.material_override as ShaderMaterial
	super()
	PuzzleManager.puzzle_completed.connect(_on_audio_completed)
	var definition: Dictionary = Catalog.definitions().get("rift_hum", {})
	var entry := Catalog.load_entry(definition)
	hum.stream = Catalog.loop_stream(entry["stream"])
	hum.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
	hum.volume_db = float(entry.get("volume_db", -27.0))
	hum.unit_size = 3.5
	hum.max_distance = 17.0
	if hum.stream != null:
		hum.play()



func _exit_tree() -> void:
	hum.stop()
	hum.stream = null


func _state_changed(previous: Dictionary) -> void:
	if linked() and not Rules.link_established(previous) and not previous.is_empty():
		_burst = 1.0


func _show_state(_animate: bool) -> void:
	if not linked():
		_calm = 0.0
	elif _calm == 0.0 and not _animate:
		_calm = 1.0
	var settled := linked()
	_energy_material.set_shader_parameter("inner_color", Color("1f7f8c") if not future or settled else Color("4a2f86"))
	_energy_material.set_shader_parameter("outer_color", Color("86c9d1") if not future else (Color("86c9d1") if settled else Color("8c69c1")))
	_energy_material.set_shader_parameter("fracture", 0.0 if not future else (0.4 if settled else 0.85))
	_energy_material.set_shader_parameter("speed", 0.6 if not future else 1.6)
	motes.amount = 24 if not future else 64
	motes.initial_velocity_max = 0.35 if not future else 0.9
	motes.color = Color("9fe6ee") if not future or settled else Color("b48cff")
	glow.light_color = Color("86c9d1") if not future or settled else Color("8c69c1")
	glow.mode = LightBehaviour.Mode.PULSE if not future else LightBehaviour.Mode.FLICKER
	if ring != null:
		ring.rotation = Vector3.ZERO if not future else Vector3(deg_to_rad(11.0), 0.0, deg_to_rad(-7.0))
	# The Future field is unstable: its hum sags in pitch.
	hum.pitch_scale = 1.0 if not future or settled else 0.76


func _process(delta: float) -> void:
	_time += delta
	_burst = maxf(0.0, _burst - delta * 0.7)
	if linked():
		_calm = minf(1.0, _calm + delta * 0.35)
	var wild := 1.0 if future else 0.0
	wild *= 1.0 - _calm * 0.7
	core.rotation.y += delta * (0.35 + wild * 0.8)
	core.position.y = 1.35 + sin(_time * 1.3) * 0.05
	var shell := (0.62 if not future else 1.05) * (1.0 + _burst * 0.6 - _calm * 0.25 * float(future))
	energy.scale = Vector3.ONE * shell * (1.0 + 0.04 * sin(_time * 2.1))
	_energy_material.set_shader_parameter("burst", _burst)
	_energy_material.set_shader_parameter("intensity", (0.5 if not future else 0.75) + _burst * 1.2)
	glow.base_energy = (1.4 if not future else 2.2) * (1.0 + _burst * 1.2)
	for index in fragments.get_child_count():
		var fragment := fragments.get_child(index) as Node3D
		var info := _seeds[index % _seeds.size()]
		var phase := info.x + _time * (0.45 + wild * 0.2 * info.w)
		var radius := lerpf(0.82, info.y, wild)
		var height := lerpf(2.25 + 0.06 * sin(_time * 1.7 + info.x), info.z + 0.25 * sin(_time * info.w + info.x), wild)
		fragment.position = Vector3(cos(phase) * radius, height, sin(phase) * radius)
		if wild > 0.0:
			fragment.rotation += Vector3(0.7, 1.1, 0.4) * delta * info.w * wild
		else:
			fragment.rotation = Vector3(0.0, -phase, deg_to_rad(18.0))


func _on_interacted(_actor: Node, _role: String, _interactable: Node) -> void:
	if linked():
		toast("The link holds. The rift is quieter now, carrying both radios' voices across the years.")
	elif future:
		toast("The containment field is broken. Shards of the core drift through the room, humming on a frequency you can feel.")
	else:
		toast("Containment stable. The core sings on a low carrier. A label reads: \"Both handhelds on before calibrating.\"")
	sfx(&"rift_activate", Vector3(0, 1.0, 1.6))

func _on_audio_completed(puzzle_id: String) -> void:
	if puzzle_id == Rules.ID:
		sfx(&"rift_stabilize", Vector3(0, 1.5, 0))
