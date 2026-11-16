#!/usr/bin/env python3
"""The unit roster (docs/units.md), written from the game's own prototypes, never typed: every unit's health, speed,
weapon (damage a shot, range, rate), resistances and who fields it. Run scripts/check.sh first (it dumps the prototypes),
then: python3 -I scripts/roster.py [dump.json]. Who fields what is read from landing-party/shared.lua (mixes, tree nodes,
costs); the player's units from their recipes."""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/Library/Application Support/factorio-lp-check/script-output/data-raw-dump.json")
d = json.load(open(DUMP))
shared = open(os.path.join(REPO, "landing-party", "shared.lua")).read()
# The names players see (the internal ids stay serenity and grubstake; the user renamed them, 2026-10-21).
SHOWN = {"serenity": "Kessler-Hayashi", "grubstake": "Grubstake"}

PLATES = ("-fire", "-laser", "-physical", "-explosion", "-electric")
# What each unit is for (words only: every number below comes from the prototypes).
ROLE = {
    "lp-infantry": "Kessler-Hayashi's basic soldier, armed with a laser rifle. Most of its raiding force",
    "lp-tank": "An armored tank. Its shells do extra damage to buildings",
    "lp-walker": "A spider-legged machine that walks over walls and fires rockets",
    "lp-harrier": "A cheap, weak flier with a gun, sent in numbers. Flies over walls, cliffs and water",
    "lp-laser-drone": "An armored flier with a laser. Expensive, so there are few of them",
    "lp-railgunner": "Clears biter spawners. Its slug pierces a few biters and stops: 250 to spawners, worms, incubators and tumors, 40 to biters on their feet, 10 to anything else; Kessler-Hayashi's railguns research raises both (+60% a level)",
    # (Each corporation's its own since 0.2.429: Kessler-Hayashi's a carrier on its tank hull, Grubstake's a truck.)
    "lp-hauler": "A lightly armed carrier. Kessler-Hayashi's rides its tank hull and takes exports by convoy; Grubstake's is a truck that builds, carries and skims",
    "lp-buggy": "A fast buggy with a machine gun. Grubstake's raider and escort",
    "lp-shotgun-hand": "Grubstake's soldier, with a shotgun. Deadly up close, useless against a turret line",
    "lp-lance": "A laser trooper with a heavier beam that outranges your troopers",
    "lp-shock": "Its electric beam jumps from target to target and stuns them briefly. Used against groups of troopers",
    "lp-aegis": "A heavy tank with a rail cannon. Its slug ignores armor; used against your battle tanks",
    "lp-slug": "A buggy with a slug gun, used against your vehicles",
    "lp-sapper": "Throws dynamite over 3 tiles, at groups of units and at walls in its way. Spares its own side",
    "lp-dozer": "Rams walls open for the shotgun hands behind it",
    "lp-scavenger": "Flies at your artillery, mortars and radars and explodes on them",
    "lp-prism": "A tank whose laser splits from its target to the units around it. Used against groups of troopers",
    "lp-tesla": "A tank whose lightning jumps along a turret line and drains the turrets it hits",
    "lp-scorcher": "An old tank hull with a machine gun and a flamethrower that fires three bursts, then reloads slowly",
    "lp-skyguard": "Its long laser tracks fliers. Weak against ground targets",
    "lp-flak-buggy": "A buggy with a flak gun against fliers. Weak against ground targets",
    "lp-bred-scout": "Synthexis's scout: circles your defenses before a wave and picks the weakest side. Fast and frail",
    "lp-trooper": "Your basic soldier, with a submachine gun",
    "lp-breacher": "Carries demolition charges for walls. Does little to units",
    "lp-rocket-trooper": "Fires rockets, good against armor and fliers. Slow to kill a crowd",
    "lp-flame-trooper": "A flamethrower against swarms of biters and bunched infantry. Outranged, and weak against armor",
    "lp-battle-tank": "Your heavy tank, for attacking bases",
}


def corp_of(line_no):
    """The CORPS section a shared.lua line falls in."""
    best = None
    for m in re.finditer(r"^\s*(grubstake|serenity) = \{", shared, re.M):
        if shared.count("\n", 0, m.start()) <= line_no:
            best = m.group(1)
    return best


fielded = {}
for m in re.finditer(r"mix = \{([^}]*)\}", shared):
    corp = corp_of(shared.count("\n", 0, m.start()))
    for k in re.findall(r'\["(lp-[a-z-]+)"\]', m.group(1)):
        fielded.setdefault(k, []).append(f"{SHOWN[corp]} (from landing)")
for m in re.finditer(r'\{id = "([a-z-]+)", branch = "([a-z-]+)", era = (\d+)(?:, requires = "([a-z]+)")?, cost = (\d+), '
                     r'unit = \{kind = "(lp-[a-z-]+)"', shared):
    corp = corp_of(shared.count("\n", 0, m.start()))
    req = f", after {m.group(4)}" if m.group(4) else ""
    fielded.setdefault(m.group(6), []).append(
        f"{SHOWN[corp]}, research: {m.group(2)} branch, era {m.group(3)}{req}, {m.group(5)} fund")
renamed = re.search(r'bases = \{[^}]*\["lp-infantry"\] = "(lp-[a-z-]+)"', shared)
if renamed:
    fielded.setdefault(renamed.group(1), []).append("Grubstake (from landing, as its infantry)")
