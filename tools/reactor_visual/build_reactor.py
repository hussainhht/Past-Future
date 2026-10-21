"""Original deterministic temporal reactor. Run with .venv/Scripts/python.exe.

Uses the project's existing low-poly mesh kit; no downloaded models or Blender needed.
Geometry is merged by material on each rigid moving part, not thousands of nodes.
"""
from pathlib import Path
import json
import math
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assets"))
import meshkit as mk

OUT = ROOT / "assets/environments/level3/reactor_visual"
COLORS = {"armor": "889181", "frame": "283a40", "steel": "aebeb5",
          "copper": "b47f4c", "rubber": "15252c", "warning": "e2ad4b",
          "cyan": "62dfdf", "amber": "efb85e", "violet": "ac85e8"}


def rod(a, b, radius=0.035, sides=8):
    a, b = np.array(a, float), np.array(b, float)
    d = b - a
    length = float(np.linalg.norm(d))
    d /= length
    return mk.cylinder(radius, length, sides).rotated(
        rx=math.degrees(math.acos(float(np.clip(d[1], -1, 1))))).rotated(
        ry=math.degrees(math.atan2(d[0], d[2]))).moved(*a)


def chain(points, radius=0.035, sides=8):
    return mk.merge(*(rod(a, b, radius, sides) for a, b in zip(points, points[1:])))


def arc(radius, width, height, start, end, steps=8):
    """Closed, bevel-free annular segment in XZ; radians measured toward -Z."""
    rings = []
    for angle in np.linspace(start, end, steps + 1):
        # Cross-section ordering gives outward normals in the existing mesh kit.
        rings.append(np.array([[r * math.cos(angle), y, -r * math.sin(angle)]
                               for r, y in [(radius-width/2, 0), (radius+width/2, 0),
                                            (radius+width/2, height), (radius-width/2, height)]]))
    return mk.loft(rings)


def radial(shape, radius, angle, y=0):
    return shape.moved(x=radius, y=y).rotated(ry=math.degrees(angle))


def bolts(node, radius, count, y, slot="steel"):
    for i in range(count):
        a = math.tau * i / count
        node.add(radial(mk.cylinder(0.035, 0.035, 6), radius, a, y), slot)


