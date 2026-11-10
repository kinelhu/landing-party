"""Every sheet.json under landing-party/graphics to one Lua table, graphics/sheets.lua, which data.lua reads: a sheet's
frame size and shift are written once, by the tool that made it, and a re-render needs no number typed again.

    python3 tools/blender/sheets_lua.py
"""
import json, os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "landing-party", "graphics")
rows = []
for d, _, files in sorted(os.walk(root)):
    if "gun.json" in files:                     # kh_guns.py's: every layer of the gun, by name
        key = os.path.relpath(d, root).replace(os.sep, "/")
        g = json.load(open(os.path.join(d, "gun.json")))
        parts = ", ".join('%s = {width = %d, height = %d, shift = {%r, %r}}' % (n, v["width"], v["height"], v["shift"][0], v["shift"][1])
                          for n, v in sorted(g.items()))
        rows.append('  ["%s"] = {%s},' % (key, parts))
    if "dirs.json" in files:                    # cannon_sheets.py's: a sheet set a direction
        key = os.path.relpath(d, root).replace(os.sep, "/")
        g = json.load(open(os.path.join(d, "dirs.json")))
        def fans(v):
            f = v.get("fans")
            out = (", fans = {width = %d, height = %d, shift = {%r, %r}, frames = %d}" % (f["width"], f["height"], f["shift"][0],
                   f["shift"][1], f["frames"])) if f else ""
            b = v.get("barrel")
            if b:
                out += ", barrel = {width = %d, height = %d, shift = {%r, %r}}" % (b["width"], b["height"], b["shift"][0], b["shift"][1])
            return out
        parts = ", ".join('%s = {width = %d, height = %d, shift = {%r, %r}, frames = %d, line_length = %d%s}' % (
            n, v["width"], v["height"], v["shift"][0], v["shift"][1], v["glow_frames"], v["line_length"], fans(v)) for n, v in sorted(g.items()))
        # (A combinator's wire posts, posts.json: player_buildings.py projects their tips.)
        if "posts.json" in files:
            pj = json.load(open(os.path.join(d, "posts.json")))
            def pt(v): return "{%r, %r}" % (v[0], v[1])
            parts += ", posts = {" + ", ".join("%s = {wire = {red = %s, green = %s}, shadow = {red = %s, green = %s}}" % (
                n, pt(v["red"]["wire"]), pt(v["green"]["wire"]), pt(v["red"]["shadow"]), pt(v["green"]["shadow"]))
                for n, v in sorted(pj.items())) + "}"
        rows.append('  ["%s"] = {%s},' % (key, parts))
    if "sheet.json" in files:
        key = os.path.relpath(d, root).replace(os.sep, "/")
        m = json.load(open(os.path.join(d, "sheet.json")))
        split = ", files = %d, lines_per_file = %d" % (m["files"], m["lines_per_file"]) if "files" in m else ""
        # (A pole's wire points, posts.json beside its sheet: faction_works.py projects its insulators' tips.)
        if "posts.json" in files:
            pj = json.load(open(os.path.join(d, "posts.json")))
            def pt(v): return "{%r, %r}" % (v[0], v[1])
            split += ", posts = {" + ", ".join("%s = {%s}" % (k, ", ".join("%s = %s" % (c, pt(v)) for c, v in sorted(pj[k].items())))
                                               for k in ("wire", "shadow")) + "}"
        rows.append('  ["%s"] = {width = %d, height = %d, frames = %d, line_length = %d, shift = {%r, %r}%s},' % (
            key, m["width"], m["height"], m["frames"], m["line_length"], m["shift"][0], m["shift"][1], split))
with open(os.path.join(root, "sheets.lua"), "w") as f:
    f.write("-- Written by tools/blender/sheets_lua.py from each sheet.json: frame size, count and shift in tiles.\nreturn {\n")
    f.write("\n".join(rows) + "\n}\n")
print(len(rows), "sheets")
