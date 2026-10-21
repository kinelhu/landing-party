"""The arena's balance table (docs/arena.md) from its results (docs/arena/results.jsonl, scripts/arena.sh).

    python3 -I scripts/arena_report.py docs/arena/results.jsonl docs/arena.md

Each matchup was fought in several rounds; a cell gives the squad's wins out of the rounds and what it lost, as a share
of the parts it was bought with (the squads' spend differs a little: whole units of a 420-part budget). Every number in
docs/arena.md is computed here from the results; nothing is typed in by hand.
"""
import json, sys
from collections import defaultdict

def load(path):
    rows = [json.loads(l) for l in open(path) if l.strip()]
    by = defaultdict(list)
    for r in rows: by[(r["kind"], r["squad"], r["against"])].append(r)
    return rows, by

def pct(x): return f"{round(100 * x)}%"

def cell(rs, side="a"):
    wins = sum(1 for r in rs if r["winner"] == side)
    spent = sum(r[side]["parts"] for r in rs)
    lost = sum(r[side]["parts_lost"] for r in rs)
    return wins, len(rs), (lost / spent if spent else 0)

def squads(rows, kind):
    seen = []
    for r in rows:
        if r["kind"] == kind and r["squad"] not in seen: seen.append(r["squad"])
    return seen

def main():
    src, out = sys.argv[1], sys.argv[2]
    rows, by = load(src)
    rounds = max(r["round"] for r in rows)
    L = []
    L.append("# The arena: what the corporations' units buy (generated)")
    L.append("")
    L.append(f"Written by `scripts/arena_report.py` from `docs/arena/results.jsonl` ({len(rows)} fights, {rounds} rounds; "
             "`scripts/arena.sh` fights them headless, `tests/lp-arena/batch.lua` says which). Do not edit by hand.")
    L.append("")
    L.append("Each squad is bought with 420 parts at the corporation's own prices (`shared.units`), in whole units, so a "
             "Tesla squad is 4 (340 parts) and an infantry squad 42. A cell: the squad's wins out of the rounds, then the "
             "share of its parts it lost (over all rounds). Nobody has research: no damage or speed bonuses on either "
             "side. The squads attack; a line of yours or a biter wave waits or meets them.")
    L.append("")
    # Biters.
    bs = squads(rows, "biters")
    evos = sorted({r["against"] for r in rows if r["kind"] == "biters"}, key=lambda a: float(a.split()[1]))
    if bs:
        L.append("## Against a biter wave")
        L.append("")
        L.append("Twenty biters and spitters, the spawners' own mix at that evolution (half from each kind of spawner).")
        L.append("")
        L.append("| Squad | " + " | ".join("evolution " + e.split()[1] for e in evos) + " |")
        L.append("|---|" + "---|" * len(evos))
        for sq in bs:
            cells = []
            for e in evos:
                rs = by.get(("biters", sq, e), [])
                if not rs: cells.append("-"); continue
                w, n, lost = cell(rs)
                cells.append(f"{w}/{n}, lost {pct(lost)}")
            L.append(f"| {sq} | " + " | ".join(cells) + " |")
        L.append("")
    # Defences.
    ds = squads(rows, "defence")
    lines = [("guns", "6 gun turrets, piercing rounds"), ("lasers", "4 laser turrets"), ("flamers", "3 flamethrower turrets and 2 gun turrets")]
    if ds:
        L.append("## Against a line of yours")
        L.append("")
        L.append("Each line behind a wall of 29 stone walls, no research. A cell: wins out of the rounds (the line destroyed), "
                 "parts lost, and the mean time to break the line where it was broken.")
        L.append("")
        L.append("| Squad | " + " | ".join(d for _, d in lines) + " |")
        L.append("|---|" + "---|" * len(lines))
        for sq in ds:
            cells = []
            for k, _ in lines:
                rs = by.get(("defence", sq, k), [])
                if not rs: cells.append("-"); continue
                w, n, lost = cell(rs)
                won = [r["seconds"] for r in rs if r["winner"] == "a"]
                t = f", {round(sum(won) / len(won))} s" if won else ""
                cells.append(f"{w}/{n}, lost {pct(lost)}{t}")
            L.append(f"| {sq} | " + " | ".join(cells) + " |")
        L.append("")
    # Duels.
    ser = squads(rows, "duel")
    gru = []
    for r in rows:
        if r["kind"] == "duel" and r["against"] not in gru: gru.append(r["against"])
    if ser:
        L.append("## Serenity against Grubstake")
        L.append("")
        L.append("Both squads at 420 parts, charging each other. A cell: Serenity's wins out of the rounds, then the exchange: "
                 "the parts Grubstake lost for each part Serenity lost (above 1, Serenity came out ahead).")
        L.append("")
        L.append("| Serenity \\ Grubstake | " + " | ".join(g.replace("grubstake ", "") for g in gru) + " |")
        L.append("|---|" + "---|" * len(gru))
        for s in ser:
            cells = []
            for g in gru:
                rs = by.get(("duel", s, g), [])
                if not rs: cells.append("-"); continue
                w = sum(1 for r in rs if r["winner"] == "a")
                la = sum(r["a"]["parts_lost"] for r in rs); lb = sum(r["b"]["parts_lost"] for r in rs)
                ex = "all" if la == 0 and lb > 0 else ("-" if la == 0 else f"{lb / la:.1f}")
                cells.append(f"{w}/{len(rs)}, {ex}")
            L.append(f"| {s.replace('serenity ', '')} | " + " | ".join(cells) + " |")
        L.append("")
    open(out, "w").write("\n".join(L))
    print(f"wrote {out}: {len(rows)} fights")

if __name__ == "__main__":
    main()
