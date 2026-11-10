"""Poly Haven models (CC0) for kitbashing: each asset's 1k .blend and the textures it references, into <dir>/<asset>/.

    python3 tools/blender/polyhaven_get.py <dir> asset [asset ...]
"""
import json, os, sys, urllib.request

out, assets = sys.argv[1], sys.argv[2:]
UA = {"User-Agent": "landing-party-asset-fetch"}
def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
for a in assets:
    d = os.path.join(out, a)
    os.makedirs(d, exist_ok=True)
    files = json.loads(get(f"https://api.polyhaven.com/files/{a}"))
    b = files["blend"]["1k"]["blend"]
    open(os.path.join(d, os.path.basename(b["url"])), "wb").write(get(b["url"]))
    for rel, f in (b.get("include") or {}).items():
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        if not os.path.exists(p):
            open(p, "wb").write(get(f["url"]))
    print(a, "ok", len(b.get("include") or {}), "textures")
