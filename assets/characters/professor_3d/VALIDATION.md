# Professor validation

Validated in Godot 4.7.2 Compatibility on Apple M4, Blender 5.2.2 LTS, and Python 3.13.

- Final asset after clothing fitting: 113,143 skinned vertices, 217,606 triangles, 23 bones, and 77 animations. Joint bind matrices invert the rest transforms; positions/normals are finite, normals have unit length, indices are valid, and weights are nonnegative and normalized.
- All 5,011 source/retargeted samplers pass the shared asset checks. Source rotation/scale values and timings remain exact; translations use the existing proportion mapping. Floor-contact clips retain the recorded sampled surface-clearance correction.
- `tests/student_3d.gd -- --professor` passes: all 77 clips load and produce finite bone transforms; core actions animate the rig; pickup/put-down and action recovery work; pause and independent per-player resources are retained.
- The professor studio scene loads successfully with its own model and age-49 heading. It shares the tested studio controls while leaving the student studio's defaults intact.
- `tests/student_3d_assets.py`, `tests/student_3d.gd`, and `tests/spawn_area.gd` pass for the original student and current lab. The student was subsequently fitted in a separate face/clothing pass; its saved animations and unrelated meshes are preserved.
- The professor Blender source was created and successfully exported through `tools/professor_blender.py --export`; the exported result passes the same asset checks. This route exports geometry and solid materials, not edited animation keyframes.
- Four original professor reference hashes match the manifest. The reference files are unchanged.
- Actual Godot neutral views cover front, back, left, right, and both three-quarter angles. Eleven animations were captured at 18 evenly spaced phases plus three rear-view phases each. Review sheets include the original references next to the renders. Walking, running, interaction, pickup, crouching, death, and crawling poses were inspected directly.

Visual iterations corrected unused vertices around sleeve tears, the beard's stepped edge and faceted shading, overly bright gray strands, an overly solid gray nape, the rear coat vent, the exposed shirt hem, and remaining student boot details.

The three forehead age-line meshes were subsequently recessed by 0.02 model units along the backward axis in both the Blender source and procedural builder. A before/after GLB comparison confirmed that only their 336 vertices changed position. Asset/animation provenance checks pass, and the refreshed Godot front view confirms that the lines no longer float in front of the fringe.

A further contact pass fits 16 facial details to the actual skin or eye triangles, preserving X/Y landmarks and skin weights. Geometry checks verify that each feature intersects its supporting surface, with shallow outward relief; repeating the fitting does not accumulate displacement. One eyebrow had inward-facing triangles, which were corrected so its visible face remains outside the skin. Forehead recessing, hair, beard surface, body, and clothing remain unchanged by this pass.

The clothing pass subsequently fitted 47 garment details and transferred weights from their supporting cloth triangles. Broad panels were refined to prevent curved underlying fabric cutting through large flat faces. Projection selects the outward side of each garment so trim beside the front opening cannot attach to the back lining. A small clearance separates complete front layers from the supporting surface without changing their relative layering. The rear seam now ends above the coat vent. Thin cloth panels also inherit their supporting surface normals, preventing noisy shading along shallow borders. Asset validation retains all 77 clips and their source provenance.

The resemblance is approximate. The generated geometry keeps the student's existing proportions and stylized facial construction; hair-lock shapes, facial contours, cloth wrinkles, and surface wear differ from the rendered references. Core movement poses remain readable, but coat tails use pelvis/thigh weights with no cloth simulation. Compressed poses can show local cloth/body intersections, and floor-clearance baking is not full-body contact IK. These checks do not establish a GPU performance budget or certify collision-free deformation in every clip.

The model is available through separate professor player/studio scenes. Assigning it to the live Future timeline is not part of this modeling pass.
