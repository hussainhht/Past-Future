# Level 3: The Final Fracture

Implemented 21 October 2026 for the live Godot 4.7.2 repository. Room C is a playable standalone
vertical slice. Room A, the Room B placeholder, the shipping menu, original character assets and
existing tests were not edited. The root specification and three pre-existing untracked `.uid`
files were left untouched. No commits, pushes, resets or stashes were made.

## Start here

Open `scenes/testing/temporal_core_sandbox.tscn` in Godot and press F6. Choose solo Past, solo
Future, or host/join. In solo mode the **DEV: OTHER TIMELINE** button lets one tester perform
both roles' physical interactions; it does not solve anything automatically. It retains each
role's location and evidence. This button is absent in live multiplayer and release builds.

Alternatively, F6 `scenes/rooms/temporal_core.tscn` for the Past preview. This scene is the real
production room, not a separate mockup.

PowerShell from the repository root:

```powershell
$Godot = 'C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $Godot --path . res://scenes/testing/temporal_core_sandbox.tscn

# Two terminals / two machines. Substitute the host's LAN/Tailscale IP on the guest.
& $Godot --path . res://scenes/testing/temporal_core_sandbox.tscn -- --core-host 7000
& $Godot --path . res://scenes/testing/temporal_core_sandbox.tscn -- --core-join 127.0.0.1 7000

# One role directly, for investigation and art review:
& $Godot --path . res://scenes/testing/temporal_core_sandbox.tscn -- --core-solo future
```

The command-line host/join route performs the existing lobby ready/start handshake automatically.
The interactive launcher exposes those buttons separately. Host is always Student/Past (Peer 1),
guest is always Professor/Future. Both enter through `GameFlowManager.start_room("room_03")`.
The development launcher redirects to the normal menu in a release build.

## Controls and play

| Input | Operation |
| --- | --- |
| WASD / arrows / left stick | Existing camera-relative movement |
| Shift / existing sprint binding | Sprint |
| `interact`: F / controller Cross or A | Use the nearest highlighted physical station |
| J / JOURNAL button | Review discovered evidence in the existing role-local journal |
| Escape / controller cancel | Close a panel or open the room menu |
| Mouse / UI focus navigation and accept | Operate terminal commands and confirmations |
| DEV: OTHER TIMELINE | Offline debug preview only |

InputManager supplies the project's existing action map and device-aware interaction prompt.
The footer lists supported keyboard and controller use bindings. Inspect screens are skippable,
scrollable native controls. No in-game voice chat is added: communicate externally.

The camera keeps the existing 35-degree pitch, 48-degree perspective and follow behavior. Each
character and collision-body root uses ground-contact coordinates. Past and Future use the same
18 × 14 metre footprint, central reactor, columns, desks and perimeter. The local view shows one
timeline; the other exists 40 metres away so the host can validate Future movement against its
actual geometry. Only the local avatar moves under input. The second avatar is an ending projection.

## Flow and puzzle solution

1. **Discovery, no clock.** Inspect the Past authorization sheet and handwritten warning, or the
   Future continuity recording. These reveal different facts and unlock only the local journal.
   The Professor is an anchored temporal echo outside ordinary linear causality, so seizing the
   anchor can preserve him despite a rewritten Past. Evidence explains rather than selects a command.
2. **Arm deliberately.** Use ARM REACTOR near the entrance and confirm the explicit 150-second
   warning. Merely opening the console never starts the challenge. Either role may request it;
   only the host authorizes it after both room instances have completed their role handshake.
3. **Stage A, power.** Future physically restores the receiver battery, then reads the nearby routing
   diagram. Tell Past: **coil 1 = 2, coil 2 = 0, coil 3 = 1**. Past uses the three west-bank coils,
   each cycling 0 → 1 → 2 → 0. Mistakes can be reversed without a penalty. Every confirmed change
   changes corresponding conduit indicators across both timelines. The correct configuration AND
   a restored Future receiver rebuild the collapsed north conduit, disabling its real collision.
