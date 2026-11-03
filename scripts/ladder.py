"""The ladder's verdict: each faction's razing of the player's buildings, per save and seed, with Kessler-Hayashi's sieges.

Reads the visit runs docs/sim/visit-<save>-<mix>-<tag>-seed<N>/ (scripts/visit.sh with LP_MIX=<mix>-<tag>-seed<N>).

    python3 -I scripts/ladder.py <tag> [<tag> ...]
"""
import glob
import json
import re
import statistics as st
import sys


def razed_total(text, pattern):
    m = re.search(pattern, text)
    return sum(int(x) for x in re.findall(r"= (\d+)", m.group(1))) if m else 0


def run(d):
    r = open(d + "/results.txt").read()
    dec = open(d + "/decisions.txt").read()
    kh, stood = 0, []
    for line in r.splitlines():
        if line.startswith('INFO {"id"'):
            s = json.loads(line[5:])
            if s["corp"] == "serenity":
                kh += s["razed"]
                stood.append(not s.get("fallen"))
    gs = sum(int(x) for x in re.findall(r"grubstake \d+: garrison \d+, razed (\d+)", r))
    syn = razed_total(r, r"Synthexis landed.*razed of the player's (\{.*\})")
    sieges = len(re.findall(r"base \d+  siege of (?!biter|spitter|medium-worm|big-worm|behemoth)", dec))
    strikes = len(re.findall(r"orbital strike: falls", dec))
    return {"kh": kh, "gs": gs, "syn": syn, "sieges": sieges, "strikes": strikes, "stood": all(stood) if stood else None,
            "passed": "ALL PASSED" in r}


def main(tags):
    for tag in tags:
        print(f"== {tag}")
        for d in sorted(glob.glob(f"docs/sim/visit-*-{tag}-seed1")):
            base = d[: -len("seed1")]
            save = d.split("/visit-")[1].split("-")[0]
            rows = []
            for n in (1, 2, 3):
                try:
                    rows.append(run(base + f"seed{n}"))
                except FileNotFoundError:
                    pass
            if not rows:
                continue
            def col(k):
                v = [x[k] for x in rows]
                return f"{v} mean {st.mean(v):.0f}"
            print(f"  {save:10s} KH {col('kh')} | sieges on the player {[x['sieges'] for x in rows]}, strikes "
                  f"{[x['strikes'] for x in rows]} | Synthexis {col('syn')} | Grubstake {col('gs')} | KH stood "
                  f"{[x['stood'] for x in rows]}")


if __name__ == "__main__":
    main(sys.argv[1:])
