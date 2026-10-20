# 07 ASSETS AND VISUALS: Materials, Shaders, Palettes & Assets

This document catalogs all 3D meshes, 2D art assets, shaders, materials, color palettes, and asset pipeline integration issues.

---

## 1. Shaders & Visual Materials

The game relies entirely on procedural shading and solid unshaded/Lambertian color modulation rather than UV-mapped texture bitmaps.

### 1.1 Lab Floor Shader (`shaders/lab_floor.gdshader`)
- **Type**: `shader_type spatial; render_mode unshaded;`
- **Uniforms**: `uniform bool future = false;`
- **Implementation**:
  ```glsl
  void fragment() {
      vec2 cells = UV * vec2(16.0, 13.0);
      vec2 cell_uv = fract(cells);
      float grout = step(0.98, max(cell_uv.x, cell_uv.y));
      float checker = mod(floor(cells.x) + floor(cells.y), 2.0);
      vec3 base = future ? vec3(0.15, 0.24, 0.27) : vec3(0.34, 0.36, 0.29);
      ALBEDO = base * (1.0 + checker * 0.045) * (1.0 - grout * 0.30);
  }
  ```
- **How It Works**:
  1. Divides the floor into a $16 \times 13$ tile grid across normalized UV coordinates.
  2. Generates dark grout borders around each tile where normalized cell UV exceeds $0.98$.
  3. Implements a subtle alternating checkerboard brightness variation ($+4.5\%$).
  4. Swaps base albedo based on the `future` boolean:
     - **Past**: Warm olive/khaki (`vec3(0.34, 0.36, 0.29)` $\approx$ `#575c4a`).
     - **Future**: Dark navy/cyan slate (`vec3(0.15, 0.24, 0.27)` $\approx$ `#263d45`).

### 1.2 Painted Prop Shader (`shaders/painted_prop.gdshader`)
- **Type**: `shader_type spatial; render_mode unshaded;`
- **Uniforms**: `uniform vec4 paint_color : source_color = vec4(0.6, 0.65, 0.55, 1.0);`
- **Implementation**:
  ```glsl
  varying vec3 world_normal;

  void vertex() {
      world_normal = MODEL_NORMAL_MATRIX * NORMAL;
  }

  void fragment() {
      vec3 light_direction = normalize(vec3(-0.6, 1.0, 0.8));
      float face_tone = 0.65 + 0.35 * max(dot(normalize(world_normal), light_direction), 0.0);
      ALBEDO = paint_color.rgb * face_tone;
  }
  ```
- **How It Works**:
  1. Calculates world-space surface normals in the vertex shader.
  2. Evaluates custom lambertian lighting against a fixed directional vector $\begin{bmatrix}-0.6 & 1.0 & 0.8\end{bmatrix}^T$.
  3. Remaps the dot product to a tone range between $0.65$ (ambient face shade) and $1.0$ (fully illuminated face).
  4. Yields a distinct hand-painted, cel-shaded look on box meshes without dynamic runtime shadow maps.

---

## 2. Color Palettes: Past vs. Future

The visual distinction between timelines is driven by color matrices defined in [scripts/world/lab_prop.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/world/lab_prop.gd):

| Prop Element Slot | Past Color (Pristine Academic) | Future Color (Decayed Ruins) | Visual Difference |
|---|---|---|---|
| `body` (Chassis/Panels) | `#889181` (Warm Sage Grey) | `#557c86` (Muted Cyan Slate) | Shifts from warm metal to oxidized cold alloy |
| `top` (Work Surfaces) | `#bbb693` (Warm Cream Wood) | `#90b7bd` (Bleached Pale Teal) | Weathered and water-damaged surface |
| `frame` (Legs/Borders) | `#4b5b55` (Dark Olive Slate) | `#304c59` (Deep Charcoal Blue) | Dark oxidized structural framing |
| `drawer` (Storage Fronts)| `#748475` (Muted Green Grey) | `#496d7b` (Dull Blue Slate) | Aged panel tone |
| `handle` (Metal Fixtures)| `#d6cfaa` (Brass / Polished) | `#adcdd3` (Cold Tarnished Steel)| Loss of brass luster |
| `paper` (Documents) | `#e3dbb6` (Clean Parchment) | `#becfd0` (Ashen Deteriorated) | Aged, waterlogged documents |
| `screen` (Monitors) | `#192f36` (Active CRT CRT-Dark)| `#102a36` (Dead Power Screen) | Unpowered, dead monitor glass |
| `signal` (Indicator LEDs)| `#c0ddbb` (Soft Green Glow) | `#80d9e4` (Flickering Cold Cyan)| Emergency backup glow |

