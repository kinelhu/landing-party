"""The arms race and the counter matrix, for the manual and the mod page (0.2.475; the user: "Do all viz and we judge
doc in hand").

arms-race.png: for six matchups, the firepower research gives the player's unit and its corporate opposite, by the
player's era. The player's line is every finite damage and shooting speed technology for its weapon whose science packs
are within the era (an era is a tier of packs passed, ops.era; assumed: all of that tier's weapon technologies
researched). The corporation's is its tree's track for that weapon at the highest level its research preset allows:
the base game's level, each category at most the era plus the preset's levels ahead in packs (rd.lua tier_of,
set_level; shared.RESEARCH_AHEAD), normal drawn, very low to very high shaded. Firepower is (1 + damage) x (1 + speed).

counter-matrix.png: the arena's score for each of the player's units against each corporate unit at equal spend, with
no research (docs/arena/results.jsonl) and with both sides at the top of their research (docs/arena/late-best-results.jsonl,
LP_ARENA_TECH=late LP_ARENA_TIER=best).

No number is typed: the dump, shared.lua and the arena's rows. Run scripts/check.sh first (the dump), then:
    uv run --with matplotlib python3 -I scripts/arms_race.py [dump.json]
Writes docs/manual/_generated/arms-race.png, counter-matrix.png and arms-race.json.
"""
import json, os, re, subprocess, sys
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(REPO, "landing-party")
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/Library/Application Support/factorio-lp-check/script-output/data-raw-dump.json")
OUT = os.path.join(REPO, "docs", "manual", "_generated")
d = json.load(open(DUMP))

LUA = r'''
package.path = "./?.lua;" .. package.path
local s = require("shared")
local function dump(v)
  if type(v) == "table" then
    local p = {}
    for k, x in pairs(v) do if type(x) ~= "function" then p[#p + 1] = string.format("%q:%s", tostring(k), dump(x)) end end
    return "{" .. table.concat(p, ",") .. "}"
  elseif type(v) == "string" then return string.format("%q", v)
  elseif type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  return "null"
end
local corps = {}
for id, c in pairs(s.CORPS) do corps[id] = {name = c.name, tree = c.tree, names = c.names} end
print(dump({ahead = s.RESEARCH_AHEAD, corps = corps}))
'''
S = json.loads(subprocess.run(["luajit", "-e", LUA], cwd=MOD, capture_output=True, text=True, check=True).stdout)
AHEAD = S["ahead"]
TREES = {c: [n for n in v["tree"].values()] if isinstance(v["tree"], dict) else v["tree"] for c, v in S["corps"].items()}
CORP_NAME = {"serenity": "Kessler-Hayashi", "grubstake": "Grubstake"}

# Names from the locale (the mod's and the base game's), as power_ladder.py reads them.
names = {}
def read_locale(path):
    sec = None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith("["):
            sec = line.strip("[]")
        elif "=" in line and sec:
            k, v = line.split("=", 1)
            names[(sec, k)] = v
read_locale(os.path.join(MOD, "locale", "en", "locale.cfg"))
def entity(n): return names.get(("entity-name", n), n)

# The base game's ladder for a category: by technology level, the summed damage and speed and the level's science tier
# (the kinds of pack), finite technologies only (rd.lua ladder).
def ladder(cat):
    at = defaultdict(lambda: [0.0, 0.0, 0])
    for t in d["technology"].values():
        if t.get("max_level") == "infinite":
            continue
        m = re.search(r"-(\d+)$", t["name"])
        k = int(m.group(1)) if m else 1
        packs = len((t.get("unit") or {}).get("ingredients") or [])
        for e in t.get("effects") or []:
            if e.get("ammo_category") == cat and e.get("type") in ("ammo-damage", "gun-speed"):
                at[k][0 if e["type"] == "ammo-damage" else 1] += e["modifier"]
                at[k][2] = max(at[k][2], packs)
    return dict(at)

def player_power(cat, era):
    """Firepower from every finite technology for cat whose packs are within the era."""
    dmg = spd = 0.0
    for t in d["technology"].values():
        if t.get("max_level") == "infinite":
            continue
        packs = len((t.get("unit") or {}).get("ingredients") or [])
        if packs > era:
            continue
        for e in t.get("effects") or []:
            if e.get("ammo_category") == cat:
                if e.get("type") == "ammo-damage": dmg += e["modifier"]
                elif e.get("type") == "gun-speed": spd += e["modifier"]
    return (1 + dmg) * (1 + spd)

def track_of(corp, cat):
    for n in TREES[corp]:
        if cat in (n.get("track") or {}).values() if isinstance(n.get("track"), dict) else cat in (n.get("track") or []):
            return n
    return None

def corp_power(corp, cat, era, ahead):
    """Its track for cat at the highest level whose technologies take at most era + ahead kinds of pack."""
    n = track_of(corp, cat)
    if not n:
        return 1.0
    if n.get("step"):
        k = max(0, min(n.get("levels") or 0, era + ahead))
        return 1 + n["step"] * k
    lad = ladder(cat)
    dmg = spd = 0.0
    for k in sorted(lad):
        if lad[k][2] <= era + ahead:
            # (A track without speed, optics since 0.2.476: damage alone.)
            dmg += lad[k][0]; spd += lad[k][1] if n.get("speed") is not False else 0
    return (1 + dmg) * (1 + spd)

