"""Small procedural modelling kit for the project's original low-poly props.

Shapes are flat-shaded triangle soups grouped by material slot. A Model is a tree of named
nodes (so doors, buttons, screens and clock hands stay separately movable) and is written as a
binary glTF with tools/gltf_tools.py. NumPy only; no modelling application is involved.

Conventions: Y up, 1 unit = 1 Godot unit, model origin on the floor (or on the wall plane for
wall-mounted pieces), front faces counter-clockwise, rings ordered counter-clockwise seen from +Y.
"""
from pathlib import Path
import math
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gltf_tools import Writer


def _rotation(rx=0.0, ry=0.0, rz=0.0):
    x, y, z = (math.radians(a) for a in (rx, ry, rz))
    mx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
    my = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    mz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
    return my @ mx @ mz


class Shape:
    """Triangles (n, 3, 3) with optional UVs (n, 3, 2)."""

    def __init__(self, tris=None, uvs=None):
        self.tris = np.zeros((0, 3, 3)) if tris is None else np.asarray(tris, dtype=float).reshape(-1, 3, 3)
        self.uvs = None if uvs is None else np.asarray(uvs, dtype=float).reshape(-1, 3, 2)

    def __add__(self, other):
        if other is None or len(other.tris) == 0:
            return self
        if len(self.tris) == 0:
            return other
        uvs = None
        if self.uvs is not None or other.uvs is not None:
            uvs = np.concatenate([s.uvs if s.uvs is not None else np.zeros((len(s.tris), 3, 2)) for s in (self, other)])
        return Shape(np.concatenate([self.tris, other.tris]), uvs)

    def moved(self, x=0.0, y=0.0, z=0.0):
        return Shape(self.tris + np.array([x, y, z]), self.uvs)

    def rotated(self, rx=0.0, ry=0.0, rz=0.0):
        return Shape(self.tris @ _rotation(rx, ry, rz).T, self.uvs)

    def scaled(self, sx=1.0, sy=None, sz=None):
        factor = np.array([sx, sx if sy is None else sy, sx if sz is None else sz])
        shape = Shape(self.tris * factor, self.uvs)
        return shape.flipped() if np.prod(factor) < 0 else shape

    def flipped(self):
        uvs = None if self.uvs is None else self.uvs[:, ::-1]
        return Shape(self.tris[:, ::-1], uvs)


def merge(*shapes):
    total = Shape()
    for shape in shapes:
        total = total + shape
    return total


# --- Rings and lofts -----------------------------------------------------------------------

def circle(r, y=0.0, n=12, phase=0.0, cx=0.0, cz=0.0):
    angles = [2 * math.pi * i / n + phase for i in range(n)]
    return np.array([[cx + r * math.cos(a), y, cz - r * math.sin(a)] for a in angles])


def rect(w, d, y=0.0, chamfer=0.0):
    hx, hz = w / 2, d / 2
    if chamfer <= 0:
        return np.array([[hx, y, hz], [hx, y, -hz], [-hx, y, -hz], [-hx, y, hz]])
    c = min(chamfer, hx * 0.95, hz * 0.95)
    return np.array([[hx, y, hz - c], [hx, y, -hz + c], [hx - c, y, -hz], [-hx + c, y, -hz],
                     [-hx, y, -hz + c], [-hx, y, hz - c], [-hx + c, y, hz], [hx - c, y, hz]])


def loft(rings, cap_bottom=True, cap_top=True):
    """Join rings (each (k,3), counter-clockwise from +Y, bottom first) into a closed solid."""
    tris = []
    for a, b in zip(rings, rings[1:]):
        # A single point (cone apex, crystal tip) is spread over the neighbouring ring.
        if len(a) == 1:
            a = np.repeat(a, len(b), axis=0)
        if len(b) == 1:
            b = np.repeat(b, len(a), axis=0)
        k = len(a)
        for i in range(k):
            j = (i + 1) % k
            tris.append([a[i], a[j], b[j]])
            tris.append([a[i], b[j], b[i]])
    if cap_top:
        top = rings[-1]
        centre = top.mean(axis=0)
        tris += [[centre, top[i], top[(i + 1) % len(top)]] for i in range(len(top))]
    if cap_bottom:
        bottom = rings[0]
        centre = bottom.mean(axis=0)
        tris += [[centre, bottom[(i + 1) % len(bottom)], bottom[i]] for i in range(len(bottom))]
    # Degenerate triangles (rings collapsed to a point) are dropped.
    tris = [t for t in tris if np.linalg.norm(np.cross(np.subtract(t[1], t[0]), np.subtract(t[2], t[0]))) > 1e-9]
    return Shape(tris)


def box(w, h, d):
    """Axis-aligned box standing on y = 0, centred on x and z."""
    return loft([rect(w, d, 0), rect(w, d, h)])