### Character Timeline Tints
- **Student Jacket (Past)**: Base ochre albedo `#b18145` with subtle warm amber bounce (`#e4bf7f`).
- **Student/Professor Jacket (Future)**: Lerped with cold cyan (`#89ccd4`) at $16\%$ blend factor in `scripts/characters/student_3d_player.gd`.

---

## 3. 2D & UI Vector Assets

All UI and decals use scalable vector graphics (`.svg`) converted to textures via Godot's built-in SVG importer:

- [assets/ui/temporal_background.svg](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/assets/ui/temporal_background.svg): High-resolution atmospheric backdrop used on the main menu, featuring an abstract split temporal clock dial.
- [assets/world/spawn_ring.svg](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/assets/world/spawn_ring.svg): Floor decal marker indicating player respawn coordinates, rotated $-90^\circ$ onto the ground plane.
- **Legacy 2D Furniture Vectors** in `assets/world/`:
  - `cabinet.svg`, `console.svg`, `table.svg`, `pill.svg`: Vector assets authored for the earlier 2D top-down prototype. Currently unused by the 3D world but preserved.

---

## 4. Third-Party Assets & Licensures

- **Package**: **KayKit Character Animations 1.1**
- **Creator**: Kay Lousberg ([kaylousberg.com](https://kaylousberg.com))
- **License**: **CC0 (Public Domain Dedication)** - full license text preserved in [assets/third_party/kaykit_character_animations/License.txt](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/assets/third_party/kaykit_character_animations/License.txt).
- **Files Stored**:
  - `Mannequin_Medium.glb` (source reference mannequin)
  - `Rig_Medium_General.glb` (17 clips)
  - `Rig_Medium_MovementBasic.glb` (18 clips)
  - `Rig_Medium_MovementAdvanced.glb` (16 clips)
  - `Rig_Medium_Simulation.glb` (14 clips)
  - `Rig_Medium_Tools.glb` (12 clips)
  - `Rig_Medium_CombatMelee.glb` (available source, not compiled into runtime)
  - `Rig_Medium_CombatRanged.glb` (available source, not compiled into runtime)
  - `Rig_Medium_Special.glb` (available source, not compiled into runtime)
- **Directory Isolation**: Marked with `.gdignore` so Godot does not import duplicate animation libraries or the raw KayKit mannequin.

---

## 5. Visual Effects & Polish Deficiencies

1. **Temporal Rift Particles**:
   - GDD specifies visual distortion and glowing violet/cyan energy rifts around temporal fractures.
   - **Current Status**: **None**. No `GPUParticles3D` or distortion screen shaders exist in the project.
2. **Interactive Object Highlighting**:
   - Currently, interactive furniture has no highlight shader, outline pass, or proximity glow to communicate usability.
3. **Wall Fading / Cutaways**:
   - The game currently uses low walls ($1.0\text{ m}$) to prevent camera occlusion. Interior walls for the corridor will require a dither transparency or height-fading shader.

---

## 6. Asset Integration Issues & Integrity Audit

1. **High Poly Count on Active Student (`student.glb`)**:
   - The compiled model has **$71,806$ vertices** and **$142,519$ triangles**.
   - While running smoothly on modern GPUs, this is dense for a stylized game jam character. It has no Level of Detail (LOD) meshes configured.
2. **Broken Legacy 2D Atlases**:
   - `assets/characters/student_2d/*_parts.png` was deleted in commit `4a1144d`.
   - Any script referencing these files (`student_paper_rig.gd`) fails to load.
3. **Broken Legacy 3D GLB**:
   - `assets/characters/student_v2.glb` was deleted in commit `4a1144d`.
   - `scenes/characters/student_model.tscn` fails to load due to missing resource.

