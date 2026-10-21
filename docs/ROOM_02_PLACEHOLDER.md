# Room 02 production placeholder

> Historical implementation report. Production Room 02 now loads the playable [Maintenance Gallery](LEVEL_02.md) through the same GameFlowManager. The placeholder scene remains available as a development asset; it is no longer the registered destination. Current production tests exercise the gallery, its entry markers, radio status and return exit.

Implemented and verified on 21 October 2026. The existing game-flow implementation is merged into `main` (`fb8def5`, including `a1586cd`); the working tree was clean before this change. No commits or pushes were made.

## Integration

`resources/levels/room_02.tres` registers **room_02 / Maintenance Corridor** through GameFlowManager's existing automatic `resources/levels/` discovery. It points to one shared scene, `scenes/world/room_02_placeholder.tscn`. `past_spawn_id` and `future_spawn_id` select its `past_entry` and `future_entry` markers. `next_room_id` is empty; Room 03 is not registered. `allowed_exits` contains `room_01` for the clearly labelled temporary return doorway.

Room 01 already declares `next_room_id = "room_02"`, requires `puzzle_01_frequency`, and requires both players ready. Its existing corridor `LevelExitInteractable` now resolves a registered destination. Neither its resource, exit, nor GameFlowManager needed editing. Frequency completion opens the existing progression path but does not initiate a room transition; the players still use the exit and readiness flow.

The placeholder is a native primitive blockout with a 14 × 10 metre interior, floor, four enclosing walls, a closed entrance door, lighting, and matching collision. It contains no new puzzles, equipment, documents, dialogue or music.

## Timeline and spawning

`room_02_placeholder.gd` reads `PuzzleManager.get_local_role()`. Both roles use the same layout: warm, light materials for Past and cool, darker blue materials for Future. The existing Student or Professor scene is instantiated once at the definition-selected marker, with its root at floor height:

| Role | Character | Marker | Position |
|---|---|---|---|
| Past / host | Student | `past_entry` | `(-1.4, 0, -1.8)` |
| Future / client | Professor | `future_entry` | `(1.4, 0, -1.8)` |

The existing fixed-perspective `follow_camera.gd`, interaction rig/prompt, TemporalRadio, radio HUD and held-radio presenter are reused. There is one character, camera, radio and interaction controller per peer, one radio HUD, and no additional AudioDirector. Existing footsteps are reused without a new soundscape or audio implementation. Character assets are loaded for the selected timeline on the main thread, following existing room conventions.

## State persistence

The scene only reconstructs local presentation from existing managers. It never calls `PuzzleManager.begin_session()`, `reset_all()`, `NetworkManager.start_game()`, or creates a new network peer. TemporalRadio restores ownership, the established 67 MHz link and its HUD from confirmed PuzzleManager state. Existing transition locks/fades and cooperative readiness remain entirely owned by GameFlowManager.

## Files

Created:

- `resources/levels/room_02.tres`
- `scenes/world/room_02_placeholder.tscn`
- `scripts/world/room_02_placeholder.gd`
- `scripts/world/room_02_placeholder.gd.uid` (Godot-generated companion)
- `docs/ROOM_02_PLACEHOLDER.md`
- `docs/assets/screenshots/room_02/past_student.png`
- `docs/assets/screenshots/room_02/future_professor.png`

Modified:

- `docs/GAME_FLOW_SYSTEM.md` — production registry/Room 02 documentation.
- `tests/game_flow_system.gd` — existing production round trip now uses the registered Room 02; adds grounded spawn, movement, camera/HUD and return-interaction checks.
- `tests/game_flow_peer.gd` — a focused production scenario using the real ENet lobby, real puzzle actions, production lab and exit, and existing test barriers.
- `tests/run_game_flow_tests.py` — exposes that scenario as `--production-only`.

The editor automatically reformatted the audio bus resource during import; that incidental change was restored to its original content. Audio, dialogue, interaction, networking and puzzle implementation files were not modified. No assets were deleted.

## Executed verification

Godot executable: `C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (4.7.2, GL Compatibility).

| Check | Actual result |
|---|---|
| Editor import | Exit 0; scene/script imports without errors |
| Existing offline game-flow suite | **257 checks passed**, exit 0; real lab → production Room 02 → lab, prerequisites, locks/fades, floor contact, movement and temporary return; no unexpected errors or shutdown leaks |
| Production ENet pair with real renderer | **Host 19 / client 18 checks passed**, both exit 0; one-ready waits, both-ready transitions, correct timeline/character/spawn, movement/camera, clear fade, no duplicates, same ENet object/session, unchanged frequency state/revision, and one puzzle completion |
| Existing gameplay solo regression | **71 checks passed**, exit 0; no runtime errors or shutdown leaks |
| Visual review | Past Student and Future Professor screenshots inspected at 1280×720, including connected 67 MHz HUDs |

The offline suite intentionally provokes invalid-scene/RPC recovery cases; its existing runner distinguishes those expected errors from actual failures. During development, a test-only readiness observation race was corrected with the existing barrier, and eager character-scene preloads were replaced with the existing main-thread loading convention to eliminate loader-object shutdown leaks. Final runs above are after those corrections.

Reproduce the focused checks:

```powershell
$env:GODOT_BIN = 'C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
.venv\Scripts\python.exe tests/run_game_flow_tests.py --offline-only
.venv\Scripts\python.exe tests/run_game_flow_tests.py --production-only
& $env:GODOT_BIN --headless --path . --script res://tests/gameplay_integration.gd
```

## Manual route

1. Launch the normal menu. Choose Solo Test, or host/join a LAN game and start through the existing lobby.
2. Complete Room 01's radio acquisitions and **67 MHz** calibration. Finish the current conversation.
3. Walk through the opened security door into its existing exit zone, near `(6.2, 0, -10.1)`. Press **F**. In LAN, both players must remain at their exits and mark ready; one player alone does not start the transition.
4. After the fade, verify the Student's warm Past room and the Professor's cool Future room. Move normally and confirm the HUD still reads **67 MHz / CONNECTED**.
5. To return, use **F** at the placeholder's entrance doorway, near `(0, 0, -3.9)`. This is explicitly a temporary test return; LAN still requires both players ready.

No blocking issues remain in the verified forward transition. The room is deliberately an empty blockout; the full Maintenance Corridor design and gameplay remain future work. This task did not add a new pause menu or radio dialogue for Room 02. The optional LAN return uses the same transition/readiness implementation; its interaction was exercised offline, while the rendered two-peer check focused on the required forward transition.
