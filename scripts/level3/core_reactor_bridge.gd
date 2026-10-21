extends Node
## Optional presentation adapter. No resource path is loaded speculatively; the
## room may receive a completed PackedScene after the visual agent verifies it.
## Validation, deadlines and ending resolution always stay in PuzzleManager.

const API := {"set_reactor_phase": TYPE_STRING, "set_charge_ratio": TYPE_FLOAT,
	"trigger_overload": TYPE_NIL, "play_ending": TYPE_STRING}
const MODULE_PATH := "res://scenes/level3/reactor_visual/reactor_visual.tscn"
const MODULE_RESOURCES := ["res://scripts/level3/reactor_visual/reactor_visual.gd",
	"res://assets/environments/level3/reactor_visual/temporal_assembly.glb",
	"res://shaders/level3/reactor_visual/temporal_metal.gdshader",
	"res://shaders/level3/reactor_visual/temporal_energy.gdshader",
	"res://shaders/level3/reactor_visual/temporal_current.gdshader"]
var modules: Dictionary = {}
var last_phase := ""
var last_ending := ""
var last_attempt := -1
var integration_status := "Stock reactor active; no verified visual scene assigned."
var _active_role := ""
var _effects: Dictionary = {}


func verified_scene() -> PackedScene:
	# These completed resources were inspected and verified together. An absent
	# module (including any missing dependency) leaves the stock room loadable.
	if not ResourceLoader.exists(MODULE_PATH): return null
	for resource: String in MODULE_RESOURCES:
		if not ResourceLoader.exists(resource): return null
	return load(MODULE_PATH) as PackedScene


func setup(worlds: Dictionary, packed: PackedScene = null) -> bool:
	if packed == null: return false
	var staged := {}
	for timeline: String in worlds:
		var instance: Node = packed.instantiate()
		if not _valid_api(instance):
			instance.free()
			for candidate: Node in staged.values(): candidate.free()
			integration_status = "Visual scene rejected: expected Node3D and four public API methods. Stock reactor retained."
			return false
		staged[timeline] = instance
	for timeline: String in staged:
		var world: Node3D = worlds[timeline]
		var module: Node3D = staged[timeline]
		module.name = "ReactorVisual"
		# Hide the central stock assembly, retaining its physical collision.
		for child in world.get_children():
			if child is MeshInstance3D and child.mesh is CylinderMesh and child.position.is_equal_approx(Vector3(0, 0.75, 0)):
				child.hide()
			elif child is StaticBody3D and child.position.length() < 0.1:
				for mesh: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
					if mesh.get_aabb().size.length() < 5.0: mesh.hide()
		world.core.hide()
		for label: Label3D in world.find_children("*", "Label3D", true, false):
			if label.text.begins_with("TEMPORAL CORE"): label.hide()
		for ring: MeshInstance3D in world.rings: ring.hide()
		# The old rift animation sets visibility each frame, so parent visibility
		# provides a permanent cutover without changing the world's script.
		var legacy_effects := Node3D.new()
		legacy_effects.name = "LegacyReactorEffects"
		world.add_child(legacy_effects)
		for shard: MeshInstance3D in world.rifts: shard.reparent(legacy_effects)
		legacy_effects.hide()
		world.reactor_light.hide()
		world.add_child(module)
		if module.has_method("set_timeline"): module.call("set_timeline", timeline)
		modules[timeline] = module
	integration_status = "Verified reactor API mounted in both timelines; stock assembly hidden."
	return true


func _valid_api(instance: Node) -> bool:
	if not instance is Node3D: return false
	for method: String in API:
		if not instance.has_method(method): return false
		var found := false
		for description: Dictionary in instance.get_method_list():
			if description.name != method: continue
			var args: Array = description.args
			if API[method] == TYPE_NIL:
				found = args.is_empty()
			else:
				found = args.size() == 1 and int(args[0].type) in [TYPE_NIL, API[method]]
		if not found: return false
	return true


func apply_state(state: Dictionary, challenge_seconds: float = 150.0) -> void:
	var fresh: bool = last_attempt != state.attempt
	var phase: String = {"DISCOVERY": "discovery", "STAGE_A": "armed", "STAGE_B": "alignment", "STAGE_C": "synchronization", "OVERLOAD": "overload", "ENDING": "ending"}.get(state.stage, "discovery")
	if state.stage == "STAGE_A" and (state.receiver or state.coils != [0, 0, 0]): phase = "power"
	if state.stage == "STAGE_B" and state.anchor and state.origin: phase = "synchronization"
	var phase_changed: bool = fresh or last_phase != phase
	for module: Node in modules.values():
		if phase_changed: module.call("set_reactor_phase", phase)
		module.call("set_charge_ratio", clampf(1.0 - float(state.remaining) / maxf(challenge_seconds, 0.001), 0.0, 1.0))
		if phase_changed and state.stage == "OVERLOAD": module.call("trigger_overload")
		if state.stage == "ENDING" and (fresh or last_ending != state.ending): module.call("play_ending", String(state.ending))
	last_attempt = state.attempt
	last_phase = phase
	last_ending = state.ending


func sync_preferences(worlds: Dictionary, role: String) -> void:
	for timeline: String in modules:
		var module: Node = modules[timeline]
		if _active_role != role and module.has_method("set_active"): module.call("set_active", timeline == role)
		var enabled: bool = worlds[timeline].effects_enabled
		if _effects.get(timeline) != enabled and module.has_method("set_effects_enabled"):
			module.call("set_effects_enabled", enabled)
		_effects[timeline] = enabled
	_active_role = role
