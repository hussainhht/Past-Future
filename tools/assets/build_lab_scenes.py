"""Write the reusable prop scenes and the Signal Laboratory room scene.

  python tools/assets/build_lab_scenes.py          # writes scenes/environment/props/*.tscn and rooms/signal_lab_layout.tscn

The scenes are ordinary Godot scenes and can be edited in the editor afterwards; running this
script again overwrites them, so either keep layout changes here or stop regenerating. Lighting,
effects and UI live in the hand-authored rooms/signal_lab.tscn, which instances the layout. Coordinates
are in the Signal Laboratory's frame: floor x -12.4..12.4, z -7.8..7.8, north wall at z = -7.8.

Layout rules kept on purpose (tests/spawn_area.gd walks the player through these):
  * behind LeftTable (z -0.75..-0.05, x -8.3..-4.5) stays clear;
  * in front of LeftTable (x -6.1..-4.7, z 1.0..3.1) stays clear;
  * a 3.2 radius around the spawn point (0, 3.7) stays clear (the rug is flat and has no collision);
  * the east wall approach at z 4.4..5.2 stays clear.
"""
from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import assetlib as lib

ROOT = lib.ROOT
PROPS = ROOT / "scenes" / "environment" / "props"
ROOMS = ROOT / "scenes" / "environment" / "rooms"
TIMELINE = "res://scripts/environment/timeline_prop.gd"
MODEL = "res://assets/environment/models/"
BOTH, PAST, FUTURE = 0, 1, 2


def fmt(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return f"{value:.6g}" if isinstance(value, float) else str(value)
    if isinstance(value, str):
        return '"' + value.replace('"', '\\"') + '"'
    if isinstance(value, tuple) and value and value[0] == "raw":
        return value[1]
    if isinstance(value, tuple) and value and value[0] == "node":
        return f'NodePath("{value[1]}")'
    if isinstance(value, (tuple, list)):
        if len(value) == 2:
            return "Vector2(%s)" % ", ".join(f"{float(v):.6g}" for v in value)
        if len(value) == 3:
            return "Vector3(%s)" % ", ".join(f"{float(v):.6g}" for v in value)
        if len(value) == 4:
            return "Color(%s)" % ", ".join(f"{float(v):.6g}" for v in value)
    raise TypeError(value)


def rad(*degrees):
    return tuple(math.radians(d) for d in degrees)


class Scene:
    def __init__(self, name, root_type="Node3D", script=TIMELINE, **props):
        self.ext, self.subs, self.nodes, self.editable = {}, [], [], []
        # The script goes first: exported properties written before it would be dropped on load.
        root = {"script": self.res("Script", script)} if script else {}
        root.update(props)
        self.nodes.append((name, root_type, None, None, root))

    def res(self, kind, path):
        if path not in self.ext:
            self.ext[path] = (kind, str(len(self.ext) + 1))
        return ("raw", f'ExtResource("{self.ext[path][1]}")')

    def sub(self, kind, **props):
        ident = f"{kind}_{len(self.subs) + 1}"
        self.subs.append((ident, kind, props))
        return ("raw", f'SubResource("{ident}")')

    def node(self, name, parent=".", kind=None, scene=None, groups=None, **props):
        instance = self.res("PackedScene", scene) if scene else None
        if groups:
            props = {"__groups": groups, **props}
        self.nodes.append((name, kind, parent, instance, props))
        return name if parent == "." else f"{parent}/{name}"

    def text(self):
        out = ["[gd_scene format=3]", ""]
        for path, (kind, ident) in self.ext.items():
            out.append(f'[ext_resource type="{kind}" path="{path}" id="{ident}"]')
        if self.ext:
            out.append("")
        for ident, kind, props in self.subs:
            out.append(f'[sub_resource type="{kind}" id="{ident}"]')
            out += [f"{k} = {fmt(v)}" for k, v in props.items()]
            out.append("")
        for name, kind, parent, instance, props in self.nodes:
            header = f'[node name="{name}"'
            if kind:
                header += f' type="{kind}"'
            if parent is not None:
                header += f' parent="{parent}"'
            if instance:
                header += f" instance={instance[1]}"
            # Exported Node properties must be listed, or Godot drops their paths on load.
            node_props = [k for k, v in props.items() if isinstance(v, tuple) and v and v[0] == "node"]
            if node_props:
                header += " node_paths=PackedStringArray(%s)" % ", ".join(f'"{k}"' for k in node_props)
            if "__groups" in props:
                header += " groups=[%s]" % ", ".join(f'"{g}"' for g in props["__groups"])
            out.append(header + "]")
            out += [f"{k} = {fmt(v)}" for k, v in props.items() if k != "__groups"]
            out.append("")
        # Instanced scenes whose own children are overridden here (e.g. a hidden placeholder).
        for instance_path in self.editable:
            out.append(f'[editable path="{instance_path}"]')
        return "\n".join(out)

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self.text(), encoding="utf-8")
        return path


# --- Prop scenes ---------------------------------------------------------------------------

def collider(scene, parent, size, centre, name="Collision"):
    shape = scene.sub("BoxShape3D", size=size)
    scene.node(name, parent, "CollisionShape3D", position=centre, shape=shape)


def prop(name, model, size=None, centre=None, offset=(0, 0, 0), asset="", scale=None):
    """A prop scene: TimelineProp root (StaticBody3D when it collides) with the model as 'Model'."""
    scene = Scene(name, "StaticBody3D" if size else "Node3D", asset_id=asset)
    extra = {"position": offset} if offset != (0, 0, 0) else {}
    if scale:
        extra["scale"] = scale
    scene.node("Model", scene=MODEL + model, **extra)
    if size:
        collider(scene, ".", size, centre or (0, size[1] / 2, 0))
    return scene


