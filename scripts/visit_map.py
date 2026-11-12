"""A visit's recording (rec.jsonl, LP_MIX=record) as one page: the player's base on a map, what was lost and whether it
was rebuilt, ghosts left, roboports out of power, robot coverage, Synthexis's units and its waves, over time.
    uv run python3 scripts/visit_map.py docs/sim/visit-nw-rich-record [out.html]
(The user, 2026-11-01: "how exactly the base is breached and how it's not rebuilt".)
"""
import bisect
import json
import os
import sys

TICKS_PER_MIN = 3600
# What the map draws of the base, by kind (the recording's entity types grouped).
GROUPS = {
    "wall": ["wall", "gate"],
    "gun": ["electric-turret", "ammo-turret", "fluid-turret", "artillery-turret"],
    "make": ["assembling-machine", "furnace", "lab", "beacon", "rocket-silo"],
    "mine": ["mining-drill"],
    "port": ["roboport"],
    "power": ["electric-pole", "solar-panel", "accumulator", "reactor", "generator", "boiler"],
    "belt": ["transport-belt", "underground-belt", "splitter", "inserter", "pipe", "pipe-to-ground", "storage-tank"],
    "other": ["radar", "container", "logistic-container"],
}
GROUP_OF = {t: g for g, ts in GROUPS.items() for t in ts}


def main(run_dir, out_path):
    recs = [json.loads(line) for line in open(os.path.join(run_dir, "rec.jsonl")) if line.strip()]
    base = next(r for r in recs if r["k"] == "base")
    t0 = base["t"]
    snaps = [r for r in recs if r["k"] == "s"]
    deaths = [r for r in recs if r["k"] == "d"]
    builds = [r for r in recs if r["k"] == "b"]
    log = next((r for r in recs if r["k"] == "log"), {"waves": []})

    def minute(t):
        return round((t - t0) / TICKS_PER_MIN, 2)

    # The base at the start, by group: flat [x, y, x, y, ...].
    groups = {g: [] for g in GROUPS}
    for t, xy in base["types"].items():
        groups[GROUP_OF.get(t, "other")].extend(xy)
    xs = [v for g in groups.values() for v in g[0::2]]
    ys = [v for g in groups.values() for v in g[1::2]]
    # (And the corporations' camps: Kessler-Hayashi's first lander on nwa stood 600 tiles past the base's edge.)
    for s in snaps:
        for c in (s.get("corps") or {}).values():
            for k in ("b", "l"):
                xs.extend(c.get(k, [])[0::2]); ys.extend(c.get(k, [])[1::2])
    box = [min(xs) - 20, min(ys) - 20, max(xs) + 20, max(ys) + 20]

    # Each loss with its rebuild: the next robot build of that type at that tile after it (-1: never).
    built_at = {}
    for b in builds:
        built_at.setdefault((b["n"], b["x"], b["y"]), []).append(b["t"])
    for v in built_at.values():
        v.sort()
    used = {}
    causes, cause_ix = [], {}
    losses = []
    for d in sorted(deaths, key=lambda r: r["t"]):
        key = (d["n"], d["x"], d["y"])
        times = built_at.get(key, [])
        i = bisect.bisect_right(times, d["t"])
        i = max(i, used.get(key, 0))
        rebuilt = -1
        if i < len(times):
            rebuilt = minute(times[i])
            used[key] = i + 1
        who = d["by"] or d["f"] or "?"
        if who not in cause_ix:
            cause_ix[who] = len(causes)
            causes.append(who)
        g = GROUP_OF.get(d["n"], "other")
        losses.append([minute(d["t"]), rebuilt, list(GROUPS).index(g), d["x"], d["y"], cause_ix[who]])

    frames = []
    for s in snaps:
        frames.append({
            "m": minute(s["t"]),
            "u": s.get("units", []), "nu": s.get("nunits", 0),
            "g": s.get("ghosts", []), "ng": s.get("nghosts", 0),
            "gby": s.get("gby", {}),
            "down": s.get("down", []),
            "rob": s.get("robots", [0, 0, 0]),
            "pens": s.get("pens", []),
            "corps": {k: {"u": c.get("u", []), "nu": c.get("nu", 0), "b": c.get("b", []), "nb": c.get("nb", 0),
                          "l": c.get("l", [])} for k, c in (s.get("corps") or {}).items()},
            "waves": [{"stage": w.get("stage"), "n": w.get("n"), "at": w.get("at"), "mark": w.get("mark"),
                       "breach": w.get("breach"), "deep": w.get("deep")} for w in s.get("waves", [])],
        })

    def pt(p):
        if isinstance(p, dict):
            return [round(p.get("x", 0)), round(p.get("y", 0))]
        if isinstance(p, list) and len(p) >= 2:
            return [round(p[0]), round(p[1])]
        return None

    waves = []
    for w in log.get("waves", []):
        trail = [q for q in (pt(p) for p in (w.get("trail") or [])) if q]
        path = [q for q in (pt(p) for p in ((w.get("plan") or {}).get("path") or [])) if q]
        deep = w.get("deep") or {}
        waves.append({"start": minute(w["t_launch"]) if w.get("t_launch") else None,
                      "breach_t": minute(w["t_breach"]) if w.get("t_breach") else None,
                      "inside_t": minute(w["t_inside"]) if w.get("t_inside") else None,
                      "end": minute(w["t_end"]) if w.get("t_end") else None,
                      "outcome": w.get("outcome"), "size": w.get("size"), "left": w.get("left"),
                      "kills": w.get("kills"), "worth": round(w.get("razed_worth") or 0),
                      "center": pt(w.get("center")), "breach": pt(w.get("breach")), "mark": pt(w.get("mark")),
                      "deep": pt(deep.get("at")) if deep else None, "trail": trail[::max(1, len(trail) // 40)],
                      "path": path[::max(1, len(path) // 40)], "farm": w.get("farm")})

    data = {"box": box, "groups": list(GROUPS), "base": groups, "losses": losses, "causes": causes,
            "frames": frames, "waves": waves, "minutes": frames[-1]["m"] if frames else 0,
            "name": os.path.basename(run_dir.rstrip("/"))}
    # The page opens 5 minutes before the first breach (nw: about 180; nwa: about 85).
    breaches = [w["breach_t"] for w in waves if w["breach_t"] is not None]
    data["start"] = max(0, round(min(breaches) - 5)) if breaches else 0
    save = data["name"].removeprefix("visit-").split("-")[0]
    page = open(os.path.join(os.path.dirname(__file__), "visit_map.html")).read()
    page = page.replace("/*SAVE*/", save).replace("/*HOURS*/", str(round(data["minutes"] / 60)))
    page = page.replace("/*DATA*/null", json.dumps(data, separators=(",", ":")))
    open(out_path, "w").write(page)
    print(f"{out_path}: {len(losses)} losses ({sum(1 for l in losses if l[1] < 0)} never rebuilt), "
          f"{len(frames)} frames, {len(waves)} waves, {os.path.getsize(out_path) / 1e6:.1f} MB")


if __name__ == "__main__":
    run = sys.argv[1]
    main(run, sys.argv[2] if len(sys.argv) > 2 else os.path.join(run, "visit_map.html"))
