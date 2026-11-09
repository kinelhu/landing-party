#!/usr/bin/env python3
"""The AI at a glance, generated from the code (the user, 2026-10-18: "some kind of representative graph could be
maintained to be able to check the system's design at a glance").

Writes docs/ai-graph.md (tables) and docs/ai-structure.dot/.svg (the module graph). Never edit those by hand.
  scripts/ai_graph.py           regenerate
  scripts/ai_graph.py --check   fail if the committed graph no longer matches the code (check.sh runs it)

Structure: every module under landing-party/scripts (and control.lua), sized by lines; its requires (solid); the
functions plugged into one module by another at load time to dodge a require loop (dashed, labelled: invisible in the
requires, they are the real back-edges); what runs it (tick cadences, events); the storage keys it writes.
Behaviour: each corporation's temper and its answers, what each act is allowed by standing (scripts/ai_behaviour.lua runs
the mod's own stance.may under luajit), the ladder's rungs and what reads them, and what each lever drives.
"""
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOD = REPO / "landing-party"
OUT_MD = REPO / "docs" / "ai-graph.md"
OUT_DOT = REPO / "docs" / "ai-structure.dot"
OUT_SVG = REPO / "docs" / "ai-structure.svg"
OUT_LDOT = REPO / "docs" / "ai-layers.dot"
OUT_LSVG = REPO / "docs" / "ai-layers.svg"
LEAF_OK = {"shared"}

REQ = re.compile(r'local\s+(\w+)\s*=\s*require\("(?:__landing-party__\.)?(?:scripts\.)?([\w]+)"\)')
INJECT = re.compile(r"^\s*(\w+)\.(\w+)\s*=\s*(\w+)\.(\w+)\s*$")
TICK = re.compile(r"tick\s*%\s*(\d+)")
EVENT = re.compile(r"defines\.events\.(\w+)")
STORE = re.compile(r"storage\.(\w+)\s*=[^=]")
RUNG = re.compile(r"(?:ladder|rung)\b[^\n]*?>=\s*(\d)|war_rung or 0\)\s*>=\s*(\d)|local RUNG = (\d)")
LEVER = re.compile(r"tune\.(strength|aggression|sooner)\(")
CAPABLE = {"strip": "strips", "tap": "taps", "jump": "jumps", "prospect": "prospects"}


def modules():
    mods = {p.stem: p for p in sorted((MOD / "scripts").glob("*.lua"))}
    mods["control"] = MOD / "control.lua"
    return mods


def structure(mods):
    info = {}
    for name, path in mods.items():
        text = path.read_text()
        alias = {}
        for var, mod in REQ.findall(text):
            if mod in mods or mod == "shared":
                alias[var] = mod
        alias.setdefault(name, name)
        injected = []
        for line in text.splitlines():
            m = INJECT.match(line)
            if not m:
                continue
            lhs, field, rhs, fn = m.groups()
            a, c = alias.get(lhs), alias.get(rhs)
            # A module that calls into another: `ops.answer_flare = flare.answer` lets ops call flare.
            # In a's own file it is a re-export (ops.rival_holds = stance.rival_holds), not a back-edge.
            if a and c and a != c and a != name and a in mods and c in mods:
                injected.append((a, c, field))
        info[name] = {
            "lines": len(text.splitlines()),
            "requires": sorted({m for m in alias.values() if m in mods and m != name}),
            "injected": injected,
            "ticks": sorted({int(n) for n in TICK.findall(text)}),
            "events": sorted(set(EVENT.findall(text))),
            "storage": sorted(set(STORE.findall(text))),
        }
    return info


# The layers the picture groups modules into. A module missing here fails --check: place it when you add it.
LAYERS = {
    "Seams (leaves)": ["stance", "pool", "tune", "rng", "names", "chart", "ground", "threat", "unit_prior", "lights", "landfx", "burstfx"],
    "Perception and attempts (any attacker)": ["firemap", "valuemap", "costmap", "feeds", "attempt", "tactics"],
    "Knowledge and strategy (per faction)": ["know", "strategy"],
    "Corporation": ["faction", "pods", "war", "standing", "pact", "trade", "ledger", "border", "rd", "phases", "biters"],
    "Settlement": ["base", "construction", "planner", "layout", "wfc", "wfc_serenity", "lots_grubstake", "site", "blocks", "modules", "crew", "cordon", "perimeter",
                   "road", "prospect", "belts"],
    "Army and operations": ["army", "ops", "routing", "intel", "siege", "assault", "strip", "answers", "cuts", "strike", "jammer", "dome", "orbital", "scorcher", "stun", "fall", "separate", "ram", "aim",
                            "power"],
    "Heists (Grubstake)": ["jumper", "tap", "skim", "prowl", "bait", "marker"],
    "The biotech": ["herd", "herd_learn", "farm", "creep", "cell"],
    "The map": ["map"],
    "The player's army": ["command", "scanner", "roads", "achievements", "studies"],
    "Wiring (edges not drawn)": ["control", "dev", "watch", "oplog"],
}
WIRING = set(LAYERS["Wiring (edges not drawn)"])


