# 05 CHARACTERS AND ANIMATIONS: Rigging, Retargeting & Asset Pipeline

> **Snapshot document.** Written on 2026-10-21 as part of the former `PROJECT_CONTEXT/` set, before the repository was reorganized. The code is the final authority; statements here (status, counts, file trees) may be out of date. Current documentation map: [docs/README.md](../README.md).

This document details the character models, skeletons, animation libraries, procedural authoring pipelines, and Blender-to-Godot workflows in **Past-Future**.

---

## 1. Active Character A: The 3D Student (Age 18)

- **Directory**: [assets/characters/student_3d/](../../assets/characters/student_3d/)
- **Active Model**: `student.glb` (7.33 MB)
- **Player Scene**: [scenes/characters/student_3d_player.tscn](../../scenes/characters/student_3d_player.tscn)
- **Status**: **COMPLETE — VERIFIED**

### 1.1 Model & Mesh Specifications
- **Format**: Binary glTF 2.0 (`.glb`).
- **Skinned Vertices**: **$90,881$** vertices.
- **Triangles**: $\approx 142,519$ triangles.
- **Mesh Parts**: 44 distinct named parts (hair locks, jacket lapels, pockets, satchel, watch, shoes, ID card).
- **Proportions**:
  - Total Visual Height: $2.15\text{ m}$.
  - Head-to-Body Ratio: $\approx 2.4$ head lengths total (stylized oversized head for top-down readability).
- **Asymmetric Landmarks**:
  - **Right Shoulder $\rightarrow$ Left Hip**: Leather messenger satchel strap.
  - **Left Hip**: Messenger bag with flap and metal buckle.
  - **Left Wrist**: Wristwatch with light dial.
  - **Left Chest**: Clipped university student ID badge.
  - **Right Chest**: Flap pocket with button.
  - **Left Upper Arm**: Utility sleeve pocket.

### 1.2 Materials & Shaders
Solid PBR base colors without external bitmap textures:
- Palette: `jacket`: `#b18145` (ochre/mustard), `shirt`: `#f0e2c7` (cream), `skin`: `#e1ac7f` (peach tan), `hair`: `#302822` (dark charcoal), `pants`: `#343c46` (slate grey), `boots`: `#60432e` (brown leather), `bag`: `#795337`.
- Materials are duplicated at runtime in `_ready()` (`.duplicate(true)`) to prevent cross-peer palette bleed.

---

## 2. Active Character B: The 3D Professor (Age 49)

- **Directory**: [assets/characters/professor_3d/](../../assets/characters/professor_3d/)
- **Active Model**: `professor.glb` (7.29 MB)
- **Player Scene**: [scenes/characters/professor_3d_player.tscn](../../scenes/characters/professor_3d_player.tscn)
- **Studio Scene**: [scenes/characters/professor_3d_studio.tscn](../../scenes/characters/professor_3d_studio.tscn)
- **Status**: **COMPLETE — VERIFIED**

### 2.1 Model & Mesh Specifications
- **Format**: Binary glTF 2.0 (`.glb`).
- **Skinned Vertices**: **$113,143$** vertices.
- **Triangles**: $\approx 178,000$ triangles.
- **Shared Heritage with Student**: Modeled directly against the 4 reference images in `assets/characters/references/49/`. Retains the student's head shape, facial proportions, hand geometry, and the exact same 23-joint KayKit skeleton.
- **Visual Differences & Aging Landmarks**:
  - **Face**: Subdued age lines, guarded mouth, gray hair at temples and nape, short salt-and-pepper beard and moustache.
  - **Clothing**: Long dark navy academic coat with notched lapels, lining, rear vent, and worn cuffs. Dark waistcoat and slate shirt replace the student's henley. Pens in left breast pocket.
  - **Watch**: The original watch remains on his left wrist with an aged brown strap, confirming their shared identity.
  - **Removed**: Student messenger bag, shoulder strap, student ID, and rolled casual sleeves are removed.

### 2.2 Procedural Fitting Pipeline
Authored via dedicated Python scripts in `tools/`:
- **`tools/build_professor.py`**: Procedural mesh generation for coat, waistcoat, collar, and aging details.
- **`tools/fit_professor_face.py`**: Snaps eyes, brows, mouth, moustache, and cheek/eye lines to the actual skin triangles.
- **`tools/fit_professor_clothes.py`**: Fits 47 clothing details to their supporting layers, transferring skin weights and ensuring a 2.5 mm clearance gap to prevent Z-fighting or edge flicker.
- **`tools/professor_blender.py`**: Connects to Blender's Python API (`bpy`) to compile `source/professor.blend` and export `professor.glb`.

---

## 3. Skeleton Rig & KayKit Proportion Retargeting

- **Source Rig**: KayKit *Rig_Medium* skeleton (CC0).
- **Joint Count**: **23 joints** plus 2 animated hand attachment slots (`handslot.l`, `handslot.r`).

