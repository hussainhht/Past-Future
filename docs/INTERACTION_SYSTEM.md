# Modular 3D Interaction System

A reusable, component-based, event-driven 3D interaction system for **Past-Future** (Godot 4.7.2).

The system allows players to approach interactive 3D objects, see contextual prompts (`[F] Use Computer`, `[F] Read Document`, etc.), trigger character action animations, execute gameplay events, and integrate with the host-authoritative `PuzzleManager` without mutating shared puzzle state directly.

---

## 1. Architecture Overview

The system strictly separates detection, input/execution, object behavior, and UI presentation:

```text
3D World Object (Area3D: Layer 4 [bit 8])
       │
       ▼
Interactable3D / PuzzleInteractable3D
       │  (Proximity & Overlap)
       ▼
InteractionDetector (Area3D: Mask 4 [bit 8], Radius 2.0m)
       │  (Evaluates nearest eligible target with hysteresis)
       ▼  target_changed(target) / target_cleared
InteractionController (attached to Character)
       │
       ├──► Updates InteractionPrompt (CanvasLayer UI: [F] Action)
       │
       └──► Player presses [F] (InputMap action "interact"):
             1. Validates player state & modal UI availability
             2. Triggers character action animation ("Interact") & locks movement
             3. Executes target.interact(actor, role) (Immediate or After Animation)
             4. Restores character movement upon animation completion
```

---

## 2. Core Files & Responsibilities

| Component | Path | Base Class | Responsibility |
|---|---|---|---|
| **Interactable3D** | `scripts/interaction/interactable_3d.gd` | `Area3D` | Base interactive component attached to any 3D object. Defines prompt, range, timeline rules, and interaction lifecycle. |
| **InteractionDetector** | `scripts/interaction/interaction_detector.gd` | `Area3D` | Player-attached proximity detector. Tracks candidates within 2.0m, selects closest eligible target, and prevents target flickering via hysteresis. |
| **InteractionController** | `scripts/interaction/interaction_controller.gd` | `Node` | Executes interactions, routes input, coordinates with player animations (`play_action`), and locks/unlocks movement. |
| **PuzzleInteractable3D** | `scripts/interaction/puzzle_interactable_3d.gd` | `Interactable3D` | Adapter connecting interactive objects to the host-authoritative `PuzzleManager` via `submit_action()`. |
| **InteractionRig** | `scenes/interaction/interaction_rig.tscn` | `Node3D` | Reusable player rig containing `InteractionDetector` and `InteractionController`. |
| **InteractionPrompt** | `scenes/ui/interaction_prompt.tscn`<br>`scripts/ui/interaction_prompt.gd` | `CanvasLayer` | Stylized HUD prompt. Displays `[ F ] <Action>` with Past (`#e4bf7f`) and Future (`#86c9d1`) palette styling. |
| **InteractionSandbox** | `scenes/testing/interaction_sandbox.tscn`<br>`scripts/testing/interaction_sandbox.gd` | `Node3D` | Standalone test environment demonstrating all 5 core interaction archetypes. |
| **Automated Tests** | `tests/interaction_system.gd` | `SceneTree` | Headless test suite verifying proximity, input, selection, animation, puzzles, and UI. |

---

## 3. Physics Collision Configuration

Interaction detection uses a dedicated collision layer to avoid interference with character movement and physics geometry:

- **Physics Layer 4** (`bit value 8`): Named `"Interaction"` in `project.godot`.
- **Interactable3D**:
  ```ini
  collision_layer = 8
  collision_mask  = 0
  monitorable     = true
  ```
- **InteractionDetector**:
  ```ini
  collision_layer = 0
  collision_mask  = 8
  monitoring      = true
  ```
- **Default Detection Radius**: `2.0 meters` (SphereShape3D on detector).
- **Default Interaction Usable Distance**: `1.5 meters` (configured per interactable).

---

## 4. How to Make Any 3D Object Interactive

You can attach an interaction component to any imported GLB model, primitive mesh, or existing room scene.

### Step-by-Step Inspector Setup

