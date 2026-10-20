# KayKit Character Animations 1.1

Creator: Kay Lousberg - https://kaylousberg.com
Official download: https://kaylousberg.itch.io/kaykit-character-animations

Original provenance: downloaded from the creator's Free 1.1 archive on
2026-10-20. `License.txt` is the unchanged CC0 license from that archive.
No paid source files are included.

This directory retains all eight original Rig_Medium animation GLBs and the
medium mannequin reference. It is excluded from Godot imports to avoid duplicate
runtime libraries and importing the source mannequin into the game.

The current builder authors entirely new visible geometry. It uses the source
23-bone hierarchy, bone axes, hand slots, and the same 77 selected clips from
General, MovementBasic, MovementAdvanced, Simulation, and Tools. The other packs
remain available unchanged.

Reference-led proportions now use adjusted rest translations and newly computed
inverse binds. Angular animation, scale, and timing remain exact. Local motion
translations are retargeted by the source-to-target rest-length ratios. Selected
floor-contact clips also receive a vertical root-clearance curve computed from
the new skinned geometry. These adaptations affect the generated student GLB
only; this directory's source GLBs and license are not edited.

`assets/characters/student_3d/manifest.json` records source SHA-256 hashes, the
bone mapping, per-clip provenance, and any clearance curves.
`tests/student_3d_assets.py` validates bind matrices, weights, original angular
tracks/timing, and documented translation retargeting.

See `assets/characters/student_3d/README.md` for editable source and rebuild steps.
