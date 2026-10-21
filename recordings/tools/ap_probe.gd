extends RefCounted
## Probe: dumps the interactables / player of whatever scene is loaded, then exits.

func run(ap) -> void:
	await ap.sec(float(ap.args.get("wait", "6")))
	ap.say("SCENE %s" % ap.scene().scene_file_path)
	ap.dump_interactables()
	var cam = ap.camera()
	if cam:
		ap.say("CAM %s fov=%s" % [str(cam.global_transform), cam.fov])
	await ap.screenshot("probe")
	ap.get_tree().quit()
