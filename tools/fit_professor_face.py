"""Seat the professor's facial details on the actual skin and eye triangles.

Coordinates are model space: Y up, +Z forward. Each part supplies name,
vertices (N x 3 NumPy array), and faces (M x 3 indices). Fitting preserves X/Y,
topology, skin weights, and the previous recessed forehead details.
"""
import numpy as np


class FrontSurface:
    """Frontmost triangle intersection at a point in the model's X/Y plane."""

    def __init__(self, parts):
        triangles = np.concatenate([p["vertices"][p["faces"]] for p in parts])
        a, b, c = triangles.transpose(1, 0, 2)
        denom = (b[:,1]-c[:,1])*(a[:,0]-c[:,0]) + (c[:,0]-b[:,0])*(a[:,1]-c[:,1])
        valid = np.abs(denom) > 1e-14
        self.a, self.b, self.c = a[valid], b[valid], c[valid]
        self.denom = denom[valid]
        self.minimum = triangles[valid].min(axis=1)[:, :2] - 1e-9
        self.maximum = triangles[valid].max(axis=1)[:, :2] + 1e-9

    def at(self, vertices):
        depths = []
        for x, y in vertices[:, :2]:
            candidate = ((self.minimum[:,0] <= x) & (x <= self.maximum[:,0]) &
                         (self.minimum[:,1] <= y) & (y <= self.maximum[:,1]))
            a, b, c, den = self.a[candidate], self.b[candidate], self.c[candidate], self.denom[candidate]
            u = ((b[:,1]-c[:,1])*(x-c[:,0]) + (c[:,0]-b[:,0])*(y-c[:,1])) / den
            v = ((c[:,1]-a[:,1])*(x-c[:,0]) + (a[:,0]-c[:,0])*(y-c[:,1])) / den
            w = 1-u-v
            inside = (u >= -1e-7) & (v >= -1e-7) & (w >= -1e-7)
            if not np.any(inside):
                raise ValueError(f"Facial detail lies outside its supporting surface at {x}, {y}")
            depths.append(np.max((u*a[:,2] + v*b[:,2] + w*c[:,2])[inside]))
        return np.asarray(depths)


def ring_depth(vertices, sides, radius, center=0.0):
    """Canonical shallow cross-section, independent of previous fitted Z values."""
    count = len(vertices)-2
    if count % sides:
        raise ValueError("Unexpected facial feature topology")
    rings = count // sides
    radii = np.broadcast_to(np.asarray(radius), (rings,))
    result = np.concatenate([(radii[:,None] * np.cos(np.arange(sides)*2*np.pi/sides)).ravel(), [0,0]])
    return result + center


def fit_face_details(parts):
    head = next(p for p in parts if p["name"] == "Skin / rounded jaw cheeks forehead")
    skin = FrontSurface([head])
    report = []
    # First fit both eyes; the catchlights then use their new surfaces.
    for part in parts:
        name, vertices = part["name"], part["vertices"]
        relief = None
        if name.startswith("Face / brown oval eye"):
            rows = vertices[:-2].reshape(-1,28,3)
            rx = np.ptp(rows[:,:,0], axis=1) / 2
            relief = ring_depth(vertices, 28, rx*(.022/.037)*.60, -.003)
        elif name.startswith("Face / thick sculpted brow"):
            relief = ring_depth(vertices, 14, .014*.50, .001)
        elif name.startswith("Face / closed mouth"):
            relief = ring_depth(vertices, 10, .003*.45, -.00005)
        elif name.startswith("Face / guarded lower lip"):
            relief = ring_depth(vertices, 10, .0026*.45)
        elif name.startswith("Face / crow's foot"):
            relief = ring_depth(vertices, 10, .0016*.45)
        elif name.startswith("Face / tired lower eyelid"):
            relief = ring_depth(vertices, 10, .0018*.45)
        elif name.startswith("Beard / short moustache"):
            relief = ring_depth(vertices, 12, np.array([.003,.004,.001])*.65)
        if relief is None:
            continue
        vertices[:,2] = skin.at(vertices) + relief
        if name.startswith("Face / thick sculpted brow"):
            triangles = vertices[part["faces"]] - vertices.mean(axis=0)
            volume = np.einsum("ij,ij->i", triangles[:,0], np.cross(triangles[:,1],triangles[:,2])).sum()/6
            if volume < 0:
                part["faces"] = part["faces"][:,::-1].copy()
        report.append({"name": name, "min_offset": float(relief.min()), "max_offset": float(relief.max())})
    eyes = FrontSurface([p for p in parts if p["name"].startswith("Face / brown oval eye")])
    for part in parts:
        if part["name"].startswith("Face / subtle eye catchlight"):
            vertices = part["vertices"]
            rows = vertices[:-2].reshape(-1,12,3)
            rx = np.ptp(rows[:,:,0], axis=1) / 2
            relief = ring_depth(vertices, 12, rx*.125, -.0001)
            vertices[:,2] = eyes.at(vertices) + relief
            report.append({"name": part["name"], "min_offset": float(relief.min()), "max_offset": float(relief.max())})
    return report


def fit_authored_face(character):
    parts, offsets = [], {}
    for part in character.parts:
        color = part["material"]
        face_start = offsets.get(color,0)
        offsets[color] = face_start + part["triangles"]
        if not (part["name"].startswith(("Face /", "Beard / short moustache")) or
                part["name"] == "Skin / rounded jaw cheeks forehead"):
            continue
        start = part["vertex_start"]
        g = character.geometry[color]
        parts.append({"name": part["name"], "vertices": np.asarray(g["vertices"][start:start+part["vertex_count"]]),
                      "faces": np.asarray(g["faces"][face_start:offsets[color]])-start,
                      "face_start": face_start, "original": part})
    report = fit_face_details(parts)
    for part in parts:
        original = part["original"]
        start = original["vertex_start"]
        character.geometry[original["material"]]["vertices"][start:start+original["vertex_count"]] = part["vertices"].tolist()
        face_start = part["face_start"]
        character.geometry[original["material"]]["faces"][face_start:face_start+original["triangles"]] = (part["faces"]+start).tolist()
    return report