4. **Stage B, alignment.** Future crosses that opened path and calibrates the Signal Anchor. This
   exposes the Past waveform and enables the Student's Origin Core. Past physically stabilizes it.
   Both then use their respective phase switches within **five seconds**. A single switch never
   completes synchronization. A missed window clears both switches for a straightforward retry.
   Solving immediately enters Stage C, regardless of how much of the 150 seconds remains.
5. **Stage C, identity.** Past uses the Origin Terminal; Future uses the Continuity Terminal. Choose
   an in-world command and confirm it in a separate panel. Both interfaces explain safe and forbidden
   outcomes, including the risk of conflicting overrides. Each command locks once. The partner sees
   a neutral lock indicator and cannot inspect its value through replicated puzzle state.
6. **Conclusion.** Both valid commands resolve together once. The fixed-camera scene stages both
   identities, changes reactor color/ring movement, plays a distinct sting, fades the appropriate
   character(s), and presents short dialogue. Non-paradox endings receive an unexplained signal from
   an unknown third time. Paradox reverses the rings, dissolves both identities, returns the avatar to
   the arrival/first-contact motif and displays ITERATION 02 DETECTED. Escape can reveal the end
   navigation early. Replay Room C is host-controlled in LAN; both peers can return to the menu.

| Student | Professor | ID | Title and result |
| --- | --- | --- | --- |
| GROUND THE CORE | RELEASE THE ECHO | `trust` | THE LAST GOODBYE: green seal, Professor voluntarily fades, Student/world survive |
| CLAIM ORIGIN | RELEASE THE ECHO | `student_override` | ERASED FUTURE: amber reverse rotation, Professor/timeline erased, forbidden protocol signature exposed |
| GROUND THE CORE | PRESERVE ECHO | `professor_override` | STOLEN TOMORROW: cold blue anchor, Student fades, changed Future and anchored Professor survive |
| CLAIM ORIGIN | PRESERVE ECHO | `paradox` | ITERATION 02: violet counter-rotation, both dissolve, first-contact loop resumes |

## Time, authority, privacy and lifecycle

`core_rules.gd:CHALLENGE_SECONDS` is exactly **150.0**, also exposed as the scene's
`challenge_seconds` export. The host uses its own monotonic deadline. It refreshes canonical
remaining time about five times a second through PuzzleManager. Each peer predicts the display
from elapsed time since its own last snapshot; no timestamp from one machine is compared with
another machine's clock. The display clamps at zero. Menus, inspection and journals leave the
shared timer running, and say so explicitly. Opening them only blocks local controls.

The only shared-manager change is an additive host-only `PuzzleManager.refresh_puzzle(id)` hook.
Timed rules optionally implement `refresh_state(state)`. Untimed puzzles retain their old behavior.
PuzzleManager settles this hook before each action, so a late request cannot beat an expired
deadline. Network clients cannot invoke a clock action or submit replacement state.

PuzzleManager's existing reliable RPCs derive role from the actual connected peer and broadcast
monotonically increasing revisions. Room C additionally validates exact payload keys/types,
attempt, increasing per-role sequence, stage, command ownership, one lock per role, prerequisites
and host-checked station distance. Invalid and duplicate actions cannot change progress. Future
movement reports are attempt-scoped, finite/bounded, speed-budgeted and swept through the actual
Future collision geometry on the host. Reports never carry role or puzzle state. Rejected divergent
movement is corrected to the host's accepted position. Actions reject stale positions; ordinary
movement does not optimistically advance the puzzle.

Private commands and deadline bookkeeping live only in the host rules object. Replicated fields
contain lock booleans and, after both votes, the ending ID. As in any listen-server game, the host
process is trusted; this does not promise secrecy against someone inspecting host process memory.

At expiry, the host enters an audiovisual **OVERLOAD** substate for three seconds, then creates a
fresh numbered Room C attempt in DISCOVERY with 150 seconds. Hardware, phase windows and commands
reset. Both avatars return to safe entrance positions so the reclosed Future conduit cannot trap
anyone. Earlier puzzle records and discovered evidence remain intact. This is a failed attempt,
not a fifth narrative ending. Resolved endings stop refreshing the clock, so later timeout work
cannot replace them. Replay uses the same fresh-attempt reset and cancels old presentation tweens.

