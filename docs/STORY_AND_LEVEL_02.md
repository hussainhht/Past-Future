# Chapter 0 story continuation and Level 02

Original authored design, 2026-10-20; implementation update, 2026-10-21. The maintenance gallery and compact Core finale are now playable, with additional power and recorder choices. See [Level 02 implementation](LEVEL_02.md) for the built route, branching outcomes, controls and verification. The Circle/Triangle/Square support puzzle in the original plan below has been replaced by the preservation-storage and archive-repair puzzle; use `LEVEL_02.md` for the current implementation. The original plan below records the story intent; its unconditional full-audit reveal now applies to the preserved-recording branch.

## Runtime inspection before Level 02 implementation (2026-10-20)

The playable Signal Laboratory already establishes the 67 MHz radio link after both characters acquire their radios and the Student calibrates the array. Confirmed puzzle state opens the security door in both timelines. Walking through it reaches a short corridor and triggers the room-clear banner once.

There is no connection from that exit to another level. `security_door.gd` emits `player_exited`; `signal_lab.gd` displays the banner and emits it again, but the current world does not use that signal to load a destination. The banner's “Both timelines found the way out” is local presentation, not evidence that both players reached an exit.

The GDD already proposes the route **Signal Laboratory → Maintenance Corridor → Temporal Research Core**. This continuation keeps that route, the same person at ages 18 and 49, the 31-year separation, and the Professor's deliberate activation with his motive withheld. The older `PROJECT_CONTEXT` implementation tables predate the current interactive laboratory; use the runtime scripts for current status.

## The story through the end of the demo

**Level 01 — Lost Frequency:** Two strangers establish a reliable connection across 31 years. The Student sees a functioning research wing; the Professor sees its wreckage. The room already hints that the fracture was deliberate, through the blackboard and the Professor's notebook. What remains unknown is who made the decision and why.

**Level 02 — Broken Corridor: What We Leave Standing:** They leave the Signal Laboratory and discover that reaching the same place does not mean having the same way forward. The Professor cannot cross the collapsed maintenance gallery. The Student can reach its intact machinery but cannot access the sealed Core. They restore a service circuit, change the supports, and reach the maintenance archive. Their cooperation proves that the Student can change the Professor's surroundings. The archive confirms that they are the same person and gives them access to the Core.

**Finale — The First Fracture:** At the Core, they stabilize the local fracture together. The restored console releases an authenticated activation record: the Professor authorized a manual override after acknowledging the containment warning. It was his decision, not an automatic malfunction. The Student asks, “You knew what would happen. Why did you do it?” The Professor does not answer. The recovered monitoring map reveals other unresolved fractures. Cut to **END OF CHAPTER 0**.

Their success remains real: they escaped the first room, changed a dangerous future, reached the Core, and stabilized this local fracture. The map reveals a larger existing problem; winning does not secretly undo their work or cause another catastrophe.

## Why they go toward the Core

The north door leads into the research wing's maintenance gallery, not out onto campus. Containment shutters have sealed the public exits. The gallery connects to the Core's service entrance.

The radio remains on 67 MHz. A brief burst of interference reveals that the communications array is stable but the fracture feeding it is not. The Professor explains that the Core's anchor can hold their connection and stop the instability spreading. The Student wants to get out safely and understand the warning signs; the Professor needs his help reaching machinery that no longer works in the Future.

The Professor knows the building's original layout, not the solution to every changed corridor. His memory cannot replace observing the present damage. He also avoids explaining why the experiment happened. Trust grows through useful actions before the final record breaks it.

## Level 02 layout and pacing

Target **3–4 minutes** for a first cooperative playthrough. Use one compact shared layout with timeline variants and a fixed perspective camera. No combat, jumps, chase, or countdown.

| Space | Student / Past | Professor / Future |
|---|---|---|
| Entry landing | Intact corridor, containment notice, working service cabinet | Dust, emergency light, broken route ahead |
| Service bay | Isolation selector and three support controls | Emergency battery crank and surviving circuit instructions |
| Maintenance gallery | Intact walkway; three clearly marked support stations | Fallen slab and broken walkway; visible load-point diagram |
| Archive alcove | Service hatch sealed under the maintenance lock | Becomes reachable after the slab is secured; surviving service record |
| Core threshold | Powered security panel with manual override entry | Damaged motor; manual door release |

Put every required clue and control in the Professor's reachable entry area until the bridge is secured. Keep optional flavor documents off the critical path. Mark supports with **Circle, Triangle, and Square**, matching symbols across both timelines rather than relying on “left” or color alone.

## Beat 1: The same corridor, two different problems

Both arrive from the laboratory, retaining their handheld radios and completed frequency puzzle. The Student sees a corridor that appears safe. The Professor sees a collapsed slab across a gap.

> **Student:** “I'm out. The corridor looks clear.”  
> **Professor:** “Mine doesn't. The ceiling came down.”  
> **Student:** “There's a service cabinet beside the door.”  
> **Professor:** “Same place. Don't touch the main feed. Let me read the isolation plate.”

Objective: **Restore the maintenance service circuit.** The Core door remains visible at the far end so both players understand the destination.

