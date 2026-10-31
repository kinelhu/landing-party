"""The arena's counter heatmap (docs/arena.md, docs/arena/counters.png) from its results (docs/arena/results.jsonl).

    uv run --with matplotlib python3 -I scripts/arena_report.py docs/arena/results.jsonl docs/arena.md

A fight's score for the row's side: the share of the other side's value it destroyed minus the share of its own value it
lost, from -1 (wiped out, nothing taken) to +1 (wiped them out, lost nothing). Value is parts for the corporations'
units (both sides spend about the same) and fighters for a line of turrets or a biter wave. A pair's cell is the mean of
its fights both ways round (row from the west on Serenity's force, then the column there), so the matrix is
antisymmetric and the side and force cancel. Every number in docs/arena.md is computed here; none is typed.
"""
import json, os, re, sys
from collections import defaultdict

# Each kind's class, by its body and its weapon (what decides its fights in the arena): many light bodies firing small
# shots; one weapon that hits several at once (a blast, an arc, a split beam); a heavy hull with flat armour; fliers.
CLASSES = [
    ("small arms", ["laser trooper", "shotgun hand", "heavy laser trooper", "buggy", "slug", "railgunner", "trooper",
                    "rocket trooper"]),
    ("splash", ["sapper", "shock", "laser tank", "lightning tank", "breacher", "flame trooper"]),
    ("armour", ["tank", "heavy tank", "dozer", "walker", "scorcher", "battle tank"]),
    ("air", ["scrap drone", "bomb drone", "laser drone"]),
    # Hard on fliers, light on the ground (2026-10-23): one per side.
    ("anti-air", ["anti-air trooper", "flak buggy", "bred spore"]),
    ("bred", ["bred small", "bred medium", "bred big", "bred behemoth", "bred spitter", "bred burster", "bred stomper"]),
    ("bred on creep", ["bred medium (creep)", "bred big (creep)", "bred spitter (creep)"]),
]
CLASS_OF = {k: c for c, ks in CLASSES for k in ks}
# The batch's labels (tests/lp-arena/batch.lua, internal) as players read them (locale).
SHOWN = {"infantry (Serenity)": "laser trooper", "infantry (Grubstake)": "shotgun hand", "lance": "heavy laser trooper",
         "prism": "laser tank", "tesla": "lightning tank", "aegis": "heavy tank", "skyguard": "anti-air trooper",
         "bred cinder": "bred burster", "harrier": "scrap drone", "scavenger": "bomb drone"}

# Who fields each kind, read from landing-party/shared.lua (a corporation's starting mix and its research tree's units).
# Grubstake's infantry is its own (shotguns), so the two infantries are told apart by their labels.
CORP_COLOUR = {"Kessler-Hayashi": "#2f6f86", "Grubstake": "#b0651a", "You": "#3d7a2a", "Synthexis": "#8a9e00"}
UNSHOWN = {v: k for k, v in SHOWN.items()}
PLAYER = {"trooper", "breacher", "rocket trooper", "flame trooper", "battle tank"}   # priced by command bandwidth (tests/lp-arena/arena.lua)

def fielders():
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "landing-party", "shared.lua")).read()
    g, s = src.index("  grubstake = {"), src.index("  serenity = {")
    e = src.index("\n}\n", s)
    out = {}
    for corp, t in (("Grubstake", src[g:s]), ("Kessler-Hayashi", src[s:e])):
        kinds = set(re.findall(r'"(lp-[a-z-]+)"', "".join(re.findall(r"mix = \{([^}]*)\}", t))))
        kinds |= set(re.findall(r'unit = \{kind = "(lp-[a-z-]+)"', t))
        for k in kinds:
            out.setdefault(k, []).append(corp)
    return out

def corp_of(label, fielded):
    if label in PLAYER:
        return "You"
    if label.startswith("bred "):
        return "Synthexis"
    if label in ("laser trooper", "shotgun hand"):
        return "Kessler-Hayashi" if label == "laser trooper" else "Grubstake"
    if label.startswith("infantry ("):
        return label[len("infantry ("):-1]
    # Back to the kind's id: the batch's label, its spaces hyphens ("flak buggy": lp-flak-buggy).
    who = fielded.get("lp-" + UNSHOWN.get(label, label).replace(" ", "-"), [])
    return who[0] if len(who) == 1 else "both" if who else "-"

