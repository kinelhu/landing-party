"""Director visits on one page (the user, 2026-11-14: "a set of visits with various director settings on a visualization
document with time slider and annotations"): one save's visits at several director settings (scripts/visit.sh with
LP_MIX=record and LP_DIRECTOR), the terrain under them, the director's beats and notices on a timeline, the player's
losses and each setting's curve.
    python3 scripts/director_page.py <save> <out.html> <visit dir>...   (each dir visit-<save>-record-dir-<setting>)
Reads rec.jsonl, events.jsonl, ops.jsonl and terrain.json from each.
"""
import json
import os
import sys

TPM = 3600
GROUPS = {"wall": ["wall", "gate"], "gun": ["electric-turret", "ammo-turret", "fluid-turret", "artillery-turret"],
          "make": ["assembling-machine", "furnace", "lab", "beacon", "rocket-silo"], "mine": ["mining-drill"],
          "port": ["roboport"], "power": ["electric-pole", "solar-panel", "accumulator", "reactor", "generator", "boiler"],
          "belt": ["transport-belt", "underground-belt", "splitter", "inserter", "pipe", "pipe-to-ground", "storage-tank"]}
GROUP_OF = {t: g for g, ts in GROUPS.items() for t in ts}


def flat(v):
    return v if isinstance(v, list) else []


def thin(xy, most):
    """A flat [x, y, ...] list kept to `most` points, evenly."""
    n = len(xy) // 2
    if n <= most:
        return [round(v) for v in xy]
    step = n / most
    out = []
    for i in range(most):
        j = int(i * step) * 2
        out += [round(xy[j]), round(xy[j + 1])]
    return out


def lines(path):
    if not os.path.exists(path):
        return []
    return [json.loads(l) for l in open(path) if l.strip()]


def one(run_dir):
    setting = run_dir.rstrip("/").rsplit("-dir-", 1)[-1]
    recs = lines(os.path.join(run_dir, "rec.jsonl"))
    base = next(r for r in recs if r["k"] == "base")
    t0 = base["t"]
    m = lambda t: round((t - t0) / TPM, 2)
    snaps = [r for r in recs if r["k"] == "s"]
    deaths = [r for r in recs if r["k"] == "d"]
    ev = lines(os.path.join(run_dir, "events.jsonl"))
    ops = lines(os.path.join(run_dir, "ops.jsonl"))
    # Frames: the corporations' units every 2 minutes, their buildings every 10, capped.
    frames, last_u, last_b = [], -99, -99
    for s in snaps:
        mm = m(s["t"])
        if mm - last_u < 2 and s is not snaps[-1]:
            continue
        last_u = mm
        f = {"m": mm, "u": {}, "b": None}
        for corp, c in (s.get("corps") or {}).items():
            f["u"][corp] = thin(flat(c.get("u")), 400)
        if mm - last_b >= 10:
            last_b = mm
            f["b"] = {corp: thin(flat(c.get("b")), 1500) for corp, c in (s.get("corps") or {}).items()}
            f["l"] = {corp: thin(flat(c.get("l")), 20) for corp, c in (s.get("corps") or {}).items()}
        frames.append(f)
    beats = [{"m": m(e["t"]), "kind": e.get("kind"), "corp": e.get("corp") or ",".join(e.get("corps") or []),
              "minutes": e.get("minutes"), "strike": e.get("strike"), "focus": e.get("focus")}
             for e in ev if e["k"] == "beat"]
    notices = [{"m": m(e["t"]), "key": e.get("key"), "args": e.get("args")} for e in ev if e["k"] == "notice"]
    camps = [{"m": m(e["t"]), "k": e["k"], "corp": e.get("corp"), "at": e.get("at"), "why": e.get("why"),
              "matched": e.get("matched")} for e in ev if e["k"] in ("landed", "fell", "departed", "stood_down")]
    texts = [{"m": m(e["t"]), "text": e.get("text")} for e in ev if e["k"] == "director"]
    minutes = []
    lost_b = 0
    for e in ev:
        if e["k"] != "minute":
            continue
        lo = e.get("losses") or {}
        lost_b += lo.get("player:building", 0)
        corp_lost = sum(v for k, v in lo.items() if k.startswith("lp-") and not k.startswith("lp-biotech"))
        minutes.append({"m": m(e["t"]), "phase": e.get("phase"), "active": e.get("active"), "budget": round(e.get("budget") or 0, 2),
                        "hurt": e.get("hurt"), "lost": round(e.get("lost") or 0), "usual": round(e.get("usual") or 0),
                        "worth": round(e.get("worth") or 0), "guns": e.get("guns"), "era": e.get("era"),
                        "next": e.get("next_beat"), "held": e.get("held_for"), "cum": lost_b, "corp_lost": corp_lost})
    opl = []
    for o in ops:
        a = o.get("attempt") or {}
        kills = o.get("kills") or []
        # ("end" in game minutes, "start" a tick.)
        end_t = o["end"] * TPM if isinstance(o.get("end"), (int, float)) else o.get("start", t0)
        opl.append({"m0": m(o.get("start", t0)), "m1": m(end_t), "kind": o.get("kind"),
                    "corp": o.get("faction"), "target": o.get("target"), "what": o.get("target_kind"),
                    "outcome": o.get("outcome"), "razed": len(kills) if isinstance(kills, list) else len(kills.keys()),
                    "in": a.get("inside")})
    # Every death recorded is the player's (its killer's force in "f").
    dl = [[m(d["t"]), d["x"], d["y"], GROUP_OF.get(d["n"], "other"), d.get("f", "")] for d in deaths]
    end = max([f["m"] for f in frames] + [x["m"] for x in minutes] + [0])
    return {"setting": setting, "end": end, "frames": frames, "beats": beats, "notices": notices, "camps": camps,
            "texts": texts, "minutes": minutes, "ops": opl, "deaths": dl}, base, run_dir


def main(save, out, dirs):
    runs, base0, terrain = [], None, None
    order = {"off": 0, "gentle": 1, "steady": 2, "chaotic": 3}
    for d in dirs:
        r, base, rd = one(d)
        runs.append(r)
        if base0 is None:
            base0 = base
            tp = os.path.join(rd, "terrain.json")
            terrain = json.load(open(tp)) if os.path.exists(tp) else None
    runs.sort(key=lambda r: order.get(r["setting"], 9))
    groups = {g: [] for g in list(GROUPS) + ["other"]}
    for t, xy in base0["types"].items():
        groups[GROUP_OF.get(t, "other")].extend(xy)
    groups = {g: thin(xy, 20000 if g == "belt" else 8000) for g, xy in groups.items()}
    data = {"save": save, "terrain": terrain, "base": groups, "runs": runs}
    page = open(os.path.join(os.path.dirname(__file__), "director_page.html")).read()
    page = page.replace("/*SAVE*/", save).replace("/*DATA*/null", json.dumps(data, separators=(",", ":")))
    open(out, "w").write(page)
    print(f"{out}: {len(runs)} runs, {os.path.getsize(out) / 1e6:.1f} MB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