## Problem 1: Restore service power

**What is wrong:** The Future has no working mains supply. Its emergency battery cannot feed the structural diagnostic terminal until the old service bypass is isolated correctly.

**What the Professor knows and does:** A surviving instruction plate identifies the isolated **SERVICE** loop. He tells the Student which circuit to select. After the bypass is preserved, he operates a local hand crank to charge the emergency battery and latches its switch on. This is a short interaction, not a sustained button hold or timing test.

**What the Student does:** Selects SERVICE on the intact isolation cabinet and engages its mechanical latch. The corresponding damaged circuit changes in the Future, allowing the Professor's battery to supply it.

**Visible result:** A severed circuit indicator becomes a continuous route, then the Future diagnostic display and archive emergency lamp light up. The Past change preserves a usable circuit; it does not transmit electricity through 31 years. The Future generates its own power.

**Wrong choice:** The cabinet refuses a non-isolated feed with “Service loop not isolated.” No deaths, radio loss, or reset of Level 01. The Professor can reread the plate.

This phase gives the Professor a necessary physical action instead of leaving him standing at a clue for the whole level.

## Problem 2: Brace the future

**What is wrong:** The fallen slab blocks the Professor's route to the archive. Raising every support would pin the passage shut rather than make it safe.

**Information is split:** The Future diagram shows what each load point needs, using physical states. Only the Past controls show how those states map to extension stages.

| Support symbol | Future evidence | Required state | Past control mapping |
|---|---|---|---|
| Circle | Fractured slab needs its upper load caught | BRACE | Stage 3 |
| Triangle | Archive-side support must be pinned without closing the passage | PIN | Stage 2 |
| Square | Extended foot obstructs the service opening | RETRACT | Stage 1 |

The Student reads the stage legend; the Professor describes the damaged structure and diagram. Together they derive **Circle 3 / Triangle 2 / Square 1**. This is the authored configuration, not simulated engineering.

The Student stages the settings and uses **Apply support plan**. Only the host-confirmed successful configuration changes the Future route. An invalid plan is rejected by the controller: the display marks the unsafe support, the jacks settle back, and both can retry. Do not dynamically scramble the rubble for every wrong answer.

**The payoff:** The slab shudders, dust falls, and it settles onto the braced support as a broad walkable ramp. An archive hatch becomes accessible. The Professor walks across using ordinary ground movement.

> **Professor:** “The slab moved.”  
> **Student:** “I only changed the supports.”  
> **Professor:** “Thirty-one years ago. You just changed what survived.”

Once secured, lock the solved support configuration. The Student cannot accidentally retract the route while the Professor is standing on it. There is no need for timed cooperation or precision platforming.

## Beat 3: The person on the other end

Across the repaired route, the Professor finds an emergency service record bearing his staff identity and appointment date. It is dated 31 years beyond the Student's present. On the radio he gives a private identifying detail: the short inscription inside their watch, a detail the Student never put on his badge or laboratory paperwork.

The watch inscription is new proposed dialogue content, not an existing readable model detail. Use **“Don't waste it.”** consistently if this detail is adopted; it needs an inspection text, not new watch geometry.

> **Student:** “How do you know what's inside my watch?”  
> **Professor:** “Because I'm still wearing it.”  
> **Student:** “Who are you?”  
> **Professor:** “You. Thirty-one years later.”  
> **Student:** “Then you remember how I get out.”  
> **Professor:** “I remember the corridor falling. Not this way through.”

This confirms the premise for the characters without explaining the catastrophe. The changed route also establishes why the Professor cannot simply remember every solution or promise the Student a safe future.

## Problem 3: Open the Core service entrance

This is a short reward-and-handoff interaction, not another lengthy cipher.

The recovered service record contains **manual access code 3142** and instructions for releasing the mechanical latch. The Professor reads it to the Student. The Student's intact terminal accepts the override; its preserved service latch releases in the Future. The Professor then operates his local manual release because the Future door motor is dead.

The code crosses time as information. No physical keycard travels into the Past. Both roles act: the Professor must reach the archive and operate his release; the Student must authorize access using intact equipment.

A partial incident entry in the same record reads:

> CONTAINMENT WARNING ACKNOWLEDGED.  
> AUTOMATIC SHUTDOWN OVERRIDDEN.  
> OPERATOR: SEE CORE AUDIT.

> **Student:** “Someone overrode the shutdown.”  
> **Professor:** “The full record is inside.”

Objective becomes **Enter the Temporal Core.** Both enter their version of the same threshold. This is the end of Level 02, not the end of their mystery.

## The finale, with a jam-sized completion path

The required two-level build still needs an ending. Put a compact Core control alcove immediately beyond Level 02's final door. It can reuse the console, rift, terminal, lights, and radio presentation already available.

The Student arms the intact anchor transmitter. The Professor connects his local emergency receiver. Each action latches; they do not need to press within a narrow time window. When both are confirmed, the local fracture stabilizes and the audit becomes readable. Treat this as the finale interaction rather than a third full puzzle.

