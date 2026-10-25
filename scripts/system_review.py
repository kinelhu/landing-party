"""The system review (the user, 2026-10-24: charts to review, "keep it lightweight"): one page per four-seed system
measurement, drawn from what the runs already write (system.jsonl a frame a minute, decisions.txt the factions'
trace), nothing typed. Per seed: the five targets (scripts/system_report.py's judge), a timeline of each faction's army,
economy and losses with raids and the watchdog's alarms marked, a map of the camps and every raid as an arrow from its
staging point to its target coloured by outcome, and the events worth reading.

Run: uv run --with matplotlib python3 -I scripts/system_review.py <system.jsonl>... docs/review/index.html
Each input is one seed's system.jsonl; its decisions.txt is read beside it.
"""
import html
import importlib.util
import json
import os
import re
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("system_report", os.path.join(HERE, "system_report.py"))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)

CORPS, COLOUR = report.CORPS, report.COLOUR
NAMES = ["survive", "even", "shapes", "fights", "pressure"]
# What each faction is meant to break of the player's, as designed (DESIGN.md; the user, 2026-10-25: count kinds apart, to
# see whether each faction's effect reflects the target priorities given to it). Words only; the numbers are the runs'.
# (Runs before 2026-10-25's split counted turrets and walls together as "defence".)
KINDS = ["turrets", "walls", "defence", "power", "logistics", "production", "other"]
MEANT = {"lp-serenity": "defences and siege targets (it breaks your line)",
         "lp-grubstake": "production and logistics (soft targets: drills, belts, chests)",
         "lp-biotech": "supply first (power, inserters that feed guns), then the defences it has cut off",
         "enemy": "whatever your pollution draws them to"}
OUTCOME = {"done": "#2e8b3a", "aborted": "#8a8a8a", "fled": "#d08a1c", "breaks": "#c0392b"}

LINE = re.compile(r"^\s*(\d+) (base (\d+)|biotech|grubstake|serenity)\s+(.*)$")
XY = r"(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)"


def parse(decisions, frames):
    """Events from the trace, each with its tick, faction and what it says; raids paired with their outcome."""
    # A camp's corporation: the frame's camp positions nearest its landing.
    corp_of = {}
    events, raids, alarms = [], [], []
    open_raid = {}
    for raw in open(decisions, errors="replace"):
        m = LINE.match(raw)
        if not m:
            continue
        tick, who, base, text = int(m.group(1)), m.group(2), m.group(3), m.group(4)
        minute = tick / 3600
        if base:
            lm = re.match(r"landed at " + XY, text)
            if lm and base not in corp_of:
                x, y = float(lm.group(1)), float(lm.group(2))
                best, bd = None, None
                for f in frames:
                    for c in ("serenity", "grubstake"):
                        for p in (report.corp(f, c).get("at") or []):
                            d = (p[0] - x) ** 2 + (p[1] - y) ** 2
                            if bd is None or d < bd:
                                best, bd = c, d
                corp_of[base] = best
            fac = corp_of.get(base, "serenity")
        else:
            fac = "biotech" if who == "biotech" else who
        if text.startswith("WATCH "):
            alarms.append({"minute": minute, "fac": fac, "text": text[6:]})
            events.append((minute, fac, "alarm", text[6:]))
            continue
        rm = re.match(r"(raid|siege) on ([\w-]+) at " + XY + r".*?stage at " + XY, text) or \
            re.match(r"(siege) of ([\w-]+) at " + XY + r".*?mortars? to " + XY, text)
        if rm:
            r = {"minute": minute, "fac": fac, "kind": rm.group(1), "target": rm.group(2),
                 "to": (float(rm.group(3)), float(rm.group(4))), "stage": (float(rm.group(5)), float(rm.group(6))),
                 "outcome": "?"}
            raids.append(r)
            open_raid[(fac, base)] = r
            events.append((minute, fac, rm.group(1), text))
            continue
        om = re.match(r"(?:raid|siege) (done|aborted|fled)", text) or re.match(r"raid: its \w+ fell; the raid (breaks)", text)
        if om and (fac, base) in open_raid:
            open_raid.pop((fac, base))["outcome"] = om.group(1)
            continue
        for key in ("landed at", "reprisal: ", "mineral rights", "mature:", "wave ", "farm "):
            if text.startswith(key) or (key == "mineral rights" and key in text):
                events.append((minute, fac, key.strip(": "), text))
                break
    return events, raids, alarms


