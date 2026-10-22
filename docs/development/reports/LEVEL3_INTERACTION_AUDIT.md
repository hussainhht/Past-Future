# Level 3 gameplay integration audit

Implemented directly in the production Temporal Core room. Puzzle rules, target
settings, role ownership, host RPC validation, revisions, private command storage,
150-second deadline, five-second phase window and all four endings are unchanged.

## Files changed by this task

- `scripts/level3/temporal_core.gd`: inspector integration, input locks, local versus
  remote proximity validation, confirmations, replicated feedback and visual bridge.
- `scripts/level3/core_ui.gd`: compact HUD, role/reactor/progress display, physical
  control accessibility rail, pending/error/synchronization feedback and focus.
- `scripts/level3/core_devices.gd`: dedicated station controls, complete machine
  framing, confirmed readouts/lamps and acknowledged coil cycling.
- `scripts/level3/core_device_inspector.gd`: shared inspector adapter for native UI
  navigation, button animation and close-up occlusion of neighboring machines.
- `scripts/level3/core_reactor_bridge.gd`: optional verified module loading,
  presentation phase mapping, charge, overload, ending, timeline and effect settings.
- `tests/level3_core.gd`, `tests/level3_peer.gd`, `tests/run_level3_tests.py`:
  update expectations and exercise physical controls through two actual ENet peers.
- `tests/level3_interactions.gd`: production interaction audit for both roles.
- `tests/level3_smoke.gd`: brief final room/module integration check.
- This audit; Godot-generated UIDs; rendered captures under
  `docs/assets/screenshots/level3/interaction_*` and `integrated_*`.

No Level 1/2 implementation or reactor-agent-owned source was edited by this task.
Other agents' concurrent changes are outside this file list.

## Reused mechanics

Level 1: `InteractionDetector`, `InteractionController`, `Interactable3D`,
`DeviceInspector3D` picking, physical-control bindings, close-up camera framing,
camera/actor restoration, contextual prompts, InputManager labels/haptics,
JournalManager and existing AudioDirector SFX.

Level 2: physical equipment control bindings, native menu theme and fonts,
role-restricted machinery, prerequisite feedback, latched controls, deliberate
confirmation and host-confirmed device presentation. Frequency and amplitude
puzzles were not duplicated.

## Complete device audit

All devices can be approached through the existing detector/controller and opened
without submitting an action. Premature or completed devices remain inspectable;
their action controls display confirmed state and remain disabled when ineligible.

| Station | Functional controls and confirmed result |
| --- | --- |
| Arming console, either role | Physical ARM opens a separate confirmation with safe cancel focused. Only confirmed ARM starts the canonical 150-second deadline. Duplicate arming is disabled and rejected by rules. |
| Coils 1, 2, 3, Student | Three physical stop selectors, 0/1/2. Selection issues the existing cycle action one acknowledged step at a time. Readout and selected-stop lamp show confirmed state. Current stop cannot resubmit. Incorrect stops remain reversible. Target remains 2/0/1. |
| Receiver battery, Professor | RECONNECT BATTERY latches the existing receiver action. OFFLINE/CONNECTED readout, lamp, audio and replicated state agree. Connection remains latched for the attempt, as required by existing rules. |
| Signal Anchor, Professor | CALIBRATE submits the existing anchor action after power. Confirmation exposes the existing Past waveform. Repeated calibration is disabled. |
| Origin stabilizer, Student | STABILIZE waits for the confirmed Professor calibration, then latches the existing Origin action. Readout and lamps reflect stable state. |
| Past and Future phase switches | Physical lever controls use the role-specific sync action. Confirmed HELD/OPEN state rotates the lever and lights its lamp. Both players see held contacts and interpolated window feedback. Missed five-second windows reset and re-enable both controls. Result remains host-authoritative. |
| Origin terminal, Student | GROUND THE CORE / CLAIM ORIGIN open a separate private-command review. BACK is initially focused; explicit confirmation submits the existing choice action. |
| Continuity terminal, Professor | RELEASE THE ECHO / PRESERVE ECHO use the same deliberate confirmation. Only neutral lock status is replicated before resolution. All four ending combinations remain intact. |
| Authorization, warning, continuity recording, routing diagram | Existing role-specific readers and local journal unlocks retained. Routing still requires the connected receiver. |

Mouse rays, numeric shortcuts and accessible native buttons operate the same
physical controls. Keyboard Enter, controller A/Cross and D-pad navigation use
native focus. Esc/F/B/Circle step back, restore camera/actor visibility and return
to gameplay without opening pause. Inspection blocks movement and world prompts.
Journal and transition overlays suspend inspection controls. Overload, replay,
disconnect and endings close inspection safely.

Input gives local button motion, sound and haptic feedback. Confirmed changes drive
machine readouts, lamps and shared audio. Rejections display actionable messages;
pending client operations do not optimistically mutate the puzzle.

## UI

The full-width lower HUD was replaced by a compact objective/status panel. A smaller
header shows role/timeline, reactor status and A/B/C progression. The countdown
stays visible during inspection. Inspector records sit beside the complete
machine, with accessible controls on the other side. Ordinary room labels appear
on target instead of filling the room. Existing journal, confirmation, settings,
ending presentation and replay/menu navigation remain functional.

## Reactor integration

The completed module's scene, script, GLB and three shaders were inspected, and its
74-check standalone verification passed before the final integration check.
The bridge validates the four public method signatures, mounts isolated instances
for both timelines, maps canonical stages to the module's lowercase phases and
forwards confirmed charge, overload and ending events. It disables processing for
the inactive timeline and forwards the existing effects preference.

The old central core, rings, base visuals, light and rift presentation are hidden
while original central collision remains. Module files were not edited. Missing
module dependencies retain the stock reactor, with no hard scene dependency.

## Executed results

- `python tests/run_level3_tests.py`: PASS. Core 101 checks; physical interactions
  467 checks; ENet host 94 checks and client 74 checks. Both peers agree on all four
  ending revisions, replay, role security and disconnect recovery.
- Rendered physical interaction audit: PASS, 467 checks. Both role views were
  visually inspected; mouse and controller events were generated by the tests.
- Reactor standalone verification: PASS, 74 checks.
- Final `level3_smoke.gd -- --render-review`: PASS after mounting the completed
  reactor. Confirms both instances, stock hiding, phase mapping, real coil/battery
  actions, inactive-timeline culling, overload, ending and retry presentation.
- Puzzle authority: PASS, 131 checks plus both ENet peers.
- Shared interaction system: PASS, 54 checks.
- Controller system: PASS, 79 checks.
- Level 1 integrated gameplay: PASS, solo 113, host 35, client 39 checks.
- Level 2 rules, scene, temporal ghost and text-layout checks: PASS.
- Full Level 2 LAN suite: FAILED outside the Level 3 path. Its existing
  `maintenance_peer.gd` radio prerequisite times out and reports an async call
  without `await`; teardown also reports a missing `%TimelineButton` in SpawnArea.
  Those earlier-level files were not changed to address this unrelated failure.
- Scoped `git diff --check`: PASS.

No unfinished Level 3 gameplay function remains. Actual attached Xbox/DualSense
hardware was not used; controller input paths were verified with generated events.
Broad testing stopped following the user's request; the final check was the brief
Level 3 integration smoke check. For a short future check, run Godot with
`--headless --path . --script res://tests/level3_smoke.gd`.