1. In your object's scene, add an `Area3D` child node.
2. Attach `res://scripts/interaction/interactable_3d.gd` (or `puzzle_interactable_3d.gd`).
3. Add a `CollisionShape3D` child with a `SphereShape3D` or `BoxShape3D` (e.g. radius `1.2m`).
4. Configure the exported properties in the Inspector:
   - `Interaction Name`: `"Use Computer"`, `"Read Document"`, `"Inspect Door"`, etc.
   - `Interaction Distance`: `1.5` meters (or desired threshold).
   - `Allowed Timeline`: `Both` (0), `Past` (1), or `Future` (2).
   - `Play Interaction Animation`: `true` (character plays `Interact` action).
   - `Timing`: `After Animation` (physical actions) or `Immediate` (for UI popups).
   - `One Shot`: `false` (set `true` for consumable/single-use items).

```text
MyProp (Node3D)
├── VisualMesh (MeshInstance3D)
└── Interactable3D (Area3D - scripts/interaction/interactable_3d.gd)
    └── CollisionShape3D (SphereShape3D radius 1.2)
```

---

## 5. Practical Implementation Examples

### Example A: Simple Signal-Driven Object (e.g., Computer Terminal)

World objects can react to interactions via signals without any subclassing:

```gdscript
extends Node3D

@onready var interactable: Interactable3D = $Interactable3D

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(actor: Node, role: String) -> void:
	print("Player interacted with terminal from role: ", role)
	# Open terminal modal UI or trigger audio
```

### Example B: Readable Document with Immediate Timing

For reading interfaces that should appear immediately while the character animation blends in:

```gdscript
# In Inspector:
# interaction_name = "Read Research Log"
# timing = 0 (Immediate)
# play_interaction_animation = true (or false)

extends Node3D

func _ready() -> void:
	$Interactable3D.interacted.connect(_on_read_document)

func _on_read_document(_actor: Node, _role: String) -> void:
	# Show document canvas layer and pause/block gameplay input
	$DocumentUI.open()
```

### Example C: Puzzle-Connected Object (e.g., Power Switch)

To connect an object to the host-authoritative `PuzzleManager`:

1. Attach `scripts/interaction/puzzle_interactable_3d.gd`.
2. Configure exported properties:
   - `Puzzle Id`: `"electricity_puzzle"`
   - `Puzzle Action`: `"activate_power"`
   - `Allowed Timeline`: `Past` (role `1`)
   - `Disable On Complete`: `true`
3. Connect to signals for visual updates:

```gdscript
extends Node3D

@onready var switch_interactable: PuzzleInteractable3D = $PuzzleInteractable3D
@onready var light_mesh: MeshInstance3D = $IndicatorLight

func _ready() -> void:
	switch_interactable.puzzle_action_accepted.connect(_on_power_activated)

func _on_power_activated(puzzle_id: String, action: String) -> void:
	# Update light material to green
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.GREEN
	light_mesh.material_override = mat
```

### Example D: Dynamic Prompt & Conditional Interaction (e.g., Security Door)

Update the prompt text and availability at runtime based on puzzle state:

```gdscript
extends Node3D

@onready var door_interactable: Interactable3D = $Interactable3D

func _ready() -> void:
	door_interactable.set_interaction_name("Inspect Locked Door")
	PuzzleManager.puzzle_state_changed.connect(_on_puzzle_changed)

func _on_puzzle_changed(puzzle_id: String, state: Dictionary, _revision: int) -> void:
	if puzzle_id == "electricity_puzzle":
		if state.get("power_on", false):
			door_interactable.set_interaction_name("Open Powered Door")
		else:
			door_interactable.set_interaction_name("Inspect Locked Door")

func _on_door_interacted(_actor: Node, _role: String) -> void:
	var state = PuzzleManager.get_state("electricity_puzzle")
	if state.get("power_on", false):
		# Open door animation
		door_interactable.set_interaction_enabled(false)
	else:
		# Display hint
		print("The electronic door lock is unpowered.")
```

---

## 6. Attaching `InteractionRig` to Player Characters

The `InteractionRig` is completely decoupled from player scene hierarchy:

1. Open character scene (`scenes/characters/student_3d_player.tscn`).
2. Add an instance of `res://scenes/interaction/interaction_rig.tscn` as a child of the player root.
3. In the scene or room script, connect the rig's controller to your UI prompt:
   ```gdscript
   var controller := player.get_node("InteractionRig/InteractionController")
   controller.prompt_ui = $InteractionPrompt
   ```