Disconnect suspends movement, interactions and Room C refresh, closes evidence/journal panels and
shows a connection-lost recovery panel. Reconnect requires returning to the menu and establishing
a new session; seamless rejoin is not claimed. Scene-owned signals disconnect on destruction,
tweens die with the scene, and generated audio stops/clears streams on teardown. A fresh intentional
entry resets only Room C. This room does not start/reset the shared puzzle session on a transition.

## Room B integration contract

Room C is registered by the new `resources/levels/room_03.tres`; GameFlowManager discovers it with
its existing directory scan. **Room B was not modified.** Its current placeholder deliberately still
has no forward exit. The corridor developer should:

1. Set their Room B definition's `next_room_id = "room_03"`. Put their actual completed puzzle ID(s)
   in Room B's `required_puzzles`. Preserve existing return exits. Do this on the identical build
   used by both peers.
2. For a normal cooperative exit, use the existing `LevelExitInteractable` and leave its destination
   blank (uses `next_room_id`), or call `GameFlowManager.request_transition("room_03")` from each
   role's exit interaction. Existing readiness, puzzle prerequisites and host authorization apply.
3. For an explicit host-driven completion event, call the single adapter below **on the host**.
   It delegates to the same synchronized fade/load/peer-commit protocol and checks the Room B origin.
   It skips exit readiness, but does not skip corridor puzzle prerequisites or adjacency checks.

```gdscript
const CoreEntry := preload("res://scripts/level3/core_integration.gd")

func _on_corridor_completed() -> void:
    if PuzzleManager.is_authority():
        var reason := CoreEntry.enter_temporal_core()
        if not reason.is_empty():
            push_warning(GameFlowManager.get_reason_message(reason))
```

The room exposes `past_entry` / `future_entry`, `is_game_flow_ready()`, `game_flow_suspend()` and
`is_gameplay_paused()`, and respects `GameFlowManager.is_input_locked()`. Both peers use exactly the
same TemporalCore RPC NodePath and shared scene. Do not call `change_scene_to_file()` to enter it
from one peer. No Room A/B puzzle state, radio ownership or session ID is reset by this transition.
Role-specific room construction and rules are separated for future independent viewport views;
this implementation does not add split-screen or claim it has been tested.

## Files and assets

| Path | Purpose |
| --- | --- |
| `scenes/rooms/temporal_core.tscn` | Production room, built from reusable props and procedural geometry |
| `resources/levels/room_03.tres` | Existing GameFlowManager registration |
| `scripts/level3/core_rules.gd` | Authoritative stage, time, synchronization and four-choice rules |
| `scripts/level3/temporal_core.gd` | Role avatars, interactions, pose validation, host refresh, cinematics and lifecycle |
| `scripts/level3/core_world.gd` | Room variants, real collisions, conduit causality, core/rings/rifts and prop reuse |
| `scripts/level3/core_ui.gd` | HUD, inspect/confirmation panels and ending navigation |
| `scripts/level3/core_story.gd` | Original role-local evidence and branch dialogue |
| `scripts/level3/core_sound.gd` | Generated audible ambience, cues, warnings and four different stings |
| `scripts/level3/core_integration.gd` | Host-controlled Room B completion adapter |
| `scripts/level3/core_launcher.gd`, `scenes/testing/temporal_core_sandbox.tscn` | Debug-only solo and LAN launch routes |
| `scripts/puzzles/puzzle_manager.gd` | Additive optional refresh hook; only existing production file changed |
| `tests/level3_core.gd`, `tests/level3_peer.gd`, `tests/run_level3_tests.py` | Deterministic/scene checks and two-process matrix |
| `tests/level3_visual.gd`, `docs/assets/screenshots/level3/` | Brief OpenGL presentation smoke and actual captured frames |
| `assets/third_party/LEVEL3_ASSET_CREDITS.md` | Existing asset licenses and provenance, original new geometry/audio |

No asset downloads were necessary. All upstream assets remain unchanged; animated materials are
new per-instance resources and existing character scripts duplicate their animation libraries.
See [LEVEL3_ASSET_CREDITS.md](../assets/third_party/LEVEL3_ASSET_CREDITS.md).

