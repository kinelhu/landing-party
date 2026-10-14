"""First contact as a timeline: the faction's strength against what the player still has, and every operation.

    timeline.py <run dir>      reads timeline.jsonl and decisions.txt; writes timeline.png and timeline.md
"""
import json
import re
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

run = Path(sys.argv[1])
rows = [json.loads(l) for l in open(run / "timeline.jsonl") if l.strip()]
events = []
for line in open(run / "decisions.txt"):
    m = re.match(r"\s*(\d+) base (\d+)\s+(.*)", line)
    if not m:
        m2 = re.match(r"\s*(\d+) faction\s+(.*)", line)
        if m2:
            events.append((int(m2.group(1)) / 3600, "faction", m2.group(2)))
        continue
    tick, base, text = int(m.group(1)), m.group(2), m.group(3)
    if re.match(r"(raid|siege)( on| of|:| done| aborted| spent| intercepted| sees| attacks)", text) \
            or text.startswith(("landing", "lander destroyed", "faction tier")):
        events.append((tick / 3600, base, text))

minutes = [r["minute"] for r in rows]
cats = sorted({c for r in rows for c in r["player"]})
fig, (a1, a2, a3) = plt.subplots(3, 1, figsize=(10, 10), sharex=True)
a1.plot(minutes, [r["garrison"] for r in rows], label="garrison + patrols")
a1.plot(minutes, [r["turrets"] for r in rows], label="faction turrets")
a1.plot(minutes, [r["settlements"] for r in rows], label="settlements standing")
a1.set_ylabel("faction")
a1.legend(loc="upper left")
a2.plot(minutes, [r["parts_rate"] for r in rows], color="tab:purple", label="parts/min (all settlements)")
a2b = a2.twinx()
a2b.step(minutes, [r["raids"] for r in rows], where="post", color="tab:red", label="raids launched")
a2b.step(minutes, [r["sieges"] for r in rows], where="post", color="tab:orange", label="sieges launched")
a2.set_ylabel("parts/min")
a2b.set_ylabel("operations (cumulative)")
a2.legend(loc="upper left")
a2b.legend(loc="lower right")
first = rows[0]["player"]
for c in cats:
    a3.plot(minutes, [r["player"].get(c, 0) / max(1, first.get(c, 1)) for r in rows], label=c)
a3.set_ylabel("player: share still standing")
a3.set_xlabel("minute")
a3.set_ylim(0, 1.1)
a3.legend(loc="lower left", ncol=3)
for t, base, text in events:
    if text.startswith(("raid on", "siege of")):
        for ax in (a1, a2, a3):
            ax.axvline(t, color="tab:red" if text.startswith("raid") else "tab:orange", alpha=0.25, lw=1)
fig.suptitle(f"First contact: {run.name}")
fig.tight_layout()
fig.savefig(run / "timeline.png", dpi=90)

# Cost to each side (rows written since 2026-10-14; older runs lack them): units the corporations lost, player
# buildings razed, settlements fallen, landers the player destroyed, the player's strikes; corporations standing.
cost = "corp_units_lost" in rows[0]
extra = ["units lost", "razed", "fallen", "landers killed", "strikes", "corporations"] if cost else []
out = [f"# First contact: {run.name}", "", "| minute | settlements | garrison | faction turrets | parts/min | raids | sieges | "
       + " | ".join(cats + extra) + " |", "|" + "---|" * (7 + len(cats) + len(extra))]
for r in rows:
    more = [r["corp_units_lost"], r["razed"], r["fallen"], r["lander_kills"], r["strikes"],
            " ".join(f"{k} {v}" for k, v in sorted((r.get("corps") or {}).items()))] if cost else []
    out.append(f"| {r['minute']:.0f} | {r['settlements']} | {r['garrison']} | {r['turrets']} | {r['parts_rate']:.0f} | "
               f"{r['raids']} | {r['sieges']} | " + " | ".join([str(r['player'].get(c, 0)) for c in cats] + [str(x) for x in more]) + " |")
out += ["", "## Events", ""]
out += [f"- {t:5.1f} min, settlement {b}: {text}" for t, b, text in events]
(run / "timeline.md").write_text("\n".join(out) + "\n")
print(run / "timeline.png")
