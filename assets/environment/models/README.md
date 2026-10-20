# Game-ready models

Godot imports everything in this folder. It is empty until verified sources are downloaded and converted
(see `docs/assets/PHASE_1_ASSET_REPORT.md`).

## Rules for a model to live here

- Binary glTF (`.glb`), self-contained: textures embedded, no external files.
- Lowercase snake_case name with a `lab_` prefix for room props, for example `lab_research_desk.glb`.
- Origin on the floor (lowest point at Y = 0) except wall-mounted items in `decorations/`.
- 1 unit = 1 metre as exported. Scale to the game's proportions is a Phase 2 decision (see the report).
- A matching `derived_models` record under its pack in `licenses/sources.json`.

## What Godot adds next to a textured model

On first import Godot 4.7.2 extracts a GLB's embedded textures beside it (for example `lab_crate.glb` produces
`lab_crate_crate.png` and `lab_crate_crate.png.import`, observed in testing). Commit those with the GLB, as the
project already does for `student.glb.import`. The GLB itself stays self-contained.

## Checking

`python tools/assets/validate_assets.py` checks provenance, licenses and budgets. Add `--godot` (with `GODOT_BIN` set)
to also import the project and load every GLB through `tools/assets/godot_model_check.gd`, which reports the
triangle count, size and lowest point Godot actually sees.

## Categories (created when first used)

`walls`, `floors`, `doors`, `keypads`, `computers`, `furniture`, `cabinets`, `tables`, `chairs`, `books`,
`papers`, `laboratory`, `decorations`, `temporal`, `debris`

Check a folder with `python tools/assets/validate_assets.py`.
