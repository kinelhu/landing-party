# Landing Party

A Factorio mod developed with Claude: a rival machine faction lands and builds settlements of its own.
Prototype stage. Design: `DESIGN.md` (read it first). Mod folder: `landing-party/`, prefix `lp-`.
Sister project: `~/Dev/factorio-mods` (Empirical Science); the two share the dev profile, nothing else.

## Environment
- Factorio **2.0.77** + Space Age, Steam install, macOS arm64. Paths live in `scripts/env.sh`.
- Game data (the best examples of how things are really done): `$APP/data/{core,base,space-age,quality,elevated-rails}`.
- **API reference, version-matched:** `$APP/doc-html/runtime-api.json` and `prototype-api.json`.
  Look up every API before using it. Memory mixes the 1.1 and 2.0 APIs, which differ a lot.

## Headless first
The user's time in game is the scarce resource; a headless run costs none. Every mechanic gets a scripted
scenario with assertions before anyone plays it. The game window is for art, feel and GUI only, and only
at milestones, asked for.
- `scripts/sim.sh <scenario> [seed] [minutes] [every] [strike]`: one run in its own profile (base game only,
  no biters; the settlement arrives as the real one does, `LP_DISTANCE` tiles from spawn). Plots
  (`growth.png`, `final.png`), the planner's `decisions.txt` and results go to `docs/sim/<scenario>-<seed>/`
  (gitignored). Look at the plots before claiming anything about layout.
- **Regression: `scripts/regress.sh [seed]`** (about 3 minutes): scenarios that strike run from forks, short
  ones in full. `--full` adds the long growth scenarios (about 10 more minutes): at milestones and before
  commits that touch growth, not after every change. After a change, run the scenarios that exercise it.
- First-contact timelines: `scripts/contact.sh [seed]` (three player variants, 2 hours, about 5 minutes;
  plots and event lists in `docs/sim/contact-<seed>-v<variant>/`). A design instrument, not a regression.
- Waiting on background runs: never `pgrep -f` a pattern that appears in the waiting command itself (it
  matches its own shell and never ends); wait on the run's process or its output file.
- Forks: `scripts/fork.sh <scenario> <seed> <strike>` saves a scenario 6 minutes before its strike once
  (keyed by a hash of the code that runs before a strike: changing operations or the player's army keeps
  them, changing growth rebuilds them); `LP_FORK=1
  scripts/sim.sh ...` runs only the rest from it (a siege run: 19 s instead of 2.5 min). Iterate on forks,
  confirm with full runs. The life GIF renders only with `LP_GIF=1` (it was most of a run's time).
- `scripts/batch.sh [scenarios] [seeds] [minutes] [strike]`: runs in parallel, one table of metrics. Fails if
  any run fails. Timings from a batch are inflated by contention: measure performance with one `sim.sh`.
- `scripts/sheet.py out.png <run dirs>` (via `uv run --with matplotlib`): many settlements at one scale with
  shape metrics. Judge variety there. `replay.py` (raid GIF and stills), `overview.py` (all settlements).
- `scripts/profile.sh [scenario] [seed] [minutes]`: per-tick engine timings. Profile before blaming code.
- Iterate on single short runs (`LP_FAST=true` grants a depot and parts); batch only to confirm.
- Do not edit `landing-party/` while a batch runs: the mod is linked, not copied, so runs that start later
  load the edited code and the batch confirms a mix.
- Scenarios live in `tests/lp-sim/control.lua` (grow, cut, raid, occupy, probe; unit spikes air, path, cost
  with `LP_UNITS`/`LP_MOVE`/`LP_TAG`). A new mechanic adds one.
- The shell is zsh: it does not word-split `$var` in loops. Write loops over parameter sets in `bash -c`.
- `scripts/check.sh`: load check beside Space Age and Quality (the sims run the base game alone).
- Seeds: use the five standard ones (12345 777 4242 101 31337) for regressions, a dozen for variety.
  Very small map seeds (2, 3) gave identical results once: avoid them.
- Engine questions: answer them with a scenario (see `probe`) or a throwaway spike, never from memory.

## Rules
- **Keep `DESIGN.md` current**: it is what design reviews read. Update the status table and the section
  concerned with every mechanic built, every decision, and every finding (bugs caught go in the findings
  log). Mark what is assumed, not tested.
- Determinism: per-settlement randomness comes from `scripts/rng.lua`, seeded and kept in `storage`; never
  `math.random`, never randomness in the data stage.
- Numbers shared by data and control live in `landing-party/shared.lua`; never type one twice.
- Verify final prototypes in the dump (`check.sh` writes it), not in the Lua source.
- Prototype changes need a game restart; `control.lua` changes need a save reload.
- Name every prototype with the `lp-` prefix.
- When a run exposes a bug, fix it and keep the run that caught it as a check (a scenario assertion or a
  metric bound), with a comment saying what it caught.

## Playing it
`scripts/setup-dev-profile.sh` links the mod into the shared dev profile, `scripts/play.sh` launches it.
In game: `/lp-land [distance]` lands a settlement east of you, `/lp-trace` logs the planner to
`script-output/landing-party/decisions.txt`.