def dot(info):
    req_by = defaultdict(set)
    for n, i in info.items():
        for r in i["requires"]:
            req_by[r].add(n)
    out = ["digraph ai {", '  graph [rankdir=TB, newrank=true, compound=true, fontname="Helvetica", fontsize=11, nodesep=0.25, ranksep=0.6];',
           '  node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10, fillcolor="#eef2f7"];',
           '  edge [color="#8899aa", arrowsize=0.6];']
    for k, (layer, names) in enumerate(LAYERS.items()):
        out.append(f'  subgraph cluster_{k} {{ label="{layer}"; style="rounded,dashed"; color="#bbbbbb"; fontcolor="#666666";')
        for n in names:
            i = info[n]
            w = 0.8 + min(3.0, i["lines"] / 900)
            leaf = not i["requires"]
            colour = "#d9f0d9" if leaf else ("#f7dede" if i["lines"] > 1000 else "#eef2f7")
            out.append(f'    "{n}" [label="{n}\\n{i["lines"]} lines", width={w:.2f}, fillcolor="{colour}"];')
        out.append("  }")
    for n in sorted(info):
        if n in WIRING:
            continue
        for r in info[n]["requires"]:
            out.append(f'  "{n}" -> "{r}";')
    seen = set()
    for n in sorted(info):
        for a, c, field in info[n]["injected"]:
            key = (a, c, field)
            if key in seen:
                continue
            seen.add(key)
            out.append(f'  "{a}" -> "{c}" [style=dashed, color="#d2691e", fontcolor="#d2691e", fontsize=8, label="{field}"];')
    out.append("}")
    return "\n".join(out) + "\n"


def layers_dot(info):
    of = {n: layer for layer, names in LAYERS.items() for n in names}
    req, plug = defaultdict(int), defaultdict(int)
    for n, i in info.items():
        if n in WIRING:
            continue
        for r in i["requires"]:
            if of[n] != of[r]:
                req[(of[n], of[r])] += 1
        for a, c, field in i["injected"]:
            if of[a] != of[c]:
                plug[(of[a], of[c])] += 1
    out = ["digraph layers {", '  graph [rankdir=TB, fontname="Helvetica", nodesep=0.5, ranksep=0.7];',
           '  node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=11, fillcolor="#eef2f7"];',
           '  edge [color="#8899aa", fontname="Helvetica", fontsize=9];']
    for layer, names in LAYERS.items():
        if layer.startswith("Wiring"):
            continue
        lines = sum(info[n]["lines"] for n in names)
        big = [n for n in names if info[n]["lines"] > 1000]
        colour = "#d9f0d9" if layer.startswith("Seams") else ("#f7dede" if big else "#eef2f7")
        extra = ("\\n" + ", ".join(f"{n} {info[n]['lines']}" for n in big)) if big else ""
        out.append(f'  "{layer}" [label="{layer}\\n{len(names)} module{"s" if len(names) != 1 else ""}, {lines} lines{extra}", fillcolor="{colour}"];')
    for (a, b), k in sorted(req.items()):
        out.append(f'  "{a}" -> "{b}" [label="{k}", penwidth={1 + k / 4:.1f}];')
    for (a, b), k in sorted(plug.items()):
        out.append(f'  "{a}" -> "{b}" [style=dashed, color="#d2691e", fontcolor="#d2691e", label="{k} plug-in"];')
    out.append("}")
    return "\n".join(out) + "\n"


