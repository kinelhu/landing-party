"""Every locale key Landing Party's final prototypes name (localised_name and localised_description, nested too) must
exist in its locale; a missing one shows in game as "Unknown key" (a Grubstake buggy did, 2026-10-23, and no test saw it).
Run by check.sh on the prototype dump:  python3 -I scripts/lint_names.py <data-raw-dump.json> <locale.cfg>"""
import json
import re
import sys

dump, cfg = json.load(open(sys.argv[1])), open(sys.argv[2]).read()
have, section = set(), None
for line in cfg.splitlines():
    m = re.match(r"^\[(.+)\]$", line.strip())
    if m:
        section = m.group(1)
    elif "=" in line and section and not line.startswith(";"):
        have.add(section + "." + line.split("=", 1)[0].strip())

def keys(ls):
    if isinstance(ls, str):
        if re.match(r"^[a-z-]+-(name|description)\.lp-", ls):
            yield ls
    elif isinstance(ls, list):
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
