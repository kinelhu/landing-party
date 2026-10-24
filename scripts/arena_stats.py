#!/usr/bin/env python3
"""Every unit's numbers for the arena's panel (tests/lp-arena/stats.lua; the user, 2026-10-24: "having unit stats
displayed in detail would help a lot. I was trying to figure out why a single burster could tank 10 player troopers").
Read from the game's prototypes through scripts/roster.py's damage walk (projectiles, beams, areas), never typed:
health, speed, range, shots a second, each hit of one shot (amount, type, repeats, area), each resistance (flat,
percent). The panel works the matchup out from them with the engine's resistance rule. Run scripts/check.sh first (it
dumps the prototypes), then: python3 -I scripts/arena_stats.py
"""
import importlib.util, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
spec = importlib.util.spec_from_file_location("roster", os.path.join(HERE, "roster.py"))
roster = importlib.util.module_from_spec(spec)
sys.argv = sys.argv[:1]
spec.loader.exec_module(roster)
d = roster.d


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return f"{v:g}"
    if isinstance(v, str):
        return '"' + v.replace('"', '\\"') + '"'
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    return "{" + ", ".join(f'["{k}"] = {lua(x)}' for k, x in v.items()) + "}"


out = {}
for kind in ("unit", "spider-unit"):
    for name, u in sorted(d.get(kind, {}).items()):
        ap = u.get("attack_parameters") or {}
        hits = []
        for amt, typ, note in roster.damage((ap.get("ammo_type") or {}).get("action"), ap.get("damage_modifier", 1)):
            if typ == "chain":
                continue
            rep = re.search(r"\(x(\d+)\)", note)
            area = re.search(r"over ([\d.]+) tiles", note)
            hits.append({"amount": round(amt, 3), "type": typ, "rep": int(rep.group(1)) if rep else 1,
                         "area": float(area.group(1)) if area else 0, "buildings": "to buildings" in note})
        speed = u.get("movement_speed")
        out[name] = {
            "health": u.get("max_health", 0),
            "speed": round(speed * 60, 2) if speed else 0,
            "range": ap.get("range", 0),
            "rate": round(60 / ap["cooldown"], 3) if ap.get("cooldown") else 0,
            "hits": hits,
            "resist": {r["type"]: [r.get("decrease", 0), r.get("percent", 0)] for r in u.get("resistances") or []},
        }

path = os.path.join(REPO, "tests", "lp-arena", "stats.lua")
with open(path, "w") as f:
    f.write("-- Written by scripts/arena_stats.py from the game's prototypes: do not edit by hand.\n")
    f.write("-- Each unit: health, speed (tiles/s), range, rate (shots/s), hits of one shot {amount, type, rep, area,\n")
    f.write("-- buildings (to buildings only)}, resist {type = {flat, percent}}.\n")
    f.write("return {\n")
    for name, s in out.items():
        f.write(f'  ["{name}"] = {lua(s)},\n')
    f.write("}\n")
print(f"{path}: {len(out)} units")