def stocked_bookcase():
    scene = Scene("BookcaseStocked", "StaticBody3D", asset_id="A13")
    scene.node("PastOnly", kind="Node3D")
    scene.node("Shelf", "PastOnly", scene=MODEL + "furniture/lab_bookcase.glb")
    scene.node("FutureOnly", kind="Node3D")
    scene.node("Shelf", "FutureOnly", scene=MODEL + "furniture/lab_bookcase_broken.glb")
    levels = (0.12, 0.77, 1.49, 2.21)
    for k, y in enumerate(levels):
        scene.node(f"Books{k}", "PastOnly", scene=MODEL + "books/kaykit_book_set.glb", position=(-0.55, y + 0.25, 0.05))
        scene.node(f"Binders{k}", "PastOnly", scene=MODEL + "furniture/lab_binder_row.glb", position=(0.42, y, 0.04))
    for k, y in enumerate(levels[::2]):
        scene.node(f"Books{k}", "FutureOnly", scene=MODEL + "books/kaykit_book_set.glb", position=(-0.6, y + 0.25, 0.05), rotation=rad(0, 0, 8))
        scene.node(f"Lone{k}", "FutureOnly", scene=MODEL + "books/kaykit_book_single.glb", position=(0.55, y + 0.22, 0.05), rotation=rad(0, 20, -28))
    collider(scene, ".", (2.2, 3.0, 0.62), (0, 1.5, 0))
    return scene


def coat_stand():
    scene = Scene("CoatStand", "StaticBody3D", asset_id="A25")
    scene.node("Stand", scene=MODEL + "furniture/lab_coat_stand.glb")
    scene.node("PastOnly", kind="Node3D")
    scene.node("Coat", "PastOnly", scene=MODEL + "decorations/lab_coat.glb", position=(0.2, 2.32, 0.0), rotation=rad(0, -90, 0))
    scene.node("FutureOnly", kind="Node3D")
    scene.node("Coat", "FutureOnly", scene=MODEL + "decorations/lab_coat_fallen.glb", position=(0.55, 0, 0.35))
    collider(scene, ".", (0.5, 2.4, 0.5), (0, 1.2, 0))
    return scene


def plant(name, past_model, future_model, radius, asset="A21"):
    scene = Scene(name, "StaticBody3D", asset_id=asset)
    scene.node("PastOnly", kind="Node3D")
    scene.node("Plant", "PastOnly", scene=MODEL + past_model)
    scene.node("FutureOnly", kind="Node3D")
    scene.node("Plant", "FutureOnly", scene=MODEL + future_model)
    collider(scene, ".", (radius * 2, 0.8, radius * 2), (0, 0.4, 0))
    return scene


def variant(name, past_model, future_model, asset, size=None, centre=None):
    scene = Scene(name, "StaticBody3D" if size else "Node3D", asset_id=asset)
    scene.node("PastOnly", kind="Node3D")
    scene.node("Model", "PastOnly", scene=MODEL + past_model)
    scene.node("FutureOnly", kind="Node3D")
    scene.node("Model", "FutureOnly", scene=MODEL + future_model)
    if size:
        collider(scene, ".", size, centre or (0, size[1] / 2, 0))
    return scene


def prop_scenes():
    scenes = {
        "wall_panel": prop("WallPanel", "architecture/lab_wall_panel.glb", asset="A02"),
        "wall_panel_damaged": prop("WallPanelDamaged", "architecture/lab_wall_panel_damaged.glb", asset="F06"),
        "wall_panel_damaged_b": prop("WallPanelDamagedB", "architecture/lab_wall_panel_damaged_b.glb", asset="F06"),
        "wall_low": prop("WallLow", "architecture/lab_wall_low.glb", asset="A02"),
        "wall_corner": prop("WallCorner", "architecture/lab_wall_corner.glb", asset="A02"),
        "monitor_wave": prop("MonitorWave", "electronics/lab_monitor_wave.glb", asset="A06"),
        "monitor_data": prop("MonitorData", "electronics/lab_monitor_data.glb", asset="A06"),
        "keyboard": prop("Keyboard", "electronics/lab_keyboard.glb", asset="A06"),
        "cable_run": prop("CableRun", "electronics/lab_cable_run.glb", asset="A26"),
        "cables_hanging": prop("CablesHanging", "decorations/lab_cables_hanging.glb", asset="F10"),
        "emergency_light": prop("EmergencyLight", "electronics/lab_emergency_light.glb", asset="A26"),
        "signal_rack": prop("SignalRack", "electronics/lab_signal_rack.glb", (1.2, 2.3, 0.8), asset="A17"),
        "oscilloscope": prop("Oscilloscope", "electronics/lab_oscilloscope.glb", asset="A17"),
        "signal_generator": prop("SignalGenerator", "electronics/lab_signal_generator.glb", asset="A17"),
        "antenna": prop("Antenna", "electronics/lab_antenna.glb", asset="A05"),
        "drafting_chair": prop("DraftingChair", "furniture/lab_drafting_chair.glb", (0.8, 1.1, 0.8), asset="A07"),
        "bookcase_stocked": stocked_bookcase(),
        "coat_stand": coat_stand(),
        "desk_lamp": prop("DeskLamp", "furniture/lab_desk_lamp.glb", asset="A16"),
        "paper_notes": prop("PaperNotes", "documents/lab_paper_notes.glb", asset="A09"),
        "paper_graph": prop("PaperGraph", "documents/lab_paper_graph.glb", asset="A09"),
        "paper_memo": prop("PaperMemo", "documents/lab_paper_memo.glb", asset="A09"),
        "paper_stack": prop("PaperStack", "documents/lab_paper_stack.glb", asset="A09"),
        "paper_crumpled": prop("PaperCrumpled", "documents/lab_paper_crumpled.glb", asset="F07"),
        "blackboard": prop("Blackboard", "decorations/lab_blackboard.glb", asset="A18"),
        "poster_array": prop("PosterArray", "decorations/lab_poster_array.glb", asset="A19"),
        "poster_safety": prop("PosterSafety", "decorations/lab_poster_safety.glb", asset="A19"),
        "poster_resonance": prop("PosterResonance", "decorations/lab_poster_resonance.glb", asset="A19"),
        "sign_lab": prop("SignLab", "decorations/lab_sign_lab.glb", asset="A19"),
        "sign_warning": prop("SignWarning", "decorations/lab_sign_warning.glb", asset="A19"),
        "mug": prop("Mug", "decorations/lab_mug.glb", asset="A22"),
        "pencil_holder": prop("PencilHolder", "decorations/lab_pencil_holder.glb", asset="A23"),
        "potted_plant": plant("PottedPlant", "decorations/lab_potted_plant.glb", "decorations/lab_potted_plant_wilted.glb", 0.3),
        "cactus_medium": plant("CactusMedium", "decorations/kaykit_cactus_medium_a.glb", "decorations/lab_cactus_dead.glb", 0.4),
        "cactus_small": plant("CactusSmall", "decorations/kaykit_cactus_small_a.glb", "decorations/lab_cactus_dead.glb", 0.26),
        "cactus_small_b": plant("CactusSmallB", "decorations/kaykit_cactus_small_b.glb", "decorations/lab_cactus_dead.glb", 0.26),
        "microscope": prop("Microscope", "laboratory/lab_microscope.glb", asset="A17"),
        "flask_set": variant("FlaskSet", "laboratory/lab_flask_set.glb", "laboratory/lab_glass_broken.glb", "A17"),
        "crate": prop("Crate", "laboratory/lab_crate.glb", (0.9, 0.7, 0.7), asset="A26"),
        "box_cardboard": prop("BoxCardboard", "laboratory/lab_box_cardboard.glb", (0.7, 0.5, 0.52), asset="A26"),
        "cable_reel": prop("CableReel", "laboratory/lab_cable_reel.glb", (0.5, 0.64, 0.64), asset="A26"),
        "debris_a": prop("DebrisA", "debris/lab_debris_cluster_a.glb", (1.4, 0.35, 0.9), asset="F02"),
        "debris_b": prop("DebrisB", "debris/lab_debris_cluster_b.glb", (1.4, 0.35, 0.9), asset="F02"),
        "debris_tiles": prop("DebrisTiles", "debris/lab_debris_tiles.glb", asset="F03"),
        "ceiling_panel": prop("CeilingPanel", "debris/lab_ceiling_panel.glb", (2.3, 0.7, 1.2), asset="F02"),
        "pipe_broken": prop("PipeBroken", "debris/lab_pipe_broken.glb", asset="F02"),
        "book_set": prop("BookSet", "books/kaykit_book_set.glb", offset=(0, 0.25, 0), asset="A15"),
        "book_single": prop("BookSingle", "books/kaykit_book_single.glb", offset=(0, 0.25, 0), asset="A15"),
        "binder_row": prop("BinderRow", "furniture/lab_binder_row.glb", asset="A15"),
        "rug": prop("Rug", "furniture/kaykit_rug_rectangle_stripes_a.glb", asset="A24"),
        "stool": prop("Stool", "furniture/kaykit_chair_stool.glb", (0.7, 0.5, 0.7), asset="A07", scale=(1.3, 1.3, 1.3)),
        "cabinet_low": prop("CabinetLow", "furniture/kaykit_cabinet_medium.glb", (2.0, 1.0, 1.0), asset="A12"),
        "table_lamp": prop("TableLamp", "furniture/kaykit_lamp_table.glb", asset="A16", scale=(0.6, 0.6, 0.6)),
        "picture_frame": prop("PictureFrame", "decorations/kaykit_pictureframe_standing_a.glb", asset="A19", scale=(0.6, 0.6, 0.6)),
        "wall_shelf": prop("WallShelf", "furniture/kaykit_shelf_b_large_decorated.glb", offset=(0, 0.1, 0), asset="A15"),
        "reading_table": prop("ReadingTable", "furniture/kaykit_table_small.glb", (1.0, 1.0, 1.0), asset="A14"),
    }
    return scenes


