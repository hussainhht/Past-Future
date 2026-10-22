# Temporal reactor catastrophe

Room 3 timeout now latches a host-authorized catastrophe, plays a five-second temporal rupture on each timeline, then starts a fresh campaign in `room_01`. Successful endings retain their existing behavior.

## Presentation

| Remaining time | Presentation |
| --- | --- |
| 150–60 seconds | Gentle cyan core activity, independent counter-rotation, sparse chronon dust. |
| 60–30 | Smooth acceleration, violet highlights, growing discharges and light tremors. |
| 30–10 | Floor fissures, vertical temporal rifts, levitating fragments, equipment vibration. |
| 10–0 | Maximum counter-rotation and energy pulses; the final three seconds draw energy and particles inward. |

Intensity has continuous values and slopes at the authored thresholds, with exponential interpolation between authoritative snapshots. Presentation never changes puzzle geometry or collision.

| Cinematic time | Presentation |
| --- | --- |
| 0–0.8 s | Core contracts; containment arcs converge; camera eases toward the reactor. |
| 0.8–1.6 s | Core ruptures, three delayed shock rings expand, energy splinters radiate outward, impact shake. |
| 1.6–3.5 s | Shields separate, rings disrupt, desks and device assemblies fly outward, structural columns tilt, selected floor panels lift and wall dressing collapses. |
| 3.5–5 s | Temporal engulfment, one soft white wash, fade to black; hold black for coordinated loading. |

The Future uses its existing weathered reactor, ruined chamber, props and palette. Reduced motion disables camera shake and softens the screen wash; settings changes are picked up while playing. Camera pitch and FOV remain unchanged.

Effects use Compatibility-safe meshes, additive shaders and bounded MultiMeshes: 64 arc segments, 64 dust motes, 48 fragments, 64 burst splinters, three shock rings, and staged visual copies of existing props. Only the active timeline updates. There are no new rigid bodies, screen/depth texture dependencies, third-party assets, or global rendering changes. Copies and effects are freed with the room; modified decorative transforms are restored on exit.

## Authority and campaign reset

`CoreRules.refresh_state()` settles the deadline before action validation, clears private terminal votes, latches `OVERLOAD`, and replicates cinematic elapsed time. It never resets Room 3. `ENDING` cannot enter this path.

The room closes pause/settings, inspection, dialogue and journal presentation, blocks movement and interactions, and suspends all puzzle actions. Duplicate start/finish calls are harmless. Pose and handshake messages stop before scene unloading.

Each cinematic reports its final black frame to the surviving `GameFlowManager` autoload. The host waits for the guest acknowledgment with a 2.5-second grace limit, then calls `PuzzleManager.begin_session()` and the existing coordinated transition protocol: begin, load, loaded acknowledgments, commit, unlock. This deliberate restart bypasses normal adjacency and solved-puzzle requirements only for a confirmed reactor failure.

The new gameplay session rebuilds all registered puzzle records, clears private choices and timers, resets journal discoveries/seen flags, and recreates Room 1 actors, inventory, pickups, doors, devices, dialogue and transient room state. Unregistered stale records are discarded. New session IDs on puzzle requests prevent queued actions from an old campaign affecting the new one. The lobby protocol is now version 3 so mixed builds are refused.

ENet, peer roles, input preferences, graphics/audio settings and controller settings survive. Disconnection uses existing recovery UI after the cinematic rather than waiting indefinitely. A failed fresh-game scene load uses the existing menu recovery path; it cannot restore a destroyed chamber with erased campaign progress.

## Audio ownership

The cinematic emits only `impact`, `rupture` and `shockwave` cues. The room passes those to the existing sound adapter, mapped to the concurrently supplied catalog events `core_overload_impact`, `core_overload_rupture` and `core_overload_shockwave`, using `AudioDirector.play_sfx()`. Assign empty cue values to disable them. No music, ambience, alarm, footsteps, dialogue, bus or mix behavior was authored for this feature.

Concurrent audio work added assets and changed the catalog during validation. A missing generated `core_music_lead.ogg.import` remap was restored to its existing imported stream without changing the Ogg bytes. Initial runs that encountered the incomplete audio import are not counted as clean passes.

The audio developer subsequently integrated their new adapter into the room. Those changes were preserved. One explicit `bool` annotation in `core_sound.gd` fixes a Godot inference error in that integration; it changes no sound behavior.

## Files authored or edited for this feature