def score(r):
    a, b = r["a"], r["b"]
    lost_a = a["parts_lost"] / a["parts"] if a["parts"] else 0
    if r["kind"] in ("pair", "mix"):
        took = b["parts_lost"] / b["parts"] if b["parts"] else 0
    else:
        took = (b["start"] - b["left"]) / b["start"] if b["start"] else 0
    return took - lost_a

def clusters(kinds, M, F, fixed_cols, corp, img):
    """Groups found from the fights alone (the user, 2026-10-21: "should we run some kind of clusterization on each unit
    unsupervised?"): each kind is its row of scores, against every kind and every fixed opponent; average-linkage
    clustering on the distance between rows. Two kinds land together when they beat and lose to the same things. The
    hand-made classes are then compared with the groups at the same count."""
    from scipy.cluster.hierarchy import linkage, dendrogram, fcluster
    import matplotlib.pyplot as plt
    X = [[M.get((a, b), 0) for b in kinds] + [F.get((a, c), 0) for c in fixed_cols] for a in kinds]
    Z = linkage(X, method="average", metric="euclidean")
    fig, ax = plt.subplots(figsize=(8, 0.32 * len(kinds) + 1.6), dpi=130)
    labels = [f"{a} ({CLASS_OF[a]})" for a in kinds]
    dendrogram(Z, labels=labels, orientation="right", ax=ax, color_threshold=0, above_threshold_color="#555555")
    for lab in ax.get_yticklabels():
        k = lab.get_text().rsplit(" (", 1)[0]
        lab.set_color(CORP_COLOUR.get(corp[k], "black"))
    ax.set_xlabel("distance between two kinds' rows of scores (x100 scale: 1.0 is a 100-point gap in one fight)", fontsize=8)
    ax.set_title("Units grouped by whom they beat and lose to, from the arena alone\n(label: kind (hand-made class); "
                 "Kessler-Hayashi teal, Grubstake amber, you green, Synthexis olive)", fontsize=9)
    ax.tick_params(axis="y", labelsize=8)
    fig.tight_layout()
    fig.savefig(img)
    n = len(CLASSES)
    cut = fcluster(Z, n, criterion="maxclust")
    clusters.of = dict(zip(kinds, cut))
    groups = {}
    for k, c in zip(kinds, cut):
        groups.setdefault(c, []).append(k)
    L = ["## Groups found from the fights alone", "",
         "Each kind is its row of scores (against every kind and every fixed opponent); kinds are joined by average "
         "linkage on the distance between rows, so two kinds land together when they beat and lose to the same things "
         f"(`scripts/arena_report.py`, scipy). Cut into {n} groups, as many as the hand-made classes:", "",
         "![Clusters](arena/clusters.png)", "", "| Group | Kinds (hand-made class) |", "|---|---|"]
    for i, (c, ks) in enumerate(sorted(groups.items(), key=lambda x: -len(x[1])), 1):
        L.append(f"| {i} | " + ", ".join(f"{k} ({CLASS_OF[k]})" for k in ks) + " |")
    L.append("")
    return L

FACTIONS = ["Kessler-Hayashi", "Grubstake", "Synthexis", "You"]

