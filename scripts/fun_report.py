#!/usr/bin/env python3
"""The fun director's measures from runs' events (docs/reviews/2026-11-15-fun-director-consult.md, section 3).

    python3 scripts/fun_report.py <run dir>...

Each run dir holds an events.jsonl written while tracing (sims and visits). Per run:
- beats: the director's beats by kind, its lulls and forecasts;
- lead: a strike force's warning to its first hit, least and median, in seconds;
- finished: strike forces the player destroyed before their lift, of those over;
- told share: the player's buildings lost inside a told window (a beat from its start to its end, a strike force from
  its warning to its lift), of all lost; the rest is the corporations' own operations, Synthexis's waves and anything
  else the director did not announce;
- in truce: buildings lost while a lull's truce held, by anyone, and by the force that killed them where the run
  counted it (0.2.399 on), and by the corporations the lull held: a truce broken;
- peaks: the worst five-minute windows of losses (three), and how many fell inside a told window: the director the
  storyteller of the run when they do;
- peak to valley: the worst five minutes against the median five minutes with any loss;
- quiet: per lull, the minutes from its start to the next minute with a loss, against the lull told (its truce), as
  quiet/told, and how many lulls stayed quiet their truce through (the consult's recovery windows);
- variety: the entropy of the beat kinds drawn (lulls aside), in bits, and the share of beats the same kind as the one
  before.
The loss counts are buildings a minute (the events' minute records), not worth.
"""
import json
import math
import os
import statistics
import sys

TPM = 3600


def lines(path):
    if not os.path.exists(path):
        return []
    return [json.loads(l) for l in open(path) if l.strip()]


def report(run_dir):
    ev = lines(os.path.join(run_dir, "events.jsonl"))
    if not ev:
        return None
    m = lambda t: t / TPM
    beats = [e for e in ev if e["k"] == "beat"]
    kinds = {}
    windows, truces, held = [], [], []
    for b in beats:
        kinds[b.get("kind")] = kinds.get(b.get("kind"), 0) + 1
        if b.get("kind") == "lull":
            truces.append((m(b["t"]), m(b["t"]) + (b.get("truce") or b.get("minutes") or 0)))
            held.append((truces[-1], {"lp-" + c for c in (b.get("corps") or [])}))
        else:
            windows.append((m(b["t"]), m(b["t"]) + (b.get("minutes") or 0)))
    strikes = {}
    for e in ev:
        k = e.get("key")
        if e["k"] == "strike_warn":
            strikes[k] = {"warn": m(e["t"])}
        elif k in strikes and e["k"] == "strike_hit":
            strikes[k]["hit"] = m(e["t"])
        elif k in strikes and e["k"] == "strike_over":
            strikes[k]["over"] = m(e["t"])
            strikes[k]["why"] = e.get("why")
    for s in strikes.values():
        windows.append((s["warn"], s.get("over", 1e9)))
    leads = sorted(round((s["hit"] - s["warn"]) * 60) for s in strikes.values() if "hit" in s)
    over = [s for s in strikes.values() if "over" in s]
    finished = sum(1 for s in over if s.get("why") == "finished")
    # (A minute record holds the minute before it: its losses placed at its middle, t - 0.5.)
    per_min = [(m(e["t"]) - 0.5, (e.get("losses") or {}).get("player:building", 0)) for e in ev if e["k"] == "minute"]
    inside = lambda t, ws: any(a <= t <= b for a, b in ws)
    lost = sum(v for _, v in per_min)
    told = sum(v for t, v in per_min if inside(t, windows))
    in_truce = sum(v for t, v in per_min if inside(t, truces))
    # (By killer, where the run counted it, 0.2.399 on: "player:by:<force>".)
    by, broken = {}, 0
    for e in ev:
        if e["k"] == "minute" and inside(m(e["t"]) - 0.5, truces):
            forces = set().union(*[fs for (a, b), fs in held if a <= m(e["t"]) - 0.5 <= b])
            for k, v in (e.get("losses") or {}).items():
                if k.startswith("player:by:"):
                    by[k[10:]] = by.get(k[10:], 0) + v
                    broken += v if k[10:] in forces else 0
    fives = {}
    for t, v in per_min:
        fives[int(t // 5)] = fives.get(int(t // 5), 0) + v
    worst = sorted(fives.items(), key=lambda kv: -kv[1])[:3]
    worst = [(k, v) for k, v in worst if v > 0]
    peaks_in = sum(1 for k, _ in worst if inside(k * 5 + 2.5, windows))
    nonzero = [v for v in fives.values() if v > 0]
    p2v = round(worst[0][1] / statistics.median(nonzero), 1) if worst and nonzero else 0
    quiet, kept = [], 0
    for a, b in truces:
        nxt = next((t for t, v in per_min if t > a and v > 0), None)
        q = (nxt - a) if nxt is not None else (per_min[-1][0] - a if per_min else 0)
        quiet.append(f"{q:.0f}/{b - a:.0f}")
        kept += 1 if q >= b - a else 0
    drawn = [b.get("kind") for b in sorted(beats, key=lambda e: e["t"]) if b.get("kind") != "lull"]
    counts = {}
    for k in drawn:
        counts[k] = counts.get(k, 0) + 1
    ent = -sum(c / len(drawn) * math.log2(c / len(drawn)) for c in counts.values()) if drawn else 0
    same = sum(1 for x, y in zip(drawn, drawn[1:]) if x == y)
    return {"run": os.path.basename(run_dir.rstrip("/")), "kinds": kinds,
            "quiet": f"{kept}/{len(truces)} ({', '.join(quiet)})" if truces else "-",
            "variety": f"{ent:.2f} bits, {same}/{max(1, len(drawn) - 1)} repeats" if drawn else "-",
            "forecasts": sum(1 for e in ev if e["k"] == "forecast"),
            "lead": f"{leads[0]}/{leads[len(leads) // 2]}" if leads else "-",
            "finished": f"{finished}/{len(over)}", "lost": lost,
            "told": f"{told / lost:.0%}" if lost else "-",
            "in_truce": f"{in_truce}" + (f" ({', '.join(f'{k} {v}' for k, v in sorted(by.items(), key=lambda kv: -kv[1]))};"
                                         f" by the held {broken})" if by else ""),
            "peaks": f"{peaks_in}/{len(worst)}", "p2v": p2v}


def main(dirs):
    rows = [r for r in (report(d) for d in dirs) if r]
    for r in rows:
        k = ", ".join(f"{n} {c}" for n, c in sorted(r["kinds"].items()))
        print(f"{r['run']}: beats {k or 'none'}; forecasts {r['forecasts']}; lead {r['lead']} s; finished {r['finished']}; "
              f"lost {r['lost']}, told {r['told']}, in truce {r['in_truce']}; peaks told {r['peaks']}, peak to valley {r['p2v']}; "
              f"quiet {r['quiet']}; variety {r['variety']}")


if __name__ == "__main__":
    main(sys.argv[1:])