def cat_of(unit):
    for t in ("unit", "car", "spider-unit"):
        u = d.get(t, {}).get(unit)
        if u:
            return (u.get("attack_parameters") or {}).get("ammo_category")

# The matchups: the player's unit, the corporation and its unit (each corporation's own prototype name).
MATCHUPS = [("lp-trooper", "serenity", "lp-infantry"), ("lp-rocket-trooper", "serenity", "lp-tank"),
            ("lp-battle-tank", "serenity", "lp-tank"), ("lp-gun-buggy", "grubstake", "lp-buggy"),
            ("lp-breacher", "grubstake", "lp-infantry"), ("lp-flame-trooper", "serenity", "lp-infantry")]
# (Each corporation's prototype of a kind: the default's plain name, another's lp-<corp>-<kind>; shared.variant.)
def variant(corp, kind): return kind if corp == "serenity" else "lp-" + corp + "-" + kind[3:]
def shown_kind(corp, kind):
    own = (S["corps"].get(corp, {}).get("names") or {}).get(kind)
    return entity(own or kind)
ERAS = list(range(0, 8))
LOW, NORMAL, HIGH = AHEAD["very-low"], AHEAD["normal"], AHEAD["very-high"]
panels = []
for pu, corp, cu in MATCHUPS:
    pc, cc = cat_of(pu), cat_of(variant(corp, cu))
    # (Your side from the tiers passed to the next one finished: at era e you are researching tier e + 1.)
    panels.append({"player": pu, "corp": corp, "unit": cu, "unit_name": shown_kind(corp, cu), "player_cat": pc,
                   "corp_cat": cc, "you": [player_power(pc, e) for e in ERAS],
                   "you_next": [player_power(pc, e + 1) for e in ERAS],
                   "them": [corp_power(corp, cc, e, NORMAL) for e in ERAS],
                   "low": [corp_power(corp, cc, e, LOW) for e in ERAS],
                   "high": [corp_power(corp, cc, e, HIGH) for e in ERAS]})
os.makedirs(OUT, exist_ok=True)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FixedLocator, NullLocator
from matplotlib.colors import LinearSegmentedColormap, TwoSlopeNorm

# Colours named for what they encode (Okabe-Ito): the player's side and the corporation's.
SIDE = {"you": "#0072B2", "them": "#D55E00"}
plt.rcParams.update({"font.family": "serif", "font.size": 7, "axes.linewidth": 0.5})
fig, axes = plt.subplots(2, 3, figsize=(5.0, 3.9), sharey=True)
top = max(max(p["you_next"] + p["high"]) for p in panels)
ticks = [t for t in (1, 2, 5, 10, 20) if t <= top * 1.3]
for ax, p in zip(axes.flat, panels):
    ax.fill_between(ERAS, p["low"], p["high"], color=SIDE["them"], alpha=0.16, linewidth=0, step=None)
    ax.plot(ERAS, p["them"], color=SIDE["them"], linewidth=1.5)
    ax.plot(ERAS, p["you_next"], color=SIDE["you"], linewidth=0.9, linestyle=(0, (2.5, 1.5)))
    ax.plot(ERAS, p["you"], color=SIDE["you"], linewidth=1.5)
    ax.set_yscale("log")
    ax.yaxis.set_major_locator(FixedLocator(ticks))
    ax.yaxis.set_minor_locator(NullLocator())
    ax.set_yticklabels([f"×{t}" for t in ticks])
    ax.set_ylim(0.9, top * 1.4)
    ax.set_xticks(ERAS)
    ax.set_xlim(0, ERAS[-1])
    ax.set_title(f"{entity(p['player'])}", fontsize=7, pad=13)
    ax.text(0.5, 1.02, f"against {CORP_NAME[p['corp']]}'s {p['unit_name'].lower()}", transform=ax.transAxes,
            ha="center", va="bottom", fontsize=5.4, color="#555555", style="italic")
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    ax.grid(axis="y", linewidth=0.3, color="#dddddd")
for ax in axes[1]:
    ax.set_xlabel("Your era", fontsize=6.5)
handles = [plt.Line2D([], [], color=SIDE["you"], linewidth=1.5, label="Yours, the tiers you have passed"),
           plt.Line2D([], [], color=SIDE["you"], linewidth=0.9, linestyle=(0, (2.5, 1.5)), label="and the next one finished"),
           plt.Line2D([], [], color=SIDE["them"], linewidth=1.5, label="Theirs, research normal"),
           plt.Rectangle((0, 0), 1, 1, color=SIDE["them"], alpha=0.16, label="research very low to very high")]
fig.legend(handles=handles, loc="lower center", ncol=2, frameon=False, fontsize=6.1)
fig.supylabel("Firepower from research", fontsize=6.5)
fig.tight_layout(rect=(0, 0.08, 1, 1), h_pad=1.0)
fig.savefig(os.path.join(OUT, "arms-race.png"), dpi=300)

