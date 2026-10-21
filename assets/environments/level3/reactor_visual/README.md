# Temporal reactor visual module

Original production geometry and presentation for THE OTHER ME, Level 3. Godot
4.7.2, GL Compatibility. This module never reads or writes puzzle state and has
no dependencies on autoloads, multiplayer, interaction, UI or earlier levels.
The existing Level 3 room and its gameplay files were not edited for this module.

## Instantiate

```gdscript
const ReactorVisual = preload("res://scenes/level3/reactor_visual/reactor_visual.tscn")

var reactor = ReactorVisual.instantiate()
reactor.set_timeline("past") # or "future"; setters also work before add_child
world.add_child(reactor)     # parent is the appropriate existing timeline world
reactor.transform = Transform3D.IDENTITY
reactor.set_reactor_phase("power")
reactor.set_charge_ratio(0.65)
```

Open `scenes/level3/reactor_visual/reactor_preview.tscn` and press F6 for the
standalone art preview. Keys 1–7 select phases, T changes timeline, E cycles
endings, C switches between detail and exact gameplay camera settings, M freezes
continuous motion, V reduces effects, S shuts down/starts up. A slider and
Up/Down control charge. The detail camera also retains the actual 35° pitch and
48° FOV; its distance is 13.8 m rather than the game's 20 m.

Geometry is imported from the supplied GLB and assembled at runtime. Open that
GLB to inspect the model in the editor; run the preview to inspect animation.

## Transform and clearance

- Root: Y up, metres, origin at the floor centre, identity rotation and scale.
- Recommended placement: **(0, 0, 0) relative to each existing timeline world**.
  The Future world's existing +40 m X offset is inherited; do not add it twice.
- Platform: radius **1.65 m**, top panels about 0.31 m above the floor.
- Suspended chamber centre: about **(0, 3.0, 0)**; ring bearings at Y = 3.05 m.
- Sampled vertex bounds across phases and endings: approximately **4.47 m wide,
  5.23 m high, 4.35 m deep**. Reserve a conservative **4.9 × 5.6 × 4.9 m** visual
  envelope for all rotor angles, alignment transitions, vibration and torn covers.
  These are visual bounds; an imported ring's square culling AABB is larger.
- The original reactor was about 3 m wide and 2.4–3 m high. The replacement
  substantially enlarges its upper silhouette without filling the room floor.
- Phase switches are at X = ±2.5 m; their ground approaches clear the platform.
  The actual player collision radius is 0.28 m. Rear towers stay inside the
  central footprint; there are no forward pillars or cables across walkways.
- Collision defaults **off**. Retain the room's existing central 1.5 m-radius
  blocker. `set_collision_enabled(true)` supplies one optional 1.48 m-radius,
  1.15 m-high cylinder for standalone use. Never enable both unnecessarily.
  No visual mesh, energy shell or rotating ring creates a collision shape.

## Public API

Use methods for runtime configuration; exported properties provide initial scene
settings. Case-insensitive string setters return `false` on unknown input and
preserve their previous value. Charge ignores NaN/infinity and clamps to [0, 1].

| Method | Parameters and behavior |
| --- | --- |
| `set_reactor_phase(phase: String) -> bool` | `discovery`, `armed`, `power`, `alignment`, `synchronization`, `ending`, `overload`. Smoothly changes speed, output and gimbal alignment. A non-ending phase clears the previous ending ID. Use `play_ending` to select a specific outcome. |
| `set_charge_ratio(value: float)` | Normalized 0–1. Smooths output and power-phase rotation speed. |
| `trigger_overload()` | Selects overload, clears any ending, sets charge to 1 and ramps available power up over 0.8 s. Reusable; no particles or timers accumulate. |
| `play_ending(ending_id: String) -> bool` | `trust`, `student_override`, `professor_override`, `paradox`; selects the ending phase automatically. |
| `set_timeline(timeline: String) -> bool` | `past` or `future`; recolors independent materials and exposes/deforms existing shields and damage. Does not duplicate the mesh library. |
| `play_startup(duration: float = 2.4)` | Smoothly ramps power and mechanical speed from current power to full. To start unpowered, call `play_shutdown()` **before** adding the node, then `play_startup()` after adding it. |
| `play_shutdown(duration: float = 3.0)` | Smoothly stops rotors and extinguishes energy/light from current power. Durations have a minimum of 0.05 s in-tree. |
| `set_effects_enabled(enabled: bool)` | Disables additive chamber shell, energy orbits, discharge segments and dynamic light; keeps mechanical geometry and opaque physical conduit currents. |
| `set_motion_enabled(enabled: bool)` | Freezes continuous rotation, shader clock, bobbing and vibration. Smooth presentation changes can still settle after a state change. |
| `set_collision_enabled(enabled: bool)` | Optional single central body on collision layer 1, mask 0. Defaults off. |
| `set_active(active: bool)` | Changes visibility and processing together. Call for the inactive timeline to avoid its animation cost. |

