# Validation and visual review

## Technical checks

- Generated GLB: 23 named joints and hand slots; all bind matrices invert the
  target rest transforms; finite geometry and unit normals; valid indices;
  non-negative, normalized skin weights with at most four influences.
- Animation provenance: all 77 previously available clips retained; source times,
  angular samples, and scale samples compared against the original GLBs.
  Translation samples checked against the explicit proportion map. Contact
  correction curves are recorded separately and validated against source motion.
- Godot import and `tests/student_3d.gd`: all 77 clips instantiate and play; finite
  bone transforms; movement/action clips move the rig; independent player colors
  and animation resources; action recovery; pickup/put-down hand prop; pause;
  mesh-derived gameplay height.
- `tests/spawn_area.gd`: existing lab scene and player integration.
- `tests/run_lan_smoke.py`: occupied port, host, client, game spawning, authority,
  and reconnect on loopback. This is not a two-physical-computer Wi-Fi test.
- Blender source is generated and reopened for rendering. Geometry-only export
  is checked separately through the same GLB asset checks.
- Original reference PNGs, source KayKit GLBs, and License.txt remain unchanged.

These are technical checks, not a score for resemblance to the references.

## Visual evidence and iterations

All four references were inspected before authoring. Front/back/left/right and
both three-quarter views are rendered at 1024 x 572. Original reference images
are paired with unretouched renders. The source camera and lights are unknown;
3-degree orthographic framing approximates the source full-body view.

The first renders exposed unsupported floating hair locks, high cuffs, a mouth
and brow partly inside the face, a visible wrist seam, and a satchel intersecting
the resting hand. Subsequent passes seated hair surfaces against the skull,
changed their sweep and nape layering, lowered the cuffs and facial landmarks,
rounded the jaw and nose, made the forearm and palm continuous, and moved/rotated
the satchel behind the left hand. The front breast pocket, ID, left sleeve
pocket, watch, strap direction, and bag side were checked across views.

Each of these actual KayKit clips is captured at 18 evenly spaced phases plus
three rear-view phases: Idle_A, Walking_A, Running_A, Interact, PickUp, Crouching,
Waving, Jump_Full_Long, Dodge_Forward, Death_A, and Crawling. GIF timing is rounded
to the nearest 10 ms over the full clip. The studio provides full-rate playback
and arbitrary scrubbing of all 77 animations. Wide framing is used in the death
and jump montages to keep extreme motion visible.

The review includes the actual past/future lab lighting at the gameplay camera
distance and the character studio. The character reads at the existing gameplay
scale; the collider and camera behavior are preserved.

Floor-contact inspection identified mesh penetration after proportion retarget.
The builder now samples the actual skinned surface at 60 Hz for death, lying,
crawling, and push-up clips and adds only the vertical root displacement needed
to keep the mesh at least 2 mm above the preview floor at those samples. This
is animation baking, not runtime cloth or collision simulation.

## Face and clothing contact pass

The updated student contains 90,881 vertices and 180,554 triangles, with the same
23-bone hierarchy and 77 KayKit clips. Seven face details now follow the actual
skin or eye surface; the mirrored eyebrow winding is corrected. The clothing
pass fits 101 details, including both collars, plackets, pockets, buttons, badge
layers, sleeve pocket, seams, boot trim, and the torso sections of both straps.
The shoulder bridge and hip connectors retain their existing 3D paths.

Broad panels are refined before projection. Front-opening trim extends the
jacket surface continuously across the opening instead of jumping inward to
the shirt. Sewn details inherit supporting cloth weights, and thin panels inherit
smooth surface normals in both Blender and the exported GLB. This avoids noisy
shading from their shallow side walls.

The editable source was compared with the pre-fitting Blender file: all 77 saved
actions have identical keyframes. Hair, body, hands, satchel, watch, main sleeves,
trouser legs, and boot shells retain their original mesh coordinates. Asset and
runtime character checks pass, as does the spawn-area integration check. Eleven
animation sequences and six neutral angles were refreshed in Godot, together
with the gameplay/studio captures and six Blender studio renders.

## Remaining limitations

- The result is a reconstruction, not an exact sculpt match. Individual hair-lock
  silhouettes, garment wrinkles/softness, the bag flap construction, and some
  facial contours differ from the supplied rendered references. Both rendering
  backends and all four comparisons are retained so those differences stay visible.
- The GL Compatibility game renderer has flatter lighting than the reference
  studio images. The Blender Cycles views demonstrate the same geometry under
  soft studio lighting, without changing the mesh for those renders.
- Clothing uses blended skin weights; the satchel is rigid to the pelvis, the
  head/hair are rigid to the head, and there is no secondary cloth/bag simulation.
  Extreme arm-to-torso contact or compressed lying poses can have local overlap.
  Clearance baking can leave other body parts raised when a protruding accessory
  is the first part to contact the floor. It is not full-body contact IK.
- There is no facial rig or individual finger animation. The KayKit rig does not
  provide those bones. Hands retain rounded finger geometry and hand-slot support.
- Geometry is intentionally denser than the source mannequin to support the
  reference's rounded sculpted forms. Counts are in manifest.json. No custom
  distance LOD system or GPU performance certification was added.
- The LAN check uses local processes. A physical two-machine session was not run.
