"""The arms race in the manual (0.2.477; the user: "maybe we present a couple power ladders on select units and call it a
day?", then "Last version is good except x axis labels"): three matchups, your unit's power ladder and its corporate
opposite's on one axis, each step every finite level of it (scripts/power_ladder.py's power-ladder.json: damage and
shooting speed research, the best round or the plate, the top rank). Strength is damage a second times health. The
portraits are the manual's own (docs/manual/media/portraits). No number is typed: the ladders' JSON. The caption on
timing is the manual's own, under the figure (manual_qmd.py).

    uv run --with matplotlib python3 -I scripts/power_ladder.py
    uv run --with matplotlib --with numpy python3 -I scripts/ladder_pairs.py
Writes docs/manual/_generated/ladder-pairs.png.
"""
import json, sys, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from matplotlib.ticker import FixedLocator, NullLocator
import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = f"{REPO}/docs/manual/_extensions/lp-manual/fonts"
for f in ("TitilliumWeb-Regular.ttf", "TitilliumWeb-SemiBold.ttf", "TitilliumWeb-Bold.ttf"):
    font_manager.fontManager.addfont(os.path.join(FONTS, f))
plt.rcParams.update({"font.family": "Titillium Web", "font.size": 7, "axes.linewidth": 0.6})
MEDALS = True   # (the portraits beside the names: the user's pick of the two drafts)
J = json.load(open(f"{REPO}/docs/manual/_generated/power-ladder.json"))
mine = {u["unit"]: u for u in J["units"]}
theirs = {(u["corp"], u["unit"]): u for u in J["corporations"]}
CORP = {"serenity": "Kessler-Hayashi", "grubstake": "Grubstake"}
PORTRAIT = {"lp-trooper": "lp-trooper", "lp-battle-tank": "lp-battle-tank", "lp-gun-buggy": "lp-gun-buggy",
            ("serenity", "lp-infantry"): "lp-infantry", ("serenity", "lp-tank"): "lp-tank",
            ("grubstake", "lp-buggy"): "lp-grubstake-buggy"}
PAIRS = [("lp-trooper", ("serenity", "lp-infantry")), ("lp-battle-tank", ("serenity", "lp-tank")),
         ("lp-gun-buggy", ("grubstake", "lp-buggy"))]
SIDE = {"you": "#0072B2", "them": "#D55E00"}
STEPS = ["Trained", "Damage research", "Speed research", "Round or armor", "Top rank"]
ROUND = {"Uranium rounds magazine": "uranium rounds", "Explosive uranium cannon shell": "explosive uranium shells",
         "Piercing rounds magazine": "piercing rounds"}

def portrait(name):
    img = plt.imread(f"{REPO}/docs/manual/media/portraits/{name}.png")[:, :, :3]
    h, w = img.shape[:2]
    yy, xx = np.mgrid[:h, :w]
    mask = ((xx - w / 2) ** 2 + (yy - h / 2) ** 2) <= (min(h, w) / 2) ** 2
    return np.dstack([img, mask.astype(float)])

fig, axes = plt.subplots(1, 3, figsize=(5.4, 2.7), sharey=True)
top = max(max(mine[a]["steps"][-1]["power"], theirs[b]["steps"][-1]["power"]) for a, b in PAIRS)
ticks = [t for t in (1, 3, 10, 30, 100) if t <= top * 2]
for ax, (a, b) in zip(axes, PAIRS):
    for lad, side, dx in ((mine[a], "you", -0.05), (theirs[b], "them", 0.05)):
        st = lad["steps"]
        xs = [i + dx for i in range(len(st))]
        ys = [s["power"] for s in st]
        ax.plot(xs, ys, "-", color=SIDE[side], linewidth=1.8, solid_capstyle="round", zorder=3)
        ax.scatter(xs, ys, s=9, color=SIDE[side], zorder=4, edgecolor="white", linewidth=0.5)
        other = (theirs[b] if side == "you" else mine[a])["steps"][-1]["power"]
        nudge = 0 if abs(np.log(ys[-1] / other)) > 0.25 else (5 if ys[-1] >= other else -5)
        ax.annotate(f"×{ys[-1]:.0f}", (xs[-1], ys[-1]), xytext=(6, nudge), textcoords="offset points",
                    color=SIDE[side], fontsize=8, fontweight="bold", va="center")
        # A flat speed step named, as the round or armor is: lasers take no speed research.
        if st[2]["step"] <= 1.0001 and st[1]["step"] > 1.0001:
            ax.annotate("no speed research", (xs[2], ys[2]), xytext=(2, -13), textcoords="offset points",
                        ha="left", fontsize=6, color=SIDE[side], style="italic")
        s4 = st[3]
        words = (ROUND.get(s4["label"], s4["label"].lower()) if side == "you"
                 else ("armor" if s4["step"] > 1.0001 else "no armor"))
        ax.annotate(words, (xs[3], ys[3]), xytext=(-4, 6) if side == "you" else (5, -8), textcoords="offset points",
                    ha="right" if side == "you" else "left", fontsize=6, color=SIDE[side], style="italic")
    ax.set_yscale("log")
    ax.yaxis.set_major_locator(FixedLocator(ticks))
    ax.yaxis.set_minor_locator(NullLocator())
    ax.set_yticklabels([f"×{t}" for t in ticks])
    ax.set_ylim(0.75, top * 1.5)
    ax.set_xticks(range(5))
    ax.set_xticklabels(STEPS, fontsize=5.8, rotation=35, ha="right", rotation_mode="anchor")
    ax.set_xlim(-0.35, 4.85)
    ax.tick_params(axis="x", length=0, pad=3)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.grid(axis="y", linewidth=0.3, color="#e4e0d8")
    you = f"Your {mine[a]['name'].lower()}"
    them = f"{CORP[b[0]]}'s {theirs[b]['name'].lower()}"
    # The two units named over the panel, yours first; with medals, a small portrait before each name.
    for i, (key, side, label) in enumerate(((a, "you", you), (b, "them", them))):
        y = 1.15 - i * 0.09
        x = 0.1 if MEDALS else 0.02
        if MEDALS:
            pic = PORTRAIT.get(key)
            img = portrait(pic) if pic else np.zeros((760, 760, 4))
            ax.add_artist(AnnotationBbox(OffsetImage(img, zoom=0.0135), (0.035, y), xycoords="axes fraction",
                          frameon=True, annotation_clip=False, bboxprops=dict(boxstyle="circle,pad=0.03",
                          edgecolor=SIDE[side], linewidth=0.9, facecolor="#f2efe8" if not pic else "white")))
        ax.text(x, y, label, transform=ax.transAxes, fontsize=6.3, color=SIDE[side], fontweight="semibold",
                va="center")
axes[0].set_ylabel("Strength: damage a second × health", fontsize=6.2)
fig.subplots_adjust(left=0.08, right=0.95, top=0.8, bottom=0.22, wspace=0.2)
fig.savefig(os.path.join(REPO, "docs", "manual", "_generated", "ladder-pairs.png"), dpi=300)
print("ladder pairs: docs/manual/_generated/ladder-pairs.png")
