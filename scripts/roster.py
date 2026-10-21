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

PLATES = ("-fire", "-laser", "-physical", "-explosion", "-electric")
# What each unit is for (words only: every number below comes from the prototypes).
ROLE = {
    "lp-infantry": "Serenity's Line trooper: a laser beam; the bulk of its raids",
    "lp-tank": "armour; cannon rounds that hit buildings three times as hard as units",
    "lp-walker": "a spider: steps over walls, rockets",
    "lp-harrier": "air: flies over walls, cliffs and water; turrets that cannot shoot up ignore it",
    "lp-railgunner": "Serenity's nest clearer: a slug through a 30-tile line, deadly to biters, a scratch to walls",
    "lp-hauler": "convoys and Grubstake's building trucks; lightly armed",
    "lp-buggy": "Grubstake's raider and escort: fast, a machine gun",
    "lp-shotgun-hand": "Grubstake's infantry: three heavy pellets, deadly at the fence, useless against a turret line",
    "lp-lance": "Optics: a heavier beam that outranges the player's troopers",
    "lp-shock": "Optics: an arcing electric beam that jumps target to target, a brief stun; against massed troopers",
    "lp-aegis": "Line: a laser cannon on an armoured hull; against the player's battle tanks",
    "lp-slug": "Scrap arms: slugs; against the player's vehicles",
    "lp-sapper": "Scrap arms: dynamite over 3 tiles, enemies only; against blobs, and the wall in the way",
    "lp-dozer": "Wheels: a ram that pushes a wall open for the shotguns",
    "lp-scavenger": "Wheels: a harrier with rockets, for the player's artillery, mortars and radars",
    "lp-prism": "Optics: a laser that splits on what it hits to the targets round it; against massed troopers",
    "lp-tesla": "Siege: lightning that jumps along a turret line and drains what it strikes of its charge",
    "lp-scorcher": "Scrap arms: a machine gun, and three bursts of flame for walls, turrets and packs, refilled slowly",
    "lp-trooper": "the player's: a rifle",
    "lp-breacher": "the player's: demolition charges, for walls",
    "lp-battle-tank": "the player's siege weapon",
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
        fielded.setdefault(k, []).append(f"{corp.capitalize()} (from landing)")
for m in re.finditer(r'\{id = "([a-z]+)", branch = "([a-z-]+)", era = (\d+)(?:, requires = "([a-z]+)")?, cost = (\d+), '
                     r'unit = \{kind = "(lp-[a-z-]+)"', shared):
    corp = corp_of(shared.count("\n", 0, m.start()))
    req = f", after {m.group(4)}" if m.group(4) else ""
    fielded.setdefault(m.group(6), []).append(
        f"{corp.capitalize()}, research: {m.group(2)} branch, era {m.group(3)}{req}, {m.group(5)} fund")
renamed = re.search(r'bases = \{[^}]*\["lp-infantry"\] = "(lp-[a-z-]+)"', shared)
if renamed:
    fielded.setdefault(renamed.group(1), []).append("Grubstake (from landing, as its infantry)")
cost = {k: int(c) for k, c in re.findall(r'\["(lp-[a-z-]+)"\] = \{health = \d+, cost = (\d+)\}', shared)}
for k in ("lp-trooper", "lp-breacher", "lp-battle-tank"):
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
        area = f" over {a['radius']} tiles" if a.get("type") == "area" else ""
        only = " to buildings" if a.get("entity_flags") == ["placeable-neutral"] else ""
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
        shots = [shots[0] + " to biters, nests and worms", shots[1] + " to anything else"]
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
        rows.append((name, u["max_health"], speed_s, w, rng, rate, resist(u), cost.get(name, "-"),
                     "; ".join(fielded.get(name, ["-"])), ROLE.get(name, "")))

def write_md():
    out = ["# Unit roster", "",
           "Written by `scripts/roster.py` from the game's prototypes (`scripts/check.sh` dumps them) and `shared.lua`:",
           "do not edit by hand. Damage is one shot's, before research and plates (a corporation's research raises its",
           "category's damage; a plated unit carries extra resistance). Grubstake's copies (`lp-grubstake-*`) share these",
           "stats in its colours.", ""]
    for name, hp, speed, w, rng, rate, res, c, who, role in rows:
        out += [f"## {name[3:]}", "", role + ("." if role else ""), "",
                "| Health | Speed | A shot | Range | Rate | Resists | Cost (parts) |", "| --- | --- | --- | --- | --- | --- | --- |",
                f"| {hp:g} | {speed} | {w} | {rng} | {rate} | {res} | {c} |", "", f"Fielded by: {who}.", ""]
    path = os.path.join(REPO, "docs", "units.md")
    open(path, "w").write("\n".join(out))
    print(f"{path}: {len(rows)} units")


if __name__ == "__main__":
    write_md()