# --- Interactive devices and effects -------------------------------------------------------

INTERACTIVE = ROOT / "scenes" / "environment" / "interactive"
EFFECTS = ROOT / "scenes" / "environment" / "effects"
DEVICE_SCRIPTS = "res://scripts/environment/interactive/"
INTERACTABLE = "res://scripts/interaction/interactable_3d.gd"
LISTENER = "res://scripts/puzzles/puzzle_listener.gd"
HIGHLIGHT = DEVICE_SCRIPTS + "highlight_rim.gd"
LIGHT = "res://scripts/environment/light_behaviour.gd"
PAST_TL, FUTURE_TL = 1, 2  # Interactable3D.allowed_timeline
IMMEDIATE = 0


def path(value):
    """A reference to another node, for an exported Node-typed property."""
    return ("node", value)


def interactable(s, name, label, size, centre, anchor, distance=1.6, timeline=0, priority=0,
                 action="interact", timing=IMMEDIATE, script=INTERACTABLE, highlight=".", animate=True, **extra):
    """An Interactable3D (or subclass) with its shape, a floor-level Anchor and a rim highlight.

    animate=False for interactions that open a LabUI screen: the screen pauses the player, and a
    body animation frozen half-way would hold the interaction controller busy until it closes."""
    props = {"script": s.res("Script", script), "interaction_name": label, "interaction_distance": distance,
             "interaction_priority": priority, "allowed_timeline": timeline, "play_interaction_animation": animate,
             "animation_action_name": action, "timing": timing, "interaction_anchor": path("Anchor"),
             "highlight_target": path("Highlight")}
    props.update(extra)
    s.node(name, ".", "Area3D", **props)
    collider(s, name, size, centre, "Shape")
    s.node("Anchor", name, "Marker3D", position=anchor)
    rim = {"script": s.res("Script", HIGHLIGHT)}
    if highlight != ".":
        rim["target"] = path(highlight)
    s.node("Highlight", name, "Node3D", **rim)


def listener(s):
    s.node("PuzzleListener", ".", "Node", script=s.res("Script", LISTENER), puzzle_id="puzzle_01_frequency")


def additive(s, colour, energy=2.0):
    """Unshaded additive billboard material for particles."""
    return s.sub("StandardMaterial3D", transparency=1, blend_mode=1, shading_mode=0, vertex_color_use_as_albedo=True,
                 albedo_color=colour, billboard_mode=3, billboard_keep_scale=True, disable_receive_shadows=True)


def sparks(s, parent, name, position, amount=10):
    material = additive(s, (1.0, 0.75, 0.4, 1.0))
    mesh = s.sub("QuadMesh", size=(0.035, 0.035), material=material)
    ramp = s.sub("Gradient", offsets=("raw", "PackedFloat32Array(0, 0.5, 1)"),
                 colors=("raw", "PackedColorArray(1, 0.95, 0.7, 1, 1, 0.55, 0.2, 1, 0.6, 0.15, 0.05, 0)"))
    s.node(name, parent, "CPUParticles3D", position=position, emitting=False, amount=amount, lifetime=0.7,
           explosiveness=0.6, randomness=0.5, mesh=mesh, direction=(0, 0.3, 1), spread=55.0, gravity=(0, -6, 0),
           initial_velocity_min=0.6, initial_velocity_max=1.8, scale_amount_min=0.6, scale_amount_max=1.4,
           color_ramp=ramp)


