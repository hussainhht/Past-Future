# Discovery and physical interaction

The playable laboratory and maintenance gallery now distinguish what the character knows from what the player needs to operate the game.

The in-game top bar is a single 52-pixel row showing the timeline, room name and compact controls.
Character names, chapter numbering and connection readouts are omitted. Solo play retains the timeline
switch; the Core keeps its active countdown in the bar and shows operation feedback briefly below it.

Story information comes from printed service instructions, equipment readouts, retained records, and named character thoughts. A document does not address “both players” or identify a machine as “Future only.” Characters infer changes from what they have seen; the corridor dialogue no longer asserts an unexplained theory of how the link anchors their memories. The identity reveal still happens through the personnel record and the private watch inscription.

Controls, objectives, network confirmations, and puzzle help appear on the right, explicitly labelled **PLAYER GUIDE / OUTSIDE THE STORY** or **PLAYER FEEDBACK / NOT DIALOGUE**. Character observations appear separately as **Student · thought** or **Professor · thought**. These local thoughts are not conversations transmitted to the other character. The ending overlay is labelled a player summary; the physical audit terminal contains only its retained machine record.

Text uses separate screen areas. Guide, feedback and status messages stack in a bounded, scrollable column, below the laboratory radio status. Thoughts wait while a dialogue is visible, including its fade, and resume afterwards. Long dialogue scrolls within its panel above the interaction prompt and footer. Pause and document overlays suppress background messages. Opaque text panels prevent signs behind them from showing through the writing. Floating station captions are culled when their projected rectangles would overlap another caption or a reserved text area.

Device records use a compact foreground card on the left, with a fixed readable font and scrolling for long entries. Scene geometry cannot obscure the card. The camera fits the complete machine and its controls into a separate area between the record and the right-side guide, leaving character thoughts below. `tests/text_layout.gd` exercises every maintenance station in each permitted role, both laboratory console views, simultaneous long messages, dialogue, deferred thoughts, real GUI clicks, inspection and resize at 1600×900, 1280×720 and 960×540. The maintenance test runner includes these checks. Optional `TEXT_LAYOUT_REVIEW_DIR` captures the stress views with a graphics device.

## Operating equipment

Walk to equipment and press **F**. The camera moves to a close-up of the actual device. Click its lever, wheel, fuse, battery handle, selector, or button. **Esc / F** steps back and restores the camera and character. The right-side guide lists optional number-key shortcuts; using a shortcut operates the same physical control.

- SERVICE and reserve levers rotate after the host confirms their actions.
- The emergency charging crank turns when a normal charge is confirmed.
- The underground storage computers, loading handles and floor hatches, archive repair sockets, export button, release wheel, and stabilization lever are actual map geometry.
- The recorder's removable cell remains absent after extraction and after a room reload.
- In the maintenance storage room, F picks up a distinct equipment case and E puts it down. Each underground bay has place/remove handles and a computer. The storage command opens a floor hatch, lowers the loaded tray to the bottom of the shaft, then closes the hatch. In the Future, the computer opens the hatch and raises the preserved tray; collection unlocks after the lift stops. Its Past screen displays measured weight; required shipping weights belong to the Future archive record. Each lift operates independently, and every portable item can be preserved, including wrong equipment. The Professor retrieves, returns or physically installs each component at the damaged archive.
- Both players collect their handheld radios before the laboratory console unlocks its two dials. The Past adjusts **frequency (1–999 MHz)** and **amplitude (1–100%)**. Drag either knob clockwise to increase or counterclockwise to decrease. The wheel over a knob and arrow keys adjust by one; Shift adjusts by ten. Tab selects the other dial for keyboard tuning. Every change is sent immediately; no calibration button is needed.
- The Future console shows two overlaid waveforms: **green is current**, **grey is target**. Frequency changes cycle spacing; amplitude changes wave height. The Professor guides the Student until the traces match, automatically establishing the radio link and unlocking the door. Both dials then lock. Only the Future can see the target.

The dial assembly sits below the CRT, with separate readouts and labels. The screen remains visible during inspection.
- The Core authorization unit retains its physical keypad. Click its number keys, or type digits; Backspace presses DEL and Enter submits the access code. Staging a code never changes puzzle progression.
- The recovered log and service instructions appear in a compact foreground card beside the controls. Scroll within the card to read long entries; scrolling or clicking the card cannot operate the machine behind it.

During close-ups, floating wayfinding labels and the room HUD hide. Foreground meshes that obscure the equipment temporarily cut away; their collision stays intact and their previous visibility returns when the inspection closes. Movement and role switching remain locked until the character steps back. Pause/disconnection also suspends device input.

## Source and validation

`scripts/gameplay/devices/device_inspector_3d.gd` owns the local camera, physical controls, ray picking, dial dragging, local drafts and cutaways. It emits requests and never edits authoritative puzzle state. `scripts/ui/lab_ui.gd` owns the distinct guide, feedback and character-thought presentations.

`scripts/gameplay/devices/laboratory_devices.gd` connects both physical console dials to authoritative live tuning actions. Standalone terminal and receiver controls provide the same live state for puzzle scenes and tests; their CanvasLayer is hidden in the playable laboratory. `scripts/ui/maintenance_panel.gd` now delegates equipment interaction to the 3D inspector.

The frequency rule, scene, and LAN suites cover both-radio gating, Past-only dial authority, live unmatched values, both matching orders, completion exactly once, reset, and persistence. The laboratory gameplay test exercises real mouse dragging, both physical controls, wheel/arrow tuning, range limits, suspension, ignored digit keys, and the confirmed lock. Layout checks cover both console views, record scrolling, pause, and resizing an open inspection.

Actual Godot captures:

| Console tuning dial | Physical SERVICE lever |
|---|---|
| ![Frequency dial on the console](interactions/screenshots/frequency_dial.png) | ![Physical isolator and service card](level02/screenshots/service_lever.png) |

| Recovered console record | Incident recorder |
|---|---|
| ![Recovered console log](interactions/screenshots/recovered_console_record.png) | ![Recorder controls and private observation](level02/screenshots/recorder_choice.png) |
