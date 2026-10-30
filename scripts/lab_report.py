"""The siege lab's report (scripts/siegelab.sh run): one row a trial, then each trial in full, from lab.jsonl.

    uv run --with matplotlib python3 -I scripts/lab_report.py docs/sim/lab-<save>/lab.jsonl docs/sim/lab-<save>

Each line of lab.jsonl is one trial (tests/lp-sim, mix lab): what the farm chose and why, the siege it laid, its wave (its
make-up, its plan's price against what it lost, in mediums, by killer), what it broke, and its prices before and after.
Writes report.md and, with matplotlib, trial-<n>.png (the fortress, where the wave broke in and where its own died).
"""
import json
import sys
from pathlib import Path


def short(name):
    return name.replace("lp-bred-", "").replace("-turret", "")


def fmt_dict(d, nd=0):
    if not d:
        return "none"
    items = sorted(d.items(), key=lambda kv: -kv[1])
    return ", ".join(f"{short(k)} {v:.{nd}f}" for k, v in items)


def prices_moved(before, after):
    out = []
    for foe in sorted(set(before) | set(after)):
        b, a = before.get(foe, {}), after.get(foe, {})
        for proto in sorted(set(b) | set(a)):
            pb, pa = b.get(proto), a.get(proto)
            if pb != pa:
                out.append(f"{short(proto)} {'prior' if pb is None else f'{pb:.1f}'} -> {pa:.1f}")
    return ", ".join(out) or "unchanged"


def plot(t, dest):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return None
    fig, ax = plt.subplots(figsize=(6, 6))
    kinds = {"laser": "tab:red", "gun": "tab:orange", "flamethrower": "tab:purple", "wall": "0.6", "gate": "0.4",
             "land-mine": "tab:brown"}
    for d in t.get("defences", []):
        c = next((v for k, v in kinds.items() if k in d[0]), "tab:blue")
        ax.plot(d[1], d[2], "s" if "wall" in d[0] or "gate" in d[0] else "o", color=c,
                ms=2 if "wall" in d[0] or "mine" in d[0] else 4, alpha=0.6 if d[3] else 0.15)
    w = t.get("wave") or {}
    for p in w.get("dead_at", []):
        ax.plot(p[0], p[1], "x", color="black", ms=3, alpha=0.6)
    if w.get("breach"):
        ax.plot(w["breach"][0], w["breach"][1], "*", color="gold", ms=16, mec="black")
    ax.set_aspect("equal")
    ax.set_title(f"trial {t['trial']}: {t.get('outcome', '?')}")
    f = Path(dest) / f"trial-{t['trial']}.png"
    fig.savefig(f, dpi=110, bbox_inches="tight")
    plt.close(fig)
    return f.name


