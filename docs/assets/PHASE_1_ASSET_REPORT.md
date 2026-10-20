# Phase 1 report: asset acquisition and preparation

Date: 2026-10-20. Branch: `claude/great-franklin-ufe6zm`, working tree on top of `554cc31`. Nothing is committed or pushed.

**PHASE 1 STATUS: PARTIALLY COMPLETE. Asset acquisition is BLOCKED.**
The inspection, inventory, license registry, tooling and verification are done. No third-party asset could be
downloaded, so the library holds zero third-party files. It is not safe to start Phase 2 until the core packs exist
(see section 13).

## What blocked acquisition

The build container sends all HTTPS through a policy proxy. On 2026-10-20 it answered **HTTP 403 to CONNECT** for every
asset host: `itch.io`, `vnbp.itch.io`, `milkandbanana.itch.io`, `kaylousberg.itch.io`, `img.itch.zone`, `kenney.nl`,
`opengameart.org`, `lpc.opengameart.org`, `cdn.opengameart.org`, `poly.pizza`, `static.poly.pizza`, `quaternius.com`
(plus `godotengine.org` and its download mirrors). The page-fetch tool also failed to resolve the three hosts tried
(`vnbp.itch.io`, `milkandbanana.itch.io`, `kenney.nl`). Nothing was
retried or routed around. Page contents were therefore never read; license facts come from search-result summaries
(`SEARCH_CORROBORATED`) or only from the brief (`LICENSE_UNVERIFIED`). No source is `VERIFIED`.