def factions(kinds, M, corp, cluster_of, img):
    """Faction against faction (the user, 2026-10-23: "faction metrics, computed by clustering unit counter metrics per
    faction matchup"), from the unit matrix. A faction's roster: the kinds it fields (from landing or its tree; a kind
    both corporations field counts for both; Synthexis's breeds, on creep too). For X against Y:
    answer, the mean over Y's kinds of X's best score against each (can X answer whatever Y fields?);
    coverage, the share of Y's kinds X has a hard counter for (a kind of X scoring +50 or more on it);
    exposure, the share of X's kinds Y hard-counters. Breadth: how many of the fight-made groups X's roster spans."""
    import matplotlib.pyplot as plt
    from matplotlib.colors import TwoSlopeNorm
    roster = {f: [k for k in kinds if corp[k] == f or (corp[k] == "both" and f in ("Kessler-Hayashi", "Grubstake"))]
              for f in FACTIONS}
    def best(X, b): return max(M.get((a, b), -1) for a in X)
    def answer(X, Y): return sum(best(X, b) for b in Y) / len(Y)
    def coverage(X, Y): return sum(1 for b in Y if best(X, b) >= 0.5) / len(Y)
    groups = {f: len({cluster_of[k] for k in roster[f]}) for f in FACTIONS}
    fig, ax = plt.subplots(figsize=(6.4, 4.6), dpi=130)
    grid = [[answer(roster[x], roster[y]) if x != y else float("nan") for y in FACTIONS] for x in FACTIONS]
    ax.imshow(grid, cmap=plt.get_cmap("RdBu"), norm=TwoSlopeNorm(vmin=-1, vcenter=0, vmax=1))
    for i, x in enumerate(FACTIONS):
        for j, y in enumerate(FACTIONS):
            if x != y:
                v = grid[i][j]
                ax.text(j, i, f"{round(100 * v):+d}\ncovers {round(100 * coverage(roster[x], roster[y]))}%", ha="center",
                        va="center", fontsize=8, color="white" if abs(v) > 0.6 else "black")
    ax.set_xticks(range(len(FACTIONS))); ax.set_xticklabels(FACTIONS, fontsize=8); ax.xaxis.tick_top()
    ax.set_yticks(range(len(FACTIONS)))
    ax.set_yticklabels([f"{f} ({len(roster[f])} kinds, {groups[f]} groups)" for f in FACTIONS], fontsize=8)
    for lab, f in zip(ax.get_yticklabels(), FACTIONS): lab.set_color(CORP_COLOUR[f])
    for lab, f in zip(ax.get_xticklabels(), FACTIONS): lab.set_color(CORP_COLOUR[f])
    ax.set_title("Faction against faction: the row's best answer to each of the column's kinds, averaged\n"
                 "(and the share of them it has a counter scoring +50 for)", fontsize=8.5)
    fig.tight_layout()
    fig.savefig(img)
    L = ["## Faction against faction", "",
         "From the unit matrix, each faction's roster (the kinds it fields from landing or its tree; a kind both "
         "corporations field counts for both; Synthexis's breeds on creep too). **Answer**: for each of the other "
         "side's kinds, the row's best score against it, averaged: can it answer whatever the other fields? "
         "**Coverage**: the share of the other side's kinds it has a counter scoring +50 or more for. **Exposure**: the "
         "share of its own kinds the other side has such a counter for. **Breadth**: how many of the groups found from "
         "the fights alone (above) its roster spans.", "",
         "![Factions](arena/factions.png)", "",
         "| Row against column | Answer | Coverage | Exposure | Their answer | Edge |", "|---|---|---|---|---|---|"]
    for x in FACTIONS:
        for y in FACTIONS:
            if x == y: continue
            X, Y = roster[x], roster[y]
            a, them = answer(X, Y), answer(Y, X)
            L.append(f"| {x} against {y} | {round(100 * a):+d} | {round(100 * coverage(X, Y))}% | "
                     f"{round(100 * coverage(Y, X))}% | {round(100 * them):+d} | {round(100 * (a - them)):+d} |")
    L += ["", "| Faction | Kinds | Breadth (groups of " + str(len(set(cluster_of.values()))) + ") | Roster |", "|---|---|---|---|"]
    for f in FACTIONS:
        L.append(f"| {f} | {len(roster[f])} | {groups[f]} | " + ", ".join(roster[f]) + " |")
    L.append("")
    return L

