"""The attacker's contract, read off siege lab runs: what every faction's attacks must do, from their records alone.

    python3 scripts/contract.py docs/sim/lab-<run> [more runs]

Each run's lab.jsonl (scripts/siegelab.sh run) holds one trial a line; a trial's attempt block is the observer's
(attempt.lua, oplog.lua: sent, lost, got, in and when, read from where its units stood). The contract is what this week's
Synthexis bugs taught (the user, 2026-10-31: lessons from Synthexis for the other factions), as checks any attacker's runs
pass or fail:

  attacks      it attacks: not every trial held (a culture that held forever behind a fort it had got into, 0.2.100)
  recovers     after a run of trials that held, it attacks again (a hold counted once ever, four trials lost, 0.2.101)
  changes      after two failures in a row, what it sends changes: its method, its specialists or its size by a quarter
               (one ram at two walls, four trials, then it held, 0.2.105; Kessler-Hayashi's raids at a laser wall, 0.2.111)
  honest       its own "in" is the observer's, no more than 3 s ahead of it (through from outside the wall, 0.2.104)
  pays         what it loses in a trial that got nothing is no more than what it sent (lost counted once, 0.2.100)

A faction that takes soft targets alone (Grubstake: a fort is not its to break, docs/corporations.md) holds by design where
there is none, so in place of recovers:

  soft         none of its attacks on the player went at a walled place (ten wall pieces or more by it, its record's sig)

Prints one line a check a run, PASS or FAIL with what decided it, and exits 1 if any failed.
"""
import json
import sys

SOFT_ONLY = {"grubstake"}   # factions whose temper keeps them off a walled place (shared.lua: temper.soft_only)
from pathlib import Path


def trials(run):
    return [json.loads(l) for l in open(Path(run) / "lab.jsonl") if l.strip()]


def sent_of(t):
    a, sg, w = t.get("attempt") or {}, t.get("siege") or {}, t.get("wave") or {}
    return {"method": a.get("method") or ("siege" if sg else "raid"), "rams": sg.get("k", 0) if sg else 0,
            "size": a.get("sent") or w.get("worth") or 0}


def failed(t):
    a, w = t.get("attempt") or {}, t.get("wave") or {}
    if t.get("outcome") not in ("wave", "op"):
        return False
    inside = a["inside"] if "inside" in a else w.get("t_inside") is not None
    return not inside


def check(run):
    ts = trials(run)
    out = []
    attacked = [t for t in ts if t.get("outcome") in ("wave", "op")]
    out.append(("attacks", len(attacked) > 0, f"{len(attacked)} of {len(ts)} trials attacked"))
    # recovers: a hold followed by an attack within the run, unless the run ends holding with nothing after
    holds, recovered, stuck = 0, True, 0
    for i, t in enumerate(ts):
        if t.get("outcome") == "held":
            holds += 1
            stuck += 1
        else:
            stuck = 0
    recovered = stuck < 3
    faction = next((t.get("faction") for t in ts if t.get("faction")), "biotech")
    if faction in SOFT_ONLY:
        walled = [t["trial"] for t in ts if (t.get("op") or {}).get("owner") == "player"
                  and ((t.get("attempt") or {}).get("sig") or {}).get("walls", 0) >= 10]
        out.append(("soft", not walled, f"at a walled place of the player's at trials {walled}" if walled
                    else f"no walled place of the player's attacked ({holds} held, by design)"))
    else:
        out.append(("recovers", recovered, f"{holds} held, {stuck} at the end in a row"))
    # changes: after two failures in a row, the next attack differs
    same, cases = [], 0
    for i in range(2, len(ts)):
        a, b, c = ts[i - 2], ts[i - 1], ts[i]
        if failed(a) and failed(b) and c.get("outcome") in ("wave", "op"):
            cases += 1
            sb, sc = sent_of(b), sent_of(c)
            changed = (sb["method"] != sc["method"] or sb["rams"] != sc["rams"]
                       or abs(sc["size"] - sb["size"]) > 0.25 * max(1, sb["size"]))
            if not changed:
                same.append(c["trial"])
    out.append(("changes", not same, f"{cases} after two failures, unchanged at trials {same}" if same else f"{cases} after two failures, each changed"))
    # honest: own claim vs observer (Synthexis's waves carry their own t_inside)
    lies = []
    for t in ts:
        a, w = t.get("attempt") or {}, t.get("wave") or {}
        own, obs = w.get("t_inside"), a.get("tick_inside")
        # (No observer's record, a run from before attempt.lua: nothing to hold its claim to.)
        if not a:
            continue
        if own is not None and (obs is None or own < obs - 180):
            lies.append(t["trial"])
    out.append(("honest", not lies, f"in before the observer at trials {lies}" if lies else "every claim the observer's"))
    # pays: lost no more than sent
    over = [t["trial"] for t in ts if (t.get("attempt") or {}).get("lost", 0) > (t.get("attempt") or {}).get("sent", 0) + 1e-6]
    out.append(("pays", not over, f"lost more than sent at trials {over}" if over else "lost within sent"))
    return out


def main(runs):
    bad = 0
    for run in runs:
        if not (Path(run) / "lab.jsonl").exists():
            continue
        for name, ok, why in check(run):
            print(f"{Path(run).name:28} {name:9} {'PASS' if ok else 'FAIL'}  {why}")
            bad += 0 if ok else 1
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