def timeline(seed, frames, raids, alarms, path):
    mins = [f["minute"] for f in frames]
    fig, axes = plt.subplots(3, 1, figsize=(9, 6.4), dpi=100, sharex=True)
    for c in ("serenity", "grubstake"):
        axes[0].plot(mins, [report.corp(f, c).get("garrison", 0) for f in frames], color=COLOUR[c], label=CORPS[c] + " army at home")
        axes[0].plot(mins, [report.corp(f, c).get("turrets", 0) for f in frames], color=COLOUR[c], ls=":", label=CORPS[c] + " turrets")
        axes[1].plot(mins, [report.corp(f, c).get("made", 0) for f in frames], color=COLOUR[c], label=CORPS[c] + " parts made")
        axes[2].plot(mins, [report.corp(f, c).get("lost", 0) for f in frames], color=COLOUR[c], label=CORPS[c] + " buildings lost")
    axes[0].plot(mins, [f.get("lp-biotech", {}).get("units", 0) / 5 for f in frames], color=COLOUR["biotech"], label="Synthexis units / 5")
    axes[2].plot(mins, [sum(report.kills(f, "player", c) for c in CORPS) for f in frames], color=COLOUR["player"],
                 label="the player's buildings lost")
    for r in raids:
        axes[0].axvline(r["minute"], color=COLOUR.get(r["fac"], "#777"), alpha=0.25, lw=1)
    for a in alarms:
        for ax in axes:
            ax.axvline(a["minute"], color="#c0392b", alpha=0.6, lw=1.2, ls="--")
    axes[0].set_ylabel("army, turrets", fontsize=8)
    axes[1].set_ylabel("parts made", fontsize=8)
    axes[2].set_ylabel("buildings lost", fontsize=8)
    axes[2].set_xlabel("minute (faint lines: raids; red dashes: watchdog alarms)", fontsize=8)
    for ax in axes:
        ax.legend(fontsize=7, loc="upper left")
        ax.tick_params(labelsize=7)
    axes[0].set_title(f"seed {seed}", fontsize=9)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def map_(seed, frames, raids, alarms, path):
    fig, ax = plt.subplots(figsize=(7, 7), dpi=100)
    end = frames[-1]
    ax.add_patch(plt.Rectangle((-45, -45), 90, 90, fill=False, color=COLOUR["player"], lw=2))
    ax.text(0, 52, "player", ha="center", fontsize=7, color=COLOUR["player"])
    for c in ("serenity", "grubstake"):
        seen = set()
        for f in frames:
            for p, r in zip(report.corp(f, c).get("at") or [], report.corp(f, c).get("radius") or []):
                key = (p[0], p[1])
                if key in seen:
                    continue
                seen.add(key)
                ax.add_patch(plt.Circle(p, max(r, 20), color=COLOUR[c], alpha=0.18))
                ax.plot(*p, "s", color=COLOUR[c], ms=6)
                ax.text(p[0], p[1] + 12, f"{CORPS[c]} m{f['minute']:.0f}", fontsize=6, ha="center", color=COLOUR[c])
    for p in (end.get("biotech") or {}).get("at") or []:
        ax.plot(*p, "o", color=COLOUR["biotech"], ms=8)
        ax.text(p[0], p[1] + 12, "Synthexis", fontsize=6, ha="center", color=COLOUR["biotech"])
    for r in raids:
        (sx, sy), (tx, ty) = r["stage"], r["to"]
        ax.annotate("", xy=(tx, ty), xytext=(sx, sy), arrowprops=dict(arrowstyle="->", lw=1.2,
                    color=OUTCOME.get(r["outcome"], "#444"), alpha=0.8))
        ax.plot(sx, sy, ".", color=COLOUR.get(r["fac"], "#777"), ms=4)
    for a in alarms:
        m = re.search(r"about " + XY, a["text"])
        if m:
            ax.plot(float(m.group(1)), float(m.group(2)), "x", color="#c0392b", ms=9, mew=2)
    ax.set_aspect("equal")
    ax.autoscale()
    ax.tick_params(labelsize=7)
    ax.set_title(f"seed {seed}: camps (discs: territory, m: minute landed), raids from staging point to target\n"
                 "green done, grey aborted, orange fled, red broken; x: units the watchdog found stuck", fontsize=8)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def main():
    *paths, out = sys.argv[1:]
    outdir = os.path.dirname(out)
    os.makedirs(os.path.join(outdir, "img"), exist_ok=True)
    sections, rows = [], []
    for path in paths:
        seed, frames = report.load(path)
        judged = report.judge(frames)
        events, raids, alarms = parse(os.path.join(os.path.dirname(path), "decisions.txt"), frames)
        timeline(seed, frames, raids, alarms, os.path.join(outdir, "img", f"timeline-{seed}.png"))
        map_(seed, frames, raids, alarms, os.path.join(outdir, "img", f"map-{seed}.png"))
        cells = "".join(f'<td class="{"ok" if judged[n][0] else "miss"}">{"met" if judged[n][0] else "missed"}</td>' for n in NAMES)
        rows.append(f'<tr><td><a href="#s{seed}">{seed}</a></td>{cells}<td>{len(alarms)}</td><td>{len(raids)}</td></tr>')
        why = "".join(f"<li><b>{n}</b> {'met' if judged[n][0] else 'missed'}: {html.escape(judged[n][1])}</li>" for n in NAMES)
        ev = "".join(f'<tr class="{k}"><td>{m:.0f}</td><td>{html.escape(CORPS.get(fac, fac))}</td><td>{html.escape(t)}</td></tr>'
                     for m, fac, k, t in events)
        outcomes = {}
        for r in raids:
            outcomes[(r["fac"], r["outcome"])] = outcomes.get((r["fac"], r["outcome"]), 0) + 1
        summary = ", ".join(f"{CORPS.get(f, f)} {o} {n}" for (f, o), n in sorted(outcomes.items()))
        # What each faction broke of the player's, by kind, beside what it is meant to go for.
        kills = frames[-1].get("kills") or {}
        used = [i for i, kd in enumerate(KINDS) if any(kills.get(f"player>{k_}:{kd}", 0) for k_ in MEANT)]
        krows = []
        for killer, meant in MEANT.items():
            vals = [kills.get(f"player>{killer}:{KINDS[i]}", 0) for i in used]
            if sum(vals):
                name = {"lp-serenity": "Kessler-Hayashi", "lp-grubstake": "Grubstake", "lp-biotech": "Synthexis", "enemy": "Wild biters"}[killer]
                krows.append(f"<tr><td>{name}</td>" + "".join(f"<td>{v}</td>" for v in vals) + f"<td class='meant'>{html.escape(meant)}</td></tr>")
        ktable = ("<div class='scroll'><table class='kinds'><tr><th>broke of yours</th>" + "".join(f"<th>{KINDS[i]}</th>" for i in used)
                  + "<th>meant to go for</th></tr>" + "".join(krows) + "</table></div>") if krows else "<p class='sum'>Nothing of yours broken.</p>"
        sections.append(f'''<section id="s{seed}"><h2>Seed {seed}</h2><ul class="why">{why}</ul>{ktable}
<p class="sum">Raids and sieges: {html.escape(summary) or "none"}. Watchdog alarms: {len(alarms)}.</p>
<div class="pics"><img src="img/timeline-{seed}.png" alt="timeline, seed {seed}"><img src="img/map-{seed}.png" alt="map, seed {seed}"></div>
<details><summary>Events ({len(events)})</summary><table class="ev"><tr><th>min</th><th>who</th><th>what</th></tr>{ev}</table></details></section>''')
    page = f'''<title>Landing Party System Review</title>
<style>
:root {{ --bg: #f4f5f4; --fg: #1d2326; --muted: #5d676b; --line: #ccd2d4; --ok: #2e8b3a; --miss: #b03a2e; --panel: #fff; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg: #16191b; --fg: #e3e7e8; --muted: #9aa5a9; --line: #333c40; --panel: #1e2427; }} }}
:root[data-theme="dark"] {{ --bg: #16191b; --fg: #e3e7e8; --muted: #9aa5a9; --line: #333c40; --panel: #1e2427; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif; margin: 0; }}
main {{ max-width: 1150px; margin: 0 auto; padding: 20px 16px 60px; }}
table {{ border-collapse: collapse; }} td, th {{ border-bottom: 1px solid var(--line); padding: 4px 10px; text-align: left; }}
td.ok {{ color: var(--ok); }} td.miss {{ color: var(--miss); font-weight: 600; }}
.pics {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 420px), 1fr)); gap: 10px; }}
.pics img {{ width: 100%; background: #fff; border: 1px solid var(--line); border-radius: 4px; }}
.why li {{ margin-bottom: 4px; }} .sum, .lede {{ color: var(--muted); }}
.ev {{ font-size: 13px; }} .kinds {{ margin: 10px 0; font-size: 14px; font-variant-numeric: tabular-nums; }}
.kinds td.meant {{ color: var(--muted); font-size: 13px; }} .scroll {{ overflow-x: auto; }} .ev tr.alarm td {{ color: var(--miss); }}
section {{ margin-top: 36px; }} details {{ margin-top: 10px; }}
</style>
<main><h1>System review</h1>
<p class="lede">Every faction on one map with a stand-in for the player, two hours a seed (the system sim). Drawn by
scripts/system_review.py from the runs' frames and traces. Targets and their reasons: scripts/system_report.py.</p>
<table><tr><th>seed</th>{"".join(f"<th>{n}</th>" for n in NAMES)}<th>alarms</th><th>raids</th></tr>{"".join(rows)}</table>
{"".join(sections)}</main>'''
    open(out, "w").write(page)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