def export_counters(M, F, kinds, fixed_cols, path):
    """The counter matrix for the game (landing-party/counters.lua; the faction AI's composition, step 5): for each own
    unit kind, its score against each foe kind and against each line and the biters, -1 to 1, from these fights. Labels
    are mapped to prototypes by tests/lp-arena/batch.lua; a kind fielded under two labels (the infantries) keeps each
    under its own prototype, and a foe column is keyed by kind."""
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "lp-arena", "batch.lua")).read()
    proto = dict(re.findall(r'\{"([^"]+)", "(lp-[a-z-]+)"', src))
    def kind(p):
        m = re.match(r"lp-(?:grubstake|serenity)-(.*)", p)
        return "lp-" + m.group(1) if m else p
    line_key = {"guns": "gun-turret", "lasers": "laser-turret", "flamers": "flamethrower-turret", "teslas": "tesla-turret",
                "biters 0.80": "biter"}
    # (The report shows plain names: back to the batch's labels.)
    def raw(label):
        return UNSHOWN.get(label, label).replace("(Kessler-Hayashi)", "(Serenity)")
    out = {}
    for a in kinds:
        # (On creep is a breed's home ground, not what it is bred as.)
        if raw(a) not in proto or "(creep)" in a:
            continue
        row = {}
        for b in kinds:
            if raw(b) in proto and "(creep)" not in b and (a, b) in M:
                row.setdefault(kind(proto[raw(b)]), []).append(M[(a, b)])
        for c in fixed_cols:
            if c in line_key and (a, c) in F:
                row[line_key[c]] = [F[(a, c)]]
        out.setdefault(proto[raw(a)], {}).update({k: sum(v) / len(v) for k, v in row.items()})
    L = ["-- Written by scripts/arena_report.py from docs/arena/results.jsonl: each own unit's score (-1 to 1) against each",
         "-- foe kind, line and the biters, from the arena's fights. Never edit by hand; regenerate with the arena.",
         "return {"]
    for p_ in sorted(out):
        cells = ", ".join(f'["{k}"] = {v:.2f}' for k, v in sorted(out[p_].items()))
        L.append(f'  ["{p_}"] = {{{cells}}},')
    L.append("}")
    open(path, "w").write("\n".join(L) + "\n")
    print(f"wrote {path}: {len(out)} units")


