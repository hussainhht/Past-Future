# Professor / age 49

An original professor variant of the student, modeled against all four images in `../references/49/`. The familiar head, body proportions, hand shapes, and KayKit rig connect him to his younger self. The coat, waistcoat, collar, aging details, stubble, and gray hair treatment are authored in `tools/build_professor.py`.

- `source/professor.blend`: editable named mesh parts, skin weights, armature, all 77 actions, packed age-49 references, and studio lighting. Open this file in Blender and save professor edits here. NLA tracks start muted for the neutral pose; select the rig and an Action to preview animation.
- `professor.glb`: separate Godot model with the same 23-bone rig and 77 animations as the student.
- `manifest.json`: geometry counts, part names, material palette, rig/retarget information, reference hashes, and animation provenance.
- `../../../scenes/characters/professor_3d_player.tscn`: player scene using the professor GLB and the shared movement/action controller. Internal `Student` and `Student_SkinnedMesh` names are retained for controller compatibility.
- `../../../scenes/characters/professor_3d_studio.tscn`: standalone animation studio. Open it in Godot and press F6 to inspect the professor, switch clips, turn the view, or scrub a pose.
- `review/`: actual Godot neutral views, comparison sheets, and sampled animation playback. `preview.png` is the turnaround overview.

## Appearance

The professor has a long navy coat with lining, front opening, rear vent, notched lapels, lower patch pockets, horn buttons, worn cuffs, right-sleeve tears, and subtle hem dust. A dark waistcoat and slate shirt replace the student's henley. Pens sit in the left breast pocket. Trousers and boots are charcoal/black. The original watch remains on his left wrist with a brown strap; the satchel, crossbody strap, student ID, and rolled student sleeves are removed. Gray temples/nape, a short beard/moustache, subdued age lines, and a guarded mouth distinguish the older face.

`tools/fit_professor_face.py` fits the eyes, brows, mouth, moustache, and fine cheek/eye lines to the actual skin triangles. Catchlights follow the fitted eye surfaces. Details are partially embedded with shallow visible relief, and retain their original facial placement and head-bone weights. The previously recessed forehead lines stay behind the fringe.

`tools/fit_professor_clothes.py` fits 47 clothing details to their supporting layers: waistcoat to shirt/trousers, lapels and pockets to coat, buttons to fabric, and trim to its parent part. Supporting skin weights are transferred to keep the details moving with the cloth. Broad panels are subdivided to follow curvature, and front layers have 2.5 mm of clearance to prevent edge flicker. Coat openings, rear vent, sleeves, garment thickness, and the facial corrections are preserved.

See `REFERENCE_STUDY.md` for the interpretation of the four images. This is a stylized reconstruction, not an exact sculpt match: individual hair locks, facial contours, and cloth wrinkles remain approximate. There is no cloth simulation; compressed or extreme poses can produce local intersections. The coat tails use pelvis/thigh blending rather than additional bones.

The existing lab and its F2 studio still use the student. The professor has its own model/player/studio scenes and can be reviewed independently before assigning him to the Future timeline.

## Rebuild and edit

From the project root:

```sh
python3 tools/build_professor.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/professor_blender.py -- --create
godot --headless --editor --path . --import --quit
python3 tests/student_3d_assets.py --character professor
godot --headless --path . --script res://tests/student_3d.gd -- --professor
godot --path . res://scenes/characters/professor_3d_studio.tscn
```

`--create` replaces manual Blender changes with the procedural source. To export geometry/material edits saved in `source/professor.blend`, use the separate professor route:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/professor_blender.py -- --export
```

This route exports geometry, skin weights, and solid materials. It retains the source animation mapping; edited animation keyframes and direct rest-bone edits are not exported. Student generation/export commands still target the student and should not be used to export the professor.

For review renders (requires a display), run:

```sh
godot --path . --script res://tools/render_student_review.gd -- --professor --no-game
python3 tools/assemble_professor_review.py
```

KayKit animation sources and their CC0 license remain shared in `../../third_party/kaykit_character_animations/`.
