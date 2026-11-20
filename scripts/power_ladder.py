"""The power ladder: how each of the player's units grows stronger, step by step, for the manual's Reference.

Each panel is one unit. Its line climbs from the unit as trained (1) through what multiplies it: damage research and
shooting speed research for its weapon's ammunition category (every finite level, read from the technologies' effects
in the dump), its best round (ammunition tiers: the round's direct damage over the base round's, or its named rung,
raised to shared.TIER_EXP, as command.lua computes it), and the top veterancy rank (shared.RANK, the ranks in
veterancy.lua). Strength is damage a second times health, so a rank's health counts as much as its damage. No number is
typed: every step is read from the dump, shared.lua or veterancy.lua.

Run scripts/check.sh first (it dumps the prototypes), then:
    uv run --with matplotlib python3 -I scripts/power_ladder.py [dump.json]
Writes docs/manual/_generated/power-ladder.png and power-ladder.json (the steps, for the manual's text and the mod page).
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
print(dump({raw = s.TIER_RAW, exp = s.TIER_EXP, order_tiers = s.ORDER_TIERS, orders = s.ORDERS, rank = s.RANK, corps = corps}))
'''
S = json.loads(subprocess.run(["luajit", "-e", LUA], cwd=MOD, capture_output=True, text=True, check=True).stdout)
vet = open(os.path.join(MOD, "scripts", "veterancy.lua")).read()
m = re.search(r"veterancy\.RANKS = \{(.*?)\}\n", vet, re.S)
assert m, "veterancy.RANKS not found"
TOP_RANK = m.group(1).count("quality =")
assert TOP_RANK > 0, "no ranks in veterancy.RANKS"

# The base game's and the mod's names (the locale files), for the labels.
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
APP = None
for line in open(os.path.join(REPO, "scripts", "env.sh")):
    mm = re.match(r'APP="?([^"]+)"?', line.strip())
    if mm:
        APP = os.path.expandvars(mm.group(1).replace("$HOME", os.path.expanduser("~")))
for p in [os.path.join(MOD, "locale", "en", "locale.cfg")] + (
        [os.path.join(APP, "data", "base", "locale", "en", "base.cfg")] if APP else []):
    if os.path.exists(p):
        read_locale(p)
def item_name(n): return names.get(("item-name", n)) or names.get(("entity-name", n)) or n
def unit_name(n): return names.get(("entity-name", n)) or n

# Research by ammunition category: the sum of every finite level's modifier (an infinite technology's levels aside).
research = defaultdict(lambda: {"ammo-damage": 0.0, "gun-speed": 0.0})
for t in d["technology"].values():
    if t.get("max_level") == "infinite":
        continue
    for e in t.get("effects") or []:
        if e.get("type") in ("ammo-damage", "gun-speed") and e.get("ammo_category"):
            research[e["ammo_category"]][e["type"]] += e["modifier"]

# Each unit's best round (ammunition tiers), as command.lua's ladder.
direct = d["mod-data"]["lp-ammo-direct"]["data"]
best = {}
for item, tier in S["order_tiers"].items():
    base_order = tier["base"]
    unit = S["orders"][base_order]
    if tier.get("replaces"):   # (a capsule's rung: the cluster grenade, named)
        base_round = tier["replaces"]
    else:
        cat = d["ammo"][tier["round"]]["ammo_category"]
        base_round = next(i["name"] for i in d["recipe"][base_order]["ingredients"]
                          if i["name"] in d["ammo"] and d["ammo"][i["name"]]["ammo_category"] == cat)
    raw = S["raw"].get(tier["round"]) or direct[tier["round"]] / direct[base_round]
    f = raw ** S["exp"]
    if f > best.get(unit, (None, 1.0))[1]:
        best[unit] = (tier["round"], f)

UNITS = ["lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-gun-buggy", "lp-flame-trooper", "lp-battle-tank"]
rank_power = (1 + S["rank"]["damage"] * TOP_RANK) * (1 + S["rank"]["health"] * TOP_RANK)
ladders = []
for u in UNITS:
    cat = d["unit"][u]["attack_parameters"]["ammo_category"]
    r = research[cat]
    steps = [("Trained", "base", 1.0)]
    steps.append(("Damage research", "research", 1 + r["ammo-damage"]))
    steps.append(("Shooting speed research", "research", 1 + r["gun-speed"]))
    rd, rf = best.get(u, (None, 1.0))
    steps.append((item_name(rd) if rd else "No better round", "round", rf))
    steps.append((f"Rank {TOP_RANK}", "rank", rank_power))
    total, cum = 1.0, []
    for label, kind, mult in steps:
        total *= mult
        cum.append({"label": label, "kind": kind, "step": round(mult, 4), "power": round(total, 4)})
    ladders.append({"unit": u, "name": unit_name(u), "category": cat, "steps": cum})
# The corporations' units (0.2.475, the arms race): trained, their tree's track for their weapon at its top (the base
# game's finite levels, damage then speed, as rd.lua's ladder; railguns their own step), the plate their tree gives
# them (its resistance to the damage it answers against the unplated one's, as health), and the top rank.
def lst(x): return list(x.values()) if isinstance(x, dict) else (x or [])
def tree_of(corp): return lst(S["corps"][corp]["tree"])
def variant(corp, kind): return kind if corp == "serenity" else "lp-" + corp + "-" + kind[3:]
def proto(name):
    for t in ("unit", "car", "spider-unit"):
        if name in d.get(t, {}):
            return d[t][name]
CORP_NAME = {"serenity": "Kessler-Hayashi", "grubstake": "Grubstake"}
CORP_UNITS = [("serenity", "lp-infantry"), ("serenity", "lp-tank"), ("serenity", "lp-railgunner"),
              ("grubstake", "lp-infantry"), ("grubstake", "lp-buggy"), ("grubstake", "lp-sapper")]
corp_ladders = []
for corp, kind in CORP_UNITS:
    u = proto(variant(corp, kind))
    cat = u["attack_parameters"]["ammo_category"]
    track = next((n for n in tree_of(corp) if cat in lst(n.get("track"))), None)
    dmg = spd = 0.0
    if track and track.get("step"):
        dmg = track["step"] * (track.get("levels") or 0)
    elif track:
        r = research[cat]
        dmg, spd = r["ammo-damage"], r["gun-speed"]
    plate = next((n for n in tree_of(corp) if kind in (n.get("plates") or {})), None)
    pf = 1.0
    if plate:
        ptype = plate["plates"][kind]
        def pct(p):
            return next((x.get("percent", 0) for x in (p or {}).get("resistances") or [] if x["type"] == ptype), 0) / 100
        pf = (1 - pct(u)) / (1 - pct(proto(variant(corp, kind) + "-" + ptype)))
    steps = [("Trained", "base", 1.0), ("Damage research", "research", 1 + dmg),
             ("Shooting speed research", "research", 1 + spd), ("Plate", "round", pf), (f"Rank {TOP_RANK}", "rank", rank_power)]
    total, cum = 1.0, []
    for label, k, mult in steps:
        total *= mult
        cum.append({"label": label, "kind": k, "step": round(mult, 4), "power": round(total, 4)})
    own = (S["corps"][corp].get("names") or {}).get(kind)
    corp_ladders.append({"unit": kind, "corp": corp, "name": unit_name(own or kind), "category": cat, "steps": cum,
                         "plate": plate["plates"][kind] if plate else None})
os.makedirs(OUT, exist_ok=True)
json.dump({"top_rank": TOP_RANK, "units": ladders, "corporations": corp_ladders},
          open(os.path.join(OUT, "power-ladder.json"), "w"), indent=1)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FixedLocator, NullLocator

# Colours named for what they encode (Okabe-Ito): what bought each step.
SOURCE_COLOURS = {"base": "#000000", "research": "#0072B2", "round": "#E69F00", "rank": "#009E73"}
plt.rcParams.update({"font.family": "serif", "font.size": 7, "axes.linewidth": 0.5})
LADDERS_ALL = ladders + corp_ladders


def draw(group, path, words, subtitle):
    fig, axes = plt.subplots(2, 3, figsize=(5.0, 3.5), sharey=True)
    # (One scale for both figures: the player's and the corporations' ladders read against each other.)
    top = max(l["steps"][-1]["power"] for l in LADDERS_ALL)
    ticks = [t for t in (1, 3, 10, 30, 100, 300) if t <= top * 1.5]
    for ax, lad in zip(axes.flat, group):
        st = lad["steps"]
        for i in range(1, len(st)):
            y0, y1 = st[i - 1]["power"], st[i]["power"]
            gains = st[i]["step"] > 1.0001
            # (A step that buys nothing, grey and dashed: no research reaches that weapon, no better round or plate.)
            ax.plot([i - 1, i], [y0, y1], color=SOURCE_COLOURS[st[i]["kind"]] if gains else "#bbbbbb",
                    linewidth=1.6 if gains else 0.9, linestyle="-" if gains else (0, (2, 2)), solid_capstyle="round")
            if gains:
                ax.text(i - 0.5, (y0 * y1) ** 0.5 / 1.25, f"×{st[i]['step']:.2g}", ha="left", va="top", fontsize=5.5,
                        color=SOURCE_COLOURS[st[i]["kind"]])
        ax.plot(range(len(st)), [s_["power"] for s_ in st], "o", color="#000000", markersize=1.8)
        ax.text(len(st) - 1, st[-1]["power"] * 1.25, f"×{st[-1]['power']:.0f}", ha="center", va="bottom", fontsize=7,
                fontweight="bold")
        ax.set_yscale("log")
        ax.yaxis.set_major_locator(FixedLocator(ticks))
        ax.yaxis.set_minor_locator(NullLocator())
        ax.set_yticklabels([f"×{t}" for t in ticks])
        ax.set_ylim(0.8, top * 2.6)
        ax.set_xlim(-0.3, len(st) - 0.7)
        ax.set_xticks(range(len(st)))
        labels = []
        for s_ in st:
            if s_["kind"] == "research":
                labels.append(s_["label"].replace(" research", "").replace("Shooting speed", "Speed"))
            elif s_["kind"] == "round":
                labels.append(words["round_tick"])
            else:
                labels.append(s_["label"])
        ax.set_xticklabels(labels, fontsize=5.3, rotation=35, ha="right", rotation_mode="anchor")
        ax.set_title(lad["name"], fontsize=7.5, pad=9)
        ax.text(0.5, 1.0, subtitle(lad), transform=ax.transAxes, ha="center", va="bottom", fontsize=5.2,
                color="#666666", style="italic")
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)
        ax.grid(axis="y", linewidth=0.3, color="#dddddd")
    handles = [plt.Line2D([], [], color=c, linewidth=1.6, label=words[k]) for k, c in SOURCE_COLOURS.items() if k != "base"]
    fig.legend(handles=handles, loc="lower center", ncol=3, frameon=False, fontsize=6.5)
    fig.supylabel("Strength against the unit as trained", fontsize=6.5)
    fig.tight_layout(rect=(0, 0.05, 1, 1), h_pad=1.6)
    fig.savefig(path, dpi=300)
    return top


def player_sub(lad):
    r = next(s_ for s_ in lad["steps"] if s_["kind"] == "round")
    return r["label"] if r["step"] > 1.0001 else "no better round"


top = draw(ladders, os.path.join(OUT, "power-ladder.png"),
           {"research": "Research", "round": "Better round", "round_tick": "Round", "rank": "Veterancy"}, player_sub)
draw(corp_ladders, os.path.join(OUT, "corp-ladder.png"),
     {"research": "Research", "round": "Plate", "round_tick": "Plate", "rank": "Veterancy"},
     lambda lad: CORP_NAME[lad["corp"]] + ("" if lad["plate"] else ", no plate"))
print(f"power ladder: {len(ladders)} units, {len(corp_ladders)} corporate units, top rank {TOP_RANK}, strongest x{top:.0f}; {OUT}")
