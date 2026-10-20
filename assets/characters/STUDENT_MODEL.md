# Alternative 3D student model

The active player uses the detailed 2D rig in [student_2d/README.md](student_2d/README.md). `student_v2.glb` is the earlier original student mesh, retained as an alternative. It replaces the early primitive blockout. The model contains 10,168 triangles and 73 mesh parts in a compact, approximately 296 KiB binary glTF file. Surfaces use solid color materials and smooth vertex normals; no texture downloads or external model assets are required.

The silhouette combines a shaped jaw and cheeks, swept layered hair, a tailored field jacket with lapels and pockets, student ID, trousers, leather shoes, and a messenger bag. The scene uses a nominal 2.15-unit visual height. Local +Z faces forward and the origin is at the floor between the shoes.

## Files

- `student_v2.glb`: reusable model, named materials, and articulated node hierarchy. It can also be opened in a glTF-compatible modeling application.
- `student_v2_preview.png`: front, three-quarter, and back views rendered by Godot.
- `../../scenes/characters/student_model.tscn`: Godot wrapper for the model.
- `../../scenes/characters/student_player.tscn`: gameplay body, ground collision, shadow, and model instance.
- `../../scripts/characters/student_player.gd`: movement, smooth turning, procedural walking, and timeline colors.
- `../../tools/build_student_model.py`: complete source of the custom mesh topology, proportions, facial details, clothing, hierarchy, and materials. Uses Python's standard library.
- `../../tools/preview_student.gd`: renders the model review sheet.

## Editing and rebuilding

From the project root, run:

```sh
python3 tools/build_student_model.py
godot --headless --editor --path . --import --quit
godot --path . --script res://tools/preview_student.gd
```

The builder overwrites `student_v2.glb`. Edit the builder for reproducible shape changes. Save external modeling edits to a separate asset if they should survive a rebuild. Adjust `Visual Height` on the player to change visible scale independently of its collision footprint.

The runtime replaces imported material surfaces with the game's painted shader. Material names select the palette in `student_player.gd`; jacket, trim, and shadow colors respond to the Past/Future accent. Skin, eyes, hair, trousers, shoes, and accessories retain their own colors. Materials are independent per character instance.

## Animation and scope

This is an articulated mesh model with named arm, elbow, thigh, and knee pivots, animated procedurally in Godot. It does not contain a skeletal skin or baked animation clips. It turns toward camera-relative travel, swings opposing limbs, flexes the advancing knee, and settles to a neutral stance when movement stops. Both timelines currently use the same student model with different jacket colors; a separate older professor remains future work.

The previous generated 2D character sheet and its atlas resources remain in this directory as an alternative. They are not loaded by the active player.