The room uses compatibility-safe primitives, opaque surfaces, low-poly torus rings, geometric
rift shards and a single local point light. No Forward+ effects, full-screen flashing, compute,
volumetrics or runtime downloads. Menu → Reduce / Restore Ambient Effects hides optional rift
shards. The two worlds share loaded source meshes; the hidden world keeps collision for validation.
All generated cues use SFX/Ambience buses initialized by the existing AudioDirector, so saved
Master/category levels and mutes apply. Low-end hardware frame-rate performance and listening
balance still require a human play session; no fabricated FPS or listening result is reported.

## Actual verification

Engine: **4.7.2.stable.official.ed1daf0bf**, Windows. Visual runner: actual OpenGL 3.3 Compatibility,
AMD Radeon Graphics, 1280 × 720. Verification was kept focused at the user's request.

| Check | Actual result |
| --- | --- |
| New production scene first-load / dependencies | PASS: headless instantiation and playable scene tests, no missing dependencies or script errors |
| Existing Student GLB integrity | PASS: 90,881 skinned vertices, 23 bind transforms, 77 clips, 5,011 samplers |
| Existing `tests/student_3d.gd` | PASS: 77 clips, zero failures |
| Existing `tests/puzzle_system.gd` after optional refresh hook | PASS: 131 checks, zero failures |
| `tests/level3_core.gd` | PASS: 90 checks, zero failures |
| `tests/level3_peer.gd` / real ENet host and client | PASS: 38 checks per peer, zero failures; all four endings have identical revisions on both peers |
| ENet ending revisions in final recorded matrix | trust 70 / student_override 138 / professor_override 206 / paradox 274 on BOTH peers |
| GL Compatibility visual smoke | PASS: 11 actual rendered screenshots; both room variants, evidence and ending presentation/navigation |
| Screenshot inspection | Both room variants, private evidence and the conclusion panel inspected for 1280 × 720 readability; screenshots remain in the repository |
| Existing spawn-room baseline, before implementation | FAIL: return-to-menu assertion at `tests/spawn_area.gd:209`, then missing `%PlayButton` / null access at line 210; stopped the stalled baseline process |
| Existing LAN smoke baseline | FAIL: busy/host passed; client printed PASS but emitted a null `scene_file_path` access at `tests/lan_peer.gd:127`; runner correctly rejected it |
| Legacy 2D / old student_v2 scenes | Known missing upstream assets, not repaired or included in Room C; not rerun |
| Two physical computers / WAN / extended human session | NOT VERIFIED |
| Human audio balance, low-end FPS, full game through finished Room B | NOT VERIFIED; Room B integration is deliberately left to its owner |

The focused suite covers idle/activated/exactly expired time, reversible coils, real station
detection, confirmation UI, dependency gates, Future collision opening, exposed Past waveform,
sync and retry, private journal, four endings, one-vote lock, malformed commands, role spoofing,
duplicate and stale-attempt actions, old state revisions, replay, immutable resolution and
disconnect recovery. The network test physically moves the guest CharacterBody through the
production room and host position validator. Test-only host teleportation speeds setup; it is
absent from production code and cannot be requested by the guest.

An initial network harness race tried replay before the guest had finished verifying the ending;
the harness now uses an explicit test-only peer checkpoint. All four final production outcomes
and state revisions agree. An observed generated-audio teardown leak was fixed by stopping players
and clearing their streams. The rendered run exited without leak warnings. Headless runs skip
starting sound on the dummy audio driver, which otherwise retained generated WAV playback at exit;
they still construct the same non-silent PCM resources. Audio listening is a separate human check.

Run only the desired checks:

```powershell
$env:GODOT_BIN = $Godot
python tests/run_level3_tests.py                 # deterministic room checks + ENet matrix
python tests/run_level3_tests.py --peers-only    # just the two-process matrix
& $Godot --headless --path . --script res://tests/level3_core.gd
& $Godot --path . --resolution 1280x720 --script res://tests/level3_visual.gd
```

Remaining integration limits: the corridor developer must connect their forward exit/completion
event; existing unrelated spawn/menu and legacy LAN test failures remain; physical LAN/WAN,
gamepad hands-on feel, audio listening balance and a low-end hardware pass remain unverified.
There is no known Room C gameplay blocker in the tested standalone flow.
