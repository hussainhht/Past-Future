# THE OTHER ME – Full gameplay playthrough report

**Deliverable:** `recordings/THE_OTHER_ME_FULL_GAMEPLAY.mp4`

## Summary

| Question | Answer |
|---|---|
| Full campaign actually completed? | **Yes.** Main menu → Level 1 → Level 2 → Level 3 → TRUST ending, in one uninterrupted run, with no automation timeouts or script errors (`automation_log.txt`). |
| Gameplay mode | **Two local game instances over real ENet networking** (host = Student/Past, client = Professor/Future, `127.0.0.1`, UDP 7000), joined through the real lobby UI. Split-screen is *not* available (its menu button reads "COMING SOON"), so it was not used. |
| Both characters controlled? | **Yes**, both fully, through the real input pipeline (see "How it was driven"). |
| Levels finished | 1 (Signal Laboratory), 2 (Maintenance Corridor), 3 (The Final Fracture) |
| Ending reached | **THE LAST GOODBYE (trust)**: Student chose GROUND THE CORE, Professor chose RELEASE THE ECHO. The ending animation and final "THE LAST GOODBYE / END OF CHAPTER 0" panel are in the video, then held for ~15 s. |
| Video | H.264 (yuv420p) + AAC stereo 48 kHz, **1920×1080, 30 fps, 435.7 s (7:15.7)**, 88 MB |
| Audio | Real game audio captured by WASAPI loopback (mix of both instances), loudness-normalised (the raw game output was very quiet, mean ≈ −48 dBFS). |

## How it was driven

- A temporary harness (`recordings/tools/autoplay.gd` plus `ap_playthrough.gd`, `ap_level2.gd`, `ap_level3.gd`) runs inside each game process. It is enabled only by `--ap-*` user args, via `override.cfg`. The root `override.cfg` was removed afterwards, and a copy is at `recordings/tools/override.cfg.template`.
- Every action is a genuine input event sent through `Input.parse_input_event`: WASD/Shift movement, `F` interact, `Space` dialogue advance, `Esc`, arrow keys/Tab/Shift for the Level 1 dials, and **mouse clicks on 3D device controls and UI buttons**. No puzzle state was written, no teleporting, no scene forcing.
- Runtime state was only read: to plan A* walking paths from the real collision world, to check that each action was confirmed, and to wait for the partner. Each player waits for the other through the replicated puzzle state, as a human would.
- Screenshots were saved at each milestone (`recordings/screenshots/`) and used to verify behaviour.

## What happened, level by level (timestamps are host-log seconds)

**Menu (0–21 s).** Host opens Play → Host on Wi-Fi. The client opens Play → Join, types `127.0.0.1` into the field, presses Join, then Ready. The host presses Start.

**Level 1 – Signal Laboratory (21–102 s).**
- Student reads the memo and research notebook.
- Both players collect their handheld radios, with pick-up animations and dialogue.
- The Professor opens the live receiver. The Student opens the calibration computer and turns the dials to **67 MHz** and **70 %**.
- Radio link established. The radio conversation plays, then both walk through the opened north security door.

**Level 2 – Maintenance Corridor (102–298 s).**
- Student isolates SERVICE; Professor cranks the emergency cell.
- Student carries cases R‑17, K‑04 and M‑22 into vaults A, B and C, and lowers and seals each tray.
- Professor reads the archive manifest, raises each tray, unloads the case and installs it in the matching archive socket (reader, regulator, memory).
- Archive record is read, with the identity dialogue ("I am you"). Both bypass ends are repaired.
- Professor exports the recording. Student enters **3142** on the physical keypad and authorises the core. Professor turns the manual release. Both latch the anchor.
- The Chapter Complete summary is shown and dismissed.

**Level 2 → 3 transition.** See finding 2 below. The host used the game's own pause menu, "SKIP TO LEVEL 3".