def block(w, h, d, bevel=0.03):
    """Box with chamfered vertical and top edges: the chunky painted-prop look."""
    b = min(bevel, w / 4, d / 4, h / 4)
    if b <= 0:
        return box(w, h, d)
    return loft([rect(w - 2 * b, d - 2 * b, 0, b), rect(w, d, b, b), rect(w, d, h - b, b), rect(w - 2 * b, d - 2 * b, h, b)])


def cylinder(r, h, n=12, r_top=None, cap_bottom=True, cap_top=True):
    return loft([circle(r, 0, n), circle(r if r_top is None else r_top, h, n)], cap_bottom, cap_top)


def lathe(profile, n=12, cap_bottom=True, cap_top=True):
    """Revolve [(radius, y), ...] bottom to top around the Y axis."""
    return loft([circle(max(r, 1e-5), y, n) for r, y in profile], cap_bottom, cap_top)


def tube(r_out, r_in, h, n=16):
    """Open ring (a pipe section or a pot rim) standing on y = 0."""
    outer = loft([circle(r_out, 0, n), circle(r_out, h, n)], False, False)
    inner = loft([circle(r_in, 0, n), circle(r_in, h, n)], False, False).flipped()
    top = [[circle(r_out, h, n)[i], circle(r_out, h, n)[(i + 1) % n], circle(r_in, h, n)[(i + 1) % n]] for i in range(n)]
    top += [[circle(r_out, h, n)[i], circle(r_in, h, n)[(i + 1) % n], circle(r_in, h, n)[i]] for i in range(n)]
    return merge(outer, inner, Shape(top), Shape(top).moved(y=-h).flipped())


def torus(r_major, r_minor, n_major=16, n_minor=6):
    tris = []
    def point(i, j):
        a, b = 2 * math.pi * i / n_major, 2 * math.pi * j / n_minor
        rr = r_major + r_minor * math.cos(b)
        return np.array([rr * math.cos(a), r_minor * math.sin(b), -rr * math.sin(a)])
    for i in range(n_major):
        for j in range(n_minor):
            p00, p10, p01, p11 = point(i, j), point(i + 1, j), point(i, j + 1), point(i + 1, j + 1)
            tris += [[p00, p10, p11], [p00, p11, p01]]
    return Shape(tris)


def _triangulate(points):
    """Ear clipping for a simple counter-clockwise polygon in 2D. Returns index triples."""
    idx = list(range(len(points)))
    out = []
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = points[i0], points[i1], points[i2]
            if cross(a, b, c) <= 1e-12:
                continue
            if any(cross(a, b, points[m]) >= 0 and cross(b, c, points[m]) >= 0 and cross(c, a, points[m]) >= 0
                   for m in idx if m not in (i0, i1, i2)):
                continue
            out.append((i0, i1, i2))
            idx.pop(k)
            break
        else:
            break
    if len(idx) == 3:
        out.append(tuple(idx))
    return out


def extrude(points, depth, z0=None):
    """Extrude a counter-clockwise XY polygon along Z, centred on z = 0 unless z0 is given."""
    pts = [tuple(p) for p in points]
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0:
        pts = pts[::-1]
    back, front = (-depth / 2, depth / 2) if z0 is None else (z0, z0 + depth)
    f = [np.array([x, y, front]) for x, y in pts]
    k = [np.array([x, y, back]) for x, y in pts]
    tris = []
    for i0, i1, i2 in _triangulate(pts):
        tris.append([f[i0], f[i1], f[i2]])
        tris.append([k[i0], k[i2], k[i1]])
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        tris += [[k[i], k[j], f[j]], [k[i], f[j], f[i]]]
    return Shape(tris)


def quad(w, h, uv=(0.0, 0.0, 1.0, 1.0)):
    """Rectangle in the XY plane facing +Z, centred, with UVs (u0, v0, u1, v1); v grows downward."""
    u0, v0, u1, v1 = uv
    a, b, c, d = [-w / 2, -h / 2, 0], [w / 2, -h / 2, 0], [w / 2, h / 2, 0], [-w / 2, h / 2, 0]
    return Shape([[a, b, c], [a, c, d]], [[[u0, v1], [u1, v1], [u1, v0]], [[u0, v1], [u1, v0], [u0, v0]]])


def crystal(r, h, sides=5, seed=0, lean=0.0, waist=0.62):
    """A faceted shard: point, widening ring, narrowing ring, tip. Seeded jitter keeps it irregular."""
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, math.pi)
    low = circle(r * 0.55, h * 0.08, sides, ph) * np.array([1, 1, 1])
    mid = circle(r, h * waist * 0.5, sides, ph + 0.3)
    up = circle(r * 0.8, h * waist, sides, ph + 0.15)
    for ring in (low, mid, up):
        ring += rng.uniform(-0.12, 0.12, ring.shape) * r * np.array([1, 0.4, 1])
    tip = np.array([[lean * r, h, 0.0]])
    base = np.array([[0.0, 0.0, 0.0]])
    return loft([base, low, mid, up, tip], cap_bottom=False, cap_top=False)