Exported initial settings: `timeline`, `reactor_phase`, `charge_ratio`,
`effects_enabled`, `motion_enabled`, `collision_enabled`.
`ending_id` is a readable presentation value; use `play_ending` to change it.

| Outcome | Color and mechanical behavior |
| --- | --- |
| `trust` | Jade green, slow forward stabilization, progressively flatter gimbals, quiet energy and no discharges. |
| `student_override` | Amber, reversed primary rotor, vertically separated bearings, downward plasma displacement and reversed energy flow. |
| `professor_override` | Cold blue, forward anchored motion, near-vertical gimbals and rising plasma. |
| `paradox` | Violet, fast reversed primary rotor, opposing inner/focus rotors, oscillating gimbals and levitation with bounded discharges. |

Past has clean sage/cream metal, copper, warm emission and closed shields.
Future has oxidized slate metal, cold energy, grime, two missing curved shields,
two torn shields, exposed cabling and crystal fractures. Switching back restores
the intact shields. Mutable shader/standard materials are created per instance;
immutable imported mesh resources remain shared.

## Replacing the original visuals during integration

The gameplay agent should make this integration in its owned files. Keep all
existing fields alive: the current room's `apply_state` and `_process` still refer
to them. **Hide instead of freeing** the original `world.core`, every entry in
`world.rings`, `world.rifts`, and `world.reactor_light`. Also hide:

1. The central intermediate CylinderMesh at local (0, 0.75, 0).
2. Only the MeshInstance3D child of the original central StaticBody3D whose
   CylinderMesh has radius 1.5; preserve that body's CollisionShape3D.
3. The old `TEMPORAL CORE` floating title above the chamber.

The dedicated `tools/reactor_visual/room_review.gd::hide_original` demonstrates
these exact selections on temporary instances of the current room. It does not
save changes. Keep floor, gate and gate collision, conduits, coil indicators,
stations, station labels, warning rails and every interaction node intact.

Instantiate one reactor under each timeline world. From confirmed gameplay
snapshots, map the existing stages to visual phases in the gameplay adapter:

| Gameplay condition | Presentation call |
| --- | --- |
| DISCOVERY | `set_reactor_phase("discovery")` |
| Start acknowledged | `set_reactor_phase("armed")`, `play_startup()` |
| STAGE_A | `set_reactor_phase("power")` and normalized confirmed charge |
| STAGE_B before both calibrations | `set_reactor_phase("alignment")` |
| STAGE_B sync window or STAGE_C | `set_reactor_phase("synchronization")` |
| ENDING | `play_ending(snapshot.ending)` |
| OVERLOAD | `trigger_overload()` once on transition |

This is an integration suggestion, not puzzle logic in this module. Decide the
normalized charge in the authoritative-state adapter; do not derive it from
private choices or let presentation setters submit actions. On replay set phase
to discovery, reset charge, and restore power as needed. Call `set_active` when
the local timeline changes.

## Geometry and rendering budget

The original deterministic generator produces 30,426 triangles, 47 material
surfaces, and a roughly 2.4 MB GLB. Static geometry is merged per material on each
rigid component. The three rotors remain independent named parts. It contains
segmented annular armor, joints, fasteners, reinforcement blocks, channels,
open cage bars, insulators, clamps, heat-exchanger fins, struts, sockets, access
doors, panel seams, warning marks, maintenance points and routed cables/pipes.