def build():
    m = mk.Model("TemporalAssembly")
    r = m.root
    platform = r.child("Platform")
    platform.add(mk.lathe([(1.48, 0.02), (1.65, 0.10), (1.65, 0.22), (1.5, 0.29)], 64), "frame")
    platform.add(mk.tube(1.64, 1.55, 0.08, 64).moved(y=0.22), "steel")
    for i in range(24):
        a = math.tau*i/24
        platform.add(arc(1.26, 0.48, 0.035, a+0.012, a+math.tau/24-0.012, 3).moved(y=0.293), "armor")
        platform.add(radial(mk.box(0.17, 0.012, 0.075), 1.54, a+0.04, 0.307), "warning" if i % 2 == 0 else "rubber")
    for radius in [0.91, 1.51]:
        platform.add(mk.tube(radius, radius-0.025, 0.016, 64).moved(y=0.31), "cyan")
    for i in range(8):
        a = math.tau*i/8
        platform.add(radial(mk.block(0.28, 0.10, 0.23, 0.02), 1.34, a, 0.32), "frame")
        platform.add(radial(mk.block(0.19, 0.025, 0.15, 0.01), 1.34, a, 0.42), "steel")
        platform.add(radial(mk.box(0.08, 0.02, 0.018), 1.34, a, 0.448), "amber")
    bolts(platform, 1.57, 32, 0.312)
    platform.add(mk.lathe([(0.74, 0.32), (0.86, 0.40), (0.86, 0.65), (0.55, 0.87)], 32), "frame")
    for i in range(12):
        platform.add(radial(mk.block(0.26, 0.22, 0.14), 0.71, math.tau*i/12, 0.44), "copper")

    # Rear towers keep the front and switch approaches open. Triangulated braces,
    # heat exchangers, removable access doors, sockets, bolts and striped mounts.
    support = r.child("Supports")
    for side in [-1, 1]:
        x, z = side*1.18, -0.78
        support.add(mk.block(0.64, 0.18, 0.66).moved(x=x, y=0.28, z=z), "steel")
        support.add(mk.block(0.30, 3.82, 0.32, 0.055).moved(x=x, y=0.44, z=z), "frame")
        for y in [0.58, 1.65, 2.9, 4.15]:
            support.add(mk.block(0.44, 0.16, 0.47).moved(x=x, y=y, z=z), "steel")
            support.add(mk.box(0.27, 0.045, 0.016).moved(x=x, y=y+0.06, z=z+0.245), "warning")
        for y in [0.85, 2.05, 3.23]:
            support.add(mk.block(0.36, 0.58, 0.10).moved(x=x, y=y, z=z+0.19), "armor")
            support.add(mk.box(0.08, 0.035, 0.04).moved(x=x+0.075, y=y+0.28, z=z+0.25), "rubber")
            for j in range(4):
                support.add(mk.box(0.23, 0.025, 0.02).moved(x=x, y=y+0.08+j*0.09, z=z+0.252), "frame")
        for j in range(14):
            support.add(mk.block(0.28, 0.045, 0.34, 0.008).moved(x=x+side*0.28, y=1.20+j*0.10, z=z), "copper")
        # Back structural strut and mechanical gimbal bearing.
        support.add(rod((x, 0.49, z-0.22), (x*0.5, 4.65, -0.44), 0.09), "steel")
        support.add(rod((x, 4.25, z), (side*0.60, 4.72, 0), 0.13, 10), "frame")
        for offset, slot in [(0, "rubber"), (0.105, "copper"), (-0.11, "cyan")]:
            pts = [(x+offset, 0.45, z-0.25), (x+offset, 1.0, z-0.32),
                   (x+offset+side*0.12, 2.5, z-0.38), (x+offset, 3.9, z-0.32), (side*0.55, 4.56, -0.1)]
            support.add(chain(pts, 0.035 if slot == "cyan" else 0.053), slot)
        for y in [0.82, 3.7]:
            support.add(mk.cylinder(0.095, 0.12, 10).rotated(rx=90).moved(x=x, y=y, z=z+0.18), "frame")
            support.add(mk.cylinder(0.055, 0.13, 10).rotated(rx=90).moved(x=x, y=y, z=z+0.20), "amber")

    chamber = r.child("Chamber")
    for y, inverted in [(1.45, False), (4.38, True)]:
        cap = mk.lathe([(0.42, 0), (0.74, 0.18), (0.77, 0.34), (0.61, 0.47)], 32)
        if inverted:
            cap = cap.rotated(rx=180)
        chamber.add(cap.moved(y=y), "armor")
        chamber.add(mk.tube(0.79, 0.68, 0.10, 32).moved(y=y-0.04), "frame")
        chamber.add(mk.tube(0.76, 0.71, 0.03, 48).moved(y=y+0.07), "cyan")
        bolts(chamber, 0.72, 16, y+0.12)
    for i in range(8):
        a = math.tau*i/8
        # Open cage: narrow bars, collars, inward-pointing containment clamps.
        chamber.add(radial(mk.block(0.095, 2.12, 0.10, 0.015), 0.66, a, 1.92), "steel")
        for y in [2.08, 3.62]:
            chamber.add(radial(mk.block(0.30, 0.14, 0.17), 0.59, a, y), "frame")
            chamber.add(radial(mk.box(0.065, 0.065, 0.18), 0.58, a, y+0.03), "amber")
    for y in [2.1, 3.68]:
        chamber.add(mk.tube(0.72, 0.64, 0.07, 32).moved(y=y), "copper")
    # Visible internals around the plasma spindle, with faceted ceramic insulators.
    for i in range(6):
        a = math.tau*i/6
        chamber.add(radial(mk.cylinder(0.055, 1.95, 8), 0.38, a, 2.0), "copper")
        for j in range(4):
            chamber.add(radial(mk.cylinder(0.082, 0.065, 8), 0.38, a, 2.15+j*0.45), "steel")
    chamber.add(mk.lathe([(0.24, 1.78), (0.12, 2.0), (0.12, 3.99), (0.24, 4.15)], 16), "cyan")

    # Removable curved covers are displaced in Future; same heavy mesh is reused.
    for i, a in enumerate([0.15, 1.55, 2.9, 4.4]):
        cover = r.child("Cover%d" % i, (0, 3.0, 0))
        cover.add(arc(0.77, 0.12, 0.43, a, a+0.50, 5), "armor")
        cover.add(arc(0.835, 0.02, 0.05, a+0.07, a+0.43, 5).moved(y=0.19), "amber")

    for idx, (name, radius, sectors, tilt, slot) in enumerate([
            ("Outer", 2.08, 24, (62, 0, 12), "cyan"),
            ("Inner", 1.57, 18, (-48, 0, -28), "amber"),
            ("Focus", 1.08, 12, (78, 0, 42), "violet")]):
        axis = r.child(name+"Axis", (0, 3.05, 0), tilt)
        ring = axis.child(name+"Rotor")
        for i in range(sectors):
            a, step = math.tau*i/sectors, math.tau/sectors
            ring.add(arc(radius, 0.18 if idx == 0 else 0.14, 0.13, a+0.012, a+step-0.012, 4), "frame")
            ring.add(arc(radius, 0.12, 0.035, a+0.025, a+step-0.025, 4).moved(y=0.135), "armor")
            ring.add(arc(radius-0.065, 0.024, 0.035, a+0.03, a+step-0.03, 4).moved(y=0.173), slot)
            ring.add(radial(mk.block(0.24, 0.12, 0.095, 0.015), radius, a, -0.025), "steel")
            ring.add(radial(mk.cylinder(0.03, 0.025, 6), radius, a, 0.105), "copper")
            if i % 3 == 0:
                ring.add(radial(mk.block(0.18, 0.14, 0.20), radius+0.10, a+step/2, -0.04), "copper")
                ring.add(radial(mk.box(0.075, 0.025, 0.10), radius+0.1, a+step/2, 0.11), slot)

    damage = r.child("FutureDamage")
    for i in range(7):
        a = i*0.83
        damage.add(chain([(0.68*math.cos(a), 2.1, 0.68*math.sin(a)),
                          (0.93*math.cos(a), 2.0, 0.93*math.sin(a)),
                          (0.98*math.cos(a), 1.72, 0.98*math.sin(a))], 0.025, 5), "copper")
        damage.add(mk.crystal(0.07, 0.22, 5, i).rotated(rz=i*23).moved(
            x=math.cos(a)*0.8, y=2.25+(i%3)*0.5, z=math.sin(a)*0.8), "violet")
    OUT.mkdir(parents=True, exist_ok=True)
    m.save(OUT / "temporal_assembly.glb", {k: tuple(int(v[j:j+2], 16)/255 for j in (0, 2, 4)) for k, v in COLORS.items()})
    def stats(node):
        return {"name": node.name, "triangles": sum(len(s.tris) for s in node.geometry.values()),
                "surfaces": len(node.geometry), "children": [stats(c) for c in node.children]}
    tree = stats(r)
    def total(t, key):
        return t[key] + sum(total(c, key) for c in t["children"])
    manifest = {"generator": "tools/reactor_visual/build_reactor.py", "original_geometry": True,
                "seed": "deterministic", "units": "metres", "floor_radius": 1.65,
                "triangles": total(tree, "triangles"), "material_surfaces": total(tree, "surfaces"), "tree": tree}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in manifest.items() if k != "tree"}, indent=2))


if __name__ == "__main__":
    build()
