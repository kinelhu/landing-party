"""Every unit of the mod's that fires a beam is heard: a sound played by its shot (a play-sound effect on its delivery),
its beam's own hum, or a cyclic sound. attack_parameters.sound is "Played once at the start of the attack if these are
ProjectileAttackParameters" (prototype-api), so a beam's was never heard: from the sound pass (2026-11-09) to 0.2.371
the laser drones fired in silence (the user, 2026-11-13, watching an air raid), the trooper's first pulse and the
Tesla trooper's lightning too.

    python3 -I scripts/lint_sounds.py <data-raw-dump.json>
"""
import json, sys

d = json.load(open(sys.argv[1]))
# Never given a sound (they came after the sound round): for the sound pass, deferred until the units' visuals are done.
AWAITING = {"lp-prism", "lp-shock", "lp-grubstake-prism", "lp-grubstake-shock"}


def actions(ammo):
    a = ammo.get("action") if isinstance(ammo, dict) else None
    if isinstance(a, list):
        return a
    return [a] if a else []


def heard(a):
    if a.get("cyclic_sound"):
        return True
    for act in actions(a.get("ammo_type", {})):
        dl = act.get("action_delivery", {})
        for x in dl if isinstance(dl, list) else [dl]:
            se = x.get("source_effects")
            for e in se if isinstance(se, list) else [se]:
                if e and e.get("type") == "play-sound":
                    return True
            b = x.get("beam")
            if b and d.get("beam", {}).get(b, {}).get("working_sound"):
                return True
    return False


silent = []
for name, u in sorted(d.get("unit", {}).items()):
    a = u.get("attack_parameters", {})
    if name.startswith("lp-") and a.get("type") == "beam" and name not in AWAITING and not heard(a):
        silent.append(name)
if silent:
    print("sound lint: beam units with no sound heard: " + ", ".join(silent))
    sys.exit(1)
print("sound lint ok")
