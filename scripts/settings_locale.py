#!/usr/bin/env python3
"""The settings' dropdown labels ([string-mod-setting] in locale/en/locale.cfg), written from shared.lua's values, so no
multiplier in them is typed (the locale's rule: numbers are never typed). check.sh runs it with --check.
  scripts/settings_locale.py [--check]"""
import pathlib, re, sys

REPO = pathlib.Path(__file__).resolve().parent.parent
SHARED = REPO / "landing-party" / "shared.lua"
LOCALE = REPO / "landing-party" / "locale" / "en" / "locale.cfg"

# Which faction has which preset lever (settings.lua makes the same).
LEVERS = {"strength": ["grubstake", "serenity"], "aggression": ["grubstake", "serenity", "biotech"],
          "income": ["grubstake", "serenity", "biotech"]}
TUNE_NAMES = {"very-low": "Very low", "low": "Low", "normal": "Normal", "high": "High", "very-high": "Very high"}
DIFFICULTY_NAMES = {"easy": "Easy", "normal": "Normal", "hard": "Hard", "very-hard": "Very hard"}
DIRECTOR_NAMES = {"steady": "Steady", "gentle": "Gentle", "chaotic": "Chaotic", "off": "Off"}
ARRIVAL_NAMES = {"oil-processing": "On researching oil processing",
                 "chemical-science-pack": "On the first chemical science pack",
                 "production-science-pack": "On the first production science pack",
                 "utility-science-pack": "On the first utility science pack",
                 "rocket": "On the first rocket launch"}


def table(src, name):
    m = re.search(r"^shared\." + name + r" = \{(.*?)\}\s*$", src, re.M)
    if not m:
        sys.exit(f"settings_locale: no shared.{name} in shared.lua")
    out = {}
    for key1, key2, v in re.findall(r'(?:\["([\w-]+)"\]|(\w+))\s*=\s*([\d.]+)', m.group(1)):
        out[key1 or key2] = float(v)
    return out


def arrivals(src):
    block = re.search(r"^shared\.ARRIVALS = \{(.*?)\n\s*\}\}?\s*$", src, re.M | re.S)
    if not block:
        sys.exit("settings_locale: no shared.ARRIVALS in shared.lua")
    out = {}
    for corp, allowed in re.findall(r'(\w+) = \{default = "[\w-]+",\s*allowed = \{([^}]*)\}', block.group(1)):
        out[corp] = re.findall(r'"([\w-]+)"', allowed)
    return out


def times(v):
    return "" if v == 1 else f" (×{v:g})"


def section():
    src = SHARED.read_text()
    tune, diff, arr = table(src, "TUNE"), table(src, "DIFFICULTY"), arrivals(src)
    lines = ["[string-mod-setting]"]
    for key, label in DIFFICULTY_NAMES.items():
        if key not in diff:
            sys.exit(f"settings_locale: difficulty {key} not in shared.DIFFICULTY")
        lines.append(f"lp-difficulty-{key}={label}{times(diff[key])}")
    for lever, corps in LEVERS.items():
        for corp in corps:
            for key, label in TUNE_NAMES.items():
                if key not in tune:
                    sys.exit(f"settings_locale: level {key} not in shared.TUNE")
                lines.append(f"lp-{corp}-{lever}-{key}={label}{times(tune[key])}")
    # The director's personalities (shared.DIRECTOR_PERSONALITIES, settings.lua's lp-director).
    m = re.search(r'^shared\.DIRECTOR_PERSONALITIES = \{([^}]*)\}', src, re.M)
    for key in re.findall(r'"([\w-]+)"', m.group(1) if m else ""):
        if key not in DIRECTOR_NAMES:
            sys.exit(f"settings_locale: no label for director personality {key}")
        lines.append(f"lp-director-{key}={DIRECTOR_NAMES[key]}")
    for corp, allowed in arr.items():
        for key in allowed:
            if key not in ARRIVAL_NAMES:
                sys.exit(f"settings_locale: no label for arrival {key}")
            lines.append(f"lp-{corp}-arrival-{key}={ARRIVAL_NAMES[key]}")
    return "\n".join(lines) + "\n"


def main():
    text = LOCALE.read_text()
    new = section()
    m = re.search(r"^\[string-mod-setting\]\n.*?(?=^\[|\Z)", text, re.M | re.S)
    if not m:
        sys.exit("settings_locale: no [string-mod-setting] section in locale.cfg")
    old = m.group(0)
    want = new + ("\n" if old.endswith("\n\n") else "")
    if "--check" in sys.argv:
        if old != want:
            sys.exit("settings_locale: locale.cfg's dropdown labels out of date with shared.lua: run scripts/settings_locale.py")
        print("settings locale ok")
        return
    LOCALE.write_text(text[:m.start()] + want + text[m.end():])
    print(f"settings_locale: {new.count(chr(10)) - 1} labels written")


if __name__ == "__main__":
    main()
