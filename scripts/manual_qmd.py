"""The player manual's generated parts (docs/manual), written by `python3 -I scripts/roster_page.py --qmd`.

Everything a chapter states as a number or lists as a table comes from here, read from the game's prototypes (the dump
scripts/check.sh writes), landing-party/shared.lua, the scripts and the locale, so no chapter types a number:
  _variables.yml           values the prose reads with {{< var ... >}}
  _generated/*.qmd         tables the chapters include: units, buildings, breeds, eras, levels, salvage, technologies,
                           settings, commands
  media/units, media/vistas   the field guide's portraits and vistas (docs/guide/img), made smaller
A value this cannot find stops it with the pattern that missed: a manual quietly missing a number is worse than no
manual. Names are the game's own (the dump's localised names, the mod's locale, the base game's locale).
"""
import os, re, shutil, subprocess

NON_ENTITY = {"item", "recipe", "technology", "item-with-entity-data", "ammo", "gun", "capsule", "tool", "armor",
              "module", "item-group", "item-subgroup", "tile", "fluid", "virtual-signal", "shortcut", "custom-input",
              "damage-type", "explosion", "corpse", "spider-leg", "delayed-active-trigger", "projectile", "beam",
              "sticker", "smoke-with-trigger", "fire", "stream", "particle", "optimized-particle", "trivial-smoke",
              "artillery-flare", "artillery-projectile", "rail-planner", "selection-tool", "spidertron-remote",
              "repair-tool", "blueprint", "deconstruction-item", "upgrade-item", "blueprint-book", "copy-paste-tool"}


