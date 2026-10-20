"""Small glTF 2.0 binary reader/writer used by the reproducible character builder.

Requires NumPy. No modeling application or downloaded Python package is invoked.
"""
from pathlib import Path
import json
import struct
import numpy as np

TYPES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPES = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}


class GLB:
    def __init__(self, path):
        raw = Path(path).read_bytes()
        magic, version, length = struct.unpack_from("<III", raw)
        assert magic == 0x46546C67 and version == 2 and length == len(raw)
        offset = 12
        self.binary = b""
        while offset < length:
            count, kind = struct.unpack_from("<I4s", raw, offset)
            payload = raw[offset + 8:offset + 8 + count]
            if kind == b"JSON":
                self.doc = json.loads(payload)
            elif kind == b"BIN\0":
                self.binary = payload
            offset += 8 + count

    def read(self, index):
        accessor = self.doc["accessors"][index]
        view = self.doc["bufferViews"][accessor["bufferView"]]
        dtype = np.dtype(DTYPES[accessor["componentType"]])
        width = TYPES[accessor["type"]]
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width * dtype.itemsize)
        return np.ndarray((accessor["count"], width), dtype=dtype,
                          buffer=self.binary, offset=offset,
                          strides=(stride, dtype.itemsize)).copy()


class Writer:
    def __init__(self):
        self.binary = bytearray()
        self.views = []
        self.accessors = []

    def add(self, values, kind, component=5126, target=None, bounds=False):
        data = np.asarray(values, dtype=DTYPES[component]).reshape(-1, TYPES[kind])
        while len(self.binary) % 4:
            self.binary.append(0)
        view = {"buffer": 0, "byteOffset": len(self.binary), "byteLength": data.nbytes}
        if target is not None:
            view["target"] = target
        self.views.append(view)
        self.binary.extend(data.tobytes())
        accessor = {"bufferView": len(self.views) - 1, "componentType": component,
                    "count": len(data), "type": kind}
        if bounds:
            accessor["min"] = data.min(axis=0).tolist()
            accessor["max"] = data.max(axis=0).tolist()
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def save(self, path, doc):
        doc.update(accessors=self.accessors, bufferViews=self.views,
                   buffers=[{"byteLength": len(self.binary)}])
        js = json.dumps(doc, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        binary = bytes(self.binary) + b"\0" * (-len(self.binary) % 4)
        result = (struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(binary))
                  + struct.pack("<I4s", len(js), b"JSON") + js
                  + struct.pack("<I4s", len(binary), b"BIN\0") + binary)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_bytes(result)


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"]).reshape(4, 4).T
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    matrix = np.eye(4)
    matrix[:3, :3] = np.array([
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]
    ]) @ np.diag(node.get("scale", [1, 1, 1]))
    matrix[:3, 3] = node.get("translation", [0, 0, 0])
    return matrix


def world_matrices(doc):
    result = {}
    def walk(index, parent):
        result[index] = parent @ node_matrix(doc["nodes"][index])
        for child in doc["nodes"][index].get("children", []):
            walk(child, result[index])
    for index in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        walk(index, np.eye(4))
    return result