### Input Integration
In `project.godot`, the action `interact` is mapped to physical key `F` (`physical_keycode: 70`).
`student_3d_player.gd` checks for `InteractionController`:
- If an interactable is in range, pressing `F` consumes input via `controller.try_interact()`.
- If no interactable is in range, pressing `F` falls through to the existing demonstration animation without conflicts.

---

## 7. Timeline Restrictions & Permissions

Objects support timeline filtering via `@export_enum("Both", "Past", "Future") var allowed_timeline`:

- **Both (0)**: Accessible by either timeline.
- **Past (1)**: Only the Student (Past player) can interact.
- **Future (2)**: Only the Professor (Future player) can interact.

In local solo testing, timeline can be toggled at runtime via `detector.set_current_role("past")` / `detector.set_current_role("future")`.
In LAN multiplayer, the assigned role comes authoritatively from `NetworkManager.role` and `PuzzleManager.get_local_role()`.

---

## 8. Launching the Interaction Sandbox

To run and test the standalone interaction sandbox in the Godot Editor:
- Open `res://scenes/testing/interaction_sandbox.tscn` and press **F6** (Run Current Scene).

Or from the command line:
```powershell
godot scenes/testing/interaction_sandbox.tscn
```

### Sandbox Features
- **WASD / Arrows**: Move 3D character.
- **F**: Contextual interaction.
- **T**: Toggle between Past and Future timelines to test permission filtering.
- **Esc**: Pause and resume (verifies interaction input and UI blocking).
- **Five Test Objects**:
  1. **Computer** (Blue Box): Contextual terminal access.
  2. **Document** (Cream Slab): Contextual document reader with immediate timing.
  3. **Switch** (Yellow Box): Past-only `PuzzleInteractable3D` toggling `electricity_puzzle`.
  4. **Door** (Grey Bulkhead): Dynamic prompt switching from "Inspect Locked Door" to "Open Powered Door" once the switch is thrown.
  5. **Temporal Rift** (Purple Column): Narrative examination event.

---

## 9. Running Automated Tests

Run the complete headless test suite with:

```powershell
godot --headless --path . --script res://tests/interaction_system.gd
```

Or using the console executable:
```powershell
& "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/interaction_system.gd
```

### Full Regression Suite:
```powershell
# 1. 3D Character Mesh & Rig Validation
python tests/student_3d_assets.py

# 2. 77-Clip Skeletal Animation Test
godot --headless --path . --script res://tests/student_3d.gd

# 3. Spawn Area Room & Physics Test
godot --headless --path . --script res://tests/spawn_area.gd

# 4. Authoritative PuzzleManager Test Suite (Offline & Sync)
python tests/run_puzzle_tests.py

# 5. LAN Multiplayer Loopback Smoke Test
python tests/run_lan_smoke.py

# 6. Interaction System Test Suite (54 checks)
godot --headless --path . --script res://tests/interaction_system.gd
```

---

## 10. Attaching to Finished Signal Laboratory Later

Once the other AI agent finishes creating the redesigned laboratory map (`scenes/world/spawn_area.tscn`):

1. **Add `InteractionPrompt` to HUD**:
   - In `scenes/world/spawn_area.tscn`, instantiate `scenes/ui/interaction_prompt.tscn` under `HUD`.
2. **Add `InteractionRig` to Player**:
   - Instantiate `scenes/interaction/interaction_rig.tscn` under `Actors/Student3DPlayer`.
3. **Connect Rig to Prompt in `spawn_area.gd`**:
   ```gdscript
   var controller := player.get_node_or_null("InteractionRig/InteractionController")
   if controller != null:
       controller.prompt_ui = $HUD/InteractionPrompt
   ```
4. **Make Laboratory Props Interactive**:
   - For any prop scene (e.g. `console_visual.tscn`, `cabinet_visual.tscn`):
     Add an `Area3D` with `interactable_3d.gd` (or `puzzle_interactable_3d.gd`) and a `CollisionShape3D`.
   - Set collision layer to 4 (`bit 8`).
   - Configure prompt text and connect interaction signals to your gameplay triggers.