**Level 3 – The Final Fracture (328–431 s).**
- Both read their evidence documents (Student: authorization and warning; Professor: continuity recording).
- The Student arms the reactor, which starts the 150 s challenge.
- Stage A: Student sets the coils to 2‑0‑1 (coil 2 was already 0), Professor reconnects the receiver battery.
- Stage B: Professor calibrates the Signal Anchor, Student stabilises the Origin core, and both phase switches are engaged within the 5 s window.
- Stage C: identity terminals, TRUST ending. All stages were done in about 20 s of the 150 s clock, so the countdown never threatened failure and no retry was needed.

## Findings and discrepancies (the current code is the source of truth)

1. **Level 2 is not the "bridge supports" puzzle in the task brief.** There is no Circle=3 / Triangle=2 / Square=1 support configuration, bridge transformation or bridge crossing in the current scripts. The implemented Level 2 is the SERVICE/battery → underground preservation vaults → archive repair → bypass → recorder export → code 3142 → manual release → anchor puzzle described above. I played that. The bridge sequence could not be recorded because it does not exist in this build.
2. **Level 2 has no wired exit to Level 3.** `resources/levels/room_02.tres` has `next_room_id = ""`, and `docs/OBJECTIVE_SYSTEM.md` also notes this. After the puzzle the room only offers "Inspect the stabilized core" or "Return to main menu". The only in-game way forward is the host-only pause-menu demo navigation ("SKIP TO LEVEL 3"), which I used through the real UI. The client cannot do this and just follows the host.
3. **Level 3's challenge is trivially short for a competent pair.** It finished in about 20 s of 150 s. The clock is wall-clock based (`Time.get_ticks_usec`).
4. **Possible Level 2 ending-dialogue stall (observed in a development run, not confirmed as a bug).** If the post-puzzle dialogue is read *before* dismissing the Chapter Complete panel, the dialogue stayed in `SHOWING_LINE` for over 60 s. This was worked around by dismissing the panel first. It happened only in a development run, not in the recorded one.
5. The first-time tutorial popup did not appear (its "shown" flag appears to have been persisted by earlier play on this machine), so it is not in the video.
6. `spawn_area.gd` and `maintenance_corridor.gd` pause when their window loses focus. With two windows on one PC this was avoided by never changing focus during play. Touching either window mid-run would pause that player.
7. No crashes, script errors, desyncs, stuck characters, failed interactions or reactor expiry occurred in the final run: `host.err` and `client.err` are empty and the logs contain 0 `TIMEOUT`/`stuck` lines. Earlier development runs hit harness bugs, all fixed (walking oscillation near goals, a nearer decoy case stealing the prompt, a role-name typo).

## Recording limitations

- The screen is 1920×1200, so two game windows could not each be 1080p. Each game window was rendered at **960×540** and captured side by side. In the final 1920×1080 video the two panes are shown at 1:1 with captions, so in-game text is smaller than on a full-size window but readable.
- The mouse cursor is not visible, because the harness sends events directly to the game; clicks show up as the controls moving.
- Audio is a single loopback mix of both instances plus anything else the PC played at that moment. Audio/video alignment was set from the capture clock and checked against the first audible game sound. It is accurate to roughly ±0.3 s, not frame-exact.
- Video start was trimmed to just after both windows appeared (the Godot boot splash is included). Captions are generated from the automation log timestamps (±0.3 s).
- `recordings/raw/screen.mp4` (80 MB, the raw 1920×540 capture) is kept so the final video can be re-composed with `recordings/tools/compose.py`. The raw `audio.wav` was deleted to save space. To re-record: copy `recordings/tools/override.cfg.template` to `override.cfg` in the project root, then run `python recordings/tools/record_run.py`.

## Validation performed

- `ffprobe`: H.264 1920×1080 yuv420p 30 fps + AAC 48 kHz stereo, video 435.67 s, audio 435.70 s.
- Frames checked at 8 s (menus), 375 s (Level 3 with the clock at 02:17 and "Signal Anchor calibrated") and 434 s (final ending panel for both players).
- Audio loudness after normalisation: mean −19.6 dB, peak −2.0 dB.

## Git note

Nothing was committed by me. Your latest commit (`d34517a`) already includes my early harness files (`recordings/tools/autoplay.gd`, `ap_probe.gd`) and `override.cfg`. `autoplay.gd` has since been modified, and `override.cfg` is now deleted in the working tree. Both are left unstaged for you to decide.