| Path | Purpose |
| --- | --- |
| `scripts/level3/reactor_instability_controller.gd` | Countdown escalation, fractures, arcs, debris, staged props and structural destruction. |
| `scripts/level3/reactor_explosion_director.gd` | Local cinematic clock, camera, overlays, reduced motion, audio cues and completion. |
| `scripts/level3/reactor_visual/reactor_visual.gd` | Existing mechanical rings, shields, core contraction and expanding energy shell. |
| `scripts/level3/temporal_core.gd` | Mount controllers, cinematic lock, state/time integration, reset acknowledgment and explosion audio mapping. |
| `scripts/level3/core_rules.gd` | Host timeout latch and replicated elapsed time; safe invalid-clock handling. |
| `scripts/level3/core_ui.gd` | Remove obsolete Room 3 retry guidance. |
| `scripts/level3/core_sound.gd` | One explicit boolean type annotation for a concurrent integration compile error. |
| `scripts/game_flow/game_flow_manager.gd` | Bounded cinematic acknowledgments, fresh session, coordinated Room 1 transition. |
| `scripts/puzzles/puzzle_manager.gd` | Cinematic action gate and session-scoped action RPCs. |
| `scripts/network/network_manager.gd` | Protocol version increment for the changed action RPC. |
| `scripts/world/follow_camera.gd` | Optional local cinematic focus, preserving ordinary camera conventions. |
| `scripts/journal/journal_manager.gd` | Clear notifications during catastrophe and session reset. |
| `scripts/journal/journal_ui.gd` | Cancel and hide stale notification presentation. |
| `shaders/level3/temporal_rupture.gdshader` | Procedural temporal filaments and growing surface fissures. |
| `tests/reactor_meltdown.gd` | Real-scene repeated restart smoke checks and optional screenshots. |
| `tests/run_reactor_meltdown_tests.py` | Two real ENet process runner on an ephemeral loopback port. |
| `tests/level3_core.gd` | Replace obsolete timeout retry expectations with Room 1/journal reset checks. |
| `tests/level3_interactions.gd` | Verify timeout exits inspection and restores Room 1 controls. |
| `tests/puzzle_system.gd` | Adapt direct boundary check to the session-scoped action signature. |
| `assets/audio/level3/music/core_music_lead.ogg.import` | Restore missing generated import metadata for the concurrent audio asset. |
| `docs/technical/REACTOR_MELTDOWN.md` | This implementation and validation report. |

Godot also generated UID sidecars for the new GDScripts and shader. `docs/assets/screenshots/meltdown/` contains stable, unstable, critical, imminent, containment, explosion, destruction, collapse and Room 1 captures, plus the corresponding `future_` captures. The pre-existing README edits and concurrent audio source/catalog/tool edits were preserved.

## Validation and limits

Engine: Godot 4.7.2. Visual captures: OpenGL 3.3 Compatibility on AMD Radeon Graphics.

| Command / check | Recorded result |
| --- | --- |
| `python tests/run_reactor_meltdown_tests.py` | PASS: host 52 checks, client 51 checks; two consecutive complete restarts, original ENet peer, roles, spawn, radio, journal, puzzle state, reduced motion and input unlock. |
| Godot `--headless --script res://tests/reactor_meltdown.gd` | Latest smoke after the concurrent adapter integration: PASS, 48 checks, two restarts. |
| `python tests/run_level3_tests.py` | Core sub-suite PASS, 103 checks. Initial interaction run exposed an invalidated test clock; guarded refresh fixed it. The wrapper was not counted as an all-green run. |
| Godot `--headless --script res://tests/level3_interactions.gd` | PASS, 539 checks after the clock/import fixes. |
| Godot `--headless --script res://tests/puzzle_system.gd` | PASS, 131 checks. |
| `python tests/run_level3_tests.py --peers-only` | PASS: host 102, client 82 checks; all four endings agreed, replay, role security and disconnect. |
| OpenGL `tests/reactor_meltdown.gd -- --render-review` and `--future-review` | Captured and inspected the Past and Future escalation, rupture, destruction, collapse and Room 1. A Future capture run overlapped incomplete audio imports, so its PASS marker alone is not treated as a clean runtime pass. |
| `git diff --check` on feature scripts/tests/shader | PASS. |

Headless scene runs still report 4–5 `ObjectDB` shutdown leaks. Verbose output identifies `RefCounted` objects with reference count zero, not surviving room/VFX nodes; the smoke checks confirm the old room was freed. This warning remains unresolved and is not described as a clean shutdown. There are no script/runtime errors in the latest smoke. The full ending/interaction suites were recorded before the audio developer's final adapter replacement and were not exhaustively rerun against that replacement.

No full campaign playthrough or exhaustive latency/hardware matrix was run. Restart coverage seeds earlier-room progress, validates its reset, checks starting position and radio availability, and performs two consecutive failures without reconnecting. Mid-cinematic disconnect recovery and every possible settings/modal combination were reviewed in code rather than exhaustively exercised. Performance was visually reviewed on the available laptop GPU; no hardware benchmark was run.
