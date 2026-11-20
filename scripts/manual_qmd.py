"""The player manual's generated parts (docs/manual), written by `python3 -I scripts/roster_page.py --qmd`.

Everything a chapter states as a number or lists as a table comes from here, read from the game's prototypes (the dump
scripts/check.sh writes), landing-party/shared.lua, the scripts and the locale, so no chapter types a number:
  _variables.yml           values the prose reads with {{< var ... >}}
  _generated/*.qmd         tables the chapters include: units, buildings, breeds, eras, levels, salvage, technologies,
                           settings, commands
  media/vistas             the front cover's three vistas (docs/guide/img); media/buildings, the labs' tree icons
  (the unit portraits, heroes, plans, strips and stills in docs/manual/media are made by docs/manual/shots, not here)
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


# A corporate track's levels (rd.lua levels_of, the arms race of 0.2.474): its categories' deepest finite level of the
# base game's damage and shooting speed technologies, else (railguns: a step of its own) its node's count.
def track_levels(n, d):
    if n.get("step"):
        return n.get("levels")
    top = 0
    for t in d["technology"].values():
        if t.get("max_level") == "infinite":
            continue
        for e in t.get("effects") or []:
            if e.get("type") in (("ammo-damage",) if n.get("speed") is False else ("ammo-damage", "gun-speed")) \
                    and e.get("ammo_category") in n["track"]:
                m = re.search(r"-(\d+)$", t["name"])
                top = max(top, int(m.group(1)) if m else 1)
    return top


def write(rp):
    M = os.path.join(rp.REPO, "docs", "manual")
    GEN = os.path.join(M, "_generated")
    os.makedirs(GEN, exist_ok=True)
    os.makedirs(os.path.join(M, "media", "buildings"), exist_ok=True)
    os.makedirs(os.path.join(M, "media", "vistas"), exist_ok=True)
    d = rp.roster.d
    loc = dict(rp.locale)
    CORPS_DATA = rp.data["corps"]
    # A description that takes its numbers from shared.lua (__1__, given by the prototype's localised_description, e.g.
    # the strike beacon's radius) reads here with them filled in, as the game shows it.
    for protos in d.values():
        for p in (protos.values() if isinstance(protos, dict) else []):
            ls = p.get("localised_description") if isinstance(p, dict) else None
            if isinstance(ls, list) and ls and isinstance(ls[0], str) and "." in ls[0] \
                    and all(isinstance(x, str) for x in ls[1:]):
                k = tuple(ls[0].split(".", 1))
                if k in loc:
                    v = loc[k]
                    for i, x in enumerate(ls[1:], 1):
                        v = v.replace(f"__{i}__", x)
                    loc[k] = v
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

    # A share, a multiple or a small count the prose says in words ("more than half", "worth double", "two gun
    # turrets"), the word from the code's value; a value with no word here stops the build (2026-11-06: these were typed).
    WORDS = {"share": {0.5: "half", 0.25: "a quarter", 0.75: "three quarters"},
             "times": {2: "double", 3: "triple"},
             "count": {1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten"},
             "nth": {1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth"}}

    def worded(kind, v, what):
        w = WORDS[kind].get(float(v)) if kind == "share" else WORDS[kind].get(int(v)) if v == int(v) else None
        if w is None:
            missed.append(f"{what}: {v} has no word for '{kind}' in manual_qmd.WORDS")
            return "?"
        return w

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

    # (A locale line break, \n, is a space in print: the rally beacon's two lines ran together as a literal "\n" in its
    # table row, 0.2.339.)
    def md(s):
        return s.replace("\\n", " ").replace("|", "/").replace("*", "\\*")

    # ---- media ----
    def copy_png(rel):
        """docs/guide/img/x.png to media/buildings/x.png (a lab's icon at the head of its tree column); returns the
        manual's path. Units take their portraits from media/portraits (docs/manual/shots/portraits.py)."""
        name = os.path.basename(rel)
        shutil.copy(os.path.join(rp.OUT, rel), os.path.join(M, "media", "buildings", name))
        return f"media/buildings/{name}"

    # ---- sources ----
    shared_src, phases_src, faction_src = src("shared.lua"), src("scripts/phases.lua"), src("scripts/faction.lua")
    ops_src, rd_src, farm_src, cell_src = src("scripts/ops.lua"), src("scripts/rd.lua"), src("scripts/farm.lua"), src("scripts/cell.lua")
    perim_src, learn_src, comp_src = src("scripts/perimeter.lua"), src("scripts/herd_learn.lua"), src("components.lua")
    pact_src, control_src, biotech_src, dev_src = src("scripts/pact.lua"), src("control.lua"), src("biotech.lua"), src("scripts/dev.lua")
    settings_src = src("settings.lua")
    army_src, landfx_src, burstfx_src = src("scripts/army.lua"), src("scripts/landfx.lua"), src("scripts/burstfx.lua")
    scorcher_src = src("scripts/scorcher.lua")
    yard_rings = [float(x) for x in re.findall(r"\d+", grab(army_src, r"^local YARD_RINGS = \{([\d, ]+)\}", "army YARD_RINGS") or "")]
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
    crystal_p = num(pact_src, r"^local REBUILT_CRYSTAL = ([\d.]+)", "pact REBUILT_CRYSTAL")
    gland = re.search(r'pen\.loot = \{\{type = "item", name = "lp-pheromone-gland".*?amount_min = (\d+), amount_max = (\d+)', biotech_src)
    if not gland:
        missed.append("biotech.lua: the incubator's glands")
    climb = num(farm_src, r"^local CLIMB = ([\d.]+)", "farm CLIMB")

    cannon_box = ((d.get("assembling-machine") or {}).get("lp-orbital-cannon") or {}).get("selection_box")
    if not cannon_box:
        missed.append("the orbital cannon's selection box (lp-orbital-cannon)")

    def cannon_v(key):
        return num(shared_src, rf"^shared\.CANNON = \{{[^}}]*\b{key} = ([\d.]+)", f"shared.CANNON {key}")
    # A corporation's capabilities by level (shared.CORPS caps): the level that brings each, for the prose's "from its
    # first level" (2026-11-10: typed until then, as was the headquarters' level 3).
    def cap_level(corp, key):
        m = re.search(rf"^  {corp} = \{{[\s\S]*?^    caps = \{{([^}}]*)\}}", shared_src, re.M)
        caps = dict(re.findall(r'\[?"?([a-z_-]+)"?\]? = (\d+)', m.group(1))) if m else {}
        if key not in caps:
            missed.append(f"shared.CORPS.{corp}.caps: no {key}")
            return None
        return int(caps[key])
    hq_levels = {cap_level(c, "headquarters") for c in ("serenity", "grubstake")}
    if len(hq_levels) != 1:
        missed.append(f"the corporations' headquarters levels differ ({hq_levels}): the prose says one")
    tune = dict(re.findall(r'\[?"?([a-z-]+)"?\]? = ([\d.]+)', grab(shared_src, r"^shared\.TUNE = \{([^}]*)\}", "TUNE") or ""))
    AHEAD = {k: int(v) for k, v in re.findall(r'\[?"?([a-z-]+)"?\]? = (-?\d+)',
             grab(shared_src, r"^shared\.RESEARCH_AHEAD = \{([^}]*)\}", "RESEARCH_AHEAD") or "")}
    def director_vars():
        D = rp.data.get("director") or {}
        def need(k):
            if k not in D:
                missed.append(f"shared.DIRECTOR: no {k}")
                return 0
            return D[k]
        pct = lambda k: fmt(round(need(k) * 100))
        out = {k: fmt(need(k)) for k in ("grace", "warn_minutes", "climax_warn", "strike_minutes", "home_minutes",
               "strike_land", "strike_guard", "power_hold", "grudge_kills", "grudge_minutes", "grudge_cluster",
               "points_max", "jam_radius", "jam_on", "jam_off", "jam_minutes", "blackout_radius", "blackout_minutes",
               "bounty_minutes", "salvage_claim", "salvage_expire", "salvage_distance", "contract_minutes",
               "rotation_minutes", "rotation_max", "lull_minutes", "spree_minutes", "surge_minutes", "supply_wait",
               "expedition_minutes", "fought_minutes")}
        # A starving camp's supply drop and departure (lifeline.lua, shared.LIFELINE).
        lif = src("shared.lua")
        out["lifeline_minutes"] = fmt(num(lif, r"^shared\.LIFELINE = \{[^}]*?\bminutes = (\d+)", "LIFELINE.minutes"))
        out["lifeline_leave"] = fmt(num(lif, r"^shared\.LIFELINE = \{[^}]*?\bleave = (\d+)", "LIFELINE.leave"))
        out["wave_word"] = worded("count", need("wave_size"), "DIRECTOR.wave_size")
        out["strike_break_pct"] = pct("strike_break")
        out["warn_edge_seconds"] = fmt(round(need("warn_minutes") * 60 * need("warn_edge")))
        out["joint_share_pct"] = pct("joint_share")
        out["datacore_word"] = worded("share", need("datacore_chance"), "DIRECTOR.datacore_chance")
        out["climax_times"] = worded("times", need("climax_points"), "DIRECTOR.climax_points")
        out["gentle_share"] = worded("share", (need("personality") or {}).get("gentle", 0), "DIRECTOR.personality.gentle")
        return out

    V = {
        "arrival": {
            "signs_tiles": fmt(num(phases_src, r"^local SIGNS_DISTANCE = (\d+)", "SIGNS_DISTANCE")),
            "survey_tiles": fmt(num(phases_src, r"^local SURVEY_DISTANCE = (\d+)", "SURVEY_DISTANCE")),
            "survey_stays_min": fmt(minutes(phases_src, "SURVEY_TICKS", "SURVEY_TICKS")),
            "survey_killed_delay_min": fmt(minutes(phases_src, "DELAY", "DELAY")),
            "survey_left_min": fmt(minutes(phases_src, "EARLY", "EARLY")),
            "late_min": fmt(minutes(phases_src, "LATE_HASTE", "LATE_HASTE")),
            # The levers (settings.lua; their defaults in shared.lua): the time between landings, a corporation's most camps.
            "cadence_min": fmt(num(shared_src, r"^shared\.LANDING_MINUTES = \{default = (\d+)", "LANDING_MINUTES")),
            "haste_min": fmt(minutes(faction_src, "HASTE", "HASTE")),
            "max_per_corp": fmt(num(shared_src, r"^shared\.MAX_CAMPS = \{default = (\d+)", "MAX_CAMPS")),
            "apart_tiles": fmt(num(faction_src, r"^local APART = (\d+)", "APART")),
            "squat_tiles": fmt(num(faction_src, r"^local SQUAT_DISTANCE = (\d+)", "SQUAT_DISTANCE")),
            "escort_base": esc_m.group(1) if esc_m else "?",
            "grudge_escort": worded("times", num(shared_src, r"^shared\.GRUDGE_ESCORT = ([\d.]+)", "GRUDGE_ESCORT"), "GRUDGE_ESCORT"),
            "escort_level": esc_m.group(2) if esc_m else "?",
            "escort_evo": esc_m.group(3) if esc_m else "?",
            "hq_floor_h": fmt((minutes(faction_src, "HQ_FLOOR", "HQ_FLOOR") or 0) / 60),
            "hq_level": fmt(min(hq_levels) if None not in hq_levels else None),
            "hq_floor_bases": worded("count", num(faction_src, r"HQ_FLOOR\) and standing >= (\d+)", "faction: the floor's bases"), "HQ floor bases"),
            "consolidate_min": fmt(minutes(faction_src, "CONSOLIDATE", "CONSOLIDATE")),
            "hq_tiles": fmt(num(faction_src, r"^local HQ_DISTANCE = (\d+)", "HQ_DISTANCE")),
            "withdraw_min": fmt(minutes(faction_src, "WITHDRAW", "WITHDRAW")),
            "vacancy_min": fmt(minutes(faction_src, "VACANCY_HASTE", "VACANCY_HASTE")),
            "armed_era": fmt(num(shared_src, r"armed_era = (\d+)", "armed_era")),
            "era_share_pct": fmt(round(rp.ERA_SHARE * 100)),
            "armed_level": fmt(num(shared_src, r"armed_level = (\d+)", "armed_level")),
            "floor_min": fmt(minutes(perim_src, "FLOOR_TICKS", "FLOOR_TICKS")),
            "research_every_min": fmt(minutes(rd_src, "CHOICE_TICKS", "CHOICE_TICKS")),
            "research_window_min": fmt(minutes(rd_src, "WINDOW_TICKS", "WINDOW_TICKS")),
            # (Its labs' income since 0.2.474, rd.lua LAB_RATE; its weapon levels the base game's, read from the dump as
            # rd.ladder reads the prototypes: the deepest track's levels.)
            "lab_rate": fmt(num(rd_src, r"^local LAB_RATE, LAB_TICKS = (\d+)", "LAB_RATE")),
            "weapon_levels": fmt(max(track_levels(n, d) for c in CORPS_DATA.values() for n in c.get("tree", []) if n.get("track"))),
            "rail_level_pct": fmt(100 * next(n["step"] for c in CORPS_DATA.values() for n in c.get("tree", []) if n.get("step"))),
            # The research preset (0.2.475, shared.RESEARCH_AHEAD and TUNE): tiers ahead at normal, the range, the pace.
            "research_ahead": fmt(AHEAD["normal"]),
            "research_behind": fmt(-AHEAD["very-low"]),
            "research_most": fmt(AHEAD["very-high"]),
            "research_pace_low": fmt(float(tune["very-low"])),
            "research_pace_high": fmt(float(tune["very-high"])),
            # A landing's look (landfx.lua): the cargo pods that streak down round a lander as it crashes.
            "landing_pods": fmt(num(landfx_src, r"^local PODS = (\d+)", "landfx PODS")),
        },
        # Both corporations' camps: the yard where an idle garrison waits (army.yard), its rings round the depot and how far
        # it keeps from anything hostile.
        "camp": {
            "yard_near_tiles": fmt(min(yard_rings)) if yard_rings else "?",
            "yard_far_tiles": fmt(max(yard_rings)) if yard_rings else "?",
            "yard_quiet_tiles": fmt(num(army_src, r"^local YARD_QUIET = (\d+)", "army YARD_QUIET")),
        },
        "synthexis": {
            "arrive_evo": fmt(num(shared_src, r"^shared\.ARRIVE_EVO = \{default = ([\d.]+)", "ARRIVE_EVO")),
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
            "wave_huge": fmt(num(shared_src, r"^shared\.WAVE_HUGE = \{default = (\d+)", "WAVE_HUGE")),
            "cap_pens": fmt(num(farm_src, r"^local CAP_PENS = (\d+)", "CAP_PENS")),
            "max_cultures": fmt(num(shared_src, r"^shared\.MAX_CULTURES = \{default = (\d+)", "MAX_CULTURES")),
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
            # A burster set off winds up this long before it bursts (burstfx.lua KIND, ticks).
            "cinder_windup_s": fmt((num(burstfx_src, r"^\s*cinder = \{windup = (\d+)", "burstfx cinder windup") or 0) / 60),
            "big_windup_s": fmt((num(burstfx_src, r"^\s*big = \{windup = (\d+)", "burstfx big windup") or 0) / 60),
        },
        "grubstake": {
            "rig_dig_min": fmt(product(src("scripts/jumper.lua"), r"^local DIG = ([\d\s\*]+?)\s*(?:--|$)", "jumper DIG") / 3600),
            "prospect_window_min": fmt(minutes(src("scripts/prospect.lua"), "WINDOW", "prospect WINDOW")),
            "pacifier_rebuild_min": fmt(minutes(pact_src, "REBUILD_TICKS", "pact REBUILD_TICKS")),
            "copter_level_nth": worded("nth", cap_level("grubstake", "lp-harrier") or 0, "grubstake caps lp-harrier"),
            # The strip camp that, finished on a patch already claimed, stays as an outpost (strip.lua).
            "outpost_nth": worded("nth", num(src("scripts/strip.lua"), r'times >= (\d+) and "lp\.claim-outpost"', "strip: outpost after") or 0, "strip outpost"),
        },
        "kh": {
            "siege_level_nth": worded("nth", cap_level("serenity", "siege") or 0, "serenity caps siege"),
            "drone_level_nth": worded("nth", cap_level("serenity", "lp-laser-drone") or 0, "serenity caps lp-laser-drone"),
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
            "hull_share": worded("share", num(shared_src, r"^shared\.HULL_SHARE = ([\d.]+)", "HULL_SHARE"), "HULL_SHARE"),
            "line_worth": worded("times", num(shared_src, r"^shared\.LINE_WORTH = ([\d.]+)", "LINE_WORTH"), "LINE_WORTH"),
            "post_guns": worded("count", len(re.findall(r"-?\d+", grab(shared_src, r"^shared\.POST_GUNS = \{([^}]*)\}", "POST_GUNS") or "")), "POST_GUNS"),
            "jam_tiles": fmt(num(shared_src, r"^shared\.JAM_RADIUS = (\d+)", "JAM_RADIUS")),
            "paint_s": fmt(product(orbital_src, r"^local PAINT = ([\d\s\*]+?)\s*(?:--|$)", "orbital PAINT") / 60),
            "strike_cool_min": fmt(minutes(orbital_src, "COOL", "orbital COOL")),
            # The lightning tank's drain (scorcher.lua): the share of a struck turret's, accumulator's or roboport's charge.
            "tesla_drain_pct": fmt(100 * (num(scorcher_src, r"^local DRAIN = ([\d.]+)", "scorcher DRAIN") or 0)),
            # The hold of a turret it strikes (scorcher.hold): the game's own tesla stun, Space Age's tesla-turret-stun.
            "tesla_stun_s": fmt(d["sticker"]["tesla-turret-stun"]["duration_in_ticks"] / 60),
            "bill_every_min": fmt(minutes(ledger_src, "BEAT", "ledger BEAT")),
        },
        # Standing down (war.lua), for every corporation; aggression scales the streak and the quiet hour.
        "war": {
            "fail_streak": fmt(num(war_src, r"^local FAIL_STREAK = (\d+)", "FAIL_STREAK")),
            "quiet_min": fmt(product(war_src, r"^local QUIET_TICKS, QUIET_HASTE = ([\d\s\*]+?),", "QUIET_TICKS") / 3600),
            "new_landing_min": fmt(product(war_src, r"^local QUIET_TICKS, QUIET_HASTE = [\d\s\*]+?, ([\d\s\*]+?)\s*(?:--|$)", "QUIET_HASTE") / 3600),
            "reserve_pct": fmt(100 * (num(src("scripts/army.lua"), r"^army\.RESERVE = ([\d.]+)", "army.RESERVE") or 0)),
        },
        "army": {
            "repair_tiles": fmt(num(src("shared.lua"), r"^shared\.SUPPLY_RANGE = (\d+)", "shared.SUPPLY_RANGE")),
            "offset_max": fmt(num(src("scripts/command.lua"), r"^local MAX_OFFSET = (\d+)", "MAX_OFFSET")),
            "defend_reach": fmt(num(src("scripts/command.lua"), r"^local DEFEND_REACH = (\d+)", "DEFEND_REACH")),
            "attack_reach": fmt(num(src("scripts/command.lua"), r"^local ATTACK_REACH = (\d+)", "ATTACK_REACH")),
            "here": fmt(num(src("scripts/command.lua"), r"^local HERE = (\d+)", "HERE")),
            "assign_range": fmt(num(src("scripts/command.lua"), r"^local ASSIGN_RANGE = (\d+)", "ASSIGN_RANGE")),
            "road_min": fmt(num(src("scripts/command.lua"), r"^local ROUTE_MIN = (\d+)", "ROUTE_MIN")),
            "defend_quiet": fmt(num(src("scripts/command.lua"), r"^local DEFEND_QUIET = (\d+)", "DEFEND_QUIET")),
            **{f"relays_l{i + 1}": fmt(float(x)) for i, x in enumerate(re.findall(r"\d+", grab(shared_src, r"^shared\.RELAYS_BY_LEVEL = \{\[0\] = \d+, ([\d, ]+)\}", "RELAYS_BY_LEVEL") or ""))},
            "relays_extra": fmt(num(shared_src, r"^shared\.RELAYS_PER_EXTRA_LEVEL = (\d+)", "RELAYS_PER_EXTRA_LEVEL")),
            "cards_max": fmt(num(src("scripts/cards.lua"), r"^local CARD_MAX = (\d+)", "CARD_MAX")),
        },
        # Veterancy's ranks (scripts/veterancy.lua RANKS): the merit each is earned at, Veteran, Elite, Heroic.
        "vet": dict(zip(("veteran", "elite", "heroic"), (fmt(float(x)) for x in re.findall(r"merit = (\d+)",
            grab(src("scripts/veterancy.lua"), r"^veterancy\.RANKS = (\{.*\})$", "veterancy.RANKS") or "")))),
        "spoils": {
            "wreck_min": fmt(minutes(shared_src.replace("shared.WRECK_TICKS", "local WRECK_TICKS"), "WRECK_TICKS", "WRECK_TICKS")),
            "core_depot": fmt(core_depot),
            "core_lander": fmt(core_lander),
            "crystal_pct": fmt(100 * crystal_p) if crystal_p is not None else "?",
            "gland_min": gland.group(1) if gland else "?",
            "gland_max": gland.group(2) if gland else "?",
            "core_survey": grab(phases_src, r'"lp-command-core", count = (\d+)', "phases: survey core"),
        },
        # The player's orbital cannons (shared.CANNON; scripts/cannon.lua; the strike's look, orbital.from_orbit). They
        # replaced the one-shot strike beacon in 0.2.274.
        "cannon": {
            "store": worded("count", cannon_v("STORE"), "CANNON.STORE"),
            "cycle_min": fmt((cannon_v("CYCLE") or 0) / 60),  # (energy_required, seconds at speed 1)
            "fuel": fmt(cannon_v("FUEL")),
            "reach": fmt(cannon_v("REACH")),
            "power": (re.search(r'^shared\.CANNON = \{[^}]*\bPOWER = "(\d+)MW"', shared_src, re.M) or [None, "?"])[1],
            "radius_min": fmt(cannon_v("R0")),
            "radius_max": fmt(cannon_v("R_MAX")),
            # (The cannons a platform needs to reach the cap: R0 * sqrt(n) = R_MAX.)
            "radius_cap_cannons": fmt(round((cannon_v("R_MAX") / cannon_v("R0")) ** 2)) if cannon_v("R0") and cannon_v("R_MAX") else "?",
            "oxidizer": fmt(cannon_v("OXIDIZER")),
            "shell_kg": fmt(cannon_v("SHELL_KG")),
            "shells_a_rocket": fmt(1000 // cannon_v("SHELL_KG")) if cannon_v("SHELL_KG") else "?",
            "shells": fmt(cannon_v("SHELLS")),
            "shells_word": worded("count", cannon_v("SHELLS"), "CANNON.SHELLS"),
            "realign_s": fmt(product(shared_src, r"^shared\.CANNON = \{[^}]*COOLDOWN = ([\d\s\*]+?)[,}]", "CANNON.COOLDOWN") / 60),
            "paint_s": fmt(product(orbital_src, r"^local CANNON_PAINT = ([\d\s\*]+?)\s*(?:--|$)", "orbital CANNON_PAINT") / 60),
            # (Its footprint, from the prototype's selection box: typed in the army chapter until the 2026-11-16 copy-edit.)
            "width": fmt(cannon_box[1][0] - cannon_box[0][0]) if cannon_box else "?",
            "depth": fmt(cannon_box[1][1] - cannon_box[0][1]) if cannon_box else "?",
        },
        # The locale's descriptions, for prose that quotes what a thing does rather than retyping its numbers.
        "desc": {f"{sec.split('-')[0]}_{k[3:].replace('-', '_')}": v.replace('"', "'").replace("\\n", " ")
                 for (sec, k), v in loc.items()
                 if sec in ("entity-description", "item-description", "technology-description") and k.startswith("lp-")
                 and "__" not in v},
        "settings": {k.replace("-", "_"): fmt(float(x)) for k, x in tune.items()},
        # The director's priors (shared.DIRECTOR), for the Headquarters chapter.
        "director": director_vars(),
        "mod": {"version": info.get("version", "?"), "factorio": info.get("factorio_version", "?"),
                "needs": ", ".join(re.split(r"\s", x.strip())[0] for x in info.get("dependencies", []) if not x.startswith(("?", "!", "(?)")))},
    }
    if missed:
        raise SystemExit("manual_qmd: not found in the code, nothing written:\n  " + "\n  ".join(missed))

    for v in sorted(set(VISTA.values())):  # the front cover's vistas only: each picture is printed once
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
        # sorted: LuaJIT dumps tables in no fixed order. A renamed kind with no prototype of its own (Kessler-Hayashi's
        # lp-line-trooper) is the original's: the table left Kessler-Hayashi's trooper out until 0.2.214.
        kinds = [rp.corp_kind(corp, k) if rp.corp_kind(corp, k) in rows else k for k in sorted(c.get("mix") or {})]
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
        # The howitzer truck only where a siege drives its guns in: a corporation whose guns come down in pods
        # (shared.CORPS orbital_drop) has none in play (Kessler-Hayashi's card stood after its drops, 2026-11-06).
        ("Kessler-Hayashi", corp_units("serenity") + ([] if corps["serenity"].get("orbital_drop") else
                            [("lp-howitzer-truck", rp.portrait("lp-howitzer-truck"), "Carries the howitzer to a siege", None)])),
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
                       for k in ("lp-trooper", "lp-breacher", "lp-rocket-trooper", "lp-gun-buggy", "lp-flame-trooper",
                                 "lp-battle-tank")]),
    ]
    L = ["## Units {#sec-units}", "",
         "Numbers are from the game's prototypes, before research. Damage is one shot. A corporation's research raises its",
         "weapons' damage and most of their rates of fire, and its armor research adds resistance to some units. An era is",
         "yours (see [The threat curve](arrivals.qmd#sec-era)). *Hits air* says whether the unit's weapon",
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
            # Each unit's shot, resistances and how it is fielded, in a second table: the faction chapters' cards carry
            # the portraits and words (the booklet's lp-data.json).
            entries.append(f"| {md(nm)} | {md(damage_word(w))} | {md(damage_word(res))} | {md(how or '-')} |")
        L += ["", "| Unit | A shot | Resists | Fielded |", "|:--|:--|:--|:--|"] + entries + [""]
    if not probe:
        L.append("<!-- The runt is left out: Synthexis's probe is off in this version (shared.BIOTECH.mind.probe). -->")
    # Better rounds (ammunition tiers, 0.2.470 to 0.2.472): each tier order's damage against its base round's, as
    # command.lua computes it: the round's direct damage over the base's (the dump's lp-ammo-direct), or its named rung
    # (shared.TIER_RAW), raised to shared.TIER_EXP; the explosive rungs' blast from shared.TIER_BLAST.
    T = rp.data["tiers"]
    direct = d["mod-data"]["lp-ammo-direct"]["data"]
    blast = T["blast"]
    L += ["### Better rounds", "",
          "A unit trained on a better round deals this much of each hit its plain order's round deals, before research.",
          f"An explosive round's blast hits the enemies within {blast['radius']:g} tiles of what it struck for "
          f"{blast['share'] * 100:.0f}% of the hit.", "",
          "| Unit | Round | Damage | Blast |", "|:--|:--|--:|:--|"]
    by_unit = {}
    for item, tier in T["order_tiers"].items():
        by_unit.setdefault(tier["base"], []).append(tier["round"])
    for base in sorted(by_unit, key=lambda b: shown(T["orders"][b])):
        unit = T["orders"][base]
        ammo = d["ammo"]
        rep = next((t["replaces"] for t in T["order_tiers"].values() if t["base"] == base and t.get("replaces")), None)
        if rep:   # (a capsule's rung, the cluster grenade: the grenade it replaces is named)
            base_round = rep
        else:
            cat = ammo[by_unit[base][0]]["ammo_category"]
            base_round = next(i["name"] for i in d["recipe"][base]["ingredients"]
                              if i["name"] in ammo and ammo[i["name"]]["ammo_category"] == cat)
        rows_t = [(base_round, 1.0)]
        for r in by_unit[base]:
            raw = T["raw"].get(r) or direct[r] / direct[base_round]
            rows_t.append((r, raw ** T["exp"]))
        for r, f in sorted(rows_t, key=lambda x: x[1]):
            L.append(f"| {md(shown(unit))} | {md(lname('item-name.' + r))} | {f:.2f} × | {'yes' if r in T['blasts'] else '-'} |")
    L.append("")
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
    for n in ("lp-barracks", "lp-rally-beacon", "lp-command-relay", "lp-threat-scanner", "lp-player-mortar",
              "lp-strip-drill", "lp-claim-marker", "lp-pact-breaker", "lp-player-bait",
              "lp-player-dome", "lp-orbital-cannon", "lp-targeting-array"):  # (the strike beacon retired, 0.2.274)
        B.append(f"| {md(shown(n))} | {health(n)} | {desc_of(n)} |")
    # No picture gallery here: the labs head their tree columns, and the culture's buildings are on the annotated plan
    # in the Synthexis chapter (the field guide's top-down squares printed small and unclear, and repeated the labs).
    out("buildings.qmd", B)

    # ---- Synthexis's breeds by evolution ----
    R = ["| Breed | Bred from evolution | Biomass |", "|:--|--:|--:|"]
    for n, pts in sorted(rp.PEN, key=lambda x: x[1][0][0]):
        R.append(f"| {md(shown(n))} | {pts[0][0]:g} | {breeds.get(n, {}).get('cost', '-')} |")
    R.append(f"| {md(shown('lp-bred-big-burster'))} | developed | {breeds.get('lp-bred-big-burster', {}).get('cost', '-')} |")
    out("breeds.qmd", R)

    # ---- eras ----
    max_lv = int(float(V["arrival"]["weapon_levels"]))
    # (Science-pack tiers since 0.2.384, ops.era: unbounded, so the rows stop at six with "and so on" in the prose.)
    # (Its weapon research: technologies of up to the era's tier and its preset's tiers ahead, rd.lua tier_of, 0.2.475.)
    ahead = int(re.search(r"normal = (-?\d+)", grab(shared_src, r"^shared\.RESEARCH_AHEAD = \{([^}]*)\}", "RESEARCH_AHEAD")).group(1))
    E = ["| Your era | Tiers passed | Corporation operations against you at once | Corporation weapon research up to tier |",
         "|:--|:--|--:|--:|", f"| 0 | none | 1 | {ahead} |"]
    for i in range(1, 7):
        tiers = "1" if i == 1 else "1 and 2" if i == 2 else f"1 to {i}"
        E.append(f"| {i} | {tiers} | {1 + i} | {i + ahead} |")
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
            if not rk.startswith("lp-") or rk.endswith("-recycling") or r.get("hidden"):
                continue  # (hidden: retired, as the one-shot strike beacon's recipe since 0.2.274)
            if any(i.get("name") == item for i in r.get("ingredients") or []):
                if any(x.get("name", "").endswith("-schematic") for x in r.get("results") or []):
                    sch = r["results"][0]["name"]
                    for tk, t in d["technology"].items():
                        tr = t.get("research_trigger") or {}
                        if tr.get("item") == sch and not t.get("hidden"):
                            cnt = next(i["amount"] for i in r["ingredients"] if i["name"] == item) * tr.get("count", 1)
                            uses.append(f"{cnt} to research {rp.tname(tk)}")
                else:
                    n = next(i["amount"] for i in r["ingredients"] if i["name"] == item)
                    rn = next((loc[(sec, rk)] for sec in ("recipe-name", "item-name", "entity-name") if (sec, rk) in loc), None) \
                        or lname("item-name." + rk)
                    uses.append(f"{n} per {rn}")
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
        [k for k in ("lp-player-dome", "lp-incubator-capture") if k in d["technology"]]
    # Then any other of ours (the orbital cannon, 0.2.274), the prizes last; none retired (hidden but not a prize: the
    # one-shot strike beacon's Orbital strike, kept in the game for old saves).
    order += sorted(k for k in d["technology"] if k.startswith("lp-") and k not in order and not k.startswith(("lp-study-", "lp-prize")))
    order += sorted(k for k in d["technology"] if k.startswith("lp-prize"))
    order = [k for k in order if k.startswith("lp-prize") or not d["technology"][k].get("hidden")]
    for tk in order:
        t = d["technology"][tk]
        pre = ", ".join(rp.tname(p) if p.startswith("lp-") else lname("technology-name." + re.sub(r"-\d+$", "", p)) + (" " + p.rsplit("-", 1)[1] if re.search(r"-\d+$", p) else "")
                        for p in (t.get("prerequisites") or []) if not p.startswith("lp-study-"))
        T.append(f"| {md(rp.tname(tk))} | {md(tdesc(tk, t))} | {md(how(tk, t))} | {md(pre) or '-'} |")
    out("techs.qmd", T)

    # ---- settings ----
    # Every setting as the game made it (scripts/check.sh's mod-settings-dump.json: type, default, range or choices,
    # order), in the game's order, named and described by the locale. (Read from settings.lua's text until 0.2.223's
    # levers: a bool, a range and a preset each needed a pattern of their own.)
    sdump = json.load(open(os.path.join(os.path.dirname(rp.roster.DUMP), "mod-settings-dump.json")))
    St = ["| Setting | Default | Choices | What it does |", "|:--|:--|:--|:--|"]
    level_names = re.findall(r'"([a-z-]+)"', grab(settings_src, r"^local levels = \{([^}]*)\}", "settings.lua levels") or "")
    settings_all = sorted(((e.get("order", ""), k, t, e) for t, v in sdump.items() for k, e in v.items() if k.startswith("lp-")))
    for _, key, typ, e in settings_all:
        nm, dsc = loc.get(("mod-setting-name", key)), loc.get(("mod-setting-description", key), "")
        if nm is None:
            missed.append(f"locale: no name for the setting {key}")
            continue
        dv = e.get("default_value")
        if typ == "bool-setting":
            dflt, choices = ("On" if dv else "Off"), "On, Off"
        elif typ == "string-setting":
            def opt(v):
                w = loc.get(("string-mod-setting", f"{key}-{v}"))
                if w is None:
                    missed.append(f"locale: no [string-mod-setting] {key}-{v}")
                return w or v
            av = e.get("allowed_values") or []
            # A scale (settings.lua's levels, very low to very high): its ends, the rest in between (the table ran to
            # two pages listing all five for each of eight settings).
            if av == level_names and len(av) > 2:
                dflt, choices = opt(dv), f"{opt(av[0])} to {opt(av[-1])}"
            else:
                dflt, choices = opt(dv), ", ".join(opt(v) for v in av)
        elif typ in ("int-setting", "double-setting"):
            dflt, choices = fmt(dv), f"{fmt(e.get('minimum_value'))} to {fmt(e.get('maximum_value'))}"
        else:
            missed.append(f"setting {key}: a type the manual does not show ({typ})")
            continue
        St.append(f"| {md(nm)} | {md(dflt)} | {md(choices)} | {md(dsc)} |")
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
    # The verbs dev.lua answers that its help line leaves out, read from its branches; a gloss for those a name does not
    # explain (a gloss for a verb that is gone stops it).
    listed = set(re.findall(r"[a-z]+", verbs or ""))
    further = [v for v in dict.fromkeys(re.findall(r'what == "([a-z]+)"', dev_src)) if v not in listed]
    gloss = {"biotech": "Synthexis lands now", "wave": "Synthexis sends a wave now"}
    for g in gloss:
        if g not in further:
            missed.append(f"dev.lua: the verb {g} (glossed in manual_qmd.py) not among its unlisted verbs")
    if missed:
        raise SystemExit("manual_qmd: not found in the code, nothing written:\n  " + "\n  ".join(missed))
    C += ["", "::: {.callout-note collapse=\"true\"}", "## Developer tools (admins only)", "",
          "`/lp` forces what the mod otherwise times and rolls for. It is for testing, and it spoils a game. "
          "Corporation names are the internal ones: `serenity` for Kessler-Hayashi, `grubstake` for Grubstake.", "",
          f"`/lp {verbs}`", "",
          "Further verbs: " + ", ".join(f"`{v}`" + (f" ({gloss[v]})" if v in gloss else "") for v in further) + ".", "",
          "`burst` sets off a Synthexis burster east of you (`big` for a big burster): its wind-up and its blast, which is "
          "real. `spread` and `ranks` make Synthexis's next siege a spread assault or a siege in ranks; `wave` sends it.",
          ":::"]
    out("commands.qmd", C)

    booklet(rp, M, GEN, d, loc, V, shown, lname, copy_png, src, out)

    print(f"{M}: _variables.yml and {len(os.listdir(GEN))} generated parts, "
          f"{len(os.listdir(os.path.join(M, 'media', 'portraits')))} portraits, {len(set(VISTA.values()))} vistas")


# ---------------------------------------------------------------------------------------------------------------------
# The booklet (docs/manual, format lp-manual-pdf): _generated/lp-data.json, the data the lp-manual filter draws unit
# cards and trees from (its shape: docs/manual/_extensions/lp-manual/lp-manual.lua), and _generated/cards-<faction>.qmd,
# a card for every unit a faction fields, which its chapter includes.
#   numbers   the dump (health, weapons, speed, fliers, research, science packs), shared.lua (costs, mixes, unlock levels,
#             research trees, breeds, the bursters' blasts, colours, mottos), the scripts (breeding thresholds by way of
#             the incubator's prototype, field studies, what farm.lua breeds a burster for) and the locale (names,
#             descriptions, study conditions)
#   words     what the code does not say (counters, blurbs, a few roles, two mottos): docs/manual/words.cfg, words only
# The book's own furniture (tab order, vistas, the player's chrome colour, how trees are banded) is set here and says so.
# A unit with no value where one is needed, a trigger with no words, a digit in words.cfg: it stops.

FACTION_IDS = {"serenity": "kessler-hayashi", "grubstake": "grubstake", "biotech": "synthexis", "player": "player"}
# Book furniture: the thumb tab's place on the fore-edge (from the top), the front cover strip's vista (the player has
# none), the opener's hero (media/heroes/<faction>.jpg) and the unit that stands for the faction on the back cover.
TABS = {"player": 1, "grubstake": 2, "kessler-hayashi": 3, "synthexis": 4}
VISTA = {"kessler-hayashi": "serenity-wide", "grubstake": "grubstake-wide", "synthexis": "synthexis-night"}
EMBLEM = {"player": "lp-trooper", "grubstake": "lp-shotgun-hand", "kessler-hayashi": "lp-infantry",
          "synthexis": "lp-bred-big-biter"}
PLAYER_CHROME = "B9BEC4"  # the player's chapters' colour in the book; the game gives the player no colour of its own
# What a research trigger answers, in the player's words (shared.lua's trigger fields: killer kinds, damage types, ...).
KILLED_BY = {"lp-trooper": "your infantry", "lp-breacher": "your infantry", "lp-rocket-trooper": "your infantry",
             "lp-flame-trooper": "your infantry", "character": "your infantry", "lp-harrier": "fliers",
             "lp-scavenger": "fliers", "lp-laser-drone": "fliers", "destroyer": "combat robots",
             "defender": "combat robots", "distractor": "combat robots", "vehicle": "your vehicles",
             "lp-battle-tank": "your vehicles", "gun-turret": "turret lines", "laser-turret": "turret lines",
             "flamethrower-turret": "turret lines", "artillery-turret": "artillery", "artillery-wagon": "artillery",
             "biter": "biters"}
DAMAGE_FROM = {"physical": "bullets", "fire": "flamethrowers", "explosion": "artillery and explosives"}
# Synthexis's breeds by line, its tree's columns (a breed missing here stops the generator).
BREED_LINE = {"lp-bred-small-biter": "biters", "lp-bred-medium-biter": "biters", "lp-bred-big-biter": "biters",
              "lp-bred-behemoth-biter": "biters", "lp-bred-medium-spitter": "spitters", "lp-bred-spore": "spitters",
              "lp-bred-cinder": "special", "lp-bred-stomper": "special"}


NUMBER_WORDS = re.compile(r"\b(twice|thrice|half|double|triple|two|three|four|five|six|seven|eight|nine|ten|"
                          r"eleven|twelve|twenty|thirty|fifty|hundred|thousand)\b", re.I)


def read_words(path):
    words, sec, bad = {}, None, []
    for i, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            sec = m.group(1)
            continue
        k, v = line.split("=", 1)
        if re.search(r"\d", v):
            bad.append(f"words.cfg line {i}: a digit in words ({k}); a number belongs to the code")
        # A number spelled out is still typed ("three times to a building", "more than twice": two blurbs, 2026-11-06).
        n = NUMBER_WORDS.search(v)
        if n:
            bad.append(f"words.cfg line {i}: a number in words ({k}: '{n.group(0)}'); a number belongs to the code")
        words.setdefault(sec, {})[k] = v.strip()
    if bad:
        raise SystemExit("manual_qmd:\n  " + "\n  ".join(bad))
    return words


def booklet(rp, M, GEN, d, loc, V, shown, lname, copy_png, src, out):
    import json
    W = read_words(os.path.join(M, "words.cfg"))
    used, missed = set(), []

    def word(sec, key):
        v = W.get(sec, {}).get(key)
        if v is not None:
            used.add((sec, key))
        else:
            missed.append(f"words.cfg [{sec}] {key}: no words, and the code has none")
        return v

    def hexcol(c):
        return "".join(f"{round(c[k] * 255):02X}" for k in ("r", "g", "b"))

    def num(x):
        return int(round(x)) if abs(x - round(x)) < 1e-9 else round(x, 2)

    def fmt_n(x):
        return f"{x:,.0f}" if abs(x - round(x)) < 1e-9 else f"{x:g}"

    def damage_word(t):
        return {"lp-bite": "bite", "lp-rail": "rail"}.get(t, t)

    corps = rp.data["corps"]
    shared_src = src("shared.lua")
    proto = {**d.get("unit", {}), **d.get("spider-unit", {})}
    breeds = rp.data.get("breeds") or {}
    unit_cost = {k: v.get("cost") for k, v in (rp.data.get("units") or {}).items()}
    bandwidth = {k: int(c) for k, c in re.findall(r'\["(lp-[a-z-]+)"\] = (\d+)',
                                                   re.search(r"shared.POPULATION = \{([^}]*)\}", shared_src).group(1))}

    def bare(name):
        return re.sub(r" \((Kessler-Hayashi|Grubstake|Synthexis)\)$", "", name)

    def burst(kind):
        """A burster's blast: shared.lua's BIG_BURST or CINDER_BURST (biotech.lua's death trigger and herd.lua deal it)."""
        key = {"lp-bred-cinder": "CINDER_BURST", "lp-bred-big-burster": "BIG_BURST"}.get(kind)
        if not key:
            return None
        m = re.search(rf"^shared\.{key} = \{{([^}}]*)\}}", shared_src, re.M)
        if not m:
            missed.append(f"shared.lua {key}")
            return None
        return {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)", m.group(1))}

    def weapon(kind):
        """(damage for the bar, the card's damage line, range, speed in tiles a tick) from the prototype."""
        u = proto[kind]
        ap = u.get("attack_parameters") or {}
        rng, spd = ap.get("range"), u.get("movement_speed")
        b = burst(kind)
        if b:
            core = f", {fmt_n(b['core'])} core" if "core" in b else ""
            return b["amount"], f"{fmt_n(b['amount'])} explosion{core}", rng, spd
        if kind == "lp-sweeper":
            for e in u.get("dying_trigger_effect") or []:
                if isinstance(e, dict) and e.get("type") == "nested-result":
                    dmg = rp.roster.damage(e.get("action"))
                    if dmg:
                        return dmg[0][0], f"{fmt_n(dmg[0][0])} explosion", rng, spd
        action = (ap.get("ammo_type") or {}).get("action")
        streams = [a["action_delivery"]["stream"] for a in (action if isinstance(action, list) else [action])
                   if isinstance(a, dict) and (a.get("action_delivery") or {}).get("type") == "stream"]
        if streams:
            # A stream (spitters, the stomper, the flamethrower trooper): its splash's hit, then the sticker it leaves.
            st = d["stream"][streams[0]]
            hit, burn = None, None
            for key in ("initial_action", "action"):
                for a in st.get(key) or []:
                    for e in ((a.get("action_delivery") or {}).get("target_effects") or []):
                        if e.get("type") == "damage" and hit is None:
                            hit = (e["damage"]["amount"] * ap.get("damage_modifier", 1), e["damage"]["type"])
                        if e.get("type") == "create-sticker":
                            s = d["sticker"].get(e["sticker"]) or {}
                            if s.get("damage_per_tick"):
                                burn = (s["damage_per_tick"]["amount"] * 60, s["damage_per_tick"]["type"], s.get("duration_in_ticks", 0) / 60)
            if hit and hit[0] >= 1:  # (the stomper's acid is a token: its weight is its stomp, not given here)
                text =f"{fmt_n(round(hit[0], 2))} {damage_word(hit[1])} a hit"
                total = hit[0]
                if burn:
                    text += f", then {fmt_n(round(burn[0], 1))}/s for {fmt_n(round(burn[2], 1))} s"
                    total += burn[0] * burn[2]
                return total, text, rng, spd
        hits = rp.roster.damage(action, ap.get("damage_modifier", 1))
        hits = [(a, t, n) for a, t, n in hits if t != "chain" and a > 0]
        if not hits:
            return None, None, rng, spd
        first = next(((a, t, n) for a, t, n in hits if "to buildings" not in n), hits[0])
        rep = re.search(r"\(x(\d+)\)", first[2])
        parts = [f"{fmt_n(first[0])} {damage_word(first[1])}" + (f" (x{rep.group(1)})" if rep else "")]
        for a, t, n in hits:
            if (a, t, n) == first:
                continue
            if "to buildings" in n:
                parts.append(f"{fmt_n(a)} more to buildings")  # (on top of the hit: the tank's 40, then 80 more)
            elif t != first[1] or a != first[0]:
                parts.append(f"{fmt_n(a)} {damage_word(t)}")
        if kind.endswith("railgunner") and len(parts) >= 2:
            parts = [re.sub(r" \w+$", "", parts[0]) + " to nests", re.sub(r" \w+$", "", parts[1]) + " to biters"]
        rate = 60 / ap["cooldown"] if ap.get("cooldown") else 0
        text = ", ".join(parts[:2])
        if rate >= 2:
            text += f", {fmt_n(round(rate, 1))} shots/s"
        return first[0], text, rng, spd

    def role_of(kind, base):
        plain = re.sub(r"^lp-grubstake-", "lp-", base)  # Grubstake's copies share the original's words
        in_game = next((loc[("entity-description", k)] for k in (base, kind, plain) if loc.get(("entity-description", k))), None)
        if in_game and W.get("role", {}).get(kind):
            missed.append(f"words.cfg [role] {kind}: the game's own description says it ({in_game})")
        # The game's description first; then words.cfg, over scripts/roster.py's ROLE (a field-guide line, not the
        # game's: the flame tank's "three bursts, then reloads" and the dozer's ram outlived 0.2.259 and 0.2.270 there).
        if not in_game and W.get("role", {}).get(kind):
            return word("role", kind).rstrip(".") + "."
        r = in_game or next((rp.roster.ROLE.get(k) for k in (base, kind, plain) if rp.roster.ROLE.get(k)), None)
        if r and re.search(r"\d", r):
            # roster.py's roles carry a few numbers (the railgunner's after a colon, the sapper's reach): the words only;
            # the card's stat panel gives the numbers.
            r = re.split(r":\s", re.sub(r" over [\d.]+ tiles,?", "", r))[0]
        if r and re.search(r"\d", r):
            missed.append(f"{kind}: its role carries a number: {r}")
        if not r:
            r = word("role", kind)
        return (r.rstrip(".") + ".") if r else None

    def answers(t):
        if not t:
            return None
        if "killer" in t:
            out_ = []
            for k in t["killer"]:
                w = KILLED_BY.get(k)
                if not w:
                    missed.append(f"manual_qmd KILLED_BY: no words for the killer {k}")
                elif w not in out_:
                    out_.append(w)
            return ", ".join(out_)
        if "damage" in t:
            w = DAMAGE_FROM.get(t["damage"])
            if not w:
                missed.append(f"manual_qmd DAMAGE_FROM: no words for {t['damage']}")
            return w
        if "turned_back" in t:
            return "raids turned back"
        if "walls_met" in t:
            return "walls"
        if "mended" in t:
            return "repair robots"
        missed.append(f"manual_qmd answers: a trigger with no words: {t}")
        return None

    U, order = {}, {}

    def card(uid, fac, base, portrait, era=None, era_level=None, cost=None, counters=None):
        if base not in proto:
            missed.append(f"{uid}: no prototype {base} in the dump")
            return
        u = proto[base]
        dmg, dtext, rng, spd = weapon(base)
        rec = {"name": bare(shown(uid if uid in proto else base)), "faction": fac, "health": num(u["max_health"])}
        if portrait:
            rec["portrait"] = portrait
        if dmg is not None:
            rec["damage"], rec["damage_text"] = num(dmg), dtext
        if rng is not None:
            rec["range"] = num(rng)
        if spd is not None:
            rec["speed"] = num(spd * 60)
        if "lp-air-unit" in (u.get("trigger_target_mask") or []):
            rec["air"] = True
        if cost:
            rec["cost"] = cost
        if era:
            rec["era"] = era
        if era_level is not None:
            rec["era_level"] = era_level
        role = role_of(uid, base)
        if role:
            rec["role"] = role
        if counters and W.get("counters", {}).get(uid):
            missed.append(f"words.cfg [counters] {uid}: the code says it ({counters})")
        rec["counters"] = counters or word("counters", uid)
        rec["countered_by"] = word("countered-by", uid)
        rec["blurb"] = word("blurb", uid)
        U[uid] = rec
        order.setdefault(fac, []).append(uid)

    def portrait_of(kind, corp=None):
        # A unit's portrait: media/portraits, by prototype, a corporation's own variant first.
        for name in ([f"lp-{corp}-{kind[3:]}"] if corp and corp != "serenity" else []) + [kind]:
            if os.path.exists(os.path.join(M, "media", "portraits", name + ".png")):
                return name
        return None

    def icon_of(kind):
        # A lab's icon at the head of its tree column (media/buildings, from the field guide's pictures).
        p = rp.portrait(kind)
        return copy_png(p) if p else None

    def pic_or_none(stem):
        return stem if stem and os.path.exists(os.path.join(M, "media", "portraits", stem + ".png")) else None

    def parts(kind):
        return f"{unit_cost[kind]} parts" if unit_cost.get(kind) else None

    trees = {}

    # ---- the corporations: cards and unit trees (shared.CORPS: mix, unlock levels, tree; labs; triggers) ----
    for corp in ("serenity", "grubstake"):
        c = corps[corp]
        fac = FACTION_IDS[corp]
        mix = sorted((c.get("mix") or {}).items(), key=lambda kv: (rp.data["unlock"].get(kv[0], 0), -kv[1], kv[0]))
        cols, seen = [], set()
        for n in c["tree"]:
            if n["branch"] not in seen:
                seen.add(n["branch"])
                lab = (c.get("labs") or {}).get(n["branch"])
                col = {"id": n["branch"], "label": shown(lab) if lab else rp.BRANCH_NAME.get(n["branch"], n["branch"])}
                icon = lab and icon_of(lab)
                if icon:
                    col["icon"] = icon
                cols.append(col)
        max_era = max(n.get("era", 0) for n in c["tree"])
        bands = [{"id": "land", "label": "Landing", "free": True}, {"id": "track", "label": "Damage"}] + \
                [{"id": str(e), "label": f"Era {e}"} for e in range(1, max_era + 1)]
        nodes = []

        def uid_of(kind):
            if corp == "serenity":
                return kind
            renamed = (c.get("names") or {}).get(kind)
            if renamed and renamed in proto:
                return renamed
            return f"lp-grubstake-{kind[3:]}"

        for kind, _ in mix:
            uid = uid_of(kind)
            lvl = rp.data["unlock"].get(kind, 0)
            era = "From landing" if not lvl else f"From its level {lvl}"
            pic = portrait_of(uid if uid != kind else kind, None if uid != kind else corp)
            card(uid, fac, uid if uid in proto else kind, pic, era, 0 if not lvl else None, parts(kind))
            nodes.append({"id": "mix-" + kind, "band": "land", "label": U.get(uid, {}).get("name", kind), "portrait": pic_or_none(pic),
                          "note": era[0].lower() + era[1:]})
        for n in c["tree"]:
            node = {"id": n["id"], "band": "track" if n.get("track") else str(n.get("era", 0)), "column": n["branch"]}
            if n.get("requires"):
                node["requires"] = [n["requires"]]
            ans = answers(n.get("trigger"))
            if ans:
                node["answers"] = ans
            if n.get("unit"):
                kind = n["unit"]["kind"]
                uid = uid_of(kind)
                lab = (c.get("labs") or {}).get(n["branch"])
                where = shown(lab) if lab else rp.BRANCH_NAME.get(n["branch"], n["branch"])
                pic = portrait_of(kind, corp)
                card(uid, fac, uid if uid in proto else kind, pic, f"Era {n['era']}, {where}", n["era"], parts(kind), ans)
                node.update({"label": U.get(uid, {}).get("name", kind), "portrait": pic_or_none(pic), "note": f"{fmt_n(n['cost'])} parts"})
            elif n.get("track"):
                node.update({"label": rp.node_name(n["id"]), "kind": "upgrade",
                             "note": f"{track_levels(n, rp.roster.d)} levels, {fmt_n(n['cost'])} parts a level"})
            else:
                node.update({"label": rp.node_name(n["id"]), "kind": "ability" if n.get("ability") else "upgrade",
                             "note": f"{fmt_n(n['cost'])} parts"})
            nodes.append(node)
        trees[f"{fac}-units"] = {"title": f"{c['name']}'s unit tree", "kicker": "Unit tree", "faction": fac, "columns": cols,
                                 "bands": bands, "nodes": nodes, "max_height": 144}
        # Its trucks: the hauler (both corporations), the howitzer truck (Kessler-Hayashi's sieges, a grudge camp's).
        # A corporation that drops its siege guns from orbit (shared.CORPS orbital_drop) runs no howitzer truck.
        for kind in ("lp-hauler",) if c.get("orbital_drop") else ("lp-howitzer-truck", "lp-hauler"):
            uid = kind if corp == "serenity" else f"lp-grubstake-{kind[3:]}"
            card(uid, fac, kind, portrait_of(uid), None, None, parts(kind))

    # ---- Synthexis: its breeds by evolution (the incubator's result_units), then what it makes to order ----
    farm_src = src("scripts/farm.lua")
    for kind, pts in sorted(rp.PEN, key=lambda x: x[1][0][0]):
        evo = pts[0][0]
        cnt = None
        if kind == "lp-bred-cinder" and re.search(r'walled_held.*can\["lp-bred-cinder"\]', farm_src):
            cnt = "a wall that held its last wave"  # farm.lua: a wave sent where a wall held orders bursters
        if kind == "lp-bred-spore" and "flying units" in loc.get(("entity-description", kind), ""):
            cnt = "fliers, your robots"  # the locale: its spores hit flying units
        card(kind, "synthexis", kind, portrait_of(kind), f"Evolution {evo:g}", num(evo),
             f"{breeds[kind]['cost']} biomass" if kind in breeds else None, cnt)
    held = V["synthexis"]["develop_held"]
    extra = [("lp-bred-big-burster", f"Developed after {held} held walls",
              "the turrets covering its way in" if "turret guarding the way in" in loc.get(("entity-description", "lp-bred-big-burster"), "") else None),
             ("lp-sweeper", "Bred against mines",
              "minefields" if "minefields" in loc.get(("entity-description", "lp-sweeper"), "") else None),
             ("lp-bred-scout", "Made for each wave", None), ("lp-bred-carrier", "Sent by a grown culture", None),
             ("lp-technician", "Bought as the culture grows", None)]
    if (rp.data["biotech"].get("mind") or {}).get("probe"):
        extra.append(("lp-runt", "Made for a wave's probe", None))
    for kind, how, cnt in extra:
        card(kind, "synthexis", kind, portrait_of(kind), how, None,
             f"{breeds[kind]['cost']} biomass" if kind in breeds else None, cnt)
    # Its tree: the breeds by quarter of evolution (furniture: four bands read better than a band a threshold).
    syn_nodes = []
    for kind, pts in sorted(rp.PEN, key=lambda x: x[1][0][0]):
        line = BREED_LINE.get(kind)
        if not line:
            missed.append(f"manual_qmd BREED_LINE: no line for the breed {kind}")
            continue
        q = min(1, int(pts[0][0] * 2 + 1e-9))  # halves of evolution
        syn_nodes.append({"id": kind, "band": f"q{q}", "column": line, "label": U[kind]["name"],
                          "portrait": pic_or_none(U[kind].get("portrait")), "note": f"from {pts[0][0]:g}"})
    for kind, how, _ in extra:
        if kind in U:
            syn_nodes.append({"id": kind, "band": "made",
                              "label": U[kind]["name"], "portrait": pic_or_none(U[kind].get("portrait")), "note": how[0].lower() + how[1:]})
    trees["synthexis-breeds"] = {
        "title": "What Synthexis breeds", "kicker": "Breeds by evolution", "faction": "synthexis",
        "columns": [{"id": "biters", "label": "Biters"}, {"id": "spitters", "label": "Spitters"},
                    {"id": "special", "label": "Bred for a job"}],
        "bands": [{"id": f"q{q}", "label": f"{q / 2:g} to {(q + 1) / 2:g}"} for q in range(2)]
                 + [{"id": "made", "label": "Developed, made", "free": True}],
        "nodes": syn_nodes, "max_height": 144}

    # ---- your army: its units by the command bandwidth that unlocks them (the order recipes' technologies) ----
    cb = sorted((k for k in d["technology"] if re.match(r"lp-command-bandwidth-\d+$", k)), key=lambda k: int(k.rsplit("-", 1)[1]))
    unlocks = {}
    for tk in cb:
        for e in d["technology"][tk].get("effects") or []:
            if isinstance(e, dict) and (e.get("recipe") or "").endswith("-order"):
                unlocks[e["recipe"][:-6]] = int(tk.rsplit("-", 1)[1])
    army_max = max(unlocks.values())
    army_nodes = []
    for kind in sorted(unlocks, key=lambda k: (unlocks[k], bandwidth.get(k, 0), k)):
        lvl = unlocks[kind]
        card(kind, "player", kind, portrait_of(kind), rp.tname(cb[lvl - 1]), lvl,
             f"{bandwidth[kind]} bandwidth" if kind in bandwidth else None)
        if kind not in bandwidth:
            missed.append(f"shared.POPULATION: no bandwidth for {kind}")
        order_rec = d["recipe"].get(kind + "-order") or {}
        vehicle = any(i.get("name") in d.get("car", {}) or i.get("name") in d.get("item-with-entity-data", {})
                      for i in order_rec.get("ingredients") or [])
        army_nodes.append({"id": kind, "band": f"cb{lvl}", "column": "vehicles" if vehicle else "infantry", "label": U[kind]["name"],
                           "portrait": pic_or_none(U[kind].get("portrait")), "note": f"{bandwidth.get(kind)} bandwidth"})
    trees["player-army"] = {"title": "What the barracks trains", "kicker": "Unit tree", "faction": "player",
                            "columns": [{"id": "infantry", "label": "Infantry"}, {"id": "vehicles", "label": "Vehicles"}],
                            "bands": [{"id": f"cb{i}", "label": rp.tname(cb[i - 1]).replace("Command ", "").capitalize()} for i in range(1, army_max + 1)],
                            "nodes": army_nodes}

    # ---- your faction technologies: banded by the most advanced science pack on the way to each, by source ----
    # The packs ranked by how deep in the technology tree each is unlocked (the dump holds the technologies, not the
    # packs' item prototypes).
    depth_memo = {}

    def depth(tk, stack=()):
        if tk in depth_memo:
            return depth_memo[tk]
        t = d["technology"].get(tk) or {}
        v = 1 + max([depth(p, stack + (tk,)) for p in t.get("prerequisites") or [] if p not in stack] + [0])
        depth_memo[tk] = v
        return v

    unlocked_at = {}
    for tk, t in d["technology"].items():
        for e in t.get("effects") or []:
            if isinstance(e, dict) and (e.get("recipe") or "").endswith("-science-pack"):
                unlocked_at[e["recipe"]] = min(unlocked_at.get(e["recipe"], 1e9), depth(tk))
    all_packs = {i[0] for t in d["technology"].values() for i in (t.get("unit") or {}).get("ingredients", [])}
    pack_order = sorted(all_packs, key=lambda k: (unlocked_at.get(k, 0), k))
    pack_rank = {k: i for i, k in enumerate(pack_order)}

    def top_pack(tk, seen):
        if tk in seen or tk not in d["technology"]:
            return -1
        seen.add(tk)
        t = d["technology"][tk]
        best = max([pack_rank.get(i[0], -1) for i in (t.get("unit") or {}).get("ingredients", [])] + [-1])
        tr = t.get("research_trigger") or {}
        if tr.get("type") == "craft-item":
            best = max(best, pack_rank.get(tr.get("item"), -1))
        for p in t.get("prerequisites") or []:
            best = max(best, top_pack(p, seen))
        return best

    study_force = dict(re.findall(r'tech = "(lp-study-[a-z]+)", force = ("lp-[a-z]+"|[A-Z]+)', src("scripts/studies.lua")))
    force_col = {'"lp-grubstake"': "grubstake", "BIO": "synthexis", '"lp-serenity"': "kessler-hayashi"}
    names_col = {corps["serenity"]["name"]: "kessler-hayashi", corps["grubstake"]["name"]: "grubstake",
                 rp.data["biotech"]["name"]: "synthexis"}

    def schematic_source(item):
        rec = next((r for r in d["recipe"].values() if any(x.get("name") == item for x in r.get("results") or [])), None)
        return rec and (rec.get("ingredients") or [None])[0]

    def source_of(tk, t):
        if tk.startswith("lp-command-bandwidth"):
            return "army"
        if tk.startswith("lp-prize-"):
            return FACTION_IDS.get(tk[len("lp-prize-"):])
        tr = t.get("research_trigger") or {}
        if tr.get("type") == "capture-spawner":
            return "synthexis" if tr.get("entity") == "lp-pen" else None
        if tr.get("type") == "craft-item":
            ing = schematic_source(tr["item"])
            dsc = loc.get(("item-description", ing["name"]), "") if ing else ""
            m = re.search("|".join(map(re.escape, names_col)), dsc)  # "Salvaged from Kessler-Hayashi railgunners."
            return names_col[m.group(0)] if m else None
        study = next((q for q in t.get("prerequisites") or [] if q.startswith("lp-study-")), None)
        if study:
            return force_col.get(study_force.get(study, ""))
        dsc = loc.get(("entity-description", tk), "") + loc.get(("technology-description", tk), "")
        if tk == "lp-player-dome" and ("dome-projector", "") and "artillery shells" in dsc:
            return "kessler-hayashi"  # its domes are Kessler-Hayashi's design (the dome projector's, dome.lua)
        # A technology whose recipes take a faction's salvage (the orbital cannon's targeting array, Kessler-Hayashi's
        # orbital beacon): that faction's, by the salvage's description.
        for e in t.get("effects") or []:
            r = d["recipe"].get(e.get("recipe") or "") if isinstance(e, dict) else None
            for ing in (r or {}).get("ingredients") or []:
                m = re.search("|".join(map(re.escape, names_col)), loc.get(("item-description", ing.get("name", "")), ""))
                if m and loc.get(("item-description", ing["name"]), "").startswith("Salvaged from"):
                    return names_col[m.group(0)]
        return None

    T_nodes, bands_used = [], set()
    for tk in sorted(k for k in d["technology"] if k.startswith("lp-") and not k.startswith("lp-study-")):
        t = d["technology"][tk]
        col = source_of(tk, t)
        if not col:
            missed.append(f"{tk}: no faction it comes from")
            continue
        tr = t.get("research_trigger") or {}
        study = next((q for q in t.get("prerequisites") or [] if q.startswith("lp-study-")), None)
        band = top_pack(tk, set())
        if t.get("hidden") and not tk.startswith("lp-prize-"):
            continue  # retired, hidden in the game (the one-shot strike beacon's Orbital strike, 0.2.274)
        if t.get("hidden"):
            how, band, note = "spoils", "fall", "its headquarters falls"
        elif tr.get("type") == "craft-item":
            ing = schematic_source(tr["item"])
            n = ing.get("amount", 1) * tr.get("count", 1)
            nm = lname("item-name." + ing["name"]).lower()
            how, note = "teardown", f"{n} {nm}s" if n > 1 else ("an " if nm[0] in "aeiou" else "a ") + nm
        elif tr.get("type") == "capture-spawner":
            how, note = "capture", "capture an " + lname("entity-name." + tr["entity"]).replace(rp.data["biotech"]["name"] + " ", "").lower()
        elif study:
            how, note = "study", loc.get(("lp", study[3:]), "").rstrip(".")
            note = note[:1].lower() + note[1:]
        else:
            fx = [e["recipe"] for e in t.get("effects") or [] if isinstance(e, dict) and (e.get("recipe") or "").endswith("-order")]
            how = "science"
            note = ", ".join(lname("recipe-name." + r).lower() + "s" for r in fx) if fx else \
                ("repeatable" if (t.get("unit") or {}).get("count_formula") else None)
        space = pack_rank.get("space-science-pack")
        if space is not None and band != "fall" and band > space:
            band = space + 1  # the planets' packs share one band, "Other worlds" (a band a pack overflowed its label)
        bands_used.add(band)
        node = {"id": tk, "band": str(band), "column": col, "label": rp.tname(tk), "kind": "tech", "how": how}
        if note:
            node["note"] = note
        req = [q for q in t.get("prerequisites") or [] if q.startswith("lp-") and not q.startswith("lp-study-")]
        if req:
            node["requires"] = req
        T_nodes.append(node)
    # Within a cell, a technology after the one it needs (the layout stacks a cell's linked nodes in this order).
    def chain(n, seen=()):
        return 1 + max([chain(q, seen + (n,)) for q in d["technology"][n].get("prerequisites") or []
                        if q.startswith("lp-") and not q.startswith("lp-study-") and q not in seen] + [0])
    T_nodes.sort(key=lambda n: (chain(n["id"]), n["id"]))
    space = pack_rank.get("space-science-pack")
    tbands = [{"id": str(b), "label": "Other worlds" if space is not None and b > space
               else lname("item-name." + pack_order[b]).replace(" science pack", "")}
              for b in sorted(b for b in bands_used if b != "fall")] + \
             ([{"id": "fall", "label": "A fall"}] if "fall" in bands_used else [])
    tcols = [{"id": "army", "label": "Your army", "faction": "player"},
             {"id": "grubstake", "label": "From " + corps["grubstake"]["name"], "faction": "grubstake"},
             {"id": "synthexis", "label": "From " + rp.data["biotech"]["name"], "faction": "synthexis"},
             {"id": "kessler-hayashi", "label": "From " + corps["serenity"]["name"], "faction": "kessler-hayashi"}]
    split = pack_rank.get("chemical-science-pack")
    if split is None:
        missed.append("the dump: no chemical science pack to split the faction technologies at")
        split = 0
    legend = {"teardown": "Teardown: craft its parts", "study": "Field study, then science", "science": "Science packs",
              "capture": "Capture", "spoils": "Spoils of a fall"}
    halves = {"early": lambda b: b != "fall" and int(b) < split, "late": lambda b: b == "fall" or int(b) >= split}
    for half, inside in halves.items():
        keep = [n for n in T_nodes if inside(n["band"])]
        ids = {n["id"] for n in keep}
        nodes_h = []
        for n in keep:
            n = dict(n)
            out_req = [q for q in n.get("requires", []) if q not in ids]
            n["requires"] = [q for q in n.get("requires", []) if q in ids]
            if not n["requires"]:
                del n["requires"]
            if out_req:
                n["note"] = (n.get("note", "") + ", " if n.get("note") else "") + "after " + ", ".join(rp.tname(q) for q in out_req)
            nodes_h.append(n)
        trees[f"player-techs-{half}"] = {
            "title": "Faction technologies" + (", early" if half == "early" else ", late"), "kicker": "Tech tree",
            "faction": "player", "columns": tcols, "bands": [b for b in tbands if inside(b["id"])], "nodes": nodes_h,
            "max_height": 144, "legend": legend}

    # ---- factions ----
    def motto(fid, from_code):
        if from_code:
            if W.get("motto", {}).get(fid):
                missed.append(f"words.cfg [motto] {fid}: shared.lua has one")
            return from_code
        return word("motto", fid)

    F = {}
    for corp in ("grubstake", "serenity"):
        fid = FACTION_IDS[corp]
        block = re.search(rf"^  {corp} = \{{name = \"[^\"]+\", force = \"[^\"]+\", color = \{{r = ([\d.]+), g = ([\d.]+), b = ([\d.]+)\}}",
                          shared_src, re.M)
        mot = re.search(rf"^  {corp} = \{{.*?\bmotto = \"([^\"]+)\"", shared_src, re.M | re.S)
        if not block:
            missed.append(f"shared.lua: {corp}'s colour")
            continue
        F[fid] = {"name": corps[corp]["name"], "color": hexcol({"r": float(block.group(1)), "g": float(block.group(2)), "b": float(block.group(3))}),
                  "motto": motto(fid, mot.group(1) if mot else None), "vista": f"media/vistas/{VISTA[fid]}.jpg", "tab": TABS[fid],
                  "hero": f"media/heroes/{fid}.jpg", "emblem": EMBLEM[fid],
                  "era_label": "Era", "era_max": max(n.get("era", 0) for n in corps[corp]["tree"])}
    F["synthexis"] = {"name": rp.data["biotech"]["name"], "color": hexcol(rp.data["biotech"]["color"]),
                      "motto": motto("synthexis", None), "vista": f"media/vistas/{VISTA['synthexis']}.jpg",
                      "hero": "media/heroes/synthexis.jpg", "emblem": EMBLEM["synthexis"],
                      "tab": TABS["synthexis"], "era_label": "Evolution", "era_max": 1}
    F["player"] = {"name": "Your army", "color": PLAYER_CHROME, "motto": motto("player", None),
                   "hero": "media/heroes/player-army.jpg", "emblem": EMBLEM["player"], "tab": TABS["player"], "era_label": "Unlock",
                   "era_max": army_max, "cover": False}
    for fid, f in F.items():
        for k in ("vista", "hero"):
            if k in f and not os.path.exists(os.path.join(M, f[k])):
                missed.append(f"{fid}: no {k} {f[k]}")
        if not os.path.exists(os.path.join(M, "media", "portraits", f["emblem"] + ".png")):
            missed.append(f"{fid}: no portrait for its back-cover emblem {f['emblem']}")

    for sec, keys in W.items():
        for k in keys:
            if (sec, k) not in used and not (sec == "motto"):
                missed.append(f"words.cfg [{sec}] {k}: not a unit of the roster, or the code already says it")
    for uid, rec in U.items():
        for k in ("health", "counters", "countered_by", "blurb"):
            if rec.get(k) in (None, ""):
                missed.append(f"{uid}: no {k}")
    if missed:
        raise SystemExit("manual_qmd (booklet): not found, the booklet's data not written:\n  " + "\n  ".join(dict.fromkeys(missed)))

    for t in trees.values():  # no nulls: the filter reads JSON null as a value (a node with no portrait has none)
        t["nodes"] = [{k: v for k, v in n.items() if v is not None} for n in t["nodes"]]
    data = {"_comment": "Written by scripts/roster_page.py --qmd (scripts/manual_qmd.py, booklet) from the prototype dump, "
                        "shared.lua, the scripts, the locale and docs/manual/words.cfg. Do not edit: run it again.",
            "edition": f"For Landing Party {V['mod']['version']}", "portraits": "media/portraits", "factions": F, "units": U,
            "trees": trees}
    open(os.path.join(GEN, "lp-data.json"), "w").write(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    for fac in ("kessler-hayashi", "grubstake", "synthexis", "player"):
        L = []
        for uid in order.get(fac, []):
            L += [f'::: {{.unit unit="{uid}"}}', U[uid]["blurb"], ":::", ""]
        out(f"cards-{fac}.qmd", L)
