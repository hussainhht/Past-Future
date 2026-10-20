"""Shared helpers for the environment asset tools.

Standard library only. NumPy is imported lazily for model bounds (already a project dependency).
Nothing here executes code from downloaded archives: zip members are only read as bytes.
"""
from datetime import date
from pathlib import Path, PurePosixPath
import hashlib
import json
import os
import re
import stat
import struct
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ENV = ROOT / "assets" / "environment"
SOURCES = ENV / "licenses" / "sources.json"
ARCHIVES = ENV / "source" / "_archives"
INCOMING = ENV / "source" / "_incoming"
MODELS = ENV / "models"

sys.path.insert(0, str(ROOT / "tools"))

MODEL_SUFFIXES = {".glb", ".gltf", ".fbx", ".obj", ".dae", ".blend", ".3ds", ".ply", ".stl", ".usd", ".usdz"}
TEXTURE_SUFFIXES = {".png", ".jpg", ".jpeg", ".tga", ".webp", ".bmp", ".tif", ".tiff", ".dds", ".exr", ".hdr"}
# Godot 4.3+ imports these without an external converter; GLB is still preferred for single-file portability.
GODOT_DIRECT = {".glb", ".gltf", ".fbx", ".obj", ".dae"}
# PROJECT-ORIGINAL marks assets the project generated itself (tools/assets/build_lab_props.py).
ALLOWED_LICENSES = {"CC0-1.0", "CC-BY-4.0", "PROJECT-ORIGINAL"}
LIMITS = {"archive_bytes": 600 << 20, "unpacked_bytes": 2 << 30, "entries": 20000, "ratio": 200}
VERIFIED_STATES = ("VERIFIED", "SEARCH_CORROBORATED", "LICENSE_UNVERIFIED")


