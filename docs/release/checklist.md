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
- Trailer: media/trailer/cut-27 (2026-11-16, 0.2.431: 112 s, 56 bars, the drive score; a strike force on nw's furnace
  rows at night as shots 9 and 10, the bomb drones' shot refilmed with a smoothed camera, the end card restored;
  contact sheet media/trailer/cut-27-contact.png; thumbnail: media/trailer/thumbnail-split.png; title and description drafted).

## Decided (the user, 2026-11-15)
- **Version 0.3.0** for the first upload, a public beta.
- **No PNG recompression**: about 18 MB saved of 163 was not worth it ("Do we need to bother for 10 MB?").
- **The page links the manual PDF and the source repository.**
- **The trailer's music:** variants proposed first, to try to improve it, before the credit is written.
- Before the upload: the playtest and calibration set up; the sound pass ("would increase the value of the mod
  greatly"); the mod page with GIFs; a multiplayer run with the director; the manual's pictures. Then the trailer,
  the release regression and the upload.

## For the user to decide
- **Version number** for the first upload (1.0.0, or 0.3.0 as a public beta).
- **The zip's size**: PNGs are 154 of its 163 MB. Lossless recompression (oxipng -o 3, no pixel changed) saved 12% on the
  twelve largest sheets (25 to 22 MB), so the zip would be about 145 MB; lossy (pngquant) about half, at a risk to the
  art. Not done: the art's files are untouched.
- **The music credit** in the trailer's description and on the page.
- **Multiplayer**: `scripts/mp.sh` showed no desync in two runs (2026-11-07). With the director (2026-11-15, 0.2.426):
  heavy mode passed with ten of its beats out, and a client played 8 minutes at half speed through sieges, strikes and
  the director's strike and joint commands, no desync (the joint itself impossible on that save: one corporation at
  war). On the way: a ledger from before 0.2.325 crashed its first collection (fixed, 0.2.424). Not yet covered: two
  clients using the army and the faction GUIs.
- Whether the page links the manual PDF and the source repository.

## Still to do before upload
- The playtest and lever calibration (waiting on the user).
- Art: the ratings' redo round is done (the user, 2026-11-16: the turret and flamer shadows fixed, nothing else to redo).
  Left: Kessler-Hayashi's hauler, which has no model of its own: the user's idea, its tank chassis with no turret, an
  APC. The walker is cut for 0.3.0.
- The manual revisited (in progress, 2026-11-10) and its PDF hosted somewhere linkable.
- A last full regression on the release commit (`scripts/regress.sh 12345`, all of it).
- Upload: mods.factorio.com, "Upload new mod", the zip from media/release/; then the page text, gallery and tags.
