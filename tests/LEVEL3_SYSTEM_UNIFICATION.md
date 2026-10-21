# Level 3 shared-system integration ? 21 October 2026

## Git and preservation

Started on `main` at `e113067`, tracking `origin/main`, with existing staged/unstaged
work and remote commit `9234df1`. Fetched origin; preserved the existing work in
`8059f02`, then merged upstream as `8872db1` and successfully pushed it to `origin/main`.
The `core_ui.gd` conflict was resolved by retaining the existing physical-device
controls and stage information and integrating upstream status presentation.
An additional backup of the original work is under the Windows temporary directory
`the-other-me-premerge-20261021-162439`.

The implementation below is a separate task-owned commit. Existing concurrent
changes to `tests/level3_environment.gd`, environment screenshots/metrics and
`docs/LEVEL3_ENVIRONMENT_ART.md` are excluded from this task's staging.

## Implemented behavior

- Extracted the actual laboratory pause menu into `scenes/ui/pause_menu.tscn` and
  `scripts/ui/pause_menu.gd`. All three levels use that same implementation,
  typography, buttons, settings, tutorial and mode-aware solo reset. Compact
  layout at 960 ? 540 keeps every standard action visible. Native focus remains
  available to keyboard and controller navigation.
- Replaced the separate Level 3 pause panel and redundant objective/footer HUD
  with the existing `LabUI` objective/status rail and matching campaign header.
  Reactor stage, role, timer, radio link and synchronization information remain.
  The timer stays visible while inspecting actual devices. Notebook/DataPad uses
  the existing JournalManager interface, without a second visible journal button.
- Registered `switch_role` in InputManager and routed T through each room's
  existing role-switch function. Level 3 solo switching no longer depends on a
  debug build. Role positions, puzzle state and the attempt clock are retained.
  LAN roles remain locked. The old debug API is only a compatibility wrapper for
  existing sandbox tests; its visible developer button is removed.
- Initialized the existing TemporalGhost in Level 3. Previously it was never
  instantiated there. Its shared transform/visibility logic now handles the
  separate Past/Future roots, including Level 3's 40-metre timeline offset, and
  refreshes its camera reference after role changes. G and R1/RB still use the
  existing action. Radius, shader and visual-only collision behavior are unchanged.
- Replaced Level 3's generated-tone audio implementation with an event adapter
  to the existing AudioDirector, sound catalog and AmbientAudioController.
  Past/Future soundscapes crossfade. A player-mounted AudioListener3D restores
  the earlier rooms' footstep listening arrangement. Confirmed device changes
  drive coil, battery, calibration, phase and identity sounds. Reactor hum,
  warning, shutdown and ending cues use existing assets and buses. The shared
  radio audio bridge and DialogueDirector handle existing reactor story notices.
- The solo reactor clock stops during the shared pause menu, including its
  settings/tutorial/studio overlays. Journals and physical device operation keep
  the challenge running. LAN simulation uses the authoritative wall clock and
  continues through local menus; tests exercise this on both actual ENet peers.
- Fixed the laboratory's Character Studio button being disabled by the same
  condition as role switching while paused. Returning from a studio opened from
  pause restores that pause menu; direct F2 entry retains its prior return behavior.
- Removed the Level 3 multiplayer test button and its menu callback, as requested.
  The remaining visible launcher is **LEVEL 3 / SOLO TEST**. The Level 2 shortcut
  remains available through explicit `--development-tools` configuration.

## Device audit

| Device | Executed result |
|---|---|
| Student/Professor records and routing diagram | Existing private records, role restrictions and journal ownership preserved; production core/interaction checks pass. |
| Arming console | Actual controller/inspector, safe-cancel confirmation, 150-second start and duplicate rejection pass. |
| Coils 1, 2, 3 | Physical selectors and host-confirmed stop cycling pass; target remains 2 / 0 / 1. |
| Receiver battery | Professor-only reconnection, confirmed latch and audio event pass. |
| Signal Anchor | Professor calibration, prerequisites and confirmed sound pass. |
| Origin stabilizer | Student ownership, Anchor prerequisite and confirmed sound pass. |
| Both phase switches | Five-second window, missed-window retry, role restrictions and host-confirmed progression pass. |
| Identity terminals | Confirmation, private choices, replay and all four outcomes pass locally and over ENet. |
| Overload/retry | Full real-time 150-second run and three-second recovery pass; attempt state resets while established evidence remains supported. |

`core_rules.gd`, PuzzleManager, network RPC authority, revision ordering, authored
station positions and physical device implementations were not changed.

## Executed verification

Results below are executed automated checks, not claims of physical controller or
second-computer testing. Broad testing stopped at the user's request; only the
checks already running were collected afterward.

