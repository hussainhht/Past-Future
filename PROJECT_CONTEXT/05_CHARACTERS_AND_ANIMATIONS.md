# 05 CHARACTERS AND ANIMATIONS: Rigging, Retargeting & Asset Pipeline

This document details the character models, skeletons, animation libraries, procedural authoring pipelines, and Blender-to-Godot workflows in the repository.

---

## 1. Active Character: The 3D Student

The primary player character represents an 18-year-old university student. The asset is entirely self-contained within [assets/characters/student_3d/](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/assets/characters/student_3d/).

```text
assets/characters/student_3d/
├── student.glb                     <- Active binary glTF asset (7.33 MB)
├── manifest.json                   <- Exact geometry counts, bone retarget map, clip provenance
├── README.md                       <- Technical specifications and rebuild instructions
├── REFERENCE_STUDY.md              <- Visual landmark analysis from 4-view concept art
├── VALIDATION.md                   <- Procedural integrity checks and visual evidence log
├── source/                         <- Blender source (.gdignore)
│   └── student.blend               <- Editable Blender 5.2.2 project with packed references
└── review/                         <- Turntable renders, GIFs, and comparison data (.gdignore)
```

### 1.1 Model & Mesh Specifications
- **Format**: Binary glTF 2.0 (`.glb`).
- **Geometry Counts**:
  - Vertices: **$71,806$** skinned vertices.
  - Triangles: **$142,519$** triangles.
  - Mesh Parts: $44$ distinct named parts (hair locks, jacket lapels, pockets, satchel, watch, shoes, ID card).
- **Proportions**:
  - Total Visual Height: $2.15\text{ m}$ (nominal height in Godot gameplay).
  - Head-to-Body Ratio: Approximately $2.4$ head lengths total (stylized oversized head for top-down readability).
  - Anatomical Asymmetry:
    - **Right Shoulder $\rightarrow$ Left Hip**: Leather messenger satchel strap.
    - **Left Hip**: Messenger bag with flap and metal buckle.
    - **Left Wrist**: Wristwatch with light dial.
    - **Left Chest**: Clipped university student ID badge.
    - **Right Chest**: Flap pocket with central button.
    - **Left Upper Arm**: Utility sleeve pocket.

### 1.2 Materials & Shader Setup
All materials use solid PBR base colors without external texture image files:
- **Palette**: Defined in `manifest.json` and `tools/build_student_kaykit.py`:
  - `jacket`: `#b18145` (ochre/mustard), `shirt`: `#f0e2c7` (cream), `skin`: `#e1ac7f` (peach tan), `hair`: `#302822` (dark charcoal), `pants`: `#343c46` (slate grey), `boots`: `#60432e` (brown leather), `bag`: `#795337`.
- **Runtime Material Instancing**:
  In `scripts/characters/student_3d_player.gd`, materials are duplicated per instance in `_ready()` so that timeline tints do not cross-contaminate between host and client:
  ```gdscript
  for surface in range(skinned_mesh.mesh.get_surface_count()):
      var material: StandardMaterial3D = skinned_mesh.mesh.surface_get_material(surface).duplicate()
      _materials[material.resource_name] = {"material": material, "base": material.albedo_color}
      skinned_mesh.set_surface_override_material(surface, material)
  ```
  Timeline recoloring lerps `jacket` surfaces with `body_color`:
  ```gdscript
  entry.material.albedo_color = entry.base.lerp(body_color, 0.16) if str(name).begins_with("jacket") else entry.base
  ```

---

## 2. Skeleton Rig & KayKit Proportion Retargeting

- **Source Rig**: KayKit *Rig_Medium* skeleton (Free 1.1 CC0).
- **Joint Count**: **23 joints** plus 2 animated hand attachment slots.

### 2.1 Bone Hierarchy
```text
root
└── hips
    ├── spine
    │   └── chest
    │       ├── neck
    │       │   └── head
    │       ├── upperarm.l
    │       │   └── lowerarm.l
    │       │       └── wrist.l
    │       │           └── hand.l
    │       │               └── handslot.l (Socket)
    │       └── upperarm.r
    │           └── lowerarm.r
    │               └── wrist.r
    │                   └── hand.r
    │                       └── handslot.r (Socket)
    ├── upperleg.l
    │   └── lowerleg.l
    │       └── foot.l
    │           └── toes.l
    └── upperleg.r
        └── lowerleg.r
            └── foot.r
                └── toes.r
```

### 2.2 Proportion Retargeting Mathematics
Because the custom student model has a stockier torso, shorter legs, and broader shoulders than KayKit's default mannequin, direct translation animations would distort the mesh. The build script [tools/student_rig.py](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/tools/student_rig.py) applies an analytical translation delta retarget:

$$\mathbf{t}_{\text{target}}(t) = \mathbf{t}_{\text{target, rest}} + \big(\mathbf{t}_{\text{source}}(t) - \mathbf{t}_{\text{source, rest}}\big) \cdot s_{\text{delta}}$$

Where:
- $\mathbf{t}_{\text{target, rest}}$ is the rest position of the custom bone.
- $\mathbf{t}_{\text{source, rest}}$ is the original KayKit rest position.
- $s_{\text{delta}} = \frac{\|\mathbf{b}_{\text{target}}\|}{\|\mathbf{b}_{\text{source}}\|}$ is the bone length scaling ratio.
- **Rotations and Scales**: Rotations (quaternions) and scale tracks from KayKit are preserved **100% bit-exact without modification**.

