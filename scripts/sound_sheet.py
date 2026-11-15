#!/usr/bin/env python3
"""The Sound Sheet: a listening page for a round of the sound board (the user, 2026-11-15: an MP4 board "is less than
ideal for giving feedback UI wise"). One card per sound, Now and Proposed as buttons, verdict chips and a note saved to
the page's store (feedback/<id>-r<round>), the questions of the round as cards of their own.
  python3 scripts/sound_sheet.py <clips dir from sound_board.py --clips> <round> <out.html> [questions.json]
Reads the clips' manifest.json; embeds the mp3s (a few MB). Settled sounds of earlier rounds are listed at the top."""
import base64, html, json, os, sys

CLIPS, ROUND, OUT = sys.argv[1], int(sys.argv[2]), sys.argv[3]
QUESTIONS = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else []
man = json.load(open(os.path.join(CLIPS, "manifest.json")))


def faction(r):
    i = r["id"]
    if i.startswith(("gs-", "harrier")):
        return "Grubstake"
    if i.startswith(("kh-", "drone")):
        return "Kessler-Hayashi"
    if i.startswith("player"):
        return "Player"
    return "Both"


def b64(path):
    return "data:audio/mpeg;base64," + base64.b64encode(open(path, "rb").read()).decode()


rows = []
for r in man:
    rows.append({"n": r["n"], "id": r["id"], "key": "%s-r%d" % (r["id"], ROUND), "label": r["label"], "now": r["now"],
                 "detail": r["detail"], "faction": faction(r),
                 "src_now": None if r["now"] == "silent" else b64(os.path.join(CLIPS, r["id"] + "-now.mp3")),
                 "src_new": b64(os.path.join(CLIPS, r["id"] + "-proposed.mp3"))})
settled = ["Grubstake machine-gun buggy and Scorcher", "Grubstake slug buggy", "Grubstake tank cannon",
           "Grubstake harrier's gun", "Kessler-Hayashi trooper's laser", "Kessler-Hayashi tank cannon",
           "Kessler-Hayashi Tesla", "Kessler-Hayashi laser drone", "Kessler-Hayashi Aegis and railgunner",
           "Arc flamer's bolt"]

page = open(os.path.join(os.path.dirname(__file__), "sound_sheet.tmpl.html")).read()
page = (page.replace("__ROUND__", str(ROUND)).replace("__ROWS__", json.dumps(rows))
        .replace("__QUESTIONS__", json.dumps(QUESTIONS)).replace("__SETTLED__", json.dumps(settled)))
open(OUT, "w").write(page)
print("%s: %d sounds, %d questions, %.1f MB" % (OUT, len(rows), len(QUESTIONS), os.path.getsize(OUT) / 1e6))