Runtime effects add three low-poly orbit hoops, one faceted plasma heart, one
small additive shell, one unshadowed light and exactly 18 discharge segments in
one MultiMesh. Opaque shader strips carry travelling cyan/amber/violet currents.
The shell uses a few analytic sine functions; there are no screen/depth textures,
compute shaders, volumetric fog, bloom dependencies, particles or Forward+ APIs.
Pulse/brightness modulation is gentle, with no full-screen effects or camera shake.

The standalone preview records 99–103 draw calls including its tile grid,
station proxies and controls. An uncapped Future-overload profile with controls
hidden recorded 94 calls and ~30,110 rendered primitives at 1600×900 on AMD
Radeon(TM) Graphics / OpenGL 3.3 Compatibility: median frame 1.581 ms, p95
2.874 ms; measured module update median 0.216 ms, p95 0.325 ms over 150 frames.
This is a standalone local sample, not a guarantee for the full networked room.
Raw results are in `review/metrics.json` and `review/profile.json`.

## Verification and reproducibility

Executed on Godot 4.7.2.stable.official.ed1daf0bf:

- **74 deterministic checks passed**: phases/endings, ring directions, charge
  response, finite animation, input validation, pre-tree configuration, independent
  materials, shared geometry, reversible damage, bounded discharges, reduced
  effects/motion, startup/shutdown, optional collision, visibility/process culling,
  ground clearance and sampled vertex bounds.
- **10 GL Compatibility captures passed**: Past discovery/synchronization, Future
  overload, all four endings and three exact gameplay-camera views.
- **6 actual-room captures passed**: original/replacement at each timeline's
  entry and replacement at each phase-switch approach, including the actual
  character scale, room props, gate and consoles. These use the current room
  builder in a temporary tree and save only PNG files in this module's review folder.
- **150-frame Future overload profile passed**. No script, shader or render errors.
- The final integration remains with the gameplay agent: attach the two modules,
  hide legacy visuals, forward confirmed snapshot presentation, and check the
  final HUD/cinematic composition after that agent's changes. No integration or
  gameplay ownership was assumed here.

```powershell
$env:GODOT_BIN = 'C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe'
.venv/Scripts/python.exe tools/reactor_visual/build_reactor.py
.venv/Scripts/python.exe tools/reactor_visual/run_checks.py --import-assets
.venv/Scripts/python.exe tools/reactor_visual/run_checks.py
.venv/Scripts/python.exe tools/reactor_visual/run_checks.py --render
.venv/Scripts/python.exe tools/reactor_visual/run_checks.py --room
.venv/Scripts/python.exe tools/reactor_visual/run_checks.py --profile
```

The builder uses the existing `tools/assets/meshkit.py` and `tools/gltf_tools.py`
with NumPy. No external models, textures, downloads or new Python dependencies
are required. Original geometry; no third-party asset attribution is needed.

## Created files

`FILES.txt` enumerates every deliverable, including generated `.uid`/`.import`
metadata and review images. The main files are:

- `assets/environments/level3/reactor_visual/`: GLB, import settings, manifest,
  this guide, file inventory and `review/` (16 PNG captures and two JSON reports).
- `scenes/level3/reactor_visual/reactor_visual.tscn`
- `scenes/level3/reactor_visual/reactor_preview.tscn`
- `scripts/level3/reactor_visual/reactor_visual.gd`
- `scripts/level3/reactor_visual/reactor_preview.gd`
- `shaders/level3/reactor_visual/temporal_metal.gdshader`
- `shaders/level3/reactor_visual/temporal_energy.gdshader`
- `shaders/level3/reactor_visual/temporal_current.gdshader`
- `tools/reactor_visual/build_reactor.py`
- `tools/reactor_visual/run_checks.py`
- `tools/reactor_visual/verify_reactor.gd`
- `tools/reactor_visual/render_review.gd`
- `tools/reactor_visual/room_review.gd`
- `tools/reactor_visual/profile_reactor.gd`

Review output has `.gdignore` so screenshots are not imported into the game.
Tool logs have a local `.gitignore`; they remain available locally for inspection.
