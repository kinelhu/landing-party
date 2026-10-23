"""The whole system's balance (the user, 2026-10-23: "we now need to think and work on the balance of the whole
system"): every faction on one map with a stand-in for the player (tests/lp-sim scenarios.system), a frame a minute,
judged against the targets below. Writes docs/system.md and docs/system/*.png; numbers in prose come from here.

Run: uv run --with matplotlib python3 -I scripts/system_report.py <system.jsonl>... docs/system.md
Each input is one seed's run (its profile's script-output/landing-party/system.jsonl); the seed is read from the path.

Targets (design calls, 2026-10-23):
  survive    no corporation wiped out by its rivals in two hours: each has a live base (Synthexis a culture) at the end.
  even       no one-sided rivalry: between two corporations, the one that lost more buildings to the other lost at most
             three times as many (a floor of 5 each, so a quiet pair passes).
  shapes     growth of their own kind: Grubstake the wider early (its territory larger than Kessler-Hayashi's 30 minutes
             after Kessler-Hayashi lands), Kessler-Hayashi the stronger late (garrison and turrets at the end).
  fights     every pairing fights: losses both ways between Kessler-Hayashi and Grubstake, and Kessler-Hayashi's kills
             among Synthexis's (its clearances).
  pressure   each corporation goes for the player: operations against the player from each of Kessler-Hayashi and
             Grubstake, and a Synthexis wave, within the two hours.
"""
import json
import os
import re
import sys

CORPS = {"serenity": "Kessler-Hayashi", "grubstake": "Grubstake", "biotech": "Synthexis"}
FORCE = {"serenity": "lp-serenity", "grubstake": "lp-grubstake", "biotech": "lp-biotech", "player": "player"}
COLOUR = {"serenity": "#2f6f86", "grubstake": "#b0651a", "biotech": "#8a9e00", "player": "#3d7a2a"}
LAND_S = 15  # Kessler-Hayashi's landing minute (scenarios.system, SYSTEM_LAND_S)
EVEN, FLOOR = 3, 5


def load(path):
    frames = [json.loads(l) for l in open(path) if l.strip()]
    m = re.search(r"system-(\d+)-", path)
    return (m.group(1) if m else os.path.basename(path)), frames


def kills(frame, victim, killer, what="buildings"):
    return frame.get("kills", {}).get(f"{FORCE[victim]}>{FORCE[killer]}:{what}", 0)


def corp(frame, c):
    return frame.get("corps", {}).get(c) or {}


def judge(frames):
    end = frames[-1]
    out = {}
    s_end, g_end = corp(end, "serenity"), corp(end, "grubstake")
    out["survive"] = (s_end.get("live", 0) > 0 and g_end.get("live", 0) > 0 and end.get("biotech", {}).get("farms", 0) > 0,
                      f"live bases: Kessler-Hayashi {s_end.get('live', 0)}, Grubstake {g_end.get('live', 0)}; "
                      f"Synthexis cultures {end.get('biotech', {}).get('farms', 0)}")
    worst, notes = True, []
    for a, b in (("serenity", "grubstake"), ("serenity", "biotech"), ("grubstake", "biotech")):
        la, lb = kills(end, a, b), kills(end, b, a)
        ratio = max(la, FLOOR) / max(lb, FLOOR)
        ok = 1 / EVEN <= ratio <= EVEN
        worst = worst and ok
        notes.append(f"{CORPS[a]} lost {la}, {CORPS[b]} lost {lb}")
    out["even"] = (worst, "; ".join(notes))
    at = next((f for f in frames if f["minute"] >= LAND_S + 30), end)
    rs, rg = max(corp(at, "serenity").get("radius") or [0]), max(corp(at, "grubstake").get("radius") or [0])
    ss = s_end.get("garrison", 0) + s_end.get("turrets", 0)
    sg = g_end.get("garrison", 0) + g_end.get("turrets", 0)
    out["shapes"] = (rg > rs and ss > sg, f"territory at minute {at['minute']:.0f}: Grubstake {rg:.0f}, Kessler-Hayashi "
                     f"{rs:.0f}; garrison and turrets at the end: Kessler-Hayashi {ss}, Grubstake {sg}")
    sg_units = kills(end, "serenity", "grubstake", "units") + kills(end, "serenity", "grubstake")
    gs_units = kills(end, "grubstake", "serenity", "units") + kills(end, "grubstake", "serenity")
    bs = kills(end, "biotech", "serenity", "units") + kills(end, "biotech", "serenity")
    out["fights"] = (sg_units > 0 and gs_units > 0 and bs > 0,
                     f"Kessler-Hayashi lost {sg_units} to Grubstake, Grubstake {gs_units} to Kessler-Hayashi; "
                     f"Synthexis lost {bs} to Kessler-Hayashi")
    os_ = s_end.get("ops", {}).get("player", 0)
    og = g_end.get("ops", {}).get("player", 0)
    waves = end.get("biotech", {}).get("waves", 0)
    out["pressure"] = (os_ > 0 and og > 0 and waves > 0,
                       f"operations against the player: Kessler-Hayashi {os_}, Grubstake {og}; Synthexis waves {waves}; "
                       f"the player lost {sum(kills(end, 'player', c) for c in CORPS)} buildings to them")
    return out