def behaviour():
    res = subprocess.run(["luajit", str(REPO / "scripts" / "ai_behaviour.lua"), str(MOD)], capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit("ai_graph: scripts/ai_behaviour.lua failed:\n" + res.stderr)
    rows = [line.split("\t") for line in res.stdout.splitlines() if line]
    return rows


def md(info, rows):
    L = ["# The AI at a glance (generated)", "",
         "Generated by `scripts/ai_graph.py` from the code; `check.sh` fails when it no longer matches. Do not edit: "
         "change the code and regenerate. The design and its reasons are in `docs/ai.md`.", "",
         "## Structure", "",
         "By layer: modules and lines in each, the requires between layers (solid, counted) and the plug-ins (dashed).", "",
         "![layers](ai-layers.svg)", "",
         "Every module:", "",
         "![modules](ai-structure.svg)", "",
         "Boxes are modules, sized by lines, in their layers (green: a leaf, it requires no other module; red: over 1,000 "
         "lines; control and dev wire everything and their edges are left out). Solid "
         "arrows are requires. Dashed arrows are functions one module plugs into another at load time (`a.f = b.f`): "
         "`a` calls `b` without requiring it, so the requires alone hide these edges.", "",
         "| Module | Lines | Requires | Required by | Calls in by plug-in | Tick cadences | Events | Storage keys written |",
         "|---|---|---|---|---|---|---|---|"]
    req_by = defaultdict(set)
    for n, i in info.items():
        for r in i["requires"]:
            req_by[r].add(n)
    plugs = defaultdict(set)
    for n, i in info.items():
        for a, c, field in i["injected"]:
            plugs[a].add(f"{c}.{field}")
    for n in sorted(info, key=lambda k: -info[k]["lines"]):
        i = info[n]
        L.append("| `{}` | {} | {} | {} | {} | {} | {} | {} |".format(
            n, i["lines"], ", ".join(i["requires"]) or "(leaf)", ", ".join(sorted(req_by[n])) or "",
            ", ".join(sorted(plugs[n])), ", ".join(str(t) for t in i["ticks"]),
            ", ".join(e.replace("on_", "") for e in i["events"]), ", ".join(i["storage"])))
    # Behaviour.
    temper = {r[1]: r[2].split() for r in rows if r[0] == "temper"}
    caps = {r[1]: r[2].split() for r in rows if r[0] == "caps"}
    answers = defaultdict(dict)
    for r in rows:
        if r[0] == "answer":
            answers[r[1]][r[2]] = r[3]
    may = {(r[1], r[2], r[3]): r[4] == "true" for r in rows if r[0] == "may"}
    corps = sorted(temper)
    acts = []
    for r in rows:
        if r[0] == "may" and r[3] not in acts:
            acts.append(r[3])
    L += ["", "## Behaviour", "", "### Tempers and answers", "",
          "| Corporation | Temper | Capabilities by level | Answers a loss with | Answers trespass with |", "|---|---|---|---|---|"]
    for c in corps:
        L.append(f"| {c} | {', '.join(temper[c]) or '-'} | {', '.join(caps.get(c, [])) or '-'} | "
                 f"{answers[c].get('loss', 'raid')} | {answers[c].get('trespass', 'raid')} |")
    L += ["", "### What each act is allowed, by standing", "",
          "From `stance.may`, run on the mod's own tables. Yes: allowed. No: forbidden. A dash: the corporation does not "
          "have the act at all (its temper lacks it), whatever the standing. Siege also needs its level or a grudge.", ""]
    L.append("| Corporation | Standing | " + " | ".join(acts) + " |")
    L.append("|---|---|" + "---|" * len(acts))
    for c in corps:
        for st in ("rival", "enemy", "truce"):
            cells = []
            for a in acts:
                if a in CAPABLE and CAPABLE[a] not in temper[c]:
                    cells.append("-")
                elif a == "siege" and not any(x.startswith("siege=") for x in caps.get(c, [])):
                    cells.append("grudge only" if may[(c, st, a)] else "no")
                else:
                    cells.append("yes" if may[(c, st, a)] else "no")
            L.append(f"| {c} | {st} | " + " | ".join(cells) + " |")
    # The ladder and the levers, read from the code.
    L += ["", "### The ladder: what reads which rung", "", "| Module | Rung | Line |", "|---|---|---|"]
    for n, path in sorted(modules().items()):
        for k, line in enumerate(path.read_text().splitlines(), 1):
            m = RUNG.search(line)
            if m and not line.strip().startswith("--"):
                rung = next(g for g in m.groups() if g)
                L.append(f"| `{n}` | {rung} | `{line.strip()[:110].replace('|', '/')}` |")
    L += ["", "### The levers: what each drives", "", "| Lever | Module | Line |", "|---|---|---|"]
    for n, path in sorted(modules().items()):
        # control.lua wires events and remotes; a lever read there is a test's remote (debug_levers), driving nothing.
        if n in ("tune", "control"):
            continue
        for k, line in enumerate(path.read_text().splitlines(), 1):
            for lever in LEVER.findall(line):
                if not line.strip().startswith("--"):
                    name = "aggression" if lever == "sooner" else lever
                    L.append(f"| {name} | `{n}` | `{line.strip()[:110].replace('|', '/')}` |")
    presets = [f"{r[1]} {r[2]}" for r in rows if r[0] == "preset"]
    L += ["", "Presets: " + ", ".join(presets) + "."]
    return "\n".join(L) + "\n"


def main():
    mods = modules()
    info = structure(mods)
    placed = {n for names in LAYERS.values() for n in names}
    missing, gone = sorted(set(info) - placed), sorted(placed - set(info))
    if missing or gone:
        sys.exit("ai_graph: LAYERS out of date: " + (f"not placed {missing} " if missing else "")
                 + (f"no longer exist {gone}" if gone else ""))
    d = dot(info)
    ld = layers_dot(info)
    m = md(info, behaviour())
    if "--check" in sys.argv:
        stale = [p.name for p, new in ((OUT_DOT, d), (OUT_LDOT, ld), (OUT_MD, m)) if not p.exists() or p.read_text() != new]
        if stale:
            sys.exit("ai_graph: " + ", ".join(stale) + " out of date with the code: run scripts/ai_graph.py and commit")
        print("ai graph ok")
        return
    OUT_DOT.write_text(d)
    OUT_LDOT.write_text(ld)
    subprocess.run(["dot", "-Tsvg", str(OUT_LDOT), "-o", str(OUT_LSVG)], check=True)
    OUT_MD.write_text(m)
    subprocess.run(["dot", "-Tsvg", str(OUT_DOT), "-o", str(OUT_SVG)], check=True)
    print(f"wrote {OUT_MD.relative_to(REPO)}, {OUT_SVG.relative_to(REPO)}")


if __name__ == "__main__":
    main()
