# Level 3 laboratory environment

Room C now has a decorative environment layer mounted by `core_world.gd` in both
timelines. It preserves the existing 18 x 14 m chamber, floor contact, station
coordinates, reactor module, physics, camera and authoritative puzzle sequence.

The scene is `scenes/level3/environment/laboratory_environment.tscn`; its builder
is `scripts/level3/environment/laboratory_environment.gd`. The four named groups
are FloorDetails, ReactorSurroundings, WallDetails and LaboratoryProps. Build one
instance per timeline with `build(is_future, existing_gate)`. The optional third
argument to `core_world.build(..., decorate)` disables only this art layer for
physics comparison; production callers use its default of true.

The floor has 42 service bays with varied plate subdivisions, recessed borders,
batched fasteners, four access hatches, two grated service drains, painted station
brackets and illuminated route markers. The reactor apron uses sixteen radial
plates, a segmented hazard band, anchor shoes and inset cable trenches aligned
with the existing coil runs. These details have no collision; the original slab
remains the Y=0 contact surface. Walking plates top out at 18 mm; grilles,
markings and hatches stay below 55 mm. Cable clamps reach 85 mm and the small
reactor mounting shoes reach 155 mm within the machinery zone.

Rear architecture combines nine framed wall modules, louvers, utility conduits,
distribution enclosures, mechanical column shoes and four low-energy unshadowed
accent lights. Tall additions stay on the rear boundary; side and foreground
walls retain their original low silhouettes. Physical lettering replaces the
old floating room sign. Perimeter clusters include research benches, storage,
a maintenance trolley, spare couplers and passive fire equipment. They have no
interaction areas, button controls or new physics bodies.

Past uses cream and sage painted alloy with restrained amber accents. Future
uses navy and oxidized blue-grey, a displaced hatch, cosmetic fractures, sparse
edge debris, exposed wiring and softly fluctuating emergency fixtures. Layout
landmarks remain matched. The existing Future conduit receives a panelled casing;
its moving portion is parented to the original gate and travels below the floor
with that gate. Opening, replay and collision behavior stay with existing code.

All mutable art materials are private to each timeline instance. The new opaque
`shaders/level3/laboratory_surface.gdshader` supplies subtle grain, edge wear and
patina without textures, transparency, screen reads, particles or bloom. The
existing reduced-effects preference disables auxiliary-light fluctuation.
Repeated boxes share one unit mesh and use MultiMesh batches by section/material;
radial plates are merged by material. There is no per-frame geometry rebuilding.

The oscilloscope, microscope, flask set and graph paper reuse existing project
original GLBs with the existing timeline palette helper. No model, texture,
shared palette or third-party license was changed. Existing KayKit furniture
stays in place; no new external assets or dependencies were added.

## Verification

Run from the repository root with Godot 4.7.2 available through `GODOT_BIN` (the
review runner also supports the existing Desktop executable location):

```powershell
python tools/review_level3_environment.py
python tools/review_level3_environment.py --render
python tests/run_level3_tests.py
python tools/reactor_visual/run_checks.py
```

The environment review compares every original collision shape, world transform,
resource and enabled flag before/after decoration, checks Y=0 walking surfaces,
material isolation, gate opening/replay, fixed camera and actual reactor rotation.
The rendered variant saves six production-camera images: entry, reactor approach
and rear approach in each timeline. It also measures the art's draw-call cost by
temporarily hiding only the decoration in the same scene instance.

Executed on 21 October 2026 with Godot 4.7.2 / OpenGL 3.3 Compatibility on AMD
Radeon(TM) Graphics:

- Environment review: 34 checks passed, six captures; no script or shader errors.
- Level 3 core: 101 checks passed.
- Physical interactions: 467 checks passed.
- ENet: host 94 / client 74 checks passed; all four endings agree, including
  replay, role security and disconnect handling.
- Existing reactor visual module: 74 checks passed.

Measured procedural art is 10,084 triangles in Past and 11,296 in Future,
excluding the four reused small prop GLBs. The reactor-approach sample added 55
draw calls in Past and 64 in Future, including reused props and lettering. These
are local measurements, not frame-rate guarantees. Full-room rendered counts
also include existing characters, reactor, devices and UI.

Screenshots and raw metrics are in `docs/assets/screenshots/level3/environment/`:
[Past](assets/screenshots/level3/environment/past_core.png),
[Future](assets/screenshots/level3/environment/future_core.png), and
[metrics](assets/screenshots/level3/environment/metrics.json).
The folder has `.gdignore`, so review images do not become game assets.

Validation is automated local scene/physics/interaction testing and loopback ENet;
no multi-device WAN or manual controller play session was performed for this art
pass. The art pass did not edit Level 1, Level 2, UI, `core_rules.gd`, reactor
internals or multiplayer code. Unrelated concurrent workspace edits are outside
this change.