### 3.1 Bone Hierarchy
```text
root
└── hips
    ├── spine
    │   └── chest
    │       ├── neck
    │       │   └── head
    │       ├── upperarm.l ──► lowerarm.l ──► wrist.l ──► hand.l ──► handslot.l
    │       └── upperarm.r ──► lowerarm.r ──► wrist.r ──► hand.r ──► handslot.r
    ├── upperleg.l ──► lowerleg.l ──► foot.l ──► toes.l
    └── upperleg.r ──► lowerleg.r ──► foot.r ──► toes.r
```

### 3.2 Proportion Retargeting Formula
Because both custom characters have stockier torsos and broader shoulders than KayKit's default mannequin, [tools/student_rig.py](../../tools/student_rig.py) applies an analytical translation delta retarget:

$$\mathbf{t}_{\text{target}}(t) = \mathbf{t}_{\text{target, rest}} + \big(\mathbf{t}_{\text{source}}(t) - \mathbf{t}_{\text{source, rest}}\big) \cdot s_{\text{delta}}$$

Where:
- $\mathbf{t}_{\text{target, rest}}$ is the rest position of the custom character's bone.
- $\mathbf{t}_{\text{source, rest}}$ is the original KayKit rest position.
- $s_{\text{delta}} = \frac{\|\mathbf{b}_{\text{target}}\|}{\|\mathbf{b}_{\text{source}}\|}$ is the bone length scaling ratio.
- All quaternions (rotations) and scale tracks from KayKit are preserved **100% bit-exact without modification**.

### 3.3 Skinned Floor Clearance Optimization
Proportion retargeting can produce floor penetration during low poses (`Crawling`, `Crouching`, `Death_A`). The tool [tools/ground_student_clips.py](../../tools/ground_student_clips.py) evaluates all skinned vertices at $60\text{ Hz}$ across low clips and applies the minimal vertical root displacement curve ($\Delta Y \ge 0$) required to maintain at least $2\text{ mm}$ clearance above the floor.

---

## 4. The 77 KayKit Animation Clips

Both characters import **77 animation clips** grouped into five libraries:

| Category | Clip Count | Key Gameplay Clips |
|---|---|---|
| **MovementBasic** | $18$ clips | `Idle_A`, `Idle_B`, `Walking_A`, `Walking_B`, `Running_A`, `Running_B`, `Jump_Full_Long` |
| **MovementAdvanced** | $16$ clips | `Crouching`, `Sneaking`, `Crawling`, `Dodge_Forward`, `Dodge_Backward`, `Roll` |
| **General** | $17$ clips | `Interact`, `PickUp`, `Use_Item`, `Waving`, `Death_A`, `Death_B`, `Cheering` |
| **Simulation** | $14$ clips | `Holding_A`, `Holding_B`, `Holding_C`, `Working_A`, `Working_B`, `Sitting` |
| **Tools** | $12$ clips | Various tool-handling, repair, and inspection actions |

---

## 5. In-Game Character Review Studios

- **Student Studio**: [scenes/characters/student_3d_studio.tscn](../../scenes/characters/student_3d_studio.tscn)
- **Professor Studio**: [scenes/characters/professor_3d_studio.tscn](../../scenes/characters/professor_3d_studio.tscn)
- **Invocation**: Press `F2` or click the "CHARACTER STUDIO" button in the HUD or Pause menu.

### Studio Features
1. **Isolated Viewport**: Operates in an independent `SubViewport` with its own `World3D`, camera, and studio lighting.
2. **Animation Browser**: Scrollable list of all 77 clips with immediate playback switching.
3. **Turntable & Scrubbing**:
   - Angle presets: Front ($0^\circ$), Three-quarter ($-34.4^\circ$), Side ($-90^\circ$), Back ($180^\circ$).
   - Continuous $360^\circ$ rotation slider.
   - Pause toggle and frame-by-frame timeline scrubbing.
   - Playback speed slider ($0.25\times$ to $2.0\times$).

---

## 6. Legacy Character Prototypes (Historical Debt)

The repository contains two earlier prototypes preserved for historical reference:
1. **Articulated 3D Model (`student_v2.glb`)**: [scenes/characters/student_model.tscn](../../scenes/characters/student_model.tscn), [scripts/characters/student_player.gd](../../scripts/characters/student_player.gd). **DEPRECATED**; `student_v2.glb` was deleted in commit `4a1144d`.
2. **Illustrated 2D 8-Direction Paper Rig**: [scenes/characters/student_paper_rig.tscn](../../scenes/characters/student_paper_rig.tscn), [scripts/characters/student_paper_rig.gd](../../scripts/characters/student_paper_rig.gd). **DEPRECATED**; directional PNG atlases were deleted in commit `4a1144d` (preserved at Git checkpoint commit `244b42a`).
