# Release checklist (draft, 2026-11-10)

What stands between the mod as it is and a first upload, as of 0.2.277. Settled calls (memory, 2026-11-07/08): no
old-save upgrade work before the first release; no declared incompatibilities until a player reports a clash; the
manual revisited after calibration; an art direction pass before the playtest.

## Done
- MIT license; info.json (name, title, author, description, factorio_version 2.1, base and Space Age); thumbnail.png.
- changelog.txt: one entry, kept current (2026-11-10).
- `scripts/package.sh`: the portal's zip from the committed mod, loaded in a clean profile before it is handed over.
  0.2.277: 163 MB, 701 files, loads.
- Mod page text: docs/release/modpage.md (draft). Gallery: docs/release/gallery/ (ten frames, captions in modpage.md).
- Trailer: media/trailer/cut-30 (2026-11-16, 0.2.431: 118 s, 59 bars, the drive score; a strike force on nw's furnace
  rows at night as shots 9 and 10, twin cannons grafted on the user's Skipjack (graft D) firing and its strike on
  Kessler-Hayashi's siege as shots 34 and 35, the bomb drones' shot refilmed with a smoothed camera, the end card restored; contact sheet
  media/trailer/cut-30-contact.png; thumbnail: media/trailer/thumbnail-split.png; title and description drafted).

## Decided (the user, 2026-11-15)
- **Version 0.3.0** for the first upload, a public beta.
- **No PNG recompression**: about 18 MB saved of 163 was not worth it ("Do we need to bother for 10 MB?").
- **The page links the manual PDF and the source repository.**
- **The trailer:** done and on YouTube (the user, 2026-11-23: "we already have a good version. I uploaded it to YT").
  Left: its link on the mod page (modpage.md's [Trailer: link]), and the mod page's link in its YouTube description once
  the mod is uploaded (https://mods.factorio.com/mod/landing-party, the portal's address for info.json's name).
- Before the upload: the playtest and calibration set up; the sound pass ("would increase the value of the mod
  greatly"); the mod page with GIFs; a multiplayer run with the director; the manual's pictures. Then the trailer,
  the release regression and the upload.

## For the user to decide
- ~~The music credit~~: none needed (the user, 2026-11-23: "not needed. We did this ourselves?"; the score is
  generated here, scripts/trailer_score.py).
- **Multiplayer**: `scripts/mp.sh` showed no desync in two runs (2026-11-07). With the director (2026-11-15, 0.2.426):
  heavy mode passed with ten of its beats out, and a client played 8 minutes at half speed through sieges, strikes and
  the director's strike and joint commands, no desync (the joint itself impossible on that save: one corporation at
  war). On the way: a ledger from before 0.2.325 crashed its first collection (fixed, 0.2.424). Not yet covered: two
  clients using the army and the faction GUIs.

## Beta prep (2026-11-19, 0.2.464)
The user: a public beta takes on the playtest items not yet played (4, 6 to 10) and the calibration. Done: the page
text brought to 0.2.464 with a beta note and how to report (docs/release/modpage.md), the playtest kit's pre-beta
section (docs/playtest.md: ammunition, beacon right-click, wild biters, circuits). Left: the user's 20-minute session
on those; then the steps below.

## Still to do before upload
The backlog's "Before 0.3.0" (DESIGN.md, "Not built: the backlog") is the list; in short: the income fallback, the
playtest and calibration, the two-client multiplayer run, then the release steps below. Done since this list was
written: the APC hauler (0.2.429), the manual and its PDF (media/Landing-Party-manual.pdf, linked from the page), the
trailer (cut-27 with the drive score; the cannon battery shot in progress).
- A last full regression on the release commit (`scripts/regress.sh 12345`, all of it).
- Upload: mods.factorio.com, "Upload new mod", the zip from media/release/; then the page text, gallery and tags.

**0.3.1 prepared 2026-11-26 (night), for the user's go:** the fixes from their nw game (changelog 0.3.1; DESIGN.md's
findings log, "The user's nw game"). Committed locally (a7ea0422), not pushed. media/release/landing-party_0.3.1.zip
built by package.sh and loaded in a clean profile. To release: `git push`, then
`uv run --with requests python3 scripts/portal.py release --go` (the zip alone; not `details`: its loop links follow the
version, and v0.3.1 has no GitHub release with the loops).

**Released 2026-11-24:** 0.3.0 public on the mod portal (https://mods.factorio.com/mod/landing-party: 13 images, 10 loops
from the v0.3.0 GitHub release, the manual PDF there), made live on the user's "live" after they looked at it hidden.
