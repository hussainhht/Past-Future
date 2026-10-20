# Character reference views

Original reference images are organized by character age:

- `18/`: the student — front, back, anatomical right (`sideview1.png`), and anatomical left (`sideview2.png`, with satchel and watch).
- `49/`: the professor — front, back, and both side views.

The studies and reference-to-render comparisons are in `../student_3d/` and
`../professor_3d/`. The source cameras are unknown; comparisons use approximately
matched full-body framing.

This directory is excluded from Godot imports. Reference pixels are unchanged
and are not used as character textures. Their hashes are recorded in each model's
manifest, and packed copies are retained in its editable Blender source.
