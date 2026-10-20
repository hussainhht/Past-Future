# Detailed 2D student

The active player uses an illustrated, eight-direction cutout of the 18-year-old student. The supplied reference is preserved unchanged at `../references/student_reference.png`. The previous 3D model remains available; see `../STUDENT_MODEL.md`.

The student has dark tousled hair, warm tan skin, an ochre rolled-sleeve jacket, cream shirt, charcoal trousers, brown boots, student ID, a messenger bag on his anatomical right hip, and a watch on his anatomical left wrist. Each direction has its own artwork rather than mirroring those asymmetric accessories.

## Review in Godot

Open **Play Together → Explore the Lab**, then press **F2** or select **Character**. The studio exposes eight views, thirteen animations, pause, and playback speed. Close it with Esc to return to the current room and session.

- WASD / arrows: move. Shift: run.
- F: interact animation. I: inspect/read animation.
- E: pick up / put down a demonstration document.

These are animation prototypes. They do not modify host-authoritative puzzles or implement inventory. Both timelines currently share this student; the older professor still needs separate artwork.

## Artwork and rig

- `*_parts.png`: eight original 4×4 atlases, each 1254×1254 RGBA.
- `torso_corrections.png`: replacement sleeveless jacket bodies for all eight views. These remove duplicate sleeve silhouettes behind the animated upper arms.
- `generation_prompts.json`: prompts used with the built-in imagegen tool. Generated PNGs were copied unchanged; alpha inspection only produces crop and joint metadata.
- `atlas_regions.json`: inspected body-part crop bounds.
- `directions_preview.png`, `walk_preview.png`, `studio_preview.png`: Godot renders of the assembled rig.
- `../../../scripts/characters/student_paper_rig.gd`: shared layered Sprite2D rig, two-bone IK, blink/hand variants, and procedural motion.
- `../../../scripts/characters/student_direction_poses.gd`: independently authored shoulder, hip, foot, neck, bag, bend, and draw-order values for each view.
- `../../../scripts/characters/student_atlas_regions.gd`: generated atlas bounds and source joint anchors, preloaded for exported builds.
- `../../../scenes/characters/student_2d_player.tscn`: grounded CharacterBody3D with a transparent SubViewport and depth-tested billboard Sprite3D.

Each atlas cell contains, in row-major order: head, torso, pelvis, right upper arm, right forearm, left upper arm, left forearm, right thigh, right shin/boot, left thigh, left shin/boot, bag, closed-eye head, gripping right forearm, gripping left forearm, document. Anatomical sides stay fixed across views. One generated east-view left boot is reversed through its Sprite2D flip and matching joint coordinates.

The thirteen clips are idle, walk, run, interact, inspect, pick_up, put_down, carry_idle, carry_walk, push, pull, react, and arrive. These are procedural cutout animations, not hand-drawn frame sequences or Spine exports. Joint anchors align the source artwork at elbows and knees; reach targets are constrained to prevent forearm stretching. Direction changes preserve animation phase. Some cloth seams, gripping poses, and transitions still need artistic polish.

## Authoring workflow

The workflow follows the shared-rig approach discussed in [Armanimation's eight-direction Spine tutorial](https://www.youtube.com/watch?v=pxP87em31e8) and the [creator's Spine forum thread](https://en.esotericsoftware.com/forum/d/24092-best-practices-of-rigging-8-directional-character-in-spine-2d): keep consistent joints, author each directional pose explicitly, account for hidden alternate attachments, and set draw order deliberately. This project implements those ideas directly in Godot and does not require Spine.

When changing artwork, inspect every idle view at large size before reviewing movement and interaction poses. Aligned mathematical joints do not guarantee that garment silhouettes or accessory placement look correct.

```sh
python3 tools/inspect_student_atlases.py
godot --headless --path . --script res://tests/student_2d.gd
godot --path . --script res://tools/preview_student_2d.gd
```

The inspection tool requires Pillow and leaves source PNGs untouched. Edit direction poses for placement, and the rig for animation. The test covers 104 view/clip combinations, elbow/knee continuity, fixed forearm lengths, direction-phase continuity, one-shot completion, and pause. `tests/spawn_area.gd` checks gameplay controls and integration; `tests/run_lan_smoke.py` checks two-process loopback networking.
