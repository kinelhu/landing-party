"""The book prints each picture once. Run after a PDF render (it reads the kept .tex):

    python3 -I docs/manual/check_images.py            (from the repository, or give the .tex's path)

Counts every image the rendered booklet includes, by where it is set, and fails (exit 1) on:
  - a picture set twice: a hero, plan, strip frame, still or cover vista in more than one place;
  - a unit portrait on more than one card, more than one tree node or the back cover twice (a portrait is meant for its
    card and its tree node, and the back cover's four stand for their factions);
  - a picture in media/ the book never prints (a dead file), or one in a retired folder (media/clips, media/units).
Written for the user's note on the 2026-11 draft: "some screenshots are reused a lot it seems?"
"""
import os, re, sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
tex_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "Landing-Party.tex")
tex = open(tex_path, encoding="utf-8").read()
MEDIA = os.path.join(HERE, "media")
RETIRED = ("media/clips/", "media/units/")


def rel(p):
    p = p.strip()
    if os.path.isabs(p):
        p = os.path.relpath(p, HERE)
    return p.replace(os.sep, "/")


IMG = r"([^{}\s]*media/[^{}\s]+\.(?:png|jpg))"
uses = defaultdict(Counter)  # path -> where -> count
for m in re.finditer(r"\\begin\{lpunit\}\{[^{}]*\}\{[^{}]*\}\{[^{}]*\}\{" + IMG + r"\}", tex):
    uses[rel(m.group(1))]["card"] += 1
for m in re.finditer(r"\\lpcoverstrip\{[^{}]*\}\{" + IMG + r"\}", tex):
    uses[rel(m.group(1))]["cover"] += 1
for m in re.finditer(r"\\lpbackfaction\{[^{}]*\}\{" + IMG + r"\}", tex):
    uses[rel(m.group(1))]["back"] += 1
for m in re.finditer(r"\\includegraphics\[width=11\.6mm,height=11\.6mm\]\{" + IMG + r"\}", tex):
    uses[rel(m.group(1))]["tree node"] += 1
for m in re.finditer(r"\\includegraphics\[width=7\.4mm\]\{" + IMG + r"\}", tex):
    uses[rel(m.group(1))]["tree column"] += 1

# Everything else: openers, plans, strip frames, figures. Every mention of a media path, less those counted above.
every = Counter(rel(m.group(1)) for m in re.finditer(IMG, tex))
for p, n in every.items():
    rest = n - sum(uses[p].values())
    if rest > 0:
        uses[p]["page"] += rest

bad = []
for p, where in sorted(uses.items()):
    if p.startswith(RETIRED):
        bad.append(f"{p}: in a retired folder")
    if p.startswith("media/portraits/"):
        for w in ("card", "tree node", "back"):
            if where[w] > 1:
                bad.append(f"{p}: {where[w]} times as a {w}")
        if where["page"] or where["cover"]:
            bad.append(f"{p}: a portrait set as a picture ({dict(where)})")
    elif sum(where.values()) > 1:
        bad.append(f"{p}: printed {sum(where.values())} times ({', '.join(f'{k} {v}' for k, v in where.items())})")

on_disk = set()
for root, _, files in os.walk(MEDIA):
    for f in files:
        if f.endswith((".png", ".jpg")):
            on_disk.add(rel(os.path.join(root, f)))
for p in sorted(on_disk - set(uses)):
    bad.append(f"{p}: in media/ but the book never prints it")
for p in sorted(set(uses) - on_disk):
    bad.append(f"{p}: printed but not in media/")

kinds = Counter(p.split("/")[1] for p in uses)
print(f"check_images: {len(uses)} pictures in {sum(every.values())} placements "
      f"read from {os.path.basename(tex_path)}; by folder: " + ", ".join(f"{k} {v}" for k, v in sorted(kinds.items())))
if bad:
    print("check_images: FAILED\n  " + "\n  ".join(bad))
    sys.exit(1)
print("check_images: no picture repeats, none unused")