def main():
    src, out = sys.argv[1], sys.argv[2]
    rows = [json.loads(l) for l in open(src) if l.strip()]
    # The names players see: Serenity's internal id stays in the batch's labels (the user renamed it, 2026-10-21).
    # Its units' plain names too (the user, 2026-10-23: "calling a heavy tank a heavy tank"), and the burster's.
    for r in rows:
        for k in ("squad", "against"):
            r[k] = SHOWN.get(r[k], r[k]).replace("(Serenity)", "(Kessler-Hayashi)")
    # Mixed arms (batch.lua's MIXES): scored for the all-ground army, whichever side it fought on.
    mixes = defaultdict(list)
    for r in rows:
        if r["kind"] == "mix":
            mixes[r["against"]].append(score(r) if not r.get("flip") else -score(r))
    # The breach (batch.lua's BREACH): the same spend at a walled gun line, apart from the matrix.
    breach = defaultdict(list)
    for r in rows:
        if r["kind"] == "breach":
            breach[r["squad"]].append(r)
    rows = [r for r in rows if r["kind"] not in ("mix", "breach")]
    kinds, cost = [], {}
    for r in rows:
        if r["squad"] not in kinds: kinds.append(r["squad"])
        if r["a"]["start"]: cost[r["squad"]] = round(r["a"]["parts"] / r["a"]["start"])
    pair = defaultdict(list)
    fixed = defaultdict(list)
    fixed_cols = []
    for r in rows:
        s = score(r)
        if r["kind"] == "pair":
            pair[(r["squad"], r["against"])].append(s)
            pair[(r["against"], r["squad"])].append(-s)
        else:
            fixed[(r["squad"], r["against"])].append(s)
            if r["against"] not in fixed_cols: fixed_cols.append(r["against"])
    order_fixed = [c for c in ["biters 0.50", "biters 0.80", "biters 0.95", "guns", "lasers", "flamers", "teslas"] if c in fixed_cols]
    M = {(a, b): sum(v) / len(v) for (a, b), v in pair.items()}
    F = {(a, c): sum(v) / len(v) for (a, c), v in fixed.items()}
    strength = {k: sum(M.get((k, o), 0) for o in kinds) / len(kinds) for k in kinds}
    unclassed = [k for k in kinds if k not in CLASS_OF]
    assert not unclassed, f"give these a class in CLASSES: {unclassed}"
    rank = {c: i for i, (c, _) in enumerate(CLASSES)}
    order = sorted(kinds, key=lambda k: (rank[CLASS_OF[k]], -strength[k]))
    fielded = fielders()
    corp = {k: corp_of(k, fielded) for k in kinds}
    rounds = max(r["round"] for r in rows)

    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    from matplotlib.colors import TwoSlopeNorm
    counter_scale = plt.get_cmap("RdBu")   # blue: the row's unit wins; red: it loses
    names = {"biters 0.50": "biters\nevo 0.5", "biters 0.80": "biters\nevo 0.8", "biters 0.95": "biters\nevo 0.95",
             "guns": "6 gun\nturrets", "lasers": "4 laser\nturrets", "flamers": "3 flamers\n+ 2 guns",
             "teslas": "3 tesla\nturrets"}
    n, m = len(order), len(order_fixed)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(0.62 * (n + m) + 4, 0.5 * n + 2.6), dpi=130,
                                   gridspec_kw={"width_ratios": [n, m]})
    norm = TwoSlopeNorm(vmin=-1, vcenter=0, vmax=1)
    for ax, cols, get, title in ((ax1, order, lambda a, b: M.get((a, b)), "against each other (equal spend)"),
                                 (ax2, order_fixed, lambda a, c: F.get((a, c)), "against biters and your lines")):
        grid = [[get(a, c) if get(a, c) is not None else float("nan") for c in cols] for a in order]
        ax.imshow(grid, cmap=counter_scale, norm=norm, aspect="auto")
        for i, a in enumerate(order):
            for j, c in enumerate(cols):
                v = grid[i][j]
                if v == v:
                    ax.text(j, i, f"{round(100 * v)}", ha="center", va="center", fontsize=6.5,
                            color="white" if abs(v) > 0.6 else "black")
        ax.set_xticks(range(len(cols)))
        ax.set_xticklabels([names.get(c, c) for c in cols], rotation=90 if ax is ax1 else 0, fontsize=7.5)
        ax.xaxis.tick_top()
        ax.set_yticks(range(n))
        ax.set_yticklabels([f"{corp[a]} {CLASS_OF[a]}: {a} ({cost.get(a, '?')})" for a in order] if ax is ax1 else [], fontsize=8)
        for lab, k in zip(ax.get_yticklabels(), order if ax is ax1 else []):
            lab.set_color(CORP_COLOUR.get(corp[k], "black"))
        if ax is ax1:
            for lab, k in zip(ax.get_xticklabels(), cols):
                lab.set_color(CORP_COLOUR.get(corp[k], "black"))
        for i in range(1, n):
            if CLASS_OF[order[i]] != CLASS_OF[order[i - 1]]:
                ax.axhline(i - 0.5, color="black", lw=1.6)
                if ax is ax1: ax.axvline(i - 0.5, color="black", lw=1.6)
        ax.set_xlabel(title, fontsize=9, labelpad=8)
        ax.xaxis.set_label_position("bottom")
    fig.suptitle("Landing Party: who counters whom (row against column; blue, the row wins; red, it loses). "
                 "Names coloured by side: Kessler-Hayashi teal, Grubstake amber, you green, Synthexis olive", fontsize=10, y=0.995)
    fig.text(0.01, 0.005, f"Score: share of the other side destroyed minus share of its own lost (x100). Price in parts in "
             f"brackets; yours at 10 parts per command bandwidth. {len(rows)} fights, {rounds} rounds, no research. scripts/arena.sh", fontsize=7)
    fig.tight_layout(rect=(0, 0.02, 1, 0.97))
    img = os.path.join(os.path.dirname(out), "arena", "counters.png")
    fig.savefig(img)

    L = ["# The arena: who counters whom (generated)", "",
         f"Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` ({len(rows)} fights, {rounds} rounds; "
         "`scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.", "",
         "![Counter heatmap](arena/counters.png)", "",
         "Each unit kind fights each other at equal spend (as near as whole units allow, about 420 parts a side), both "
         "ways round, and a 420-part squad of it meets three biter waves of 20 and three of your lines (no research). "
         "A cell is the row's score: the share of the other side it destroyed minus the share of its own value it lost, "
         "from -100 (wiped out, took nothing) to +100. Rows are grouped by class (below), strongest first within each.", "",
         "## Classes", "",
         "A class is a body and a weapon: **small arms** (many light bodies, small shots), **splash** (one weapon "
         "that hits several at once: a blast, an arc, a split beam), **armour** (a heavy hull whose flat resistance "
         "eats small shots), **air** (fliers: only weapons that can shoot up touch them; `docs/units.md` says which). "
         "The class against class score is "
         "the mean of its kinds' cells.", "",
         "| Row against column | " + " | ".join(c for c, _ in CLASSES) + " |", "|---|" + "---|" * len(CLASSES)]
    for c, ks in CLASSES:
        cells = []
        for d, ls in CLASSES:
            v = [M[(a, b)] for a in ks for b in ls if a != b and (a, b) in M]
            cells.append(f"{round(100 * sum(v) / len(v)):+d}" if v else "")
        L.append(f"| {c} | " + " | ".join(cells) + " |")
    L += ["",
         "## Each kind's counters", "",
         "| Kind (price) | Beats most (its score) | Beaten most by (their score) |", "|---|---|---|"]
    for a in order:
        others = [(b, M[(a, b)]) for b in kinds if b != a and (a, b) in M]
        best = sorted(others, key=lambda x: -x[1])[:3]
        worst = sorted(others, key=lambda x: x[1])[:3]
        fmt = lambda xs, sign: ", ".join(f"{b} ({round(100 * sign * v)})" for b, v in xs)
        L.append(f"| {a} ({cost.get(a, '?')}) | {fmt(best, 1)} | {fmt(worst, -1)} |")
    L.append("")
    L += clusters(order, M, F, order_fixed, corp, os.path.join(os.path.dirname(out), "arena", "clusters.png"))
    export_counters(M, F, kinds, fixed_cols, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "landing-party", "counters.lua"))
    L += factions(order, M, corp, clusters.of, os.path.join(os.path.dirname(out), "arena", "factions.png"))
    if mixes:
        L += ["## Mixed arms: does a flier soak a ground army's fire?", "",
              "A ground army against the same spend with part of it in fliers, both ways round. Ground-only weapons "
              "cannot hurt a flier; a unit whose shot is aimed at one is turned to a ground target it can hurt "
              "(`landing-party/scripts/aim.lua`). The score is the all-ground army's.", "",
              "| Mix | All-ground army's score | Fights |", "|---|---|---|"]
        for label, v in mixes.items():
            L.append(f"| {label} | {round(100 * sum(v) / len(v)):+d} | {len(v)} |")
        L.append("")
    if breach:
        L += ["## The breach: bursters among other biters at a wall", "",
              "The same spend sent at gun turrets behind a wall two deep (`tests/lp-arena/batch.lua`, BREACH), as plain "
              "biters and with part of it in bursters. A burster bursts where it dies: alone it is shot short of the "
              "wall; among others it reaches it. Ranges over the rounds.", "",
              "| Wave | Spend | Won | Turrets broken | Wall pieces broken | Units lost |", "|---|---|---|---|---|---|"]
        def span(v):
            return f"{min(v)}" if min(v) == max(v) else f"{min(v)} to {max(v)}"
        # In batch.lua's order (results come in the order fights end).
        src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "lp-arena", "batch.lua")).read()
        listed = re.findall(r'^\s*\{"([^"]+)", \{\{"lp-bred', src.split("local BREACH = {", 1)[1].split("\n}\n", 1)[0], re.M)
        for label, rs in sorted(breach.items(), key=lambda x: listed.index(x[0]) if x[0] in listed else 99):
            tur = [sum(n for t, n in (r["b"].get("lost") or {}).items() if t.endswith("turret")) for r in rs]
            wal = [(r["b"].get("lost") or {}).get("wall", 0) for r in rs]
            lost = [r["a"]["start"] - r["a"]["left"] for r in rs]
            won = sum(1 for r in rs if r["winner"] == "a")
            L.append(f"| {label} | {rs[0]['a']['parts']} | {won} of {len(rs)} | {span(tur)} | {span(wal)} | {span(lost)} of {rs[0]['a']['start']} |")
        L.append("")
    open(out, "w").write("\n".join(L))
    print(f"wrote {out} and {img}: {len(rows)} fights")

if __name__ == "__main__":
    main()