def label3d(s, parent, name, position, text, size, pixel=0.0025, colour=(1, 1, 1, 1)):
    s.node(name, parent, "Label3D", position=position, text=text, font_size=size, pixel_size=pixel,
           outline_size=6, outline_modulate=(0.02, 0.04, 0.05, 0.85), modulate=colour, double_sided=False,
           shaded=False)


def security_door():
    s = Scene("SecurityDoor", "Node3D", DEVICE_SCRIPTS + "security_door.gd", asset_id="A03")
    s.node("Frame", scene=MODEL + "architecture/lab_door_frame.glb")
    s.node("Leaf", kind="Node3D", position=(0, 0, -0.15))
    s.node("Model", "Leaf", scene=MODEL + "architecture/lab_door_leaf.glb")
    s.node("Body", "Leaf", "AnimatableBody3D", sync_to_physics=False)
    collider(s, "Leaf/Body", (2.0, 3.0, 0.14), (0, 1.5, 0), "Shape")
    s.node("Corridor", scene=MODEL + "architecture/lab_corridor.glb")
    s.node("CorridorLight", kind="OmniLight3D", position=(0, 2.7, -1.9), light_color=(1.0, 0.86, 0.62, 1),
           light_energy=1.3, omni_range=4.5, omni_attenuation=1.2)
    s.node("Walls", kind="StaticBody3D")
    for name, size, centre in (("JambLeft", (0.36, 3.3, 0.46), (-1.16, 1.65, 0.04)), ("JambRight", (0.36, 3.3, 0.46), (1.16, 1.65, 0.04)),
                               ("CorridorLeft", (0.3, 3.2, 3.4), (-1.45, 1.6, -1.9)), ("CorridorRight", (0.3, 3.2, 3.4), (1.45, 1.6, -1.9)),
                               ("CorridorEnd", (2.6, 3.2, 0.3), (0, 1.6, -3.65)), ("CorridorFloor", (2.9, 0.2, 3.8), (0, -0.1, -1.8))):
        collider(s, "Walls", size, centre, name)
    s.node("FutureOnly", kind="Node3D")
    sparks(s, "FutureOnly", "FrameSparks", (0.85, 3.05, 0.3), 8)
    s.node("ExitZone", kind="Area3D", collision_layer=0, collision_mask=1, monitorable=False)
    collider(s, "ExitZone", (2.4, 2.4, 1.6), (0, 1.2, -2.3), "Shape")
    interactable(s, "Inspect", "Inspect sealed door", (2.2, 2.6, 1.0), (0, 1.3, 0.45), (0, 0, 0.55), 1.7,
                 action="inspect", highlight="../../Leaf")
    listener(s)
    return s


def door_keypad():
    s = Scene("DoorKeypad", "Node3D", DEVICE_SCRIPTS + "door_keypad.gd", asset_id="A04")
    s.node("Model", scene=MODEL + "electronics/lab_keypad.glb")
    label3d(s, ".", "Display", (0, 0.56, 0.112), "SEALED", 28, 0.0016, (1.0, 0.81, 0.48, 1))
    interactable(s, "Interactable", "Check keypad", (0.8, 2.0, 1.0), (0, -0.1, 0.5), (0, -1.1, 0.55), 1.5)
    listener(s)
    return s


def junction_box():
    s = Scene("JunctionBox", "Node3D", DEVICE_SCRIPTS + "junction_box.gd", asset_id="A26")
    s.node("Model", scene=MODEL + "electronics/lab_junction_box.glb")
    sparks(s, ".", "Sparks", (0.05, 0.55, 0.26), 12)
    interactable(s, "Inspect", "Inspect breaker", (1.0, 2.2, 1.0), (0, -0.05, 0.5), (0, -1.15, 0.6), 1.5, action="inspect")
    return s


FREQUENCY = "res://scenes/gameplay/frequency/"

RESEARCH_LOG = """TEMPORAL COMMUNICATION ARRAY
Receiver bank B  ·  recovered calibration record #01

23:38  Array calibration started. Door seal engaged.
23:41  Primary synchronization frequency: 67 MHz
23:43  Both handheld radios must be on the carrier.
23:44  CORE CONTAINMENT FAILURE.

Margin, handwritten: "Tell him 67. He calibrates it from the Past."
"""


def rim(s, parent):
    """Rim highlight for an instanced interactable that has none of its own."""
    s.node("Highlight", parent, "Node3D", script=s.res("Script", HIGHLIGHT))


def console_terminal():
    """Overlay for the existing console (Actors/Console in spawn_area): screen, readout, lamp, and the
    frequency puzzle's own FrequencyComputer (Past) and FrequencyClue (Future) as its interactions."""
    s = Scene("ConsoleTerminal", "Node3D", DEVICE_SCRIPTS + "console_terminal.gd", asset_id="A05")
    s.node("Screen", kind="MeshInstance3D", position=(0, 1.7, 0.49), mesh=s.sub("QuadMesh", size=(1.16, 0.84)), cast_shadow=0)
    label3d(s, ".", "Readout", (0, 1.38, 0.5), "TX READY", 40, 0.0034, (1.0, 0.84, 0.6, 1))
    s.node("StatusLamp", kind="MeshInstance3D", position=(0.62, 2.32, 0.43),
           mesh=s.sub("BoxMesh", size=(0.18, 0.09, 0.06)), cast_shadow=0)
    s.node("ScreenGlow", kind="OmniLight3D", position=(0, 1.75, 1.0), light_color=(1.0, 0.84, 0.6, 1), light_energy=0.9,
           omni_range=3.6, omni_attenuation=1.4)
    sparks(s, ".", "Sparks", (0.42, 1.98, 0.5), 14)
    s.node("Computer", scene=FREQUENCY + "frequency_computer.tscn", position=(0, 0.6, 0.85), interaction_priority=1,
           highlight_target=path("Highlight"))
    rim(s, "Computer")
    s.node("RecoveredLog", scene=FREQUENCY + "frequency_clue.tscn", position=(0, 0.95, 0.75), interaction_priority=1,
           research_text=RESEARCH_LOG, highlight_target=path("Highlight"))
    rim(s, "RecoveredLog")
    listener(s)
    return s


