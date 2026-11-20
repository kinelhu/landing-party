"""A corporation's research over a game, for the Kessler-Hayashi chapter (0.2.475): scenario `research` (tests/lp-sim)
records each minute its tracks' levels and caps, its labs standing and the player's era; this draws them.

    scripts/sim.sh research 12345 160      (writes docs/sim/research-12345/research.jsonl)
    cp docs/sim/research-12345/research.jsonl docs/manual/data/research-timeline.jsonl
    uv run --with matplotlib python3 -I scripts/research_timeline.py

Each track's level a step line, its cap (the highest level the player's era allows it, rd.lua tier_of) dotted, the
stretches with no Optics lab standing shaded, the player's era along the top. No number is typed: the run's rows.
Writes docs/manual/_generated/research-timeline.png.
"""
import json, os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "docs", "manual", "data", "research-timeline.jsonl")
OUT = os.path.join(REPO, "docs", "manual", "_generated")
rows = [json.loads(l) for l in open(SRC) if l.strip()]
assert rows, f"no rows in {SRC}"

# The tracks as the manual names them (the locale's node names would be the corporation's voice: plain words here).
TRACKS = {"optics": "Lasers (Optics lab)", "ordnance": "Tank shells (Armory)", "railguns": "Railguns (Siege works)"}

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Colours named for what they encode (Okabe-Ito): one per track.
TRACK_COLOURS = {"optics": "#D55E00", "ordnance": "#0072B2", "railguns": "#009E73"}
plt.rcParams.update({"font.family": "serif", "font.size": 7, "axes.linewidth": 0.5})
fig, ax = plt.subplots(figsize=(5.0, 2.4))
mins = [r["minute"] for r in rows]
# Stretches with no Optics lab standing.
dark, start = [], None
for r in rows:
    down = (r.get("labs") or {}).get("lp-optics-lab", 0) == 0
    if down and start is None:
        start = r["minute"]
    if not down and start is not None:
        dark.append((start, r["minute"])); start = None
if start is not None:
    dark.append((start, mins[-1]))
marks = []
for i, (a, b) in enumerate(dark):
    ax.axvspan(a, b, color="#888888", alpha=0.14, linewidth=0)
    # (The first stretch is before its first Optics lab; any later one, a lab destroyed.)
    words = "before its first Optics lab" if i == 0 and a <= mins[0] else "its Optics lab destroyed"
    marks.append((words, a, b))
shown = []
for key, label in TRACKS.items():
    lv = [((r.get("tracks") or {}).get(key) or {}).get("level", 0) for r in rows]
    cap = [((r.get("tracks") or {}).get(key) or {}).get("cap", 0) for r in rows]
    if max(cap) == 0 and max(lv) == 0:
        continue
    c = TRACK_COLOURS[key]
    ax.step(mins, cap, where="post", color=c, linewidth=0.8, linestyle=(0, (1.5, 1.5)))
    ax.step(mins, lv, where="post", color=c, linewidth=1.6)
    shown.append((key, label))
ax.set_xlim(mins[0], mins[-1])
ax.set_ylim(0, max(max(((r.get("tracks") or {}).get(k) or {}).get("cap", 0) for r in rows) for k, _ in shown) + 0.8)
# (Placed once the scale is set: the first stretch's words centred in it under the caps, a later one's beside it.)
top_y = ax.get_ylim()[1]
for words, a, b in marks:
    if b - a > 20:
        ax.text((a + b) / 2, top_y * 0.62, words, fontsize=5.4, color="#555555", ha="center", va="center")
    else:
        ax.text(b + 1, top_y * 0.72, words, fontsize=5.4, color="#555555", ha="left", va="center")
ax.set_xlabel("Minutes", fontsize=6.5)
ax.set_ylabel("Level", fontsize=6.5)
for side in ("top", "right"):
    ax.spines[side].set_visible(False)
ax.grid(axis="y", linewidth=0.3, color="#dddddd")
# The player's era along the top, where it changes.
prev = None
for r in rows:
    if r["era"] != prev:
        ax.text(r["minute"], ax.get_ylim()[1], f"era {r['era']}", fontsize=5.4, color="#555555", va="bottom", ha="left")
        ax.axvline(r["minute"], color="#cccccc", linewidth=0.4)
        prev = r["era"]
handles = [plt.Line2D([], [], color=TRACK_COLOURS[k], linewidth=1.6, label=l) for k, l in shown]
handles += [plt.Line2D([], [], color="#555555", linewidth=0.8, linestyle=(0, (1.5, 1.5)), label="its cap at your era"),
            plt.Rectangle((0, 0), 1, 1, color="#888888", alpha=0.14, label="no Optics lab standing")]
fig.legend(handles=handles, loc="lower center", ncol=3, frameon=False, fontsize=6)
fig.tight_layout(rect=(0, 0.13, 1, 0.95))
os.makedirs(OUT, exist_ok=True)
fig.savefig(os.path.join(OUT, "research-timeline.png"), dpi=300)
print(f"research timeline: {len(rows)} minutes, {len(shown)} tracks, {len(dark)} stretches without an Optics lab")