GitHub release downloads are allowed, which is how the official Godot 4.7.2 build was fetched for testing
(checksum verified against the release's `SHA512-SUMS.txt`). That was for running the project's tests only.

## 1. Successfully downloaded packs

None. 0 bytes of third-party assets.

## 2. Individual models downloaded

None.

## 3. Reused project assets

All measured from the scene files, not taken from the docs.

| Asset | Path | Size (u) | Placed | Satisfies |
|---|---|---|---|---|
| Tiled floor | `Floor` node, `shaders/lab_floor.gdshader`, `scripts/world/lab_floor.gd` | 24.8 x 15.6, 16 x 13 tiles | 1 | A01 |
| Research table | `scenes/props/table_visual.tscn` | 4.32 x 0.8, 1.5 high, with a notebook box and a paper box | 2 (`LeftTable`, `RightTable`) | A08, A14, parts of A09 and A10 |
| Cabinet | `scenes/props/cabinet_visual.tscn` | 1.65 x 0.8, 3.2 high, four drawers | 2 | A12 |
| Console | `scenes/props/console_visual.tscn` | 1.65 x 0.8, 2.45 high; **one** screen, five signal bars, three buttons | 1 | A05 |
| Prop base | `scenes/props/lab_prop.tscn`, `scripts/world/lab_prop.gd` | box footprint, shadow disc, per-timeline palette | n/a | structure |
| Painted shader | `shaders/painted_prop.gdshader` | flat colour with fixed-light face tone | n/a | style |

None was changed. Duplicates: only three byte-identical first frames among the character animation review renders, unrelated to the environment.

## 4. Checklist coverage

26 categories. By what exists now: **5 fully covered by project assets** (A01, A05, A08, A12, A14), **2 partly** (A09, A10),
**0 by third-party files**, 19 uncovered. Each uncovered item has a preferred and an alternative source in
`ASSET_INVENTORY.md`. If everything downloads and fits, the plan covers all 26. Essential items still missing: A02 walls,
A03 door, A04 keypad, A06 monitors and keyboard, A11 rift, full A09 papers.

## 5. Missing assets

Everything not in section 3. Items that could be covered without any download, in the project's existing painted-box style:
walls, door, keypad, monitors, papers, clock, blackboard (primitives), and a crystal (procedural). That is the fallback if
acquisition stays blocked; it would cost detail, not function.

## 6. Manual download requirements

The tools handle everything after the file is on disk. Browser steps, by priority:

| Pack | Page | Steps |
|---|---|---|
| VNB Office Set #1 (itch.io, interactive) | https://vnbp.itch.io/low-poly-3d-office-set-vnb | Download Now, enter 0, "No thanks, just take me to the downloads", take the free standard FBX/OBJ ZIP only. Read the license field and any attribution wording on the page |
| Lab Assets | https://opengameart.org/content/lab-assets | Download the file under File(s); no login. The itch.io page is the fallback |
| Kenney Modular Space Kit | https://kenney.nl/assets/modular-space-kit | Press Download |
| Security Keypad | https://opengameart.org/content/security-keypad | Download the zip (about 64 KB). Tell me its file format |
| Open Book, Low-Poly Crystal, Low-Poly Door | https://poly.pizza/m/FsCIGEfTEs, `/dxCmHfpqc5`, `/57c3bbHmnJ` | Read the license badge and creator, then Download as GLB. Optional: a procedural crystal needs no license |
| KayKit Furniture Bits (optional) | https://kaylousberg.itch.io/furniture-bits | Free file only, never EXTRA or SOURCE |

Then, for each file (Windows, from the repo root):

```powershell
pip install -r tools/requirements-character.txt
python tools/assets/download_assets.py --adopt "C:\Users\<you>\Downloads\<file>.zip" --id <registry id>
python tools/assets/inspect_assets.py --markdown docs/assets/contents
```

Registry ids are in `ASSET_INVENTORY.md` ("Source key"). The alternative that avoids manual steps for the OpenGameArt,
Kenney and poly.pizza items is allowing these hosts in the environment's network settings: `opengameart.org`,
`kenney.nl`, `poly.pizza`, `static.poly.pizza` (optionally `quaternius.com`). itch.io packs (VNB, KayKit) stay manual either way.

## 7. Model compatibility

Tested with real Godot 4.7.2 on synthetic models (a Blender-exported FBX and a textured OBJ):

| Format | Godot 4.7.2 | Observed | Recommendation |
|---|---|---|---|
| GLB / glTF | Native | Loads; size, floor origin and texture preserved | Preferred. Copy as is |
| FBX | Native importer | World size and floor correct, **but the mesh node arrives with scale 100** (mesh stored at 0.01) | Convert to GLB through Blender (node scale 1) |
| OBJ | Native, mesh only | Size and texture correct; no hierarchy | Convert to GLB for one self-contained file |
| DAE | Not tested | Blender 5.2.2's pip build has no Collada import | Use the FBX or OBJ from the same pack |
| .blend | Not opened | Can carry scripts | Export to FBX or OBJ by hand first |

The Blender route (`convert_models.py`) gave 1 unit = 1 metre, floor at Y = 0, embedded textures and kept animation.
OBJ input adds a 90 degree axis-conversion rotation on the mesh node; world placement is correct. Whether the real packs
behave the same is unknown until they are downloaded. Scale policy for Phase 2 is in `ASSET_INVENTORY.md`: the existing
furniture runs about 1.1 to 1.3 times taller against the 2.23 u student than real furniture, so imported props need a per-category scale.

## 8. Licensing overview

Target licenses are CC0 (no credit needed) and CC BY 4.0 (credit required). Only the VNB office set is CC BY (per search
result); everything else is CC0 or unconfirmed. Details, the evidence grades and six hazards are in
`assets/environment/licenses/LICENSES.md`. The two to remember: VNB's sibling pack forbids reselling the raw models, and
the paper-debris textures come from another pack with an unchecked license.

## 9. Download and project size

| Item | Size |
|---|---|
| Third-party assets downloaded | 0 bytes |
| Files added to the repository (all new, untracked) | 154 KB |
| Working tree (excluding `.git`) | about 71 MB before, 72 MB after |
| Expected downloads, from search results, unverified | core set about 20 MB (Lab Assets about 8.6 MB, Kenney kit about 7 MB, Construction Site 3.1 MB, keypad 64 KB, keycard 219 KB); Sci-Fi Essentials about 167 MB if ever wanted |
| Kept outside the repo for testing | Godot 4.7.2 (78 MB zip), `bpy` venv (about 1 GB), both in the session scratchpad |

## 10. Files converted

No real asset. The converter was exercised on synthetic models only: handmade OBJ, textured OBJ, Blender FBX, an animated
FBX and a pass-through GLB.

## 11. Problems encountered

1. Network policy blocked every asset host (above). Nothing was bypassed.
2. The page-fetch tool also failed (DNS) on the hosts tried, so licenses are search-corroborated at best. Search does not index the nine poly.pizza pages, Low Poly Portal or Open Books.
3. Blender converts a model **silently without textures** if it cannot read them. Found by a failing test; the converter now warns and records `missing_textures`.
4. The first converter version dropped animations; Kenney's kit is described as having animated pieces. Fixed; animations are kept.
5. Documentation drift: `PROJECT_CONTEXT/` lists HEAD `303fc5b` and says `PuzzleManager` does not exist; HEAD is `554cc31` and it is registered. It also says the console has dual displays; it has one. Source files were treated as authoritative.
6. Camera: `spawn_area.tscn` stores `projection = 1` (orthogonal) but `follow_camera.gd` forces perspective in `_ready()`. Harmless; noted because the scene file contradicts the invariant.
7. Pre-existing, unchanged: 14 `res://` references point to deleted files (the 2D student PNGs and `student_v2.glb`), and `tests/student_2d.gd` fails on them, as documented.
8. Phase 2 constraint: `tests/spawn_area.gd` pins `Actors/{LeftTable,RightTable,LeftCabinet,RightCabinet,Console}`, requires 8 or more meshes in each visual, and reads `Actors/LeftTable/Visual/Table/Top`'s `paint_color`. Replacing those visuals would break it. Also, `lab_prop.gd` overrides every mesh's material with the flat `painted_prop` shader, which would strip textures from imported models.

## 12. Import and regression verification

Godot 4.7.2.stable.official.ed1daf0bf (the version the project documents) was run on two copies, so the real tree stayed
untouched: a pristine `git archive` of `HEAD`, and the working tree with all additions.

| Check | Pristine HEAD | With Phase 1 additions |
|---|---|---|
| Godot project import | 0 errors, 0 warnings | 0 errors, 0 warnings; `assets/environment/` ignored by `.gdignore` |
| `tests/student_3d.gd` | PASS (77 clips) | PASS (77 clips) |
| `tests/spawn_area.gd` | PASS | PASS |
| `tests/run_lan_smoke.py` | busy, host, client PASS | busy, host, client PASS |
| `tests/run_puzzle_tests.py` | PASS (131 checks) + host and client sync PASS | identical |
| `tests/student_3d_assets.py` | PASS | PASS |
| `tests/student_2d.gd` | known failure (missing PNGs) | not re-run (legacy, unchanged) |
| `res://` references | 89 targets, 31 missing | 91 targets, same 31 missing, none new |
| Tracked-file fingerprint | n/a | identical to before: no existing file was modified |

New: `tests/asset_tools.py` passes: 74 checks with plain Python, 84 with Blender and Godot. It covers safe extraction
(path traversal, absolute paths, symlinks, zip bombs, corrupt archives), 403 and rate-limit handling including a fake
proxy refusing `CONNECT`, truncated downloads, idempotent re-runs, provenance and license rules, OBJ and FBX conversion,
texture embedding, missing-texture detection, kept animation, and Godot loading converted models (with a corrupt GLB failing as it should).
These use synthetic data; the tools were not run against the real sites.

## 13. Recommended Phase 2 tasks (after the core packs exist)

1. **Phase 1b, short:** adopt the core archives, run `inspect_assets.py`, pick the real model for each item, extract pristine copies, convert, mark sources `VERIFIED` only after reading the page or the archive's license file, run `validate_assets.py --godot`.
2. **Scale policy:** choose per-category scale against the existing furniture; test in the fixed camera.
3. **Shading:** add a textured variant of `painted_prop.gdshader` (or palette atlas) so imported models keep detail; map palette slots onto imported meshes without breaking `lab_prop.gd` or `tests/spawn_area.gd`.
4. **Walls and camera:** the camera looks from the south; decide which walls may be tall and which need a low or cut-away version.
5. **Door and keypad:** build the door leaf, indicator light and keypad buttons as separate nodes so `PuzzleListener` can drive them; the model carries no lock logic.
6. **Future variants:** share meshes, swap materials and a few damaged parts; cracks as thin quads (no Decal on GL Compatibility).
7. **Repaint:** every imported model to the Past and Future palettes in the brief.
8. **Fallback decision:** if downloads stay impossible, build walls, door, keypad, monitors, papers and crystal from primitives in the existing style.
