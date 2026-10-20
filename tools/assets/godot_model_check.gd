extends SceneTree
## Run: godot --headless --path . --script res://tools/assets/godot_model_check.gd
## Loads every GLB under res://assets/environment/models and reports what Godot actually imported.
## validate_assets.py --godot runs this after a project import.

const MODELS := "res://assets/environment/models"

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _glb_files(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() == "glb":
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_glb_files(folder.path_join(sub)))
	return found


func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices = arrays[Mesh.ARRAY_INDEX]
		count += (indices.size() if indices != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return count


func _run() -> void:
	var paths := _glb_files(MODELS) if DirAccess.dir_exists_absolute(MODELS) else PackedStringArray()
	for path in paths:
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("CANNOT LOAD " + path)
			failures += 1
			continue
		var instance := scene.instantiate() as Node3D
		root.add_child(instance)
		var bounds := AABB()
		var started := false
		var triangles := 0
		var textured := 0
		for node in instance.find_children("*", "MeshInstance3D", true, false):
			var piece := node as MeshInstance3D
			if piece.mesh == null:
				continue
			var box := piece.global_transform * piece.get_aabb()
			bounds = box if not started else bounds.merge(box)
			started = true
			triangles += _triangles(piece.mesh)
			for surface in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface) as BaseMaterial3D
				if material != null and material.albedo_texture != null:
					textured += 1
		if not started or triangles == 0:
			push_error("NO MESH " + path)
			failures += 1
		print("%s: triangles=%d textured_surfaces=%d size=(%.3f, %.3f, %.3f) min_y=%.3f" % [
			path.trim_prefix("res://"), triangles, textured, bounds.size.x, bounds.size.y, bounds.size.z, bounds.position.y])
		instance.queue_free()
	print("GODOT MODEL CHECK: ", "PASS" if failures == 0 else "FAIL", " (", paths.size(), " models, ", failures, " failures)")
	quit(0 if failures == 0 else 1)