cost = {k: int(c) for k, c in re.findall(r'\["(lp-[a-z-]+)"\] = \{health = \d+, cost = (\d+)[,}]', shared)}
# Who cannot shoot up (landing-party/air.lua): the kinds marked ground_only, and the player's cannon and charges.
ground_only = set(re.findall(r'\["(lp-[a-z-]+)"\] = \{[^}]*ground_only = true', shared)) | {"lp-battle-tank", "lp-breacher"}
# The player's units cost no parts; their bandwidth instead (shared.POPULATION).
bandwidth = {k: int(c) for k, c in re.findall(r'\["(lp-[a-z-]+)"\] = (\d+)', re.search(r"shared.POPULATION = \{([^}]*)\}", shared).group(1))}
for k in ("lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-flame-trooper", "lp-battle-tank"):
    fielded.setdefault(k, []).append("the player (a barracks)")
fielded.setdefault("lp-hauler", []).append("both (convoys; Grubstake's builders)")


def dmg_of(effects):
    out = []
    for e in effects if isinstance(effects, list) else [effects]:
        if not isinstance(e, dict):
            continue
        if e.get("type") == "damage":
            out.append((e["damage"]["amount"], e["damage"]["type"], ""))
        if e.get("type") == "nested-result":
            out += damage(e.get("action"))
    return out


def damage(action, mult=1):
    """[(amount, type, note)] one shot deals, following projectiles, beams and areas."""
    out = []
    for a in action if isinstance(action, list) else [action]:
        if not isinstance(a, dict):
            continue
        rep = a.get("repeat_count", 1)
        # air.lua's small circle round a single hit (it skips fliers) is still a single hit.
        wrap = a.get("type") == "area" and a.get("radius") == 0.3 and a.get("trigger_target_mask") == ["common"]
        area = f" over {a['radius']} tiles" if a.get("type") == "area" and not wrap else ""
        only = " to buildings, on top of the hit" if a.get("entity_flags") == ["placeable-neutral"] else ""
        deliveries = a.get("action_delivery") or []
        for dl in deliveries if isinstance(deliveries, list) else [deliveries]:
            hits = []
            if dl.get("type") == "instant":
                hits = dmg_of(dl.get("target_effects") or [])
            elif dl.get("type") == "projectile":
                p = d["projectile"].get(dl["projectile"], {})
                hits = damage(p.get("action"))
            elif dl.get("type") == "beam":
                b = d["beam"].get(dl["beam"], {})
                hits = damage(b.get("action"))
            elif dl.get("type") == "chain":
                hits = [(0, "chain", " (arcs to the next targets)")]
            for amt, typ, note in hits:
                out.append((amt * mult, typ, (f" (x{rep})" if rep > 1 else "") + area + only + note))
    return out


def weapon(u):
    ap = u.get("attack_parameters") or {}
    mult = ap.get("damage_modifier", 1)
    hits = damage((ap.get("ammo_type") or {}).get("action"), mult)
    shots = []
    for amt, typ, note in hits:
        if typ == "chain":
            shots.append(note.strip())
        else:
            shots.append(f"{amt:g} {typ}{note}")
    if (u.get("name") or "").endswith("railgunner") and len(shots) == 2:
        shots = [shots[0] + " to biters, spawners and worms", shots[1] + " to anything else"]
    rate = 60 / ap["cooldown"] if ap.get("cooldown") else 0
    return "; ".join(shots) or "-", ap.get("range", "-"), f"{rate:.2g}/s" if rate else "-"


def resist(u):
    parts = []
    for r in u.get("resistances") or []:
        s = r["type"]
        if r.get("decrease"):
            s += f" -{r['decrease']:g}"
        if r.get("percent"):
            s += f" {r['percent']:g}%"
        parts.append(s)
    return ", ".join(parts) or "-"


rows = []
for kind in ("unit", "spider-unit"):
    for name, u in sorted(d.get(kind, {}).items()):
        if not name.startswith("lp-") or name.startswith("lp-grubstake-") or name.endswith(PLATES):
            continue
        w, rng, rate = weapon(u)
        speed = u.get("movement_speed")
        if speed is None and kind == "spider-unit":
            speed_s = "walks"
        else:
            speed_s = f"{speed * 60:.1f} tiles/s"
        rows.append((name, u["max_health"], speed_s, w, rng, rate, resist(u), "no" if name in ground_only else "yes",
                     f"{cost[name]} parts" if name in cost else f"{bandwidth[name]} bandwidth" if name in bandwidth else "-",
                     "; ".join(fielded.get(name, ["-"])), ROLE.get(name, "")))

def write_md():
    out = ["# Unit roster", "",
           "Written by `scripts/roster.py` from the game's prototypes (`scripts/check.sh` dumps them) and `shared.lua`:",
           "do not edit by hand. Damage is one shot's, before research and plates (a corporation's research raises its",
           "category's damage; a plated unit carries extra resistance). Grubstake's copies (`lp-grubstake-*`) share these",
           "stats in its colours. Hits air: whether its weapon can touch a flier (`landing-party/air.lua`); one that cannot",
           "turns from a flier to a ground target it can hurt (`landing-party/scripts/aim.lua`).", ""]
    for name, hp, speed, w, rng, rate, res, air, c, who, role in rows:
        out += [f"## {name[3:]}", "", role + ("." if role else ""), "",
                "| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |",
                "| --- | --- | --- | --- | --- | --- | --- | --- |",
                f"| {hp:g} | {speed} | {w} | {rng} | {rate} | {res} | {air} | {c} |", "", f"Fielded by: {who}.", ""]
    path = os.path.join(REPO, "docs", "units.md")
    open(path, "w").write("\n".join(out))
    print(f"{path}: {len(rows)} units")


if __name__ == "__main__":
    write_md()