def chunk(size, seed=0, flat=0.6):
    """An irregular rock/rubble piece: a jittered, chamfered box."""
    rng = np.random.default_rng(seed)
    w, h, d = size
    rings = [rect(w * 0.8, d * 0.8, 0, w * 0.2), rect(w, d, h * 0.45 * flat, w * 0.25), rect(w * 0.7, d * 0.75, h * flat, w * 0.2)]
    for ring in rings:
        ring += rng.uniform(-0.18, 0.18, ring.shape) * np.array([w, 0, d])
    return loft(rings)


# --- Models --------------------------------------------------------------------------------

class Node:
    def __init__(self, name, translation=(0, 0, 0), rotation=(0, 0, 0)):
        self.name, self.translation, self.rotation = name, tuple(translation), tuple(rotation)
        self.geometry = {}  # slot -> Shape
        self.children = []

    def add(self, shape, slot):
        self.geometry[slot] = self.geometry.get(slot, Shape()) + shape
        return self

    def child(self, name, translation=(0, 0, 0), rotation=(0, 0, 0)):
        node = Node(name, translation, rotation)
        self.children.append(node)
        return node


def _quaternion(rx, ry, rz):
    m = _rotation(rx, ry, rz)
    w = math.sqrt(max(0.0, 1 + m[0, 0] + m[1, 1] + m[2, 2])) / 2
    if w < 1e-6:
        # 180 degree turns: fall back to a robust conversion.
        x = math.sqrt(max(0.0, 1 + m[0, 0] - m[1, 1] - m[2, 2])) / 2
        y = math.copysign(math.sqrt(max(0.0, 1 - m[0, 0] + m[1, 1] - m[2, 2])) / 2, m[0, 1] + m[1, 0])
        z = math.copysign(math.sqrt(max(0.0, 1 - m[0, 0] - m[1, 1] + m[2, 2])) / 2, m[0, 2] + m[2, 0])
        return [x, y, z, 0.0]
    return [(m[2, 1] - m[1, 2]) / (4 * w), (m[0, 2] - m[2, 0]) / (4 * w), (m[1, 0] - m[0, 1]) / (4 * w), w]


class Model:
    """A named node tree. save() writes a GLB whose materials are named after their slots."""

    def __init__(self, name):
        self.root = Node(name)

    def save(self, path, colors):
        writer = Writer()
        doc = {"asset": {"version": "2.0", "generator": "Past-Future tools/assets/meshkit.py (original procedural model)"},
               "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [], "meshes": [], "materials": []}
        slots = {}

        def material(slot):
            if slot not in slots:
                r, g, b = colors.get(slot, (0.8, 0.8, 0.8))
                slots[slot] = len(doc["materials"])
                doc["materials"].append({"name": slot, "pbrMetallicRoughness": {
                    "baseColorFactor": [r, g, b, 1.0], "metallicFactor": 0.0, "roughnessFactor": 1.0}})
            return slots[slot]

        def emit(node):
            index = len(doc["nodes"])
            entry = {"name": node.name}
            doc["nodes"].append(entry)
            if any(t != 0 for t in node.translation):
                entry["translation"] = list(map(float, node.translation))
            if any(r != 0 for r in node.rotation):
                entry["rotation"] = _quaternion(*node.rotation)
            primitives = []
            for slot, shape in sorted(node.geometry.items()):
                if len(shape.tris) == 0:
                    continue
                tris = shape.tris
                normals = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
                lengths = np.linalg.norm(normals, axis=1, keepdims=True)
                keep = lengths[:, 0] > 1e-12
                tris, normals = tris[keep], (normals[keep] / lengths[keep])
                positions = tris.reshape(-1, 3)
                flat = np.repeat(normals, 3, axis=0)
                attributes = {"POSITION": writer.add(positions, "VEC3", 5126, 34962, bounds=True),
                              "NORMAL": writer.add(flat, "VEC3", 5126, 34962)}
                if shape.uvs is not None:
                    attributes["TEXCOORD_0"] = writer.add(shape.uvs[keep].reshape(-1, 2), "VEC2", 5126, 34962)
                count = len(positions)
                indices = writer.add(np.arange(count), "SCALAR", 5125 if count > 65535 else 5123, 34963)
                primitives.append({"attributes": attributes, "indices": indices, "material": material(slot)})
            if primitives:
                entry["mesh"] = len(doc["meshes"])
                doc["meshes"].append({"name": node.name, "primitives": primitives})
            children = [emit(child) for child in node.children]
            if children:
                entry["children"] = children
            return index

        emit(self.root)
        writer.save(path, doc)
        return path