NOTEBOOK_PAST = """Day 214. The array finally holds a carrier for more than a second. When it locks, the crystal answers with an echo: the same signal, arriving before we sent it.

The handhelds are the trick. With both radios on, and the array calibrated on the right carrier, the rift carries a voice across the fracture. The carrier changes with every calibration, so it goes in the receiver log the moment we set it.

The door seal is slaved to the array and only releases on a stable link. (Facilities hate this. So do I.)"""

NOTEBOOK_FUTURE = """The ink has run, but most of the page is still legible: "...with both radios on, and the array calibrated on the right carrier..."

Added later, in a shakier hand:

Thirty-one years, and the room never let go of that night. If anyone reads this: the console still runs on its emergency cell, and its recovered log has the frequency. My old handheld is in the reading corner.

Read him the frequency. He is still there at the array, on the other side of the rift.

Don't tell him why I started it."""

MEMO_PAST = """To: Signal Array staff
Re: Security door, north wall

From this term the north door is wired to the array's containment lock. While a calibration runs the door stays sealed and the keypad refuses every code, the master code included.

The seal releases automatically when the array reports a stable temporal link. Do not prop the door, do not pry the keypad panel, and please stop leaving mugs on the oscilloscope.

Facilities Office"""

MEMO_FUTURE = """The memo is yellowed and spotted with mould. Someone circled one line in red:

"The seal releases automatically when the array reports a stable temporal link."

Underneath, in pencil: Nobody got out that night. The link never held."""


def document(name, model, title, future_title, past_text, future_text, prompt, asset, shape=(1.0, 2.2, 1.6), centre=(0, -0.4, 0.5), anchor=(0, -1.5, 0.85)):
    s = Scene(name, "Node3D", DEVICE_SCRIPTS + "lab_document.gd", asset_id=asset, title=title, future_title=future_title,
              past_text=past_text, future_text=future_text, prompt=prompt)
    s.node("Model", scene=MODEL + model)
    interactable(s, "Interactable", prompt, shape, centre, anchor, 1.5, animate=False)
    return s


def wall_clock_scene():
    s = Scene("WallClock", "Node3D", DEVICE_SCRIPTS + "wall_clock.gd", asset_id="A20", future_rotation=(0, 0, -9))
    s.node("Model", scene=MODEL + "decorations/lab_wall_clock.glb")
    return s


def temporal_rift():
    s = Scene("TemporalRift", "Node3D", "res://scripts/environment/temporal_rift.gd", asset_id="A11")
    s.node("Emitter", scene=MODEL + "temporal/lab_rift_emitter.glb")
    s.node("Core", kind="Node3D", position=(0, 1.35, 0))
    s.node("Model", "Core", scene=MODEL + "temporal/lab_rift_core.glb")
    s.node("Fragments", kind="Node3D")
    for k in range(9):
        s.node(f"Fragment{k}", "Fragments", scene=MODEL + f"temporal/lab_rift_fragment_{'abc'[k % 3]}.glb")
    shell = s.sub("ShaderMaterial", shader=s.res("Shader", "res://shaders/temporal_rift.gdshader"))
    s.node("Energy", kind="MeshInstance3D", position=(0, 2.2, 0), cast_shadow=0,
           mesh=s.sub("SphereMesh", radius=1.0, height=2.0, radial_segments=24, rings=12), material_override=shell)
    mote_mesh = s.sub("QuadMesh", size=(0.07, 0.07), material=additive(s, (1, 1, 1, 1)))
    s.node("Motes", kind="CPUParticles3D", position=(0, 2.2, 0), amount=24, lifetime=3.2, preprocess=2.0, mesh=mote_mesh,
           emission_shape=1, emission_sphere_radius=1.1, direction=(0, 1, 0), spread=180.0, gravity=(0, 0.12, 0),
           initial_velocity_min=0.08, initial_velocity_max=0.35, scale_amount_min=0.5, scale_amount_max=1.4,
           color=(0.62, 0.9, 0.93, 1))
    s.node("Glow", kind="OmniLight3D", position=(0, 2.2, 0), script=s.res("Script", LIGHT), light_color=(0.53, 0.79, 0.82, 1),
           light_energy=1.4, omni_range=7.5, omni_attenuation=1.3, mode=1, speed=0.35, depth=0.45)
    s.node("Hum", kind="AudioStreamPlayer3D", position=(0, 2.0, 0), volume_db=-10.0, unit_size=4.0, max_distance=20.0)
    s.node("Body", kind="StaticBody3D")
    s.node("Shape", "Body", "CollisionShape3D", position=(0, 1.0, 0), shape=s.sub("CylinderShape3D", radius=1.5, height=2.0))
    interactable(s, "Inspect", "Inspect temporal rift", (3.8, 2.4, 3.8), (0, 1.2, 0), (0, 0, 0), 2.3, action="inspect")
    # The frequency puzzle's TemporalLinkPresenter colours this lamp: purple until linked, cyan after.
    s.node("LinkLamp", kind="MeshInstance3D", position=(0, 0.32, 1.42), cast_shadow=0, groups=["keep_materials"],
           mesh=s.sub("SphereMesh", radius=0.1, height=0.2, radial_segments=12, rings=6))
    s.node("LinkPresenter", kind="Node3D", script=s.res("Script", "res://scripts/gameplay/frequency/temporal_link_presenter.gd"),
           indicator=path("../LinkLamp"))
    s.node("FutureOnly", kind="Node3D")
    for k, (x, z, ry, rz) in enumerate(((2.1, 0.4, 20, 35), (-1.7, 1.5, 80, -40), (0.6, -2.2, 140, 50), (-2.0, -1.1, 200, 25))):
        s.node(f"Shard{k}", "FutureOnly", scene=MODEL + "temporal/lab_rift_fragment_b.glb", position=(x, 0.12, z), rotation=rad(0, ry, rz))
    listener(s)
    return s


