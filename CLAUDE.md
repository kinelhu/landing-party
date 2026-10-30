# Landing Party

A Factorio mod developed with Claude: a rival machine faction lands and builds settlements of its own.
Prototype stage. Design: `DESIGN.md` (read it first). Mod folder: `landing-party/`, prefix `lp-`.
Sister project: `~/Dev/factorio-mods` (Empirical Science); the two share the dev profile, nothing else.

## Environment
- Factorio **2.1.23** + Space Age (Steam moved from 2.0.77 on 2026-10-23; the port is 0.2.0), Steam install, macOS arm64. Paths live in `scripts/env.sh`.
- Game data (the best examples of how things are really done): `$APP/data/{core,base,space-age,quality,elevated-rails}`.
- **API reference, version-matched:** `$APP/doc-html/runtime-api.json` and `prototype-api.json`.
  Look up every API before using it. Memory mixes the 1.1 and 2.0 APIs, which differ a lot.

## Headless first
The user's time in game is the scarce resource; a headless run costs none. Every mechanic gets a scripted
scenario with assertions before anyone plays it. The game window is for art, feel and GUI only, and only
at milestones, asked for.
- `scripts/sim.sh <scenario> [seed] [minutes] [every] [strike]`: one run in its own profile (with Space Age, Quality
  and Elevated Rails, a dependency since 2026-10-18; no biters; the settlement arrives as the real one does, `LP_DISTANCE` tiles from spawn). Plots
  (`growth.png`, `final.png`), the planner's `decisions.txt` and results go to `docs/sim/<scenario>-<seed>/`
  (gitignored). Look at the plots before claiming anything about layout.
- **Quick regression: `scripts/regress.sh 12345 --quick`** (44 runs, one or two a layer of the AI graph, about 6
  minutes) while iterating. A scenario whose outcome is settled ends early (`finish_early`, `settle_when` in
  `tests/lp-sim/control.lua`): its final checks run then, and the benchmark's remaining ticks cost almost nothing.
- **Before a commit: `scripts/regress.sh 12345 --changed`**: the quick set plus every scenario of the areas the
  uncommitted change touches (biotech, player, perception, growth, ops; a shared module runs everything). About 6 to
  20 minutes. `--area=biotech,ops` names areas instead; the table is in `regress.sh` (`area_of_scenario`,
  `areas_of_file`), and a new scenario or module goes in it. A change to the test harness alone selects nothing: name
  its areas. `LP_DRY=1` lists the runs without making them; every regression ends with its time and its slowest runs.
- **Whole list: `scripts/regress.sh [seed]`** (240 runs, about 37 minutes) at milestones; `--full` adds the long
  growth scenarios (about 40): before commits that touch growth. Scenarios that strike run from forks.
- First-contact timelines: `scripts/contact.sh [seed]` (three player variants, 2 hours, about 5 minutes;
  plots and event lists in `docs/sim/contact-<seed>-v<variant>/`). A design instrument, not a regression.
- **In-game looks: `/lp` dev tools** (`landing-party/scripts/dev.lua`; `/lp help`) force raids, sieges, strips,
  perimeter steps and landings on demand. Prefer them to saves timed so an event happens after loading. The
  playground: `LP_MIX=tour scripts/showcase.sh 12345 20`, then `scripts/play-showcase.sh tour`. A new mechanic
  worth looking at gets a `/lp` verb, and a check in scenario `dev`.
- **Real factories: `scripts/visit.sh <save.zip> [minutes]`** runs the corporations against a copy of a real save in
  its own profile (never the real profile or the original file; ask the user before copying one of theirs).
- **Siege lab: `scripts/siegelab.sh build`, then `scripts/siegelab.sh run <save.zip> [trials]`**: trials of Synthexis's real AI against a fortress save, defences rebuilt between trials, learning kept; a replay page per run (`docs/sim/lab-<save>/report.html`) and `lab-out.zip` to edit (map editor, time paused) and run again.
- **Reference factories: `scripts/make_reference.sh <belt|laser|artillery> [seed] [evolution]`** builds a control base
  (`tests/lp-ref`, without Landing Party) on a map with default biters and saves it to
  `~/Library/Application Support/factorio-lp-ref/<kind>.zip`, for `scripts/visit.sh` as any save: the same working,
  polluting core for all, defended by gun turrets (no robots), lasers and roboports, or lasers, roboports and artillery.
  The user's own saves stay the real-world check.
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