def main(src, dest):
    trials = [json.loads(l) for l in open(src) if l.strip()]
    lines = ["# Siege lab", "", f"{len(trials)} trials, from `{src}`.", "",
             "| trial | outcome | siege | wave | strength | plan, there and back | lost (mediums) | got in | broke | prices |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    for t in trials:
        w, sg = t.get("wave") or {}, t.get("siege") or {}
        siege = (f"{sg.get('k', 0)} bursters, {sg.get('n', 0) - sg.get('k', 0)} {short(sg.get('breed') or '?')}, "
                 f"{sg.get('price', 0):.0f} biomass") if sg else "none"
        lost = sum((w.get("lost_worth_by") or {}).values())
        broke = sum((w.get("kills") or {}).values())
        lines.append(f"| {t['trial']} | {t.get('outcome', '?')} | {siege} | {w.get('size', 0)} | {w.get('worth', 0):.0f} | "
                     f"{w.get('predicted') or 0:.0f} | {lost:.0f} | {'yes' if w.get('t_inside') is not None else 'no'} | {broke} | "
                     f"{prices_moved((t.get('prices_before') or {}).get('price', {}), (t.get('prices_after') or {}).get('price', {}))} |")
    lines.append("")
    for t in trials:
        w, sg = t.get("wave") or {}, t.get("siege") or {}
        lines += [f"## Trial {t['trial']}: {t.get('outcome', '?')}", ""]
        if t.get("held"):
            lines += [f"Held: {t['held']}", ""]
        if t.get("weighs"):
            lines += [f"Weighed: {t['weighs']}", ""]
        if sg:
            lines += [f"Siege: {sg.get('k', 0)} big bursters and a herd of {sg.get('n', 0) - sg.get('k', 0)} "
                      f"{short(sg.get('breed') or '?')}, {sg.get('price', 0):.0f} biomass, at {sg.get('at')}.", ""]
        if w:
            lines += [f"Wave: {w.get('size', 0)} ({w.get('worth', 0):.0f} mediums): {fmt_dict(w.get('made_of'))}.",
                      f"Its plan priced the way in at {w.get('predicted') or 0:.0f} there and back; it crossed for "
                      f"{w.get('crossed') or 0:.0f}.",
                      f"Lost, in mediums, by stage and killer: {fmt_dict(w.get('lost_worth_by'))}.",
                      f"Its bursts broke: {fmt_dict(w.get('bursts'))}. Its own broke: {fmt_dict(w.get('kills'))}.",
                      f"Got in: {'yes' if w.get('t_inside') is not None else 'no'}; {w.get('home', 0)} home.", ""]
        lines += [f"Prices: {prices_moved((t.get('prices_before') or {}).get('price', {}), (t.get('prices_after') or {}).get('price', {}))}.",
                  f"Rebuilt after: {fmt_dict(t.get('rebuilt'))}.", ""]
    (Path(dest) / "report.md").write_text("\n".join(lines))
    print("\n".join(lines[:6 + len(trials)]))


STAGES = ["scout", "gather", "march", "stage", "breach", "inside", "withdraw", "blind", "done"]


def page_data(dest):
    """The replay page's data from a run's folder: names as indices, positions to a tenth of a tile, frames as arrays."""
    d = Path(dest)
    names, ix = [], {}

    def nid(n):
        if n is None:
            return -1
        if n not in ix:
            ix[n] = len(names)
            names.append(n)
        return ix[n]

    def r(v):
        return round(v, 1) if isinstance(v, (int, float)) else v

    runs = [json.loads(l) for l in open(d / "lab-run.jsonl") if l.strip()]
    run = runs[-1]
    ents = [[nid(e[0]), r(e[1]), r(e[2]), e[3] if len(e) > 3 else None, nid(e[4]) if len(e) > 4 else -1]
            for e in run["defences"]]
    pens = run.get("pens", [])
    decisions = []
    for line in open(d / "decisions.txt", errors="replace"):
        parts = line.strip().split(None, 2)
        if len(parts) == 3 and parts[0].isdigit() and "TRACE" not in parts[2]:
            decisions.append((int(parts[0]), parts[1], parts[2]))
    costmaps = []
    # (The plan's own maps first, at the grain its waves follow; the farm's coarse weighing where there is none.)
    plans = sorted((d / "costmaps").glob("plan-*.json")) if (d / "costmaps").exists() else []
    for f in plans or (sorted((d / "costmaps").glob("farm*-*.json")) if (d / "costmaps").exists() else []):
        try:
            costmaps.append(json.load(open(f)))
        except ValueError:
            pass
    trials = []
    for t in (json.loads(l) for l in open(d / "lab.jsonl") if l.strip()):
        w = t.get("wave") or {}
        frames, units, defhp, big, deaths = [], [], [], [], []
        rec = d / t.get("rec", "")
        if rec.is_file():
            for line in open(rec):
                e = json.loads(line)
                if e["ev"] == "frame":
                    fi = len(frames)
                    frames.append([e["t"], STAGES.index(e["s"]) if e["s"] in STAGES else -1])
                    units.append([[u[0], nid(u[1]), r(u[2]), r(u[3]), u[4], ["herd", "burster", "scout", "sweep"].index(u[5])]
                                  for u in e["u"]])
                    for i, hp in e.get("d", []):
                        defhp.append([fi, i - 1, hp])
                    for b in e.get("big", []):
                        big.append([fi, b[0], r(b[1][0]), r(b[1][1])])
                elif e["ev"] == "die":
                    kp = e.get("kp") or [None, None]
                    deaths.append([e["t"], e.get("id"), nid(e["n"]), nid(e["f"]), r(e["p"][0]), r(e["p"][1]), nid(e.get("k")),
                                   r(kp[0]), r(kp[1]), e.get("kid"), nid(e.get("dt")), (e["def"] - 1) if e.get("def") else -1])
        launch = t.get("launch") or t["start"]
        cm = None
        for c in costmaps:
            if c.get("tick", 0) <= launch and (cm is None or c["tick"] > cm["tick"]):
                cm = c
        if cm:
            cm = {"x0": cm["x0"], "y0": cm["y0"], "size": cm["size"], "cells": [[c[0], c[1], r(c[3])] for c in cm["cells"]]}
        wid = w.get("id")
        notes = [[tk, txt] for tk, who, txt in decisions if t["start"] <= tk <= t.get("end", tk) and who == "biotech"
                 and (txt.startswith("farm ") or (wid is not None and txt.startswith(f"wave {wid}:")))]
        plan = t.get("plan") or w.get("plan") or {}
        trials.append({
            "trial": t["trial"], "outcome": t.get("outcome"), "held": t.get("held"), "start": t["start"], "end": t.get("end"),
            "launch": t.get("launch"), "siege": t.get("siege"), "rebuilt": t.get("rebuilt") or {},
            "plan": {"path": plan.get("path") or [], "start": plan.get("start"), "breach": plan.get("breach"),
                     "cost": plan.get("cost"), "cover": plan.get("cover")},
            "wave": {"size": w.get("size"), "worth": w.get("worth"), "left": w.get("left"), "made_of": w.get("made_of") or {},
                     "predicted": w.get("predicted"), "crossed": w.get("crossed"), "lost_worth_by": w.get("lost_worth_by") or {},
                     "lost_by": w.get("lost_by") or {}, "kills": w.get("kills") or {},
                     "bursts": (w.get("bursters") or {}).get("broke") or {}, "inside": w.get("t_inside") is not None,
                     "breach": w.get("breach"), "outcome": w.get("outcome"), "t_breach": w.get("t_breach"),
            "big_sent": w.get("big_sent"), "big_set_off": w.get("big_set_off"),
                     "t_inside": w.get("t_inside"), "razed": w.get("razed_worth")} if w else None,
            "prices_before": (t.get("prices_before") or {}).get("price", {}),
            "prices_after": (t.get("prices_after") or {}).get("price", {}),
            "alive": t.get("alive"), "frames": frames, "units": units, "defhp": defhp, "big": big, "deaths": deaths,
            "costmap": cm, "notes": notes})
    return {"names": names, "center": run.get("center"), "ents": ents, "pens": pens, "biomass": run.get("biomass"),
            "trials": trials, "stages": STAGES, "medium_hp": 75}


def write_page(dest):
    data = json.dumps(page_data(dest), separators=(",", ":")).replace("</", "<\\/")
    tpl = (Path(__file__).parent / "lab_page.html").read_text()
    out = Path(dest) / "report.html"
    # (Its name by its fort: the square's lab and the star fort's side by side in a gallery.)
    d = Path(dest).name
    name = "Star Fort Siege Lab" if "star" in d else "Your Fort Siege Lab" if "plot-edit" in d else "Siege Lab"
    tpl = tpl.replace("<title>Siege Lab</title>", f"<title>{name}</title>").replace("<h1>Siege Lab</h1>", f"<h1>{name}</h1>")
    out.write_text(tpl.replace("__LAB_DATA__", data))
    print(f"page: {out} ({out.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
    write_page(sys.argv[2])