### 2.3 Skinned Floor Clearance Optimization
Proportion retargeting can cause floor penetration during lying, crouching, or crawling clips. The tool [tools/ground_student_clips.py](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/tools/ground_student_clips.py) evaluates all skinned vertices at $60\text{ Hz}$ across clips like `Crawling`, `Crouching`, and `Death_A`. It applies the minimal vertical root displacement curve ($\Delta Y \ge 0$) required to maintain at least $2\text{ mm}$ clearance above the floor.

---

## 3. The 77 KayKit Animation Clips

The character imports **77 animation clips** grouped into five thematic libraries:

| Category | Clips Available | Key Gameplay Clips Used |
|---|---|---|
| **MovementBasic** | $18$ clips | `Idle_A`, `Idle_B`, `Walking_A`, `Walking_B`, `Running_A`, `Running_B`, `Jump_Full_Long` |
| **MovementAdvanced** | $16$ clips | `Crouching`, `Sneaking`, `Crawling`, `Dodge_Forward`, `Dodge_Backward`, `Roll` |
| **General** | $17$ clips | `Interact`, `PickUp`, `Use_Item`, `Waving`, `Death_A`, `Death_B`, `Cheering` |
| **Simulation** | $14$ clips | `Holding_A`, `Holding_B`, `Holding_C`, `Working_A`, `Working_B`, `Sitting` |
| **Tools** | $12$ clips | Various tool-handling and inspection actions |

---

## 4. In-Game Character Review Studio

- **Source Code**: [scripts/characters/student_3d_studio.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/characters/student_3d_studio.gd)
- **Scene File**: [scenes/characters/student_3d_studio.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_3d_studio.tscn)
- **Invocation**: Press `F2` or click the "CHARACTER / F2" button in the HUD during gameplay or solo preview.

### Studio Features
1. **Isolated Viewport**: Operates in an independent `SubViewport` with its own `World3D`, orthographic camera, and directional keylight.
2. **Animation Browser**: Scrollable list of all 77 clips. Clicking any clip immediately switches playback.
3. **Turntable & Scrubbing**:
   - Preset buttons: Front ($0^\circ$), Three-quarter ($-34.4^\circ$), Side ($-90^\circ$), Back ($180^\circ$).
   - Slider for continuous $360^\circ$ model rotation.
   - Pause toggle and scrub slider for frame-by-frame pose inspection.
   - Playback speed slider ($0.25\times$ to $2.0\times$).

---

## 5. Offline Authoring Pipeline & Tooling

The student model is built and reviewed via Python scripts in [tools/](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/tools/):

```powershell
# 1. Build the student glTF binary with retargeted clips
python tools/build_student_kaykit.py

# 2. Generate the editable Blender project with packed references
python tools/student_blender.py --create

# 3. Validate asset constraints (bone counts, bind matrices, weights)
python tests/student_3d_assets.py

# 4. Run Godot import and headless skeletal test
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/student_3d.gd
```

- **`tools/build_student_kaykit.py`**: Defines Catmull-Rom curves, cross-sectional lofts, hair lock tubes, and vertex skin weights.
- **`tools/student_mesh.py`**: Handles primitive normals, index generation, and glTF binary writing.
- **`tools/student_blender.py`**: Connects to Blender's Python API (`bpy`) to import/export meshes and generate Cycles studio review renders.

---

## 6. Legacy Character Prototypes (Historical Debt)

The repository contains three earlier character prototypes from earlier iterations:

### 6.1 Articulated 3D Model (`student_v2.glb`)
- **Files**: [scripts/characters/student_player.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/characters/student_player.gd), [scenes/characters/student_player.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_player.tscn), [scenes/characters/student_model.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_model.tscn).
- **Status**: **BROKEN**. Commit `4a1144d` deleted `assets/characters/student_v2.glb`. Attempting to load `student_model.tscn` produces a missing dependency error.
- **Architecture**: A rigid articulated model with pivot hierarchy animated procedurally. Fully superseded by `student_3d_player.tscn`.

### 6.2 Illustrated 2D 8-Direction Paper Rig
- **Files**: [scripts/characters/student_paper_rig.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/characters/student_paper_rig.gd), [scenes/characters/student_2d_player.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_2d_player.tscn), [tests/student_2d.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/tests/student_2d.gd).
- **Status**: **BROKEN**. Commit `4a1144d` deleted all directional PNG atlases (`east_parts.png`, `south_parts.png`, etc.). `student_paper_rig.gd` fails on preload. Preserved in Git checkpoint commit `244b42a`.

---

## 7. The Professor: Future Character Status

Per GDD Section 3:
- The Professor is an older version (Age 49) of the Student.
- **Current Status**: **Unimplemented**.
- In the active build, both the Past (Student) and Future (Professor) players use the same 3D student mesh. The Future timeline distinguishes the character solely by tinting the jacket albedo cyan (`#89ccd4`).
- **Required Future Work**: Authoring a distinct Professor mesh/model (mature facial structure, glasses/beard, darker formal academic coat) sharing the KayKit skeleton.

