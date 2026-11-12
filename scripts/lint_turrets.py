"""Every turret of the mod's takes as long to deploy and to fold as vanilla's of its type: a state takes 1 / its speed
ticks whatever its animation's frames (measured, scenario turretmodel, 2026-11-12: Grubstake's gun turret on vanilla's
speeds fired its first round at vanilla's tick, on speeds slowed by its lost frames 50 ticks later). From 0.2.324 to
0.2.350 this lint read a state's time as frames over speed and passed the slowed speeds, every modelled turret five to
fifteen times slower to deploy than vanilla's.

    python3 -I scripts/lint_turrets.py <data-raw-dump.json>
"""
import json, sys

d = json.load(open(sys.argv[1]))
VANILLA = {"ammo-turret": "gun-turret", "electric-turret": "laser-turret", "fluid-turret": "flamethrower-turret"}
# A turret whose nearest vanilla kind is not its type's: Kessler-Hayashi's arc flamer, an electric turret firing a flame
# stream, deploys as vanilla's flamethrower turret does (2026-11-11).
BY_NAME = {"lp-flamer": ("fluid-turret", "flamethrower-turret")}


def frames(a):
    if not a:
        return 1
    l = a["layers"][0] if "layers" in a else a.get("north", a)
    if "layers" in l:
        l = l["layers"][0]
    return l.get("frame_count") or 1


def times(p):
    return (1 / p.get("preparing_speed", 1), 1 / p.get("folding_speed", 1))


bad = []
for ty, ref in VANILLA.items():
    vp, vf = times(d[ty][ref])
    for n, p in d.get(ty, {}).items():
        if not n.startswith("lp-"):
            continue
        tp, tf = times(p)
        r, (rp, rf) = ref, (vp, vf)
        # (Every flamer, each corporation's and the oil one, by kind: all electric turrets, all deploying as the flamethrower.)
        k = "lp-flamer" if (n.endswith("-flamer") or n.endswith("-flamer-oil")) else n
        if k in BY_NAME:
            r = BY_NAME[k][1]
            rp, rf = times(d[BY_NAME[k][0]][r])
        if not (0.9 * rp <= tp <= 1.1 * rp) or not (0.9 * rf <= tf <= 1.1 * rf):
            bad.append(f"{n}: deploys in {tp:.0f} ticks and folds in {tf:.0f}, {r} {rp:.0f} and {rf:.0f}")
if bad:
    print("TURRET LINT FAILED: a turret deploying or folding at other than vanilla's pace (keep its speeds vanilla's)")
    for b in bad:
        print("  " + b)
    sys.exit(1)
print("turret lint ok")