| Command / suite | Result |
|---|---|
| `python tests/run_level3_tests.py` | PASS: core 101, physical interactions 540, ENet host 102/client 82; both peers agree on trust, student_override, professor_override and paradox. |
| `python tests/run_gameplay_tests.py` | PASS: solo 113, host 35, client 39. |
| `python tests/run_puzzle_tests.py` | PASS: 131 checks and host/client synchronization. |
| `python tests/run_signal_lab_tests.py` | PASS: scene and both peers. |
| `python tests/run_maintenance_tests.py` | Storage rules, corridor rules, scene, ghost and text-layout checks PASS. Initial LAN client reload assertion failed; isolated baseline passed. Fixed the test's two-frame scene-loading assumption to await `scene_changed`; `--lan-only` then PASS on both peers. |
| `python tests/run_controller_tests.py` | PASS: 79 generated-input checks; physical hardware unverified. |
| `python tests/run_menu_tests.py` | PASS: 90 checks, including solo-only Level 3 launcher and hidden Level 2 development shortcut. |
| `python tests/run_game_flow_tests.py` | PASS: 257 checks; full host 236/client 227; host-leaves 7/client 8. |
| `python tests/run_dialogue_tests.py` | PASS: 382 checks. |
| Godot `tests/audio_system.gd` | PASS: 271 checks. |
| Godot `tests/temporal_ghost.gd` | PASS: 78 checks. |
| Godot `tests/interaction_system.gd` | PASS: 58 checks. |
| Godot `tests/journal_system.gd` | PASS: 24 reported assertions. |
| Godot `tests/settings_ui.gd` | PASS: 58 checks. |
| Godot `tests/shared_campaign_systems.gd` | PASS: final headless 127 checks, including actual Enter activation of studio buttons in all rooms. Earlier rendered batch PASS: 151 checks and captures at 1600 ? 900, 1280 ? 720 and 960 ? 540. |
| Godot `tests/shared_campaign_systems.gd -- --countdown-only` | PASS: 7 checks, including the full 150-second real-time countdown, solo pause and three-second recovery. |
| Godot `tests/level3_smoke.gd` | PASS. |
| Godot `tests/spawn_area.gd` | PASS after the final studio availability fix. |
| `git diff --check` | PASS. |

Early headless Level 3 runs reported audio-resource shutdown leaks despite gameplay
assertions passing. Tests now free the production room and allow native audio
release before process shutdown, consistent with other project runners. The final
Level 3 suite completed without those errors. The Dummy driver does not start the
new reactor ambience loop.

## Production-room matrix and manual limits

| Feature | Level 1 | Level 2 | Level 3 |
|---|---|---|---|
| Shared pause, settings, tutorial, studio, resume | Automated PASS | Automated PASS | Automated PASS |
| HUD and minimum-window layout | Rendered PASS | Rendered PASS | Rendered PASS |
| T role switch with visible/hidden shortcut | Automated PASS | Automated PASS | Automated PASS |
| G toggle and opposite-role ghost after T | Automated/rendered PASS | Automated/rendered PASS | Automated/rendered PASS |
| Timeline footstep emitter and listener | Automated PASS | Automated PASS | Automated PASS |
| Past/Future ambience selection | Automated PASS | Automated PASS | Automated PASS |
| Existing prompts and device inspector | Automated PASS | Automated PASS | Automated PASS |
| Journal ownership and continuity | Automated PASS | Automated PASS | Automated PASS |
| Controller input paths | Generated input PASS | Generated input PASS | Generated input PASS |
| Multiplayer ownership and transitions | Loopback ENet PASS | Loopback ENet PASS | Loopback ENet PASS |

Unverified: physical Xbox/DualSense hardware, a second physical computer, real LAN
conditions, and subjective listening on speakers/headphones. This was automated
production-scene execution plus visual inspection of rendered captures, not a full
human gameplay session. No unexecuted manual check is labelled PASS.

## Captures

Screenshots are under `docs/assets/screenshots/system_unification/`:

- `main_menu_solo_only.png`
- `level1_hud_1280.png`
- `level1_pause_1280.png`
- `level2_hud_1280.png`
- `level3_hud_1280.png`
- `level3_pause_1280.png`
- `level3_student_ghost.png`
- `level3_professor_ghost.png`

The capture batch preceded the final laboratory Studio-button availability fix;
its Level 1 pause capture shows that button disabled. The subsequent 127-check
production test activates that button with Enter and verifies the fix. No extra
render suite was started after the user's testing-limit instruction.

## Asset protection

Compared implementation against post-merge `8872db1`: reactor GLB, meshes,
materials, shaders, animations, laboratory environment scripts/scenes, character
assets, map layout, existing devices and bridge are unchanged. Level 3's room scene
and Level 2's world scene are unchanged. The Level 1 scene diff only extracts pause
UI and updates the T hint; its authored 3D nodes/resources/camera compare unchanged.

## Task-owned files

- `scenes/menu/main_menu.tscn`
- `scenes/world/spawn_area.tscn`
- `scenes/ui/pause_menu.tscn`
- `scripts/gameplay/laboratory_gameplay.gd`
- `scripts/input/input_manager.gd`
- `scripts/level3/core_sound.gd`
- `scripts/level3/core_ui.gd`
- `scripts/level3/temporal_core.gd`
- `scripts/menu/main_menu.gd`
- `scripts/ui/lab_ui.gd`
- `scripts/ui/pause_menu.gd`
- `scripts/ui/pause_menu.gd.uid`
- `scripts/world/maintenance_corridor.gd`
- `scripts/world/spawn_area.gd`
- `scripts/world/temporal_ghost.gd`
- `tests/gameplay_integration.gd`
- `tests/level3_core.gd`
- `tests/level3_interactions.gd`
- `tests/level3_peer.gd`
- `tests/level3_smoke.gd`
- `tests/maintenance_peer.gd`
- `tests/menu_buttons.gd`
- `tests/settings_ui.gd`
- `tests/shared_campaign_systems.gd`
- `tests/shared_campaign_systems.gd.uid`
- `tests/LEVEL3_SYSTEM_UNIFICATION.md`
- `docs/assets/screenshots/system_unification/.gdignore`
- `docs/assets/screenshots/system_unification/main_menu_solo_only.png`
- `docs/assets/screenshots/system_unification/level1_hud_1280.png`
- `docs/assets/screenshots/system_unification/level1_pause_1280.png`
- `docs/assets/screenshots/system_unification/level2_hud_1280.png`
- `docs/assets/screenshots/system_unification/level3_hud_1280.png`
- `docs/assets/screenshots/system_unification/level3_pause_1280.png`
- `docs/assets/screenshots/system_unification/level3_student_ghost.png`
- `docs/assets/screenshots/system_unification/level3_professor_ghost.png`