def sha256_file(path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def today() -> str:
    return date.today().isoformat()


def load_sources(path=SOURCES) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def save_sources(data: dict, path=SOURCES) -> None:
    path = Path(path)
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(temp, path)


def pack_by_id(data: dict, pack_id: str) -> dict:
    for pack in data["packs"]:
        if pack["id"] == pack_id:
            return pack
    raise KeyError(f"No entry '{pack_id}' in sources.json")


def clean_member(name: str):
    """A safe relative POSIX path for a zip member, or None if it could escape the destination."""
    if not name or "\x00" in name:
        return None
    normalized = name.replace("\\", "/")
    path = PurePosixPath(normalized)
    if path.is_absolute() or re.match(r"^[A-Za-z]:", normalized) or ".." in path.parts:
        return None
    return path


def is_link(info: zipfile.ZipInfo) -> bool:
    return stat.S_ISLNK(info.external_attr >> 16)


def audit_zip(archive) -> dict:
    """Describe a zip without extracting anything. `problems` is empty for a safe, intact archive."""
    problems, entries = [], []
    archive = Path(archive)
    if archive.stat().st_size > LIMITS["archive_bytes"]:
        problems.append(f"archive larger than {LIMITS['archive_bytes'] >> 20} MB")
    if not zipfile.is_zipfile(archive):
        return {"entries": [], "problems": ["not a readable zip archive"], "unpacked": 0, "packed": archive.stat().st_size}
    unpacked = packed = 0
    with zipfile.ZipFile(archive) as zf:
        infos = zf.infolist()
        if len(infos) > LIMITS["entries"]:
            problems.append(f"{len(infos)} entries exceeds the {LIMITS['entries']} limit")
        broken = zf.testzip()
        if broken:
            problems.append(f"CRC failure in '{broken}'")
        for info in infos:
            safe = clean_member(info.filename) is not None and not is_link(info)
            if not safe:
                problems.append(f"unsafe entry '{info.filename}'")
            if not info.is_dir():
                unpacked += info.file_size
                packed += info.compress_size
            entries.append({"name": info.filename, "size": info.file_size, "packed": info.compress_size,
                            "crc": info.CRC, "dir": info.is_dir(), "safe": safe})
    if unpacked > LIMITS["unpacked_bytes"]:
        problems.append(f"{unpacked >> 20} MB unpacked exceeds the {LIMITS['unpacked_bytes'] >> 20} MB limit")
    if packed and unpacked / packed > LIMITS["ratio"]:
        problems.append(f"compression ratio {unpacked / packed:.0f}:1 looks like a zip bomb")
    return {"entries": entries, "problems": problems, "unpacked": unpacked, "packed": packed}


def safe_extract(archive, dest, only=None):
    """Extract safe regular files into dest. Never overwrites a differing file. Returns (written, skipped)."""
    dest = Path(dest).resolve()
    written, skipped = [], []
    with zipfile.ZipFile(archive) as zf:
        for info in zf.infolist():
            if info.is_dir() or (only is not None and info.filename not in only):
                continue
            relative = clean_member(info.filename)
            if relative is None or is_link(info):
                skipped.append((info.filename, "unsafe path or link"))
                continue
            target = (dest / relative).resolve()
            if dest not in target.parents:
                skipped.append((info.filename, "escapes destination"))
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = target.with_name(target.name + ".part")
            remaining = info.file_size
            with zf.open(info) as source, open(temp, "wb") as out:
                for block in iter(lambda: source.read(1 << 20), b""):
                    remaining -= len(block)
                    if remaining < 0:
                        out.close()
                        temp.unlink()
                        raise ValueError(f"'{info.filename}' is larger than its header declares")
                    out.write(block)
            if target.exists() and sha256_file(target) != sha256_file(temp):
                temp.unlink()
                skipped.append((info.filename, "a different file already exists"))
                continue
            os.replace(temp, target)
            written.append(target)
    return written, skipped


def parse_glb(data: bytes):
    """Return (json document, binary chunk) for a GLB held in memory, or raise ValueError."""
    if len(data) < 20:
        raise ValueError("too short to be a GLB")
    magic, version, length = struct.unpack_from("<III", data)
    if magic != 0x46546C67:
        raise ValueError("bad GLB magic")
    if version != 2:
        raise ValueError(f"unsupported GLB version {version}")
    if length != len(data):
        raise ValueError(f"header says {length} bytes but file has {len(data)}")
    offset, doc, binary = 12, None, b""
    while offset + 8 <= length:
        size, kind = struct.unpack_from("<I4s", data, offset)
        payload = data[offset + 8:offset + 8 + size]
        if len(payload) != size:
            raise ValueError("truncated chunk")
        if kind == b"JSON":
            doc = json.loads(payload)
        elif kind == b"BIN\0":
            binary = payload
        offset += 8 + size
    if doc is None:
        raise ValueError("no JSON chunk")
    return doc, binary


def model_stats(doc: dict) -> dict:
    """Counts, material/texture info and world-space bounds for a glTF document."""
    import numpy as np
    from gltf_tools import world_matrices

    accessors, meshes = doc.get("accessors", []), doc.get("meshes", [])
    triangles = vertices = primitives = 0
    for mesh in meshes:
        for primitive in mesh.get("primitives", []):
            primitives += 1
            position = accessors[primitive["attributes"]["POSITION"]]
            vertices += position["count"]
            if primitive.get("mode", 4) == 4:
                count = accessors[primitive["indices"]]["count"] if "indices" in primitive else position["count"]
                triangles += count // 3
    low, high = np.full(3, np.inf), np.full(3, -np.inf)
    warnings = []
    world = world_matrices(doc) if doc.get("scenes") else {}
    for index, node in enumerate(doc.get("nodes", [])):
        if "mesh" not in node or index not in world:
            continue
        for primitive in meshes[node["mesh"]].get("primitives", []):
            position = accessors[primitive["attributes"]["POSITION"]]
            if "min" not in position or "max" not in position:
                warnings.append("POSITION accessor has no min/max; bounds are incomplete")
                continue
            lo, hi = position["min"], position["max"]
            corners = np.array([[x, y, z, 1.0] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
            points = (world[index] @ corners.T).T[:, :3]
            low, high = np.minimum(low, points.min(axis=0)), np.maximum(high, points.max(axis=0))
    has_bounds = bool(np.isfinite(low).all())
    images = doc.get("images", [])
    external = [image["uri"] for image in images if "uri" in image and not image["uri"].startswith("data:")]
    return {
        "meshes": len(meshes), "primitives": primitives, "vertices": vertices, "triangles": triangles,
        "materials": len(doc.get("materials", [])), "images": len(images), "external_images": external,
        "min": [round(float(v), 4) for v in low] if has_bounds else None,
        "max": [round(float(v), 4) for v in high] if has_bounds else None,
        "size": [round(float(v), 4) for v in high - low] if has_bounds else None,
        "generator": doc.get("asset", {}).get("generator", ""), "warnings": warnings,
    }


def human_bytes(count: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if count < 1024 or unit == "GB":
            return f"{count:.0f} {unit}" if unit == "B" else f"{count:.1f} {unit}"
        count /= 1024
    return f"{count:.1f} GB"