def radio_pickup(name, role, presence):
    """The frequency puzzle's RadioPickup, shown in one timeline, with the lab's handheld radio model."""
    s = Scene(name, "Node3D", presence=presence)
    s.node("Pickup", scene="res://scenes/gameplay/radio/radio_pickup.tscn", radio_role=role, position=(0, 0.25, 0),
           placeholder=path("Model"), highlight_target=path("Highlight"))
    s.node("Model", "Pickup", scene=MODEL + "electronics/lab_radio_handheld.glb", position=(0, -0.25, 0),
           rotation=rad(0, 15 if role == "past" else -30, 0), scale=(1.4, 1.4, 1.4))
    rim(s, "Pickup")
    s.node("PlaceholderRadio", "Pickup", visible=False)  # the frequency puzzle's stand-in box
    s.editable.append("Pickup")
    return s


def device_scenes():
    return {
        INTERACTIVE / "security_door.tscn": security_door(),
        INTERACTIVE / "door_keypad.tscn": door_keypad(),
        INTERACTIVE / "junction_box.tscn": junction_box(),
        INTERACTIVE / "console_terminal.tscn": console_terminal(),
        INTERACTIVE / "research_notebook.tscn": document("ResearchNotebook", "documents/lab_notebook_open.glb", "Signal Array: Research Log",
                                                         "Research Log (water-damaged)", NOTEBOOK_PAST, NOTEBOOK_FUTURE, "Read research notebook", "A10"),
        INTERACTIVE / "lab_memo.tscn": document("LabMemo", "documents/lab_paper_memo.glb", "Memo: North Security Door",
                                                "Memo (yellowed)", MEMO_PAST, MEMO_FUTURE, "Read memo", "A09"),
        INTERACTIVE / "wall_clock.tscn": wall_clock_scene(),
        INTERACTIVE / "radio_pickup_past.tscn": radio_pickup("PastRadio", "past", PAST),
        INTERACTIVE / "radio_pickup_future.tscn": radio_pickup("FutureRadio", "future", FUTURE),
        EFFECTS / "temporal_rift.tscn": temporal_rift(),
    }


# --- Room ----------------------------------------------------------------------------------

def place(scene, parent, key, name, pos, rot=(0, 0, 0), scale=None, presence=BOTH, f_off=None, f_rot=None, asset=None):
    props = {"position": pos}
    if any(rot):
        props["rotation"] = rad(*rot)
    if scale:
        props["scale"] = scale if isinstance(scale, tuple) else (scale, scale, scale)
    if presence:
        props["presence"] = presence
    if f_off:
        props["future_offset"] = f_off
    if f_rot:
        props["future_rotation"] = f_rot
    if asset:
        props["asset_id"] = asset
    return scene.node(name, parent, scene=f"res://scenes/environment/props/{key}.tscn", **props)


