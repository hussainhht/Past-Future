# KayKit Character Animations 1.1

Creator: **Kay Lousberg** — <https://kaylousberg.com>

Official download: <https://kaylousberg.itch.io/kaykit-character-animations>

Downloaded from the creator's **Free 1.1** archive on 2026-10-20. `License.txt` is copied unchanged from that archive: CC0, including personal, educational, and commercial use; attribution is optional. No paid source files were downloaded.

This folder contains the eight original `Rig_Medium` animation GLBs and the medium mannequin reference, copied unchanged. It is excluded from Godot imports to avoid importing the source mannequin and duplicate animation sets into the game.

`tools/build_student_kaykit.py` takes the actual 23-joint skeleton, rest transforms, inverse bind matrices, and unmodified animation tracks from these files. It creates entirely new visible geometry and bakes 77 clips from General, MovementBasic, MovementAdvanced, Simulation, and Tools into `assets/characters/student_3d/student.glb`. The combat and special sets are retained for later use, but are not baked into the student yet.

`assets/characters/student_3d/manifest.json` records which source file supplied each baked clip and SHA-256 hashes of those files. `tests/student_3d_assets.py` compares every baked animation sampler against the original source. The model uses the source skeleton directly; no engine retargeting or approximate procedural replacement of the animations is involved.
