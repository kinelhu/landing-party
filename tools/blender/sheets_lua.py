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
            return (", fans = {width = %d, height = %d, shift = {%r, %r}, frames = %d}" % (f["width"], f["height"], f["shift"][0],
                    f["shift"][1], f["frames"])) if f else ""
        parts = ", ".join('%s = {width = %d, height = %d, shift = {%r, %r}, frames = %d, line_length = %d%s}' % (
            n, v["width"], v["height"], v["shift"][0], v["shift"][1], v["glow_frames"], v["line_length"], fans(v)) for n, v in sorted(g.items()))
        rows.append('  ["%s"] = {%s},' % (key, parts))
    if "sheet.json" in files:
        key = os.path.relpath(d, root).replace(os.sep, "/")
        m = json.load(open(os.path.join(d, "sheet.json")))
        split = ", files = %d, lines_per_file = %d" % (m["files"], m["lines_per_file"]) if "files" in m else ""
        rows.append('  ["%s"] = {width = %d, height = %d, frames = %d, line_length = %d, shift = {%r, %r}%s},' % (
            key, m["width"], m["height"], m["frames"], m["line_length"], m["shift"][0], m["shift"][1], split))
with open(os.path.join(root, "sheets.lua"), "w") as f:
    f.write("-- Written by tools/blender/sheets_lua.py from each sheet.json: frame size, count and shift in tiles.\nreturn {\n")
    f.write("\n".join(rows) + "\n}\n")
print(len(rows), "sheets")
