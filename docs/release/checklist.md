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
- Trailer: media/trailer/cut-25 (thumbnail: media/trailer/thumbnail-split.png; title and description drafted).

## For the user to decide
- **Version number** for the first upload (1.0.0, or 0.3.0 as a public beta).
- **The zip's size**: PNGs are 154 of its 163 MB. Lossless recompression (oxipng) changes no pixel and saves some; lossy
  (pngquant) about half, at a risk to the art. Not done.
- **The music credit** in the trailer's description and on the page.
- **Multiplayer**: `scripts/mp.sh` showed no desync in two runs (2026-11-07); two clients using the army and the faction
  GUIs are not yet covered.
- Whether the page links the manual PDF and the source repository.

## Still to do before upload
- The playtest and lever calibration (waiting on the user).
- The art direction pass (graphics-pass memory).
- The manual revisited (in progress, 2026-11-10) and its PDF hosted somewhere linkable.
- A last full regression on the release commit (`scripts/regress.sh 12345`, all of it).
- Upload: mods.factorio.com, "Upload new mod", the zip from media/release/; then the page text, gallery and tags.
