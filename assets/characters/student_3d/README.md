# Reference-led student character

The active Godot player now uses newly authored visible geometry reconstructed from all four images in `../references/`. The original references and all KayKit source GLBs and licenses are retained. No mannequin geometry is used in the finished character.

Open `review/index.html` for the four side-by-side comparisons, six-view turnaround, animation playback, sampled poses, and actual gameplay/studio captures. Godot comparisons show the game renderer; the expandable Blender comparisons show the same geometry under soft studio lighting. These are actual renders, not repainted reference images.

## Deliverables

- `student.glb`: the active, standalone skinned character, materials, 23 bones, and all 77 previously available clips.
- `source/student.blend`: editable named mesh parts, skin groups, armature, 77 animation actions, materials, packed copies of all four references, embedded build scripts, and a studio camera/light setup. The reference collection is hidden initially. NLA tracks are muted for the neutral preview.
- `manifest.json`: geometry counts, part ranges, palette, bone retarget map, animation provenance, source/reference SHA-256 hashes, and floor-clearance curves.
- `REFERENCE_STUDY.md`: observed features, proportions, laterality, and conservative interpretation of differences between views.
- `VALIDATION.md`: checks performed, visual iterations, and remaining limitations.
- `review/`: front/back/both sides/two three-quarter views; comparisons; 18-frame playback sequences plus three reverse-angle samples for each reviewed clip; lab and studio captures.

The materials use solid PBR base colors, roughness, and limited metal response. Hair locks, clothing construction, eyes, watch dial, badge, seams, laces, and buckles are geometry. No external texture files are required by the GLB. Original references are packed in the Blender file for editing convenience, not used as character textures.

## Rebuild

Run from the project root. Python 3.13 is used by the supplied environment. NumPy and Pillow are needed for generation/review; Blender's `bpy` module is needed only for the editable Blender file, Blender export, and studio renders. Exact tested versions are in `tools/requirements-character.txt`.

```powershell
# After creating a Python 3.13 virtual environment at .venv:
& .venv/Scripts/python.exe -m pip install -r tools/requirements-character.txt
& .venv/Scripts/python.exe tools/build_student_kaykit.py
& .venv/Scripts/python.exe tools/student_blender.py --create
& .venv/Scripts/python.exe tests/student_3d_assets.py

$GodotBin = 'C:/path/to/Godot_console.exe'
& $GodotBin --headless --editor --path . --import --quit
& $GodotBin --headless --path . --script res://tests/student_3d.gd
& $GodotBin --headless --path . --script res://tests/spawn_area.gd
& $GodotBin --path . --script res://tools/render_student_review.gd
& .venv/Scripts/python.exe tools/student_blender.py --render
& .venv/Scripts/python.exe tools/assemble_student_review.py

$env:GODOT_BIN = $GodotBin
& .venv/Scripts/python.exe tests/run_lan_smoke.py
```

The rendered review requires a graphics device; do not run its Godot command with `--headless`. `-- --neutral-only` produces the six neutral views only. `-- --no-game` omits the lab captures. Ground-contact correction is part of the build, not a runtime dependency. The `.blend` and review folders are excluded from Godot imports.

`--create` reconstructs the Blender file from procedural source and replaces any edits in that file. To retain hand edits, save them and use this route instead:

```powershell
& .venv/Scripts/python.exe tools/student_blender.py --export
& .venv/Scripts/python.exe tests/student_3d_assets.py
# Reimport in Godot and rerun the review commands above.
```

The Blender exporter reads the `Character meshes` collection, vertex groups, and material assignments. It preserves gameplay node paths and rebuilds the same animation library. Solid material Base Color, Roughness, and Metallic values are exported from the Blender Principled shader. For procedural rebuilds, edit `PALETTE` in `tools/build_student_kaykit.py`. Image texture node graphs are not part of this solid-material exporter. Edit the rig's rest coordinates in `tools/student_rig.py` and rebuild; direct Blender rig/action edits are deliberately not exported by the geometry-only route.

Authoring modules:

- `tools/build_student_kaykit.py`: geometry and palette, including hair/scalp surfaces and continuous forearm/palm forms.
- `tools/student_mesh.py`: mesh primitives, normals, normalized weights, materials, and GLB packaging.
- `tools/student_rig.py`: proportion mapping and translation retarget.
- `tools/ground_student_clips.py`: sampled skinned-surface clearance for lying/death/crawling contact clips.
- `tools/student_blender.py`: editable source creation, geometry export, and six-view Cycles rendering.
- `tools/render_student_review.gd` / `tools/assemble_student_review.py`: Godot evidence and comparison assembly.

## Animation and gameplay

The source medium rig was inspected directly: six separate mannequin meshes; rigid head weights; two-influence arm blends; mostly two/three-influence torso/leg blends; named hand slots. The new character follows these useful weighting and material principles while using its own visible geometry and reference proportions. Source mesh statistics are in `review/kaykit_mesh_study.json`.

The rig retains KayKit's hierarchy, bone axes, names, and both hand slots. Rest joint locations are adjusted to the reference-led body. Inverse binds are regenerated. Rotation and scale samples and clip timing remain exact; local translations use `target_rest + (source_sample - source_rest) * length_ratio`. Floor-contact clips additionally receive a minimal vertical root correction sampled from actual skinned vertices at 60 Hz. The original animation files are never modified. The source combat/special packs remain present; the existing runtime library remains 77 clips.

The active scene remains `scenes/characters/student_3d_player.tscn`. Mesh and skeleton paths, material tinting, animation names, hand attachments, action completion, studio isolation, and networking are preserved. Runtime height now comes from the imported mesh bounds, keeping the player at its existing gameplay height when authored proportions change.

WASD/arrows move; Shift runs; F interacts; I inspects; E picks up/puts down the demonstration document; R respawns; F2 opens the character studio. The studio exposes all 77 clips and supports view rotation, playback speed, pause, and scrubbing. All older 2D assets and scenes remain available.