def write(rp):
    M = os.path.join(rp.REPO, "docs", "manual")
    GEN = os.path.join(M, "_generated")
    os.makedirs(GEN, exist_ok=True)
    os.makedirs(os.path.join(M, "media", "units"), exist_ok=True)
    os.makedirs(os.path.join(M, "media", "vistas"), exist_ok=True)
    d = rp.roster.d
    loc = rp.locale
    missed = []

    def src(rel):
        return open(os.path.join(rp.MOD, rel)).read()

    def grab(text, pattern, what):
        m = re.search(pattern, text, re.M)
        if not m:
            missed.append(f"{what}: /{pattern}/")
            return None
        return m.group(1)

    def num(text, pattern, what):
        v = grab(text, pattern, what)
        return None if v is None else float(v)

    def minutes(text, name, what):
        """A Lua tick constant (`local NAME = 20 * 60 * 60` or `= 20 * 3600`) in minutes."""
        v = grab(text, rf"^\s*local {name}\s*=\s*([\d\s\*\.]+?)\s*(?:--|$)", what)
        if v is None:
            return None
        t = 1.0
        for f in v.split("*"):
            t *= float(f)
        return t / 3600

    def product(text, pattern, what):
        """A Lua product of numbers (`30 * 60 * 60`), as a number; 0 when not found (and recorded missed)."""
        v = grab(text, pattern, what)
        t = 1.0
        for f in (v or "0").split("*"):
            t *= float(f)
        return t

    dome_src, orbital_src, ledger_src, war_src = src("scripts/dome.lua"), src("scripts/orbital.lua"), src("scripts/ledger.lua"), src("scripts/war.lua")

    # ---- the base game's names (science packs, prerequisites, the bred biters' bodies) ----
    vanilla = {}
    app = os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents")
    for part in ("core", "base", "space-age"):
        p = os.path.join(app, "data", part, "locale", "en", f"{part}.cfg")
        if not os.path.exists(p):
            continue
        sec = None
        for line in open(p, encoding="utf-8"):
            line = line.rstrip("\n")
            m = re.match(r"^\[(.+)\]$", line)
            if m:
                sec = m.group(1)
            elif "=" in line and sec:
                k, v = line.split("=", 1)
                vanilla.setdefault((sec, k), v)

    def lname(key):
        sec, k = key.split(".", 1)
        return loc.get((sec, k)) or vanilla.get((sec, k)) or k

    def resolve(ls):
        if isinstance(ls, str):
            return ls
        key, params = ls[0], [resolve(p) for p in ls[1:]]
        if key == "":
            return "".join(params)
        if key == "?":
            return params[0] if params else ""
        t = lname(key)
        for i, p in enumerate(params, 1):
            t = t.replace(f"__{i}__", p)
        return t

    ENT = {}
    for t, v in d.items():
        if t in NON_ENTITY or not isinstance(v, dict):
            continue
        for k, e in v.items():
            if isinstance(e, dict) and "max_health" in e and k not in ENT:
                ENT[k] = (t, e)

    def shown(name):
        """The name the game shows, less the ' (Kessler-Hayashi)' its tooltips add: tables are by faction."""
        e = ENT.get(name, (None, {}))[1]
        n = resolve(e["localised_name"]) if e.get("localised_name") else lname("entity-name." + name)
        return re.sub(r" \((Kessler-Hayashi|Grubstake)\)$", "", n)

    def health(name):
        e = ENT.get(name)
        return fmt(e[1]["max_health"]) if e else "-"

    def damage_word(s):
        for k in ("lp-bite", "lp-rail", "lp-mend"):
            s = s.replace(k, loc.get(("damage-type-name", k), k[3:]).lower())
        return s

    def ordinal(n):
        return {1: "", 2: "second", 3: "third", 4: "fourth"}.get(n, f"{n}th")

    def md(s):
        return s.replace("|", "/").replace("*", "\\*")

    # ---- media ----
    def copy_png(rel):
        """docs/guide/img/x.png to media/units/x.png, made smaller; returns the manual's path."""
        name = os.path.basename(rel)
        dst = os.path.join(M, "media", "units", name)
        srcp = os.path.join(rp.OUT, rel)
        if shutil.which("sips"):
            subprocess.run(["sips", "-Z", "160", srcp, "--out", dst], capture_output=True, check=True)
        else:
            shutil.copy(srcp, dst)
        return f"media/units/{name}"

    # ---- sources ----
    shared_src, phases_src, faction_src = src("shared.lua"), src("scripts/phases.lua"), src("scripts/faction.lua")
    ops_src, rd_src, farm_src, cell_src = src("scripts/ops.lua"), src("scripts/rd.lua"), src("scripts/farm.lua"), src("scripts/cell.lua")
    perim_src, learn_src, comp_src = src("scripts/perimeter.lua"), src("scripts/herd_learn.lua"), src("components.lua")
    pact_src, control_src, biotech_src, dev_src = src("scripts/pact.lua"), src("control.lua"), src("biotech.lua"), src("scripts/dev.lua")
    settings_src = src("settings.lua")
    import json
    info = json.load(open(os.path.join(rp.MOD, "info.json")))
    corps = rp.data["corps"]
    KH, GS = corps["serenity"], corps["grubstake"]

    # ---- values for the prose ----
    def fmt(x):
        if x is None:
            return "?"
        return f"{x:,.0f}" if abs(x - round(x)) < 1e-9 else f"{x:g}"

    esc_m = re.search(r"local n = (\d+) \+ (\d+) \* \(faction\.corp\(b\.corp\)\.level or 0\) \+ math\.floor\((\d+) \* evo\)", faction_src)
    if not esc_m:
        missed.append("faction.lua: the drop escort's formula")
    core_depot = num(control_src, r'kind == "lp-depot" then command\.drop_cores\(ent\.surface, ent\.position, (\d+)\)', "control: depot cores")
    core_lander = num(control_src, r'kind == "lp-lander" then\s*\n\s*command\.drop_cores\(ent\.surface, ent\.position, (\d+)\)', "control: lander cores")
    crystal_p = num(pact_src, r"math\.random\(\) < ([\d.]+)", "pact: crystal chance")
    gland = re.search(r'pen\.loot = \{\{type = "item", name = "lp-pheromone-gland".*?amount_min = (\d+), amount_max = (\d+)', biotech_src)
    if not gland:
        missed.append("biotech.lua: the incubator's glands")
    climb = num(farm_src, r"^local CLIMB = ([\d.]+)", "farm CLIMB")
    tune = dict(re.findall(r'\[?"?([a-z-]+)"?\]? = ([\d.]+)', grab(shared_src, r"^shared\.TUNE = \{([^}]*)\}", "TUNE") or ""))
    V = {
        "arrival": {
            "signs_tiles": fmt(num(phases_src, r"^local SIGNS_DISTANCE = (\d+)", "SIGNS_DISTANCE")),
            "survey_tiles": fmt(num(phases_src, r"^local SURVEY_DISTANCE = (\d+)", "SURVEY_DISTANCE")),
            "survey_stays_min": fmt(minutes(phases_src, "SURVEY_TICKS", "SURVEY_TICKS")),
            "survey_killed_delay_min": fmt(minutes(phases_src, "DELAY", "DELAY")),
            "survey_left_min": fmt(minutes(phases_src, "EARLY", "EARLY")),
            "late_min": fmt(minutes(phases_src, "LATE_HASTE", "LATE_HASTE")),
            "cadence_min": fmt(minutes(faction_src, "CADENCE", "CADENCE")),
            "haste_min": fmt(minutes(faction_src, "HASTE", "HASTE")),
            "max_alive": fmt(num(faction_src, r"^local MAX_ALIVE = (\d+)", "MAX_ALIVE")),
            "max_per_corp": fmt(num(faction_src, r"^local MAX_PER_CORP = (\d+)", "MAX_PER_CORP")),
            "apart_tiles": fmt(num(faction_src, r"^local APART = (\d+)", "APART")),
            "squat_tiles": fmt(num(faction_src, r"^local SQUAT_DISTANCE = (\d+)", "SQUAT_DISTANCE")),
            "escort_base": esc_m.group(1) if esc_m else "?",
            "escort_level": esc_m.group(2) if esc_m else "?",
            "escort_evo": esc_m.group(3) if esc_m else "?",
            "hq_floor_h": fmt((minutes(faction_src, "HQ_FLOOR", "HQ_FLOOR") or 0) / 60),
            "consolidate_min": fmt(minutes(faction_src, "CONSOLIDATE", "CONSOLIDATE")),
            "hq_tiles": fmt(num(faction_src, r"^local HQ_DISTANCE = (\d+)", "HQ_DISTANCE")),
            "withdraw_min": fmt(minutes(faction_src, "WITHDRAW", "WITHDRAW")),
            "vacancy_min": fmt(minutes(faction_src, "VACANCY_HASTE", "VACANCY_HASTE")),
            "armed_era": fmt(num(shared_src, r"armed_era = (\d+)", "armed_era")),
            "armed_level": fmt(num(shared_src, r"armed_level = (\d+)", "armed_level")),
            "floor_min": fmt(minutes(perim_src, "FLOOR_TICKS", "FLOOR_TICKS")),
            "research_every_min": fmt(minutes(rd_src, "CHOICE_TICKS", "CHOICE_TICKS")),
            "research_window_min": fmt(minutes(rd_src, "WINDOW_TICKS", "WINDOW_TICKS")),
            "fund_share_pct": fmt(100 * (num(rd_src, r"^local FUND_SHARE, FUND_CAP = ([\d.]+)", "FUND_SHARE") or 0)),
            "weapon_levels": fmt(num(rd_src, r"^local LEVEL_COST, LEVEL_DAMAGE, MAX_LEVEL = \d+, [\d.]+, (\d+)", "MAX_LEVEL")),
            "weapon_level_pct": fmt(100 * (num(rd_src, r"^local LEVEL_COST, LEVEL_DAMAGE, MAX_LEVEL = \d+, ([\d.]+)", "LEVEL_DAMAGE") or 0)),
        },
        "synthexis": {
            "arrive_evo": fmt(num(farm_src, r"^local ARRIVE_EVO = ([\d.]+)", "ARRIVE_EVO")),
            "clear_tiles": fmt(num(farm_src, r"^local FED_NEAR = (\d+)", "FED_NEAR")),
            "far_tiles": fmt(num(farm_src, r"^local FAR, FARTHEST = (\d+)", "FAR")),
            "farthest_tiles": fmt(num(farm_src, r"^local FAR, FARTHEST = \d+, (\d+)", "FARTHEST")),
            "pens": fmt(num(farm_src, r"^local PENS = (\d+)", "PENS")),
            "pens_max": fmt(num(farm_src, r"^local PENS_MAX = (\d+)", "PENS_MAX")),
            "pen_cap": fmt(num(shared_src, r"^shared\.PEN_CAP = (\d+)", "PEN_CAP")),
            "first_wave_min": fmt(minutes(farm_src, "FIRST_WAVE", "FIRST_WAVE")),
            "wave_gap_min": fmt(minutes(farm_src, "WAVE_GAP", "WAVE_GAP")),
            "wave_min": fmt(num(shared_src, r"^shared\.WAVE_MIN = (\d+)", "WAVE_MIN")),
            "wave_max": fmt(num(shared_src, r"^shared\.WAVE_MAX = (\d+)", "WAVE_MAX")),
            "wave_huge": fmt(num(farm_src, r"^local CAP_PENS, WAVE_HUGE = \d+, (\d+)", "WAVE_HUGE")),
            "cap_pens": fmt(num(farm_src, r"^local CAP_PENS, WAVE_HUGE = (\d+)", "CAP_PENS")),
            "home_guard": fmt(num(farm_src, r"^local HOME_GUARD = (\d+)", "HOME_GUARD")),
            "reland_min": fmt(minutes(farm_src, "RELAND", "RELAND")),
            "starve_min": fmt(minutes(farm_src, "STARVE", "STARVE")),
            "fed_cap": fmt(num(farm_src, r"^local FED_CAP = (\d+)", "FED_CAP")),
            "unfed_wild_min": fmt(minutes(farm_src, "UNFED_WILD", "UNFED_WILD")),
            "climb_per_hour": fmt(round((climb or 0) * 60, 4)),
            "lead": fmt(num(farm_src, r"^local LEAD = ([\d.]+)", "LEAD")),
            "stock_evo": fmt(num(farm_src, r"^local STOCK_EVO = ([\d.]+)", "STOCK_EVO")),
            "clinic_wait_min": fmt(minutes(cell_src, "CLINIC_WAIT", "CLINIC_WAIT")),
            "trickle": fmt(num(farm_src, r"^local TRICKLE = (\d+)", "TRICKLE")),
            "start_biomass": fmt(num(farm_src, r"^local START_BIOMASS = (\d+)", "START_BIOMASS")),
            "order_breach_pct": fmt(100 * (num(farm_src, r"^local ORDER_BREACH = ([\d.]+)", "ORDER_BREACH") or 0)),
            "order_wait_min": fmt(minutes(farm_src, "ORDER_WAIT", "ORDER_WAIT")),
            "develop_held": fmt(num(learn_src, r"^local DEVELOP_HELD = (\d+)", "DEVELOP_HELD")),
        },
        "grubstake": {
            "rig_dig_min": fmt(product(src("scripts/jumper.lua"), r"^local DIG = ([\d\s\*]+?)\s*(?:--|$)", "jumper DIG") / 3600),
            "prospect_window_min": fmt(minutes(src("scripts/prospect.lua"), "WINDOW", "prospect WINDOW")),
            "pacifier_rebuild_min": fmt(minutes(pact_src, "REBUILD_TICKS", "pact REBUILD_TICKS")),
        },
        "kh": {
            "dome_tiles": fmt(num(dome_src, r"^local RADIUS = (\d+)", "dome RADIUS")),
            "dome_hold_min": fmt(product(dome_src, r"^local HOLD = ([\d\s\*]+?)\s*(?:--|$)", "dome HOLD") / 60),
            "dome_down_min": fmt(minutes(dome_src, "BREAK", "dome BREAK")),
            "projector_back_min": fmt(minutes(dome_src, "PROJECTOR_BACK", "PROJECTOR_BACK")),
            "line_start_min": fmt(minutes(perim_src, "PERIMETER_START", "PERIMETER_START")),
            "line_every_min": fmt(minutes(perim_src, "PERIMETER_TICKS", "PERIMETER_TICKS")),
            "line_step_tiles": fmt(num(perim_src, r"^local PERIMETER_STEP = (\d+)", "PERIMETER_STEP")),
            "line_max_tiles": fmt(num(perim_src, r"^local PERIMETER_MAX = (\d+)", "PERIMETER_MAX")),
            "deploy_s": fmt(product(ops_src, r"^local DEPLOY_TICKS = ([\d\s\*]+?)\s*(?:--|$)", "DEPLOY_TICKS") / 60),
            "howitzer_down_min": fmt(product(shared_src, r"^shared\.HOWITZER_DOWN = ([\d\s\*]+?)\s*(?:--|$)", "HOWITZER_DOWN") / 3600),
            "jam_tiles": fmt(num(shared_src, r"^shared\.JAM_RADIUS = (\d+)", "JAM_RADIUS")),
            "paint_s": fmt(product(orbital_src, r"^local PAINT = ([\d\s\*]+?)\s*(?:--|$)", "orbital PAINT") / 60),
            "strike_cool_min": fmt(minutes(orbital_src, "COOL", "orbital COOL")),
            "bill_every_min": fmt(minutes(ledger_src, "BEAT", "ledger BEAT")),
            "truce_value": fmt(num(ledger_src, r"^local VALUE_PER_MINUTE, MIN_TRUCE, MAX_TRUCE = (\d+)", "VALUE_PER_MINUTE")),
        },
        # Standing down (war.lua), for every corporation; aggression scales the streak and the quiet hour.
        "war": {
            "fail_streak": fmt(num(war_src, r"^local FAIL_STREAK = (\d+)", "FAIL_STREAK")),
            "quiet_min": fmt(product(war_src, r"^local QUIET_TICKS, QUIET_HASTE = ([\d\s\*]+?),", "QUIET_TICKS") / 3600),
            "new_landing_min": fmt(product(war_src, r"^local QUIET_TICKS, QUIET_HASTE = [\d\s\*]+?, ([\d\s\*]+?)\s*(?:--|$)", "QUIET_HASTE") / 3600),
            "reserve_pct": fmt(100 * (num(src("scripts/army.lua"), r"^army\.RESERVE = ([\d.]+)", "army.RESERVE") or 0)),
        },
        "army": {
            "repair_tiles": fmt(num(src("scripts/command.lua"), r"^local REPAIR_RANGE = (\d+)", "REPAIR_RANGE")),
            "offset_max": fmt(num(src("scripts/command.lua"), r"^local MAX_OFFSET = (\d+)", "MAX_OFFSET")),
            **{f"relays_l{i + 1}": fmt(float(x)) for i, x in enumerate(re.findall(r"\d+", grab(shared_src, r"^shared\.RELAYS_BY_LEVEL = \{\[0\] = \d+, ([\d, ]+)\}", "RELAYS_BY_LEVEL") or ""))},
            "relays_extra": fmt(num(shared_src, r"^shared\.RELAYS_PER_EXTRA_LEVEL = (\d+)", "RELAYS_PER_EXTRA_LEVEL")),
        },
        "spoils": {
            "wreck_min": fmt(minutes(shared_src.replace("shared.WRECK_TICKS", "local WRECK_TICKS"), "WRECK_TICKS", "WRECK_TICKS")),
            "core_depot": fmt(core_depot),
            "core_lander": fmt(core_lander),
            "crystal_pct": fmt(100 * crystal_p) if crystal_p is not None else "?",
            "gland_min": gland.group(1) if gland else "?",
            "gland_max": gland.group(2) if gland else "?",
            "core_capture": grab(src("scripts/command.lua"), r"on_capture = function\(surface, pos\)\s*\n\s*command\.drop_cores\(surface, \{x = pos\[1\], y = pos\[2\]\}, (\d+)\)", "command: capture cores"),
            "core_survey": grab(phases_src, r'"lp-command-core", count = (\d+)', "phases: survey core"),
        },
        # The locale's descriptions, for prose that quotes what a thing does rather than retyping its numbers.
        "desc": {f"{sec.split('-')[0]}_{k[3:].replace('-', '_')}": v.replace('"', "'")
                 for (sec, k), v in loc.items()
                 if sec in ("entity-description", "item-description", "technology-description") and k.startswith("lp-")
                 and "__" not in v},
        "settings": {k.replace("-", "_"): fmt(float(x)) for k, x in tune.items()},
        "mod": {"version": info.get("version", "?"), "factorio": info.get("factorio_version", "?"),
                "needs": ", ".join(re.split(r"\s", x.strip())[0] for x in info.get("dependencies", []) if not x.startswith(("?", "!", "(?)")))},
    }
    if missed:
        raise SystemExit("manual_qmd: not found in the code, nothing written:\n  " + "\n  ".join(missed))

    for v in sorted(rp.vistas):
        shutil.copy(os.path.join(rp.OUT, "img", f"vista-{v}.jpg"), os.path.join(M, "media", "vistas", f"{v}.jpg"))

    def yaml(obj, ind=0):
        out = []
        for k, v in obj.items():
            if isinstance(v, dict):
                out.append(" " * ind + f"{k}:")
                out += yaml(v, ind + 2)
            else:
                out.append(" " * ind + f'{k}: "{v}"')
        return out

    open(os.path.join(M, "_variables.yml"), "w").write(
        "# Written by scripts/roster_page.py --qmd from the mod's code. Do not edit: run it again.\n"
        + "\n".join(yaml(V)) + "\n")

    def out(name, lines):
        open(os.path.join(GEN, name), "w").write(
            "<!-- Written by scripts/roster_page.py --qmd from the prototypes, shared.lua and the locale. Do not edit. -->\n\n"
            + "\n".join(lines).rstrip() + "\n")

    # ---- units ----
    rows = {r[0]: r for r in rp.roster.rows}
    probe = (rp.data["biotech"].get("mind") or {}).get("probe")
    breeds = rp.data.get("breeds") or {}
    pen_points = {name: pts for name, pts in rp.PEN}
    develop_held = V["synthexis"]["develop_held"]

    def corp_units(corp):
        c = corps[corp]
        kinds = [rp.corp_kind(corp, k) for k in sorted(c.get("mix") or {})]  # sorted: LuaJIT dumps tables in no fixed order
        kinds += [n["unit"]["kind"] for n in c["tree"] if n.get("unit")]
        res = []
        for k in kinds:
            how = rp.fielded_text(k, corp)
            if not how:
                for orig, new in (c.get("names") or {}).items():
                    if new == k:
                        how = rp.fielded_text(orig, corp)
            res.append((k, rp.portrait(k, corp), how, None))
        return res

    player_tech = {}
    for tk, t in d["technology"].items():
        for e in t.get("effects") or []:
            if isinstance(e, dict) and e.get("recipe", "").endswith("-order"):
                player_tech[e["recipe"][:-6]] = rp.tname(tk)
    groups = [
        ("Kessler-Hayashi", corp_units("serenity") + [("lp-howitzer-truck", rp.portrait("lp-howitzer-truck"), "Carries the howitzer to a siege", None)]),
        ("Grubstake", corp_units("grubstake")),
        ("Both corporations", [("lp-hauler", rp.portrait("lp-hauler"), "Both corporations", None)]),
        ("Synthexis", [(n, rp.portrait(n), f"Bred from evolution {pen_points[n][0][0]:g}", breeds.get(n, {}).get("cost")) for n, _ in rp.PEN]
         + [("lp-bred-big-burster", rp.portrait("lp-bred-big-burster"), f"Developed once your walls have held its waves {develop_held} times", breeds.get("lp-bred-big-burster", {}).get("cost")),
            ("lp-bred-scout", rp.portrait("lp-bred-scout"), "Made at an incubator for each wave", None),
            ("lp-sweeper", rp.portrait("lp-sweeper"), "Bred when a wave's way in crosses mines", breeds.get("lp-sweeper", {}).get("cost")),
            ("lp-bred-carrier", rp.portrait("lp-bred-carrier"), "Sent by a grown culture", None),
            ("lp-technician", rp.portrait("lp-technician"), "Bought with biomass as the culture grows", None)]
         + ([("lp-runt", rp.portrait("lp-runt"), "Made for a wave's probe", breeds.get("lp-runt", {}).get("cost"))] if probe else [])),
        ("Your army", [(k, rp.portrait(k), f"Research: {player_tech.get(k, '?')}", None)
                       for k in ("lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-flame-trooper", "lp-battle-tank")]),
    ]
    EXTRA_DESC = {"lp-technician": "Walks between the biochambers and keeps them running.",
                  "lp-howitzer-truck": loc.get(("entity-description", "lp-howitzer-truck"), "")}
    L = ["## Units {#sec-units}", "",
         "Numbers are from the game's prototypes, before research. Damage is one shot. A corporation's research raises its",
         "weapons' damage, and its armor research adds resistance to some units. *Hits air* says whether the unit's weapon",
         "can touch a flying unit. Speed is in tiles a second, range in tiles and rate in shots a second. Corporations pay",
         "for units in parts, Synthexis in biomass, and you in command bandwidth.", ""]
    for title, items in groups:
        L += [f"### {title}", "", "| Unit | Health | Speed | Range | Rate | Hits air | Cost |", "|:--|--:|--:|--:|--:|:--|:--|"]
        entries = []
        for kind, img, how, biomass in items:
            r = rows.get(kind)
            if not r:
                continue
            name, hp, speed, w, rng, rate, res, air, cost, who, role = r
            nm = shown(kind)
            if title == "Grubstake" and ENT.get("lp-grubstake-" + kind[3:]):
                nm = shown("lp-grubstake-" + kind[3:])
            rng_s = f"{rng:.3g}" if isinstance(rng, float) else str(rng)
            cost_s = f"{biomass} biomass" if biomass else cost
            L.append(f"| {md(nm)} | {fmt(hp)} | {speed.replace(' tiles/s', '')} | {rng_s} | {rate.replace('/s', '')} | {air} | {cost_s} |")
            desc = loc.get(("entity-description", kind)) or rp.roster.ROLE.get(kind) or EXTRA_DESC.get(kind, "")
            desc = desc.rstrip(".") + "." if desc else ""
            facts = []
            if w != "-":
                facts.append(f"*A shot:* {md(damage_word(w))}.")
            if res != "-":
                facts.append(f"*Resists:* {md(damage_word(res))}.")
            if how:
                facts.append(f"*Fielded:* {md(how)}.")
            text = f"**{md(nm)}.** {md(desc)}" + (" \\\n" + " ".join(facts) if facts else "")
            if img:
                entries += ['::: {.unit-entry layout="[14,-2,84]" layout-valign="top" fig-pos="H"}', f"![]({copy_png(img)}){{fig-alt=\"{nm}\"}}", "", text, ":::", ""]
            else:
                entries += [text, ""]
        L += [""] + entries
    if not probe:
        L.append("<!-- The runt is left out: Synthexis's probe is off in this version (shared.BIOTECH.mind.probe). -->")
    out("units.qmd", L)

    # ---- buildings ----
    def desc_of(n):
        return md(loc.get(("entity-description", n), ""))

    camp = ["lp-lander", "lp-uplink", "lp-generator", "lp-pylon", "lp-drill", "lp-bin", "lp-fabricator", "lp-turret", "lp-wall",
            "lp-gate", "lp-flamer", "lp-mine", "lp-mortar", "lp-howitzer", "lp-radar", "lp-depot", "lp-launchpad", "lp-belt",
            "lp-lamp", "lp-post-lamp"]
    B = ["## Buildings {#sec-buildings}", "", "### Corporation camps", "",
         "Both corporations build from the same set, each in its own colors. Grubstake's turret fires bullets, and every",
         f"{ordinal(int(num(shared_src, r'^\s*flak = (\d+)', 'flak') or 0))} turret it builds is a scrap cannon.", "",
         "| Building | Health (Kessler-Hayashi) | Health (Grubstake) | What it does |", "|:--|--:|--:|:--|"]
    for n in camp:
        g = "lp-grubstake-" + n[3:]
        B.append(f"| {md(shown(n))} | {health(n)} | {health(g) if g in ENT else '-'} | {desc_of(n)} |")
    B.append(f"| {md(shown('lp-scrap-cannon'))} | - | {health('lp-grubstake-scrap-cannon')} | |")
    B += ["", "### Kessler-Hayashi only", "", "| Building | Health | What it does |", "|:--|--:|:--|"]
    for n in ("lp-optics-lab", "lp-line-lab", "lp-siege-lab", "lp-jammer", "lp-invoice-post"):
        B.append(f"| {md(shown(n))} | {health(n)} | {desc_of(n)} |")
    B += ["", "Each research lab advances one branch of Kessler-Hayashi's research, and only while it stands.", "",
          "### Grubstake only", "", "| Building | Health | What it does |", "|:--|--:|:--|"]
    for n, h in (("lp-pacifier", "lp-grubstake-pacifier"), ("lp-skim-yard", "lp-skim-yard"), ("lp-claim-stake", "lp-claim-stake"),
                 ("lp-claim-rig", "lp-claim-rig"), ("lp-power-tap", "lp-power-tap")):
        B.append(f"| {md(shown(n))} | {health(h)} | {desc_of(n)} |")
    B += ["", "### Synthexis", "", "| Building | Health | What it does |", "|:--|--:|:--|"]
    for n in ("lp-pen", "lp-biochamber", "lp-clinic", "lp-heating-tower", "lp-tumor", "lp-bred-worm", "lp-cell-lamp"):
        B.append(f"| {md(shown(n))} | {health(n)} | {desc_of(n)} |")
    B += ["", "### Yours", "", "| Building | Health | What it does |", "|:--|--:|:--|"]
    for n in ("lp-barracks", "lp-rally-beacon", "lp-command-relay", "lp-muster-point", "lp-threat-scanner", "lp-player-mortar",
              "lp-strip-drill", "lp-border-stake", "lp-trade-post", "lp-claim-marker", "lp-pact-breaker", "lp-player-bait",
              "lp-strike-beacon"):
        B.append(f"| {md(shown(n))} | {health(n)} | {desc_of(n)} |")
    pics = [(n, rp.portrait(n)) for n in ("lp-optics-lab", "lp-line-lab", "lp-siege-lab", "lp-depot", "lp-pen", "lp-biochamber",
                                          "lp-clinic", "lp-heating-tower", "lp-tumor")]
    pics = [(n, p) for n, p in pics if p]
    if pics:
        B += ["", "::: {layout-ncol=3}"]
        for n, p in pics:
            B += [f"![{md(shown(n))}]({copy_png(p)})", ""]
        B.append(":::")
    out("buildings.qmd", B)

    # ---- Synthexis's breeds by evolution ----
    R = ["| Breed | Bred from evolution | Biomass |", "|:--|--:|--:|"]
    for n, pts in sorted(rp.PEN, key=lambda x: x[1][0][0]):
        R.append(f"| {md(shown(n))} | {pts[0][0]:g} | {breeds.get(n, {}).get('cost', '-')} |")
    R.append(f"| {md(shown('lp-bred-big-burster'))} | developed | {breeds.get('lp-bred-big-burster', {}).get('cost', '-')} |")
    out("breeds.qmd", R)

    # ---- eras ----
    max_lv = int(float(V["arrival"]["weapon_levels"]))
    E = ["| Your era | Technologies you have researched | Corporation operations against you at once | Corporation weapon damage levels |",
         "|:--|--:|--:|--:|", f"| 0 | under {rp.ERA_TECHS[0]} | 1 | up to {min(max_lv, 1)} |"]
    for i, k in enumerate(rp.ERA_TECHS, 1):
        E.append(f"| {i} | {k} | {1 + i} | up to {min(max_lv, i + 1)} |")
    out("eras.qmd", E)

    # ---- corporation levels ----
    levels = [int(x) for x in re.findall(r"\d+", grab(shared_src, r"^shared\.LEVELS = \{([^}]*)\}", "LEVELS") or "")]
    caps_src = {corp: grab(shared_src, rf"{key}caps = \{{([^}}]*)\}}", f"{corp} caps") for corp, key in
                (("serenity", r"serenity = \{[\s\S]*?"), ("grubstake", r"grubstake = \{[\s\S]*?"))}
    CAPNAME = {"lp-harrier": loc.get(("lp", "cap-harrier")), "lp-walker": loc.get(("lp", "cap-walker")),
               "siege": loc.get(("lp", "cap-siege")), "pickets_see": loc.get(("lp", "cap-pickets")),
               "headquarters": loc.get(("lp", "cap-headquarters")), "lp-laser-drone": shown("lp-laser-drone").lower() + "s"}
    def gains(corp, lvl):
        cs = re.findall(r'\[?"?([a-z_-]+)"?\]? = (\d+)', caps_src[corp] or "")
        return ", ".join(CAPNAME.get(k, k) for k, v in cs if int(v) == lvl) or "-"
    Lv = ["| Level | Parts sent off-world | Kessler-Hayashi gains | Grubstake gains |", "|:--|--:|:--|:--|"]
    for i, p in enumerate(levels, 1):
        Lv.append(f"| {i} | {p:,} | {gains('serenity', i)} | {gains('grubstake', i)} |")
    out("levels.qmd", Lv)

    # ---- salvage ----
    adds = re.findall(r'^add\("[a-z-]+", "(lp-[a-z-]+)", "(lp-[a-z-]+)", (\d+), (\d+)(?:, ([\d.]+))?\)', comp_src, re.M)
    def used_in(item):
        uses = []
        for rk, r in d["recipe"].items():
            if not rk.startswith("lp-") or rk.endswith("-recycling"):
                continue
            if any(i.get("name") == item for i in r.get("ingredients") or []):
                if any(x.get("name", "").endswith("-schematic") for x in r.get("results") or []):
                    sch = r["results"][0]["name"]
                    for tk, t in d["technology"].items():
                        tr = t.get("research_trigger") or {}
                        if tr.get("item") == sch:
                            cnt = next(i["amount"] for i in r["ingredients"] if i["name"] == item) * tr.get("count", 1)
                            uses.append(f"{cnt} to research {rp.tname(tk)}")
                else:
                    n = next(i["amount"] for i in r["ingredients"] if i["name"] == item)
                    uses.append(f"{n} per {lname('recipe-name.' + rk) if ('recipe-name', rk) in loc else lname('item-name.' + rk)}")
        return "; ".join(sorted(uses)) or "-"
    S = ["| Salvage | Dropped by | How many | Used for |", "|:--|:--|:--|:--|"]
    seen = {}
    for ent, item, a, b, p in adds:
        how = a if a == b else f"{a} to {b}"
        if p:
            how += f", {float(p) * 100:g}% of the time"
        seen.setdefault(item, []).append((shown(ent), how))
    seen.setdefault("lp-pacifier-crystal", []).append((shown("lp-pacifier"), f"1 from the first; {V['spoils']['crystal_pct']}% of rebuilt ones"))
    seen.setdefault("lp-pheromone-gland", []).append((shown("lp-pen"), f"{V['spoils']['gland_min']} to {V['spoils']['gland_max']}"))
    for item, srcs in seen.items():
        S.append(f"| {md(lname('item-name.' + item))} | {'; '.join(md(s) for s, _ in srcs)} | {'; '.join(h for _, h in srcs)} | {md(used_in(item))} |")
    S.append(f"| {md(lname('item-name.lp-command-core'))} | {md(shown('lp-depot'))}; {md(shown('lp-lander'))}; a captured outpost; "
             f"the survey party | {V['spoils']['core_depot']}; {V['spoils']['core_lander']}; 1; 1 | {md(used_in('lp-command-core'))} |")
    out("salvage.qmd", S)

    # ---- your technologies ----
    def packs(u):
        return " + ".join(lname("item-name." + i[0]) for i in u.get("ingredients", []))
    def how(tk, t):
        tr = t.get("research_trigger")
        if tr and tr.get("type") == "craft-item":
            c = tr.get("count", 1)
            return f"Craft {str(c) + ' × ' if c > 1 else ''}{lname('item-name.' + tr['item'])}"
        if t.get("hidden"):
            who = KH["name"] if tk.endswith("serenity") else GS["name"]
            return f"Granted when {who}'s headquarters falls"
        if tr and tr.get("type") == "capture-spawner":
            return "Capture a Synthexis incubator (Space Age's capture rocket)"
        # A field study's node (studies.lua): its study's condition, then its packs.
        study = next((q for q in (t.get("prerequisites") or []) if q.startswith("lp-study-")), None)
        u = t.get("unit") or {}
        if study:
            cond = loc.get(("lp", study[3:]), "")
            return f"Field study: {cond.rstrip('.')}; then {u.get('count', '?')} × ({packs(u)})"
        if u.get("count"):
            return f"{u['count']} × ({packs(u)})"
        if u.get("count_formula"):
            return f"{u['count_formula'].replace('*', ' × ')} × ({packs(u)}), repeatable"
        return ""
    def tdesc(tk, t):
        base = re.sub(r"-\d+$", "", tk)
        unlocks = [e["recipe"] for e in t.get("effects") or [] if isinstance(e, dict) and e.get("recipe")]
        names = [lname("recipe-name." + r) if ("recipe-name", r) in loc else lname("item-name." + r) for r in unlocks]
        dsc = loc.get(("technology-description", base), "")
        if base == "lp-command-bandwidth":
            return ("Unlocks " + ", ".join(names) + "." if names else dsc)
        return dsc
    T = ["| Technology | What it gives | How you get it | After |", "|:--|:--|:--|:--|"]
    order = sorted(k for k in d["technology"] if k.startswith("lp-command-bandwidth")) + \
        sorted(k for k in d["technology"] if k.startswith("lp-") and (d["technology"][k].get("research_trigger") or {}).get("type") == "craft-item") + \
        sorted(k for k in d["technology"] if k.startswith("lp-") and any(q.startswith("lp-study-") for q in (d["technology"][k].get("prerequisites") or []))) + \
        [k for k in ("lp-player-dome", "lp-incubator-capture") if k in d["technology"]] + \
        sorted(k for k in d["technology"] if k.startswith("lp-prize"))
    for tk in order:
        t = d["technology"][tk]
        pre = ", ".join(rp.tname(p) if p.startswith("lp-") else lname("technology-name." + re.sub(r"-\d+$", "", p)) + (" " + p.rsplit("-", 1)[1] if re.search(r"-\d+$", p) else "")
                        for p in (t.get("prerequisites") or []) if not p.startswith("lp-study-"))
        T.append(f"| {md(rp.tname(tk))} | {md(tdesc(tk, t))} | {md(how(tk, t))} | {md(pre) or '-'} |")
    out("techs.qmd", T)

    # ---- settings ----
    St = ["| Setting | Default | Choices | What it does |", "|:--|:--|:--|:--|"]
    for key in [k for (sec, k) in loc if sec == "mod-setting-name"]:
        nm, dsc = loc[("mod-setting-name", key)], loc.get(("mod-setting-description", key), "")
        if key == "lp-chat-notices":
            dflt = grab(settings_src, r'name = "lp-chat-notices".*?default_value = (\w+)', "chat default")
            St.append(f"| {md(nm)} | {'On' if dflt == 'true' else 'Off'} | On, Off | {md(dsc)} |")
        else:
            lv = re.findall(r'"([a-z-]+)"', grab(settings_src, r"local levels = \{([^}]*)\}", "levels") or "")
            dflt = grab(settings_src, r'default_value = "([a-z-]+)", allowed_values = levels', "lever default")
            choices = ", ".join(loc.get(("string-mod-setting", f"{key}-{l}"), l) for l in lv)
            St.append(f"| {md(nm)} | {loc.get(('string-mod-setting', f'{key}-{dflt}'), dflt)} | {md(choices)} | {md(dsc)} |")
    if missed:
        raise SystemExit("manual_qmd: not found in the code, nothing written:\n  " + "\n  ".join(missed))
    out("settings.qmd", St + ["", "All of them are map settings: an admin can change them in a running game."])

    # ---- commands ----
    C = ["| Command | What it does |", "|:--|:--|"]
    dev_key = None
    for name, key in re.findall(r'commands\.add_command\("([a-z-]+)", \{"lp\.([a-z-]+)"\}', control_src):
        text = loc.get(("lp", key), "")
        if name == "lp":
            dev_key = key
            continue
        m = re.match(r"^(<[^>]+>) - (.*)$", text)
        cmd = f"`/{name} {m.group(1)}`" if m else f"`/{name}`"
        C.append(f"| {cmd} | {md(m.group(2) if m else text)} |")
    verbs = grab(dev_src, r'player\.print\("/lp (list \|[^"]*)"\)', "dev verbs")
    if missed:
        raise SystemExit("manual_qmd: not found in the code, nothing written:\n  " + "\n  ".join(missed))
    C += ["", "::: {.callout-note collapse=\"true\"}", "## Developer tools (admins only)", "",
          "`/lp` forces what the mod otherwise times and rolls for. It is for testing, and it spoils a game. "
          "Corporation names are the internal ones: `serenity` for Kessler-Hayashi, `grubstake` for Grubstake.", "",
          f"`/lp {verbs}`", "", "Further verbs: `incidents`, `rig`, `tap`, `biotech` (Synthexis lands now), `wave`.", ":::"]
    out("commands.qmd", C)

    print(f"{M}: _variables.yml and {len(os.listdir(GEN))} generated parts, "
          f"{len(os.listdir(os.path.join(M, 'media', 'units')))} portraits, {len(rp.vistas)} vistas")