def plots(runs, outdir):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    os.makedirs(outdir, exist_ok=True)
    fig, axes = plt.subplots(2, len(runs), figsize=(4.2 * len(runs), 6.4), dpi=110, squeeze=False)
    for j, (seed, frames) in enumerate(runs):
        mins = [f["minute"] for f in frames]
        for c in ("serenity", "grubstake"):
            axes[0][j].plot(mins, [max(corp(f, c).get("radius") or [0]) for f in frames], color=COLOUR[c], label=CORPS[c])
            axes[1][j].plot(mins, [corp(f, c).get("garrison", 0) + corp(f, c).get("turrets", 0) for f in frames],
                            color=COLOUR[c], label=CORPS[c])
        axes[1][j].plot(mins, [f.get("lp-biotech", {}).get("units", 0) / 5 for f in frames], color=COLOUR["biotech"],
                        label="Synthexis (units / 5)")
        axes[0][j].set_title(f"seed {seed}", fontsize=9)
        axes[0][j].set_ylabel("territory radius (tiles)", fontsize=8)
        axes[1][j].set_ylabel("garrison + turrets", fontsize=8)
        axes[1][j].set_xlabel("minute", fontsize=8)
    axes[0][0].legend(fontsize=7)
    axes[1][0].legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "growth.png"))
    plt.close(fig)


def main():
    *paths, md = sys.argv[1:]
    runs = [load(p) for p in paths]
    outdir = os.path.join(os.path.dirname(md), "system")
    plots(runs, outdir)
    names = ["survive", "even", "shapes", "fights", "pressure"]
    lines = ["# The whole system's balance", "",
             "Generated by `scripts/system_report.py` from `scenarios.system` runs (tests/lp-sim): every faction on one map",
             "with a stand-in for the player, a frame a minute. Targets and their reasons: the script's docstring.", "",
             "![growth](system/growth.png)", "",
             "| seed | minutes | " + " | ".join(names) + " |", "|---|---|" + "---|" * len(names)]
    detail = []
    for seed, frames in runs:
        j = judge(frames)
        lines.append(f"| {seed} | {frames[-1]['minute']:.0f} | " + " | ".join("met" if j[n][0] else "**missed**" for n in names) + " |")
        detail.append(f"### Seed {seed}")
        detail += [f"- **{n}** ({'met' if j[n][0] else 'missed'}): {j[n][1]}" for n in names]
        detail.append("")
    open(md, "w").write("\n".join(lines + [""] + detail))
    print(f"wrote {md}")


if __name__ == "__main__":
    main()