The audit is the Professor's activation record from the Future terminal, clearly labeled as such. It does not claim that he was already 49 on the Student's date. The stabilized link presents the same recovered audit text on the Student's terminal, making the evidence visible to both players rather than depending on the Professor voluntarily reading his confession aloud.

> MANUAL ACTIVATION AUTHORIZED — THE PROFESSOR.  
> CONTAINMENT FAILURE RISK ACKNOWLEDGED.  
> AUTOMATIC ABORT DISABLED.  
> ACTIVATION CONFIRMED.

> **Student:** “That's your authorization.”  
> **Professor:** “Yes.”  
> **Student:** “You knew. Why did you do it?”

Silence. The monitoring map finishes recovering and shows other unresolved anchors. A second signal appears beyond their stabilized channel. End Chapter 0 here. His motive remains deliberately unanswered, as in the existing GDD; no new family tragedy, secret antagonist, or full-game explanation is established by this draft.

If time permits, expand the Core into the GDD's optional third puzzle: exchange coil settings and receiver intervals before the same stabilization and audit reveal. The required ending must not depend on implementing that larger room or a 90-second timer.

## Continuity rules and content cleanup

- Keep **67 MHz**, the **31-year** separation, ages **18 / 49**, and the failure marker **23:44**. Do not turn either 67 or 23:44 into an unrelated second-level keypad answer.
- Physical changes travel Past → Future; voice and recorded information travel both ways through the established link. Objects do not teleport between timelines.
- Only the marked puzzle mechanisms change. Keep the archived clues fixed during this room's support changes, and show the diagnostic overlay as its recorded incident reading. No continuously rewritten history or new memory simulation is required.
- The Professor retains memories of the original damage, not instant knowledge of a changed route. Describe visible changes rather than giving him the answer through a convenient new memory.
- The current Future lab memo says “Nobody got out that night.” Before integrating this continuation, narrow that sentence to **“Nobody got through this door that night. The link never held.”** This avoids asserting that the living Professor could not have survived by another route.
- The blackboard and notebook already imply intention. Level 02 escalates that existing suspicion; the final audit identifies the responsible operator. Do not present “not an accident” as entirely new information at the finale.
- The receiver relay is currently optional and must remain optional for leaving Level 01. Adjust the Professor's “Bring the receiver relay online” line to an optional suggestion so it does not masquerade as a required exit task.
- The existing room-clear banner should report the local exit, or wait for authoritative arrival tracking before claiming both players arrived. Dialogue completion or skipping must never determine whether a puzzle is solved.

The memo wording, optional receiver guidance and local exit banner have now been corrected in the live content. The new level supplies the watch/identity conversation and the choice-dependent audit. See the implementation guide for the final behavior.

## Original build handoff (now implemented as described in LEVEL_02.md)

1. Connect the laboratory's exit to a new maintenance-corridor destination. Track each player's arrival on the host; one local exit must not claim both arrived. Let the first arrival explore the entry landing while waiting.
2. Preserve the existing network session, acquired radios, 67 MHz calibration, and completed puzzles during travel. Do not call `begin_session()` or reset the frequency puzzle on a room change. Solo role switching must preserve the same progress.
3. Implement one shared Level 02 progression record: `service_isolated`, `battery_ready`, support selections, `supports_secured`, `archive_reached`, `core_authorized`, and `future_release_open`. These are proposed state fields, not existing APIs.
4. Use the existing PuzzleManager request/validation/broadcast flow. Gate Future battery operation on isolation, support commitment on battery readiness, archive interaction on the secured route, code authorization on archive discovery, and the Future release on authorization. Clients present confirmed state only.
5. Reuse the existing interaction rig, document reader, terminal, radio, dialogue director, timeline props, and door presentation. Add only the corridor layout, three support props, crank/selector interactions, slab/ramp states, and archive content needed for this path.
6. For the slab transition, start with two authored stable layouts: blocked and secured. Keep the route collision blocked during movement; enable the secured walkable route when its presentation finishes. Late room loads apply the completed layout directly. Do not use dynamic rubble physics.
7. Keep confirmed puzzle progression independent of dialogue playback. Queue story beats once per session and defer them while a terminal/document is open. Skipping the identity conversation must not block archive access or the ending.
8. Verify both solve orders for role arrival, incorrect selections, repeated requests, simultaneous requests, room reloads, late snapshots, solo switching, and disconnect recovery. Ensure nobody can remove the solved crossing or bypass the Core release through collision.

The first build milestone is **walk through the current door, load the corridor in both timelines, keep the radios connected, and complete service power plus the support crossing**. The archive reveal, Core access, and finale then complete the narrative path.

## Implemented betrayal choices

The radio link anchors both selves while their surroundings change. Either role can allocate a local reserve for a practical shortcut at the expense of the remote auxiliary feed. The Professor can also extract the incident recorder's battery to power his door early, knowingly destroying the untransferred authorization. The cost is explained through equipment instructions; no interface labels the decision as betrayal.

Repairing both shared bypass ends restores disrupted controls and permits a non-destructive recording export. It does not undo the reserve history or recreate erased evidence. Consequently, the Core finale now has preserved-recording and erased-recording variants rather than always presenting the same proof.
