"""Every locale key Landing Party's final prototypes name (localised_name and localised_description, nested too) must
exist in its locale; a missing one shows in game as "Unknown key" (a Grubstake buggy did, 2026-10-23, and no test saw it).
And the locale stays in vanilla's register (docs/wip/locale-audit.md, 2026-11-02): the rules below that a pattern can
see. The audit's text had drifted back within three days (a dome description of 190 characters, "defences", "learnt",
"labelled", "fliers", "nest", 2026-11-05), and nothing had checked it.
Run by check.sh on the prototype dump:  python3 -I scripts/lint_names.py <data-raw-dump.json> <locale.cfg>
The register alone, without a dump:      python3 -I scripts/lint_names.py --register <locale.cfg>"""
import json
import re
import sys

register_only = sys.argv[1] == "--register"
cfg = open(sys.argv[2]).read()
dump = None if register_only else json.load(open(sys.argv[1]))
have, section, values = set(), None, []
for line in cfg.splitlines():
    m = re.match(r"^\[(.+)\]$", line.strip())
    if m:
        section = m.group(1)
    elif "=" in line and section and not line.startswith(";"):
        k, v = line.split("=", 1)
        have.add(section + "." + k.strip())
        values.append((section, k.strip(), v))

# ---- register (the audit's rules a pattern can check) ----
# Developer-facing lines: the admin dev tools' help.
DEV = {"lp.command-dev", "lp.command-trace"}
RULES = [
    # US spelling: vanilla is US English throughout (28 "armor", 0 "armour" in base.cfg).
    (r"\b(armour|armoury|defence|defences|colour|colours|labelled|labelling|learnt|travelled|behaviour|favour|centre|"
     r"metre|metres|grey)\b", "British spelling (vanilla is US English)"),
    # "round" for around ("the nests round its landing site").
    (r"\b(round (it|its|the|them|him|her))\b", "\"round\" for around"),
    # Vanilla says spawner (or enemy base); "nest" is not in its locale at all.
    (r"\bnests?\b", "\"nest\": vanilla says spawner"),
    # Vanilla's word is flying (units, robots); "flier" is the mod's own.
    (r"\bfliers?\b", "\"flier\": say flying units"),
    # Digits for numbers ("10 minutes", not "ten minutes").
    (r"\b(one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|thirty|sixty)( and a half)? "
     r"(seconds?|minutes?|hours?|tiles?)\b", "number as a word (vanilla writes digits)"),
    (r"\u2014", "em dash"),
    # The slogans the audit took out of every notice.
    (r"remain behind the line|thank you for your cooperation|resources in the right hands|engineered to adapt",
     "slogan"),
]
# Vanilla descriptions are one sentence, usually under 80 characters; the audit's longest kept is 134 (the invoice post).
# A line over this is a design lecture (the dome's 190, the old bursters' 210 and 290). Control tokens and rich text are
# not counted; a "\n" starts a new line.
DESC_MAX = 140
bad = []
for sec, k, v in values:
    if sec + "." + k in DEV:
        continue
    for pat, why in RULES:
        m = re.search(pat, v, re.I)
        if m:
            bad.append(f"{sec}.{k}: {why}: \"{m.group(0)}\"")
    if sec.endswith("-description"):
        for part in v.split("\\n"):
            n = len(re.sub(r"__CONTROL[A-Z_]*__|\[[^\]]*\]", "", part))
            if n > DESC_MAX:
                bad.append(f"{sec}.{k}: description line of {n} characters (over {DESC_MAX})")
if bad:
    print("LOCALE REGISTER LINT FAILED (docs/wip/locale-audit.md):")
    for b in bad:
        print("  " + b)
    sys.exit(1)
print("locale register ok")
if register_only:
    sys.exit(0)

def keys(ls):
    if isinstance(ls, str):
        if re.match(r"^[a-z-]+-(name|description)\.lp-", ls):
            yield ls
    elif isinstance(ls, list):
        # {"?", a, b, ...} takes the first alternative whose keys all exist: none of them is required.
        if ls and ls[0] == "?":
            return
        for x in ls:
            yield from keys(x)

missing = set()
for kind, protos in dump.items():
    for name, p in protos.items():
        if not isinstance(p, dict):
            continue
        for field in ("localised_name", "localised_description"):
            for k in keys(p.get(field)):
                if k not in have:
                    missing.add((k, name))
if missing:
    for k, name in sorted(missing):
        print(f"missing locale key {k} (named by {name})")
    sys.exit(1)
print("locale names ok")
