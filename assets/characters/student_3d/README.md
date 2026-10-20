# Original 3D student with KayKit animations

The active player uses an original skinned low-poly mesh, authored in `tools/build_student_kaykit.py`, with the actual KayKit `Rig_Medium` skeleton and CC0 animation tracks. No KayKit character mesh was reused. All visible face, hair, clothing, hands, boots, ID, watch, and satchel geometry is generated from the source in this repository.

The design translates the supplied [student reference](../references/student_reference.png) into large rounded forms, a broad head, simple oval eyes, clear eyebrows, compact limbs, chunky boots/hands, and a limited palette. The dark swept hair, ochre rolled-sleeve jacket, cream shirt, charcoal trousers, anatomical-right messenger bag, and anatomical-left watch identify the student.

## Study references

Before authoring, we inspected the actual free Rogue, Ranger, Barbarian, and Mage GLBs from [KayKit Adventurers 2.0](https://kaylousberg.itch.io/kaykit-adventurers), rendered them from front/back, and inspected the published [Protagonists design in Series 5](https://kaylousberg.com/patreon-characters/series-5). These informed proportions, simple faces, large accessory shapes, and clothing construction. The Adventurer models and paid Protagonists model are not included or used as our mesh.

## Review

Run the game → **Play Together → Explore the Lab → Character / F2**. The 3D studio exposes all 77 imported clips, four view buttons, arbitrary character rotation, playback speed, pause, and pose scrubbing while paused. This rotates the preview character; the gameplay camera stays fixed.

- WASD / arrows: move and turn. Shift: run.
- F: KayKit `Interact`.
- I: KayKit `Use_Item`.
- E: KayKit `PickUp`, toggling a small demonstration document on completion; pressing again puts it away using the same reach cycle.
- R: respawn. Esc: pause. F2: character studio.

`preview.png` shows front, three-quarter, and rear views. `lab_preview.png` and `studio_preview.png` show the actual gameplay and review UI. Regenerate them with the preview command below.

## Files and editing

- `student.glb`: standalone original mesh, 23 source joints including hand attachment bones, and 77 genuine KayKit clips. It uses approximately 11,000 triangles and 5,700 vertices. Full counts and part list are in `manifest.json`.
- `../../../tools/build_student_kaykit.py`: all authored geometry, color palette, and skin-weight functions. NumPy is the only nonstandard Python dependency. Blender is not required to rebuild.
- `../../../tools/gltf_tools.py`: binary glTF reader/writer.
- `../../../assets/third_party/kaykit_character_animations/`: unchanged source animation GLBs, reference rig, license, and provenance notes; excluded from runtime imports.
- `../../../scenes/characters/student_3d_player.tscn`: grounded collision body, shadow, turning visual root, and skinned model.
- `../../../scripts/characters/student_3d_player.gd`: independent per-player materials/animation resources, locomotion, action recovery, pause, and hand prop.
- `../../../scenes/characters/student_3d_studio.tscn`: isolated 3D preview with the animation library.

```sh
python3 tools/build_student_kaykit.py
godot --headless --editor --path . --import --quit
python3 tests/student_3d_assets.py
godot --headless --path . --script res://tests/student_3d.gd
godot --path . --script res://tools/preview_student_3d.gd
```

The source rig's bone hierarchy, rest transforms, inverse bind matrices, and animation samples are preserved. Weighted mesh regions bend at the elbows, wrists, hips, knees, chest, and spine. Animation clips are copied by bone name into the standalone model. Gameplay loops locomotion clips and blends between them; actions finish once. The studio uses independent animation resources so looping a preview cannot change gameplay behavior.

## Scope and remaining polish

This is a first 3D art pass for review. The deliberately simplified proportions differ from the illustrated reference. Accessories and cloth are skinned, with no cloth simulation; some extreme poses can still intersect the jacket, strap, or bag. Terminal contact, object-specific hand placement, facial animation, and a separate 49-year-old professor are not implemented. Actions and the demonstration document do not modify inventory or host-authoritative puzzle state.

The original 2D artwork, rig, studio, and tests remain available in `../student_2d/` and their original scenes. Checkpoint commit **244b42a** preserves the complete previous 2D gameplay version. The older articulated 3D model (`../student_v2.glb`) also remains available.
