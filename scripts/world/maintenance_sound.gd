extends Node
## Maintenance corridor audio: a quiet industrial bed, two positional machines, sparse
## details and one sound per confirmed puzzle result. Every cue follows a PuzzleManager
## snapshot or a physical animation; nothing here changes puzzle state.

const Rules := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const Catalog := preload("res://scripts/audio/sound_catalog.gd")

## Actions whose confirmed result carries its own sound, so the generic click is skipped.
const OWNED_ACTIONS := ["isolate_service", "charge_battery", "reserve_power", "repair_bypass", "read_archive",
	"preserve_recording", "extract_cell", "authorize_core", "release_door", "arm_anchor"]
const DETAIL_SPACING := {"clank": [18.0, 35.0], "steam": [30.0, 60.0]}

var room: Node3D
var audio: AudioDirector
var events: Array[StringName] = []

var _machine: AudioStreamPlayer3D
var _buzz: AudioStreamPlayer3D
var _buzz_target := -80.0
var _details: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func bind(owner_room: Node3D, director: AudioDirector) -> void:
	room = owner_room
	audio = director
	_rng.randomize()
	var definitions := Catalog.definitions()
	_machine = _emitter(definitions[&"maint_machine_loop"], "BoilerMachinery")
	_buzz = _emitter(definitions[&"maint_buzz_loop"], "ElectricalBuzz")
	_buzz.volume_db = -80.0
	for kind in DETAIL_SPACING:
		_details[kind] = _rng.randf_range(DETAIL_SPACING[kind][0] * 0.4, DETAIL_SPACING[kind][1] * 0.7)


func _emitter(definition: Dictionary, node_name: String) -> AudioStreamPlayer3D:
	var entry := Catalog.load_entry(definition)
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.stream = Catalog.loop_stream(entry["stream"])
	player.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
	player.volume_db = float(definition.get("volume_db", -24.0))
	player.unit_size = float(definition.get("unit_size", 6.0))
	player.max_distance = float(definition.get("max_distance", 22.0))
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player


## Starts the timeline's industrial bed and puts the machines at their props.
func set_role(role: String) -> void:
	audio.start_ambience(StringName("maint_bed_" + role), 2.0)
	var machine: Node3D = room.get_node_or_null("Layout/Shared/CoreMachine")
	var routes: Node3D = room.get_node_or_null("Layout/Shared/PowerRoutes")
	_machine.global_position = (machine.global_position if machine != null else room.player.global_position) + Vector3(0, 1.0, 0)
	_buzz.global_position = (routes.global_position if routes != null else room.player.global_position) + Vector3(0, 0.8, 0)
	if AudioServer.get_driver_name() != "Dummy" and not _machine.playing:
		_machine.play()


func _process(delta: float) -> void:
	if room == null or room._paused or not room._initialized:
		return
	_buzz.volume_db = lerpf(_buzz.volume_db, _buzz_target, 1.0 - exp(-delta / 0.6))
	if AudioServer.get_driver_name() != "Dummy":
		if _buzz.volume_db > -60.0 and not _buzz.playing:
			_buzz.play()
		elif _buzz.volume_db <= -60.0 and _buzz.playing:
			_buzz.stop()
	for kind in DETAIL_SPACING:
		_details[kind] -= delta
		if _details[kind] > 0.0:
			continue
		_details[kind] = _rng.randf_range(DETAIL_SPACING[kind][0], DETAIL_SPACING[kind][1])
		var angle := _rng.randf() * TAU
		var spot: Vector3 = room.player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(6.0, 12.0)
		spot.y = _rng.randf_range(0.5, 2.8)
		_play_at(&"maint_detail" if kind == "clank" else &"maint_steam_hiss", spot)


func owns_action(action: String) -> bool:
	return action in OWNED_ACTIONS


## One cue per confirmed change, heard by both players because every peer receives the same snapshot.
func on_state(previous: Dictionary, state: Dictionary) -> void:
	_buzz_target = -26.0 if state.get("battery_ready", false) else -80.0
	if previous.is_empty():
		return
	if not previous.service_isolated and state.service_isolated:
		_at(&"maint_lever_clunk", "Service")
	if not previous.battery_ready and state.battery_ready:
		_at(&"maint_crank", "Battery")
		_later(0.85, &"maint_charge_latch", "Battery")
		_later(1.0, &"maint_power_surge", "")
	if previous.priority != state.priority and state.priority != "shared":
		_at(&"maint_reserve_lever", "Reserve" + String(state.priority).capitalize())
	for who in ["past", "future"]:
		if not previous["bypass_" + who] and state["bypass_" + who]:
			_at(&"maint_fuse_seat", "Bypass" + who.capitalize())
		if not previous["anchor_" + who] and state["anchor_" + who]:
			_at(&"maint_anchor_latch", "Anchor")
	if not previous.archive_read and state.archive_read:
		_at(&"maint_archive", "Archive")
	if previous.recording == "pending" and state.recording == "preserved":
		_at(&"maint_recorder_export", "Recorder")
	elif previous.recording == "pending" and state.recording == "erased":
		_at(&"maint_cell_pull", "Recorder")
	if not previous.core_authorized and state.core_authorized:
		_at(&"maint_keypad_authorize", "Keypad")
		_later(0.45, &"maint_gate_open", "PastGate")
	if not previous.future_release_open and state.future_release_open:
		_at(&"maint_release_wheel", "Release")
		_later(0.9, &"maint_gate_open", "FutureGate")
	var both_before: bool = previous.anchor_past and previous.anchor_future
	if not both_before and state.anchor_past and state.anchor_future:
		_later(0.3, &"maint_anchor_complete", "")
	if state.battery_ready and previous.battery_ready and Rules.has_power(previous, room.role) and not Rules.has_power(state, room.role):
		_log(&"maint_power_down")
		audio.play_sfx(&"maint_power_down")


## Hatch and platform motion from the storage room's own tween, in the order it moves.
func on_lift(kind: StringName, index: int) -> void:
	var lift: Node3D = room.storage.lifts[index]
	_play_at(kind, lift.global_position + Vector3(0, 0.4, 0))


func on_power_lost() -> void:
	_log(&"maint_power_down")
	audio.play_sfx(&"maint_power_down")


func _at(id: StringName, device: String) -> void:
	_play_at(id, _position(device))


func _later(seconds: float, id: StringName, device: String) -> void:
	get_tree().create_timer(seconds).timeout.connect(_play_device.bind(id, device))


func _play_device(id: StringName, device: String) -> void:
	if device.is_empty():
		_log(id)
		audio.play_sfx(id)
	else:
		_at(id, device)


func _play_at(id: StringName, spot: Vector3) -> void:
	_log(id)
	audio.play_world_sfx(id, spot)


func _position(device: String) -> Vector3:
	match device:
		"PastGate": return room.get_node("Layout/PastOnly/CoreGate").global_position
		"FutureGate": return room.get_node("Layout/FutureOnly/CoreGate").global_position
	var target: Node3D = room.devices.get(device)
	return (target.global_position if target != null else room.player.global_position) + Vector3(0, 1.0, 0)


func _log(id: StringName) -> void:
	events.append(id)
	if events.size() > 96:
		events.pop_front()


func _exit_tree() -> void:
	events.clear()
	for player in [_machine, _buzz]:
		if is_instance_valid(player):
			player.stop()