def room():
    s = Scene("SignalLabLayout", "Node3D", None)
    s.node("Architecture", kind="Node3D")
    s.node("North", "Architecture", kind="Node3D")
    door_module = 7
    for i in range(10):
        x = -11.16 + i * 2.48
        if i == door_module:
            continue
        damaged = {1: "wall_panel_damaged", 8: "wall_panel_damaged_b"}.get(i)
        if damaged:
            place(s, "Architecture/North", "wall_panel", f"Panel{i}", (x, 0, -7.8), presence=PAST)
            place(s, "Architecture/North", damaged, f"Panel{i}Damaged", (x, 0, -7.8), presence=FUTURE)
        else:
            place(s, "Architecture/North", "wall_panel", f"Panel{i}", (x, 0, -7.8))
    for side, wx, ry in (("West", -12.4, 90), ("East", 12.4, -90)):
        s.node(side, "Architecture", kind="Node3D")
        for k in range(6):
            z = -6.5 + k * 2.6
            damaged = (side == "West" and k == 4) or (side == "East" and k == 1)
            key = "wall_panel"
            place(s, f"Architecture/{side}", key, f"Panel{k}", (wx, 0, z), (0, ry, 0), scale=(1.048, 1, 1),
                  presence=PAST if damaged else BOTH)
            if damaged:
                place(s, f"Architecture/{side}", "wall_panel_damaged" if side == "West" else "wall_panel_damaged_b",
                      f"Panel{k}Damaged", (wx, 0, z), (0, ry, 0), scale=(1.048, 1, 1), presence=FUTURE)
    s.node("South", "Architecture", kind="Node3D")
    for i in range(10):
        place(s, "Architecture/South", "wall_low", f"Low{i}", (-11.16 + i * 2.48, 0, 7.8), (0, 180, 0))
    for name, x, z in (("CornerNW", -12.4, -7.8), ("CornerNE", 12.4, -7.8)):
        place(s, "Architecture", "wall_corner", name, (x, 0, z))

    s.node("Interactive", kind="Node3D")
    s.node("SecurityDoor", "Interactive", scene="res://scenes/environment/interactive/security_door.tscn", position=(-11.16 + door_module * 2.48, 0, -7.8))
    s.node("DoorKeypad", "Interactive", scene="res://scenes/environment/interactive/door_keypad.tscn", position=(7.78, 1.1, -7.74))
    s.node("JunctionBox", "Interactive", scene="res://scenes/environment/interactive/junction_box.tscn", position=(-2.6, 1.15, -7.74))
    s.node("ConsoleTerminal", "Interactive", scene="res://scenes/environment/interactive/console_terminal.tscn", position=(0.0, 0.0, -6.6))
    s.node("ResearchNotebook", "Interactive", scene="res://scenes/environment/interactive/research_notebook.tscn", position=(6.86, 1.5, 0.64), rotation=rad(0, -6, 0))
    s.node("LabMemo", "Interactive", scene="res://scenes/environment/interactive/lab_memo.tscn", position=(-7.25, 1.5, 0.72), rotation=rad(0, 9, 0))
    # Puzzle 01's handheld radios: the Student's beside the signal generator, the Professor's in the reading corner.
    s.node("PastRadio", "Interactive", scene="res://scenes/environment/interactive/radio_pickup_past.tscn", position=(-4.85, 1.5, 0.86))
    s.node("FutureRadio", "Interactive", scene="res://scenes/environment/interactive/radio_pickup_future.tscn", position=(-8.45, 1.0, 5.4))

    s.node("NorthWall", kind="Node3D")
    place(s, "NorthWall", "poster_safety", "PosterSafety", (-11.2, 1.55, -7.74), f_off=(0.05, -1.53, 0.55), f_rot=(-84, 0, 6))
    place(s, "NorthWall", "blackboard", "Blackboard", (-6.2, 1.12, -7.66))
    place(s, "NorthWall", "poster_array", "PosterArray", (1.9, 1.15, -7.74))
    place(s, "NorthWall", "sign_lab", "SignLab", (2.95, 3.3, -7.74), f_rot=(0, 0, -4))
    place(s, "NorthWall", "sign_warning", "SignWarning", (3.85, 1.85, -7.74))
    s.node("Clock", "NorthWall", scene="res://scenes/environment/interactive/wall_clock.tscn", position=(-1.25, 3.42, -7.74))
    place(s, "NorthWall", "emergency_light", "EmergencyNorth", (9.3, 3.3, -7.76))
    place(s, "NorthWall", "cable_run", "CableToBreaker", (-1.55, 0, -7.42))
    place(s, "NorthWall", "antenna", "ConsoleAntenna", (0.35, 2.45, -6.7))

    s.node("ResearchStation", kind="Node3D")
    rs = "ResearchStation"
    place(s, rs, "desk_lamp", "DeskLamp", (3.6, 1.5, 0.42), (0, 25, 0), f_off=(0.15, 0.17, 0.1), f_rot=(0, 0, 84))
    place(s, rs, "paper_stack", "PaperStack", (3.75, 1.5, 0.82), (0, -8, 0), presence=PAST)
    place(s, rs, "monitor_wave", "MonitorLeft", (4.62, 1.5, 0.56), (0, 6, 0))
    place(s, rs, "monitor_data", "MonitorRight", (5.82, 1.5, 0.56), (0, -6, 0), f_off=(0.0, 0.08, 0.32), f_rot=(-84, 0, 0))
    place(s, rs, "keyboard", "Keyboard", (5.22, 1.5, 0.86), f_off=(0.3, 0, 0.05), f_rot=(0, 22, 0))
    place(s, rs, "pencil_holder", "PencilHolder", (6.25, 1.5, 0.3), f_off=(0.6, -1.48, 0.95), f_rot=(90, 30, 0))
    place(s, rs, "mug", "Mug", (7.36, 1.5, 0.32), f_rot=(0, 0, 0))
    place(s, rs, "drafting_chair", "Chair", (5.2, 0, 1.78), f_off=(0.9, 0.3, 0.55), f_rot=(0, 35, 82))
    place(s, rs, "picture_frame", "PhotoFrame", (7.35, 1.5, 0.66), (0, -30, 0), f_rot=(-80, 0, 0), f_off=(0, 0.04, 0.1))

    s.node("ScienceBench", kind="Node3D")
    sb = "ScienceBench"
    place(s, sb, "microscope", "Microscope", (-6.75, 1.5, 0.5), (0, 20, 0), f_off=(0.0, 0.18, 0.2), f_rot=(0, 0, 76))
    place(s, sb, "flask_set", "FlaskSet", (-5.55, 1.5, 0.56))
    place(s, sb, "oscilloscope", "Oscilloscope", (-4.3, 1.5, 0.48), (0, -8, 0))
    place(s, sb, "signal_generator", "SignalGenerator", (-3.58, 1.5, 0.78), (0, -15, 0))
    place(s, sb, "mug", "Mug", (-7.42, 1.5, 0.3), presence=PAST)
    place(s, sb, "desk_lamp", "DeskLamp", (-7.35, 1.5, 0.55), (0, -35, 0), f_rot=(0, 0, -12))
    place(s, sb, "drafting_chair", "Chair", (-3.55, 0, 1.62), (0, -20, 0), f_off=(0.2, 0, 0.3), f_rot=(0, 60, 0))
    place(s, sb, "paper_graph", "PaperGraph", (-6.1, 1.5, 0.95), (0, 14, 0), f_off=(-0.6, -1.49, 0.9), f_rot=(0, 50, 0))

    s.node("Library", kind="Node3D")
    lb = "Library"
    place(s, lb, "bookcase_stocked", "BookcaseNorth", (-12.08, 0, -3.65), (0, 90, 0))
    place(s, lb, "bookcase_stocked", "BookcaseSouth", (-12.08, 0, -1.25), (0, 90, 0), f_off=(0.25, 0, 0.0), f_rot=(0, 0, -7))
    place(s, lb, "emergency_light", "EmergencyWest", (-12.36, 3.25, -2.4), (0, 90, 0))
    place(s, lb, "cabinet_low", "CabinetLow", (-11.9, 0, 2.6), (0, 90, 0), asset="A12", f_rot=(0, -6, 0), f_off=(0.15, 0, 0))
    place(s, lb, "wall_shelf", "WallShelf", (-12.15, 2.0, 2.6), (0, 90, 0), f_rot=(0, 0, 9), f_off=(0, -0.12, 0))
    place(s, lb, "cactus_small_b", "ShelfCactus", (-11.9, 1.0, 3.25))
    place(s, lb, "book_set", "CabinetBooks", (-11.95, 1.0, 2.05), (0, 90, 0), f_off=(0.6, -1.0, 0.4), f_rot=(0, 30, 90))
    place(s, lb, "poster_resonance", "PosterWest", (-12.34, 1.45, 5.45), (0, 90, 0))
    place(s, lb, "coat_stand", "CoatStand", (-11.55, 0, 4.4), f_rot=(0, 0, 14), f_off=(-0.35, 0, 0))
    place(s, lb, "potted_plant", "PlantSW", (-11.7, 0, 7.05))
    place(s, lb, "cactus_medium", "PlantNW", (-11.55, 0, -7.0))

    s.node("ReadingCorner", kind="Node3D")
    rc = "ReadingCorner"
    place(s, rc, "rug", "Rug", (-8.2, 0.005, 5.2), scale=1.5)
    place(s, rc, "reading_table", "Table", (-8.7, 0, 5.3))
    place(s, rc, "table_lamp", "TableLamp", (-8.95, 1.0, 5.1), f_rot=(0, 0, -78), f_off=(0.3, 0.12, 0))
    place(s, rc, "book_set", "TableBooks", (-8.45, 1.0, 5.55), (0, 20, 0), f_off=(0.3, -1.0, 0.8), f_rot=(0, 60, 90))
    place(s, rc, "paper_notes", "TableNotes", (-8.3, 1.0, 4.95), (0, -12, 0))
    place(s, rc, "stool", "StoolA", (-7.35, 0, 5.75), f_rot=(90, 0, 0), f_off=(0, 0.36, 0.2))
    place(s, rc, "stool", "StoolB", (-9.9, 0, 6.2))

    s.node("RiftArea", kind="Node3D")
    ra = "RiftArea"
    # The array's feed: a cable bundle from the console to the rift emitter, along the floor.
    feed = ((1.2, -6.2), (3.5, -5.2), (5.6, -3.6), (7.2, -1.6), (8.3, 0.6))
    for k, ((x0, z0), (x1, z1)) in enumerate(zip(feed, feed[1:])):
        angle = math.degrees(math.atan2(-(z1 - z0), x1 - x0))
        place(s, ra, "cable_run", f"FeedCable{k}", ((x0 + x1) / 2, 0, (z0 + z1) / 2), (0, angle, 0))
    s.node("TemporalRift", ra, scene="res://scenes/environment/effects/temporal_rift.tscn", position=(9.2, 0, 2.3))
    place(s, ra, "signal_rack", "MonitorRack", (11.95, 0, 0.0), (0, -90, 0))
    place(s, ra, "cable_run", "RackCable", (10.45, 0, 1.0), (0, 40, 0))
    place(s, ra, "poster_resonance", "PosterEast", (12.34, 1.4, -2.5), (0, -90, 0), f_off=(-0.4, -1.38, 0.2), f_rot=(-88, 0, 10))
    place(s, ra, "emergency_light", "EmergencyEast", (12.36, 3.25, -1.0), (0, -90, 0))
    place(s, ra, "cactus_small", "PlantE", (11.85, 0, 3.45))

    s.node("Storage", kind="Node3D")
    st = "Storage"
    place(s, st, "crate", "CrateNE", (11.7, 0, -5.5), (0, 90, 0), f_rot=(0, 15, 0))
    place(s, st, "box_cardboard", "BoxNE", (11.7, 0.7, -5.45), (0, 80, 0), f_off=(-0.9, -0.7, 0.4), f_rot=(0, 25, 70))
    place(s, st, "crate", "CrateSE", (10.95, 0, 6.85))
    place(s, st, "box_cardboard", "BoxSE", (9.95, 0, 7.0), (0, 10, 0))
    place(s, st, "box_cardboard", "BoxSEStack", (10.95, 0.7, 6.85), (0, -15, 0), f_off=(-0.2, -0.7, -0.9), f_rot=(0, 40, -75))
    place(s, st, "cable_reel", "Reel", (8.85, 0, 6.95), f_off=(0.6, 0, -0.4), f_rot=(0, 0, 90))

    s.node("FutureDamage", kind="Node3D")
    fd = "FutureDamage"
    place(s, fd, "ceiling_panel", "CeilingPanel", (-1.9, 0, -1.4), (0, 24, 0), presence=FUTURE)
    place(s, fd, "debris_a", "DebrisNorth", (-4.7, 0, -6.9), presence=FUTURE)
    place(s, fd, "debris_b", "DebrisRift", (10.0, 0, 4.85), (0, 30, 0), presence=FUTURE)
    place(s, fd, "debris_a", "DebrisWest", (-10.6, 0, 0.9), (0, 70, 0), presence=FUTURE)
    place(s, fd, "debris_tiles", "TilesCentre", (2.6, 0, -2.4), presence=FUTURE)
    place(s, fd, "debris_tiles", "TilesDoor", (8.4, 0, -5.0), (0, 40, 0), presence=FUTURE)
    place(s, fd, "debris_tiles", "TilesWest", (-9.2, 0, 3.1), (0, 110, 0), presence=FUTURE)
    place(s, fd, "pipe_broken", "PipeWest", (-8.2, 0, -6.2), (0, 10, 0), presence=FUTURE)
    place(s, fd, "cables_hanging", "CablesNorth", (8.9, 0, -7.6), presence=FUTURE)
    place(s, fd, "cables_hanging", "CablesWest", (-12.2, 0, 3.9), (0, 90, 0), presence=FUTURE)
    place(s, fd, "cables_hanging", "CablesCentre", (-2.2, 0, -2.0), (0, 30, 0), presence=FUTURE)
    for k, (x, z, ry, key) in enumerate(((3.6, 1.6, 30, "paper_notes"), (4.9, 2.3, -60, "paper_memo"), (6.8, 1.9, 10, "paper_graph"),
                                         (1.2, -5.2, 70, "paper_notes"), (-0.9, -5.4, -20, "paper_memo"), (-6.4, 1.6, 120, "paper_notes"),
                                         (2.2, -1.0, 15, "paper_graph"), (-9.9, -0.4, 80, "paper_memo"))):
        place(s, fd, key, f"Paper{k}", (x, 0.01, z), (0, ry, 0), presence=FUTURE, asset="F07")
    for k, (x, z) in enumerate(((3.9, 2.0), (-0.4, -5.0), (5.6, 2.6), (-5.0, 1.9))):
        place(s, fd, "paper_crumpled", f"Crumpled{k}", (x, 0, z), (0, k * 70, 0), presence=FUTURE)
    for k, (x, z, ry) in enumerate(((-11.0, -2.6, 30), (-10.6, -1.6, 75), (-10.9, -0.6, 10), (-10.3, -2.1, 140))):
        place(s, fd, "book_single", f"FallenBook{k}", (x, -0.07, z), (90, ry, 0), presence=FUTURE, asset="F01")
    return s


def main() -> int:
    written = []
    for key, scene in prop_scenes().items():
        written.append(scene.save(PROPS / f"{key}.tscn"))
    devices = device_scenes()
    for target, scene in devices.items():
        written.append(scene.save(target))
    written.append(room().save(ROOMS / "signal_lab_layout.tscn"))
    print(f"wrote {len(written)} scenes ({len(written) - len(devices) - 1} props, {len(devices)} devices and effects, room layout)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