# ---- the counter matrix ----
PLAYER = ["trooper", "rocket trooper", "breacher", "flame trooper", "gun buggy", "battle tank"]
PLAYER_PROTO = {"trooper": "lp-trooper", "rocket trooper": "lp-rocket-trooper", "breacher": "lp-breacher",
                "flame trooper": "lp-flame-trooper", "gun buggy": "lp-gun-buggy", "battle tank": "lp-battle-tank"}
def kind_of_label(label):
    m = re.match(r"(.*) \((Serenity|Grubstake)\)$", label)
    base = (m.group(1) if m else label).replace(" ", "-")
    return "lp-" + base, (m.group(2).lower() if m else None)
# Which corporation fields each kind: its base mix or its tree (shared.CORPS).
FIELDS = {"serenity": {"lp-infantry", "lp-tank", "lp-railgunner", "lp-laser-drone"},
          "grubstake": {"lp-infantry", "lp-buggy", "lp-harrier"}}
for corp, tree in TREES.items():
    for n in tree:
        if n.get("unit"):
            FIELDS.setdefault(corp, set()).add(n["unit"]["kind"])
def owner(label):
    kind, corp = kind_of_label(label)
    if corp:
        return corp, kind
    for c in ("serenity", "grubstake"):
        if kind in FIELDS.get(c, set()):
            return c, kind
    return None, kind
def shown(corp, kind):
    own = (S["corps"].get(corp, {}).get("names") or {}).get(kind)
    return entity(own or kind)
def cells(path):
    by = defaultdict(list)
    for line in open(path):
        if line.startswith("{"):
            r = json.loads(line)
            if r.get("kind") == "pair" and r["squad"] in PLAYER and r["against"] not in PLAYER:
                a, b = r["a"], r["b"]
                by[(r["squad"], r["against"])].append(100 * (b["parts_lost"] / b["parts"] - a["parts_lost"] / a["parts"]))
    return {k: sum(v) / len(v) for k, v in by.items()}
early = cells(os.path.join(REPO, "docs", "arena", "results.jsonl"))
late = cells(os.path.join(REPO, "docs", "arena", "late-best-results.jsonl"))
cols = sorted({k[1] for k in late} | {k[1] for k in early})
cols = [c for c in cols if owner(c)[0]]
cols.sort(key=lambda c: (owner(c)[0] != "serenity", shown(*owner(c))))
fig2, axs = plt.subplots(1, 2, figsize=(5.0, 3.9), sharey=True)
# A diverging map from the corporation's colour (they win) to the player's (you win), white even.
cmap = LinearSegmentedColormap.from_list("won_by", [SIDE["them"], "#ffffff", SIDE["you"]])
norm = TwoSlopeNorm(vmin=-100, vcenter=0, vmax=100)
for ax, (title, data) in zip(axs, [("No research", early), ("Both at the top of their research", late)]):
    grid = [[data.get((p, c), float("nan")) for p in PLAYER] for c in cols]
    im = ax.imshow(grid, cmap=cmap, norm=norm, aspect="auto")
    ax.set_xticks(range(len(PLAYER)))
    ax.set_xticklabels([entity(PLAYER_PROTO[p]) for p in PLAYER], rotation=45, ha="right", fontsize=5.6,
                       rotation_mode="anchor")
    ax.set_yticks(range(len(cols)))
    ax.set_yticklabels([shown(*owner(c)) for c in cols], fontsize=5.6)
    ax.set_title(title, fontsize=7)
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    # The corporations apart: a rule between Kessler-Hayashi's units and Grubstake's.
    split = sum(1 for c in cols if owner(c)[0] == "serenity")
    ax.axhline(split - 0.5, color="#555555", linewidth=0.6)
axs[0].text(-0.62, (split - 1) / 2, "Kessler-Hayashi", transform=axs[0].get_yaxis_transform(), rotation=90,
            ha="center", va="center", fontsize=6.3)
axs[0].text(-0.62, split + (len(cols) - split - 1) / 2, "Grubstake", transform=axs[0].get_yaxis_transform(),
            rotation=90, ha="center", va="center", fontsize=6.3)
cb = fig2.colorbar(im, ax=axs, orientation="horizontal", fraction=0.04, pad=0.2, aspect=40)
cb.set_ticks([-100, 0, 100])
cb.set_ticklabels(["they win", "even", "you win"])
cb.ax.tick_params(labelsize=6, length=0)
cb.outline.set_visible(False)
fig2.savefig(os.path.join(OUT, "counter-matrix.png"), dpi=300, bbox_inches="tight")

json.dump({"eras": ERAS, "panels": panels, "matrix": {"columns": cols, "player": PLAYER,
           "early": {f"{p}|{c}": early.get((p, c)) for p in PLAYER for c in cols},
           "late": {f"{p}|{c}": late.get((p, c)) for p in PLAYER for c in cols}}},
          open(os.path.join(OUT, "arms-race.json"), "w"), indent=1)
print(f"arms race: {len(panels)} matchups, eras {ERAS[0]} to {ERAS[-1]}; counter matrix {len(PLAYER)} x {len(cols)}; {OUT}")
