# Student character references

The active character is reconstructed from these four unchanged source images:

- `frontview.png`
- `backview.png`
- `sideview1.png` (anatomical right)
- `sideview2.png` (anatomical left, with satchel and watch)

The study and approximate image landmarks are documented in
`../student_3d/REFERENCE_STUDY.md`. Reference-to-render comparisons are in
`../student_3d/review/`. The source camera is not known, so matching uses a
near-horizontal orthographic view with approximate full-body framing.

This directory remains excluded from Godot imports. Reference pixels are not
used as textures or altered by the build; source hashes are recorded in the
character manifest. Packed copies are also available in the editable Blender
file's hidden reference collection.
