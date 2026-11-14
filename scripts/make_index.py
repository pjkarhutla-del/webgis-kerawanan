"""Membuat data/kawasan_index.json (nama + bbox) untuk fitur pencarian kawasan."""
import json
import pathlib
import sys

src, dst = sys.argv[1], sys.argv[2]
cfg_path = pathlib.Path(__file__).resolve().parent.parent / "config.json"
cfg = json.load(open(cfg_path, encoding="utf-8"))
field = (cfg.get("kawasan") or {}).get("namaField", "")

fc = json.load(open(src, encoding="utf-8"))
feats = fc.get("features", [])


def walk(c, b):
    if c and isinstance(c[0], (int, float)):
        b[0] = min(b[0], c[0]); b[1] = min(b[1], c[1])
        b[2] = max(b[2], c[0]); b[3] = max(b[3], c[1])
    else:
        for i in c:
            walk(i, b)


def get_name(props):
    for k, v in props.items():
        if k.lower() == field.lower() and v not in (None, ""):
            return str(v)
    return None


boxes = {}
for f in feats:
    geom = f.get("geometry")
    name = get_name(f.get("properties") or {})
    if not geom or not name:
        continue
    b = [180.0, 90.0, -180.0, -90.0]
    walk(geom["coordinates"], b)
    if name in boxes:
        o = boxes[name]
        boxes[name] = [min(o[0], b[0]), min(o[1], b[1]), max(o[2], b[2]), max(o[3], b[3])]
    else:
        boxes[name] = b

if not boxes and feats:
    print(f"PERINGATAN: kolom '{field}' tidak ditemukan. Kolom tersedia:",
          ", ".join((feats[0].get("properties") or {}).keys()))
    print("Ubah kawasan.namaField di config.json lalu build ulang agar pencarian aktif.")

out = [{"n": n, "b": [round(x, 5) for x in b]} for n, b in sorted(boxes.items())]
with open(dst, "w", encoding="utf-8") as fh:
    json.dump(out, fh, ensure_ascii=False, separators=(",", ":"))
print(f"kawasan_index.json: {len(out)} kawasan")
