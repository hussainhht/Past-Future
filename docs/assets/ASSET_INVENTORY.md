# Asset inventory: Signal Laboratory (Puzzle 01, "Lost Frequency")

As of 2026-10-20, Phase 1. Source-level detail (URLs, license text, checksums) lives in
`assets/environment/licenses/sources.json`. The narrative result is `docs/assets/PHASE_1_ASSET_REPORT.md`.

**Nothing from outside the repository has been downloaded.** The build container's network policy refused every asset
host, so every "Preferred source" below is a plan, not a file on disk.

## Reading the status columns

Three separate fields, so verification, downloading and importing are never confused.

| Field | Values used |
|---|---|
| Project now | `EXISTING` (already in the repo and sufficient), `PARTIAL`, `NO` |
| Verification (of the source's license) | `SEARCH_CORROBORATED` (search-result summary of the official page; live page not read), `LICENSE_UNVERIFIED` (only the brief claims it), `n/a` (project-made). `VERIFIED` is reserved for a live page or an in-archive license file; none yet |
| Download | `BLOCKED` (container network policy answered HTTP 403, nothing bypassed), `MANUAL_DOWNLOAD_REQUIRED` (interactive itch.io flow, also blocked here), `n/a` |
| Import into Godot | `NOT_STARTED` for every third-party item; `EXISTING` where the project already has the object |

Source keys used below are defined in the table under "Source key".

## Table 1: required objects and where they come from

| ID | Asset | Qty | Project now | Preferred source | Alternative | Verification | Download | Import |
|---|---|---|---|---|---|---|---|---|
| A01 | Floor / tiled floor | 1 | EXISTING: procedural `Floor` (24.8 x 15.6 u, 16 x 13 tiles, Past/Future uniform) | Keep it | KMS floor tiles, only for a cracked Future variant | n/a | n/a | EXISTING |
| A02 | Walls + wall panels | 4+ | NO: only 1.0 u collision boxes and 0.32 u rim meshes, no visible wall | KMS | QMS | SEARCH_CORROBORATED | BLOCKED | NOT_STARTED |
| A03 | Security door | 1 | NO | KMS door pieces, if one fits | PP-DOOR, QMS | SEARCH_CORROBORATED / LICENSE_UNVERIFIED | BLOCKED | NOT_STARTED |
| A04 | Door keypad | 1 | NO | KEY | Build from primitives | SEARCH_CORROBORATED | BLOCKED | NOT_STARTED |
| A05 | Main computer console | 1 | EXISTING: `console_visual.tscn` (1.65 x 2.45 u; one screen, five signal bars, three buttons) | Keep it | VNB computer, PP-COMPUTER | n/a | n/a | EXISTING |
| A06 | Dual monitors + keyboard | 1 set | NO (the console has one screen, not two) | VNB | PP-COMPUTER, primitives | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A07 | Computer chair | 1 | NO | VNB | KFB | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A08 | Research table | 1 | EXISTING: `table_visual.tscn` (4.32 x 0.8 x 1.5 u), two placed | Keep it | VNB desk, KFB table | n/a | n/a | EXISTING |
| A09 | Research papers | 4-6 | PARTIAL: one paper box on the table | VNB papers | Textured quads; PAPER for the Future | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A10 | Open notebook | 1-2 | PARTIAL: a closed notebook box with a label | PP-BOOK-OPEN | BOOKS, VNB | LICENSE_UNVERIFIED | BLOCKED | NOT_STARTED |
| A11 | Temporal rift + fragments | 1 | NO | PP-CRYSTAL | PORTAL; a procedural crystal (no license at all) | LICENSE_UNVERIFIED | BLOCKED | NOT_STARTED |
| A12 | Lab cabinets | 2-3 | EXISTING: `cabinet_visual.tscn` (1.65 x 3.2 x 0.8 u), two placed | Keep them | LAB counters and shelves, VNB | n/a | n/a | EXISTING |
| A13 | Bookshelves | 1-2 | NO | VNB | KFB | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A14 | Side workbench | 1-2 | EXISTING: the two placed tables serve as workbenches | Keep them | LAB lab counters | n/a | n/a | EXISTING |
| A15 | Books / binders | 3 types | NO | VNB | PP-BOOK | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A16 | Desk lamp | 2-3 | NO | VNB | KFB | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A17 | Lab instruments | 2-3 | NO | LAB | None needed | SEARCH_CORROBORATED | BLOCKED | NOT_STARTED |
| A18 | Wall blackboard | 1 | NO | VNB whiteboard, recoloured | Box plus chalk texture | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A19 | Wall posters / schematics | 3-5 | NO | VNB wall decorations | Textured quads authored in Phase 2-3 | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A20 | Wall clock | 1 | NO | VNB | Primitives | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A21 | Potted plants | 2-4 | NO | KFB | PP-PLANT, VNB | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A22 | Coffee mug | 1-2 | NO | PP-MUG | VNB | LICENSE_UNVERIFIED | BLOCKED | NOT_STARTED |
| A23 | Pens / pencil holder | 1-2 | NO | VNB pens | PP-MUG-TOOL | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A24 | Carpet / rug | 1 | NO | VNB | KFB | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |
| A25 | Lab coat | 1 | NO | LAB, if its PPE set includes a coat (unconfirmed) | A simple modelled coat, or drop it (LOW priority) | SEARCH_CORROBORATED | BLOCKED | NOT_STARTED |
| A26 | Cables / boxes | 3-5 | NO | VNB clutter | KSS, QSE, SITE | SEARCH_CORROBORATED | MANUAL_DOWNLOAD_REQUIRED | NOT_STARTED |

Tally: **5 of 26 categories are fully covered by what the project already has** (A01, A05, A08, A12, A14), **2 are
partly covered** (A09, A10), and **0 are covered by third-party files** because none could be fetched.
Essential items still missing: A02 walls, A03 door, A04 keypad, A06 monitors and keyboard, A11 rift, and full A09 papers.

## Table 2: integration plan (Phase 2 targets; nothing here exists yet)

Model folders are under `assets/environment/models/`. Scene names follow the Phase 2 plan
(`scenes/props/environment/`). "Scale" is discussed under "Scale reference" below.

| ID | Target GLB | Scene | Past / Future use | Modification needs | Notes |
|---|---|---|---|---|---|
| A01 | none (procedural) | `Floor` in `spawn_area.tscn` | Same mesh; shader `future` flag already switches colour | Future: add cracks as extra quads | GL Compatibility has no usable Decal path, so use thin mesh quads |
| A02 | `walls/lab_wall_panel_01.glb` ... | `wall_panel.tscn` | Past: warm cream panels. Future: cracked and bent variants of the same panel | Repaint to palette, add collision, decide the wall height against the fixed camera | Back and side walls can be tall; walls toward the camera must stay low or use a cut-away |
| A03 | `doors/lab_door.glb` | `security_door.tscn` | Past: intact, locks via PuzzleManager. Future: damaged frame | Door leaf must be a separate node for opening; indicator light mesh | Lock logic belongs to `PuzzleManager`, not the model |
| A04 | `keypads/lab_keypad.glb` | `security_keypad.tscn` | Past: lit buttons. Future: dead and cracked | Reduce triangles if dense; separate button meshes for feedback | `InteractableArea3D` is Phase 2 |
| A05 | none (existing) | `console_visual.tscn` via `lab_prop.tscn` kind 2 | Already recoloured per timeline | None; the Future version still needs a damage state | `tests/spawn_area.gd` pins this node path |
| A06 | `computers/lab_monitor.glb`, `lab_keyboard.glb` | `lab_monitor_set.tscn` | Past: lit screens. Future: dead, cracked | Two monitors on a stand, emissive screen slot | Screen texture is a Phase 3 effect |
| A07 | `chairs/lab_chair.glb` | `computer_chair.tscn` | Future: tipped over | Recolour, floor-level origin | Collision footprint small and optional |
| A08 | none (existing) | `table_visual.tscn` via kind 0 | Already recoloured per timeline | None | `tests/spawn_area.gd` pins `Actors/LeftTable/Visual/Table/Top` |
| A09 | `papers/lab_paper_01.glb` ... | `research_papers.tscn` | Past: stacked on the desk. Future: scattered | Own paper material, not the pack's texture | Puzzle clue text will be a texture or label, not geometry |
| A10 | `books/lab_notebook.glb` | `notebook.tscn` | Same object, aged material in the Future | Page texture slot for the clue | Interact target for Puzzle 01 |
| A11 | `temporal/lab_crystal.glb` | `temporal_crystal.tscn` | Visible in both; glow and fragments are Phase 3 | Several fragment variants, emissive slot | May be procedural |
| A12 | none (existing) | `cabinet_visual.tscn` via kind 1 | Already recoloured per timeline | None | |
| A13 | `furniture/lab_bookshelf.glb` | `bookshelf.tscn` | Future: collapsed or leaning | Recolour, book colour slots | |
| A14 | none (existing) | `table_visual.tscn` via kind 0 | As A08 | None | Lab counters from LAB are an optional upgrade |
| A15 | `books/lab_book_01.glb` ... | `books.tscn` | Same, with dust tint in the Future | Three distinct covers | Share one atlas to save draw calls |
| A16 | `furniture/lab_desk_lamp.glb` | `desk_lamp.tscn` | Past: lit. Future: dark | Emissive bulb slot | Real light sources are optional and cost performance |
| A17 | `laboratory/lab_instrument_01.glb` ... | `scientific_instrument.tscn` | Past: intact. Future: broken glass variant | Recolour from the pack's atlas | Gives the room its "science" read |
| A18 | `decorations/lab_blackboard.glb` | `blackboard.tscn` | Past: chalk equations. Future: smashed | Chalk texture | Wall-mounted, exempt from the floor-origin rule |
| A19 | `decorations/lab_poster_01.glb` ... | `wall_poster.tscn` | Past: pinned. Future: torn | Poster textures authored for the game | Wall-mounted |
| A20 | `decorations/lab_wall_clock.glb` | `wall_clock.tscn` | Future: stopped | Hands as separate nodes | Fits the time theme |
| A21 | `decorations/lab_plant_01.glb` ... | `potted_plant.tscn` | Future: withered tint | Recolour | |
| A22 | `decorations/lab_mug.glb` | `mug.tscn` | Future: broken or removed | Recolour | |
| A23 | `decorations/lab_pencil_holder.glb` | `pencil_holder.tscn` | Same | Recolour | |
| A24 | `floors/lab_rug.glb` | `rug.tscn` | Future: stained | Thin mesh above the floor shader | |
| A25 | `decorations/lab_coat.glb` | `lab_coat.tscn` | Past only | None | LOW priority; skip if absent |
| A26 | `laboratory/lab_crate_01.glb`, `lab_cable_01.glb` ... | `cable_box.tscn` | Future: more clutter | Recolour | Clutter fills dead space between routes |

## Table 3: extras for the Future timeline

| ID | Need | Source plan | Download |
|---|---|---|---|
| F01 | Broken furniture variants | Derived in Phase 2 from A07, A08, A12, A13 (tilt, offset, swap parts, material) | none |
| F02 | Rubble and debris | SITE (planks, boxes, barrels), PP-ROCK, KMS pieces, or simple rock primitives | BLOCKED |
| F03 | Cracked or damaged tiles | Procedural: shader tint plus thin crack quads | none |
| F04 | Damaged computers | Derived from A05 and A06 | none |
| F05 | Destroyed electronics | Derived from A06 and A26, optionally QSE screens | none |
| F06 | Bent or damaged metal panels | Derived from A02 | none |
| F07 | Scattered research papers | PAPER (project paper material) or duplicated A09 | BLOCKED |
| F08 | Broken glass or lab objects | Derived from LAB glassware | BLOCKED |
| F09 | Temporal fracture crystals | A11 | BLOCKED |
| F10 | Wires and damaged cables | A26 plus procedural tube meshes | none |
| F11 | Dust, soot, rust | Materials and shader work, Phase 2-3 | none |

## Source key

| Key | Registry id | Page |
|---|---|---|
| VNB | `vnb_office_set_1` | https://vnbp.itch.io/low-poly-3d-office-set-vnb |
| LAB | `milkandbanana_lab_assets` | https://milkandbanana.itch.io/lab-assets (also https://opengameart.org/content/lab-assets) |
| KMS | `kenney_modular_space_kit` | https://kenney.nl/assets/modular-space-kit |
| KFB | `kaykit_furniture_bits` | https://kaylousberg.itch.io/furniture-bits |
| QMS | `quaternius_modular_scifi_megakit` | https://opengameart.org/content/modular-sci-fi-megakit |
| KSS | `kenney_space_station_kit` | https://kenney.nl/assets/space-station-kit |
| KFK | `kenney_factory_kit` | https://kenney.nl/assets/factory-kit |
| QSE | `quaternius_scifi_essentials_kit` | https://opengameart.org/content/sci-fi-essentials-kit |
| KEY | `oga_security_keypad` | https://opengameart.org/content/security-keypad |
| CARD | `oga_3d_keycard` | https://opengameart.org/content/3d-keycard |
| PAPER | `oga_paper_debris` | https://opengameart.org/content/3d-dungeon-debris-paper |
| SITE | `majadroid_construction_site` | https://opengameart.org/content/3d-house-construction-site-lowpoly-cc0 |
| PORTAL | `oga_low_poly_portal` | https://opengameart.org/content/low-poly-portal |
| BOOKS | `oga_open_books` | https://opengameart.org/content/open-books |
| PP-DOOR | `polypizza_low_poly_door` | https://poly.pizza/m/57c3bbHmnJ |
| PP-BOOK-OPEN | `polypizza_open_book` | https://poly.pizza/m/FsCIGEfTEs |
| PP-CRYSTAL | `polypizza_low_poly_crystal` | https://poly.pizza/m/dxCmHfpqc5 |
| PP-COMPUTER | `polypizza_computer` | https://poly.pizza/m/emxvTSMKnt |
| PP-BOOK | `polypizza_book` | https://poly.pizza/m/Qkvcgg5tpj |
| PP-MUG-TOOL | `polypizza_mug_with_office_tool` | https://poly.pizza/m/4jSgnM5WWk |
| PP-MUG | `polypizza_mug` | https://poly.pizza/m/0uSqGCZqE8 |
| PP-PLANT | `polypizza_plant` | https://poly.pizza/m/wSt6PYau5u |
| PP-ROCK | `polypizza_rock` | https://poly.pizza/m/RtLRqYjfMs |

## Acquisition order (smallest collection that covers the room)

1. **VNB Office Set #1**: expected to supply 13 of the 26 categories on its own. Download first.
2. **Lab Assets**: instruments, counters, the "science" read (A17, plus A14 and A25 if useful).
3. **Kenney Modular Space Kit**: walls and a door (A02, A03).
4. **Security Keypad**: A04.
5. **Crystal** and **Open Book**: A11 and A10. If their licenses cannot be confirmed, make a procedural crystal and use a VNB or primitive notebook.
6. Inspect what arrived (`inspect_assets.py`). Only then decide on KayKit Furniture Bits, and only for gaps VNB leaves (bookshelf, plant, rug).
7. Defer, not needed for Puzzle 01: Quaternius MegaKit, Kenney Space Station and Factory Kits, Quaternius Sci-Fi Essentials, Keycard, Portal, Open Books, Majadroid site.

## Scale reference (measured from the repository)

| Object | Game size (u) | Real-world look-alike | Ratio to the 2.23 u student | Real ratio to a 1.75 m person |
|---|---|---|---|---|
| Student character | 2.23 tall | 1.75 m | 1.00 | 1.00 |
| Research table | 1.5 high, 4.32 long | bench 0.9 m | 0.67 | 0.51 |
| Console | 2.45 tall | rack 1.8 m | 1.10 | 1.03 |
| Cabinet | 3.2 tall | tall cabinet 2.0 m | 1.43 | 1.14 |

The existing furniture runs about 1.1 to 1.3 times taller against the player than real furniture would, so a
real-world-scale pack (1 unit = 1 metre) needs a per-category scale in Phase 2 rather than one global factor.
Scaling by 2.23/1.75 = 1.27 matches the character; matching the existing chunky props needs roughly 1.6 for tables.

## Problems recorded

- All asset hosts denied by the container network policy; page contents could not be read (see the report).
- `PROJECT_CONTEXT/` is behind the code: it lists HEAD `303fc5b` and says no `PuzzleManager` exists, but HEAD is `554cc31` and `PuzzleManager` is registered in `project.godot`. It also says the console has dual displays; the scene has one.
- Several pack contents are inferred from descriptions; confirm against the archives.
