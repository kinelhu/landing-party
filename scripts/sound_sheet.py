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
    if i.startswith(("kh-", "drone", "dome", "orbital")):
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
           "Arc flamer's bolt",
           # (Round four's twelve, in the mod since 0.2.425.)
           "Dozer's ram", "Grubstake light engine", "Kessler-Hayashi light and heavy drives", "Grubstake steps",
           "The player's troops' steps", "Light, heavy and drone deaths", "Strike force pods' klaxon",
           "A camp's landing roar", "A mast going up",
           # (Round five's nine, in the mod since 0.2.426.)
           "Grubstake heavy engine", "Laser drone's flight", "Harrier's flight", "Kessler-Hayashi steps",
           "A siege's horn", "Kessler-Hayashi trooper's death", "Grubstake trooper's death", "Sapper's throw",
           "A dome's catch"]
TEXT = {
    4: ("Sounds, round four", "Movement, deaths, the last silent weapons and the events you should hear. Play Now, then "
        "Proposed, and mark each: keep it, drop it, or say how to change it. Where two cards propose the same sound, keep "
        "the one you prefer and drop the other. Nothing goes into the mod until it is kept here."),
    5: ("Sounds, round five", "Round four's twelve keeps are in the mod. Here are its four tweaks as you asked, and the "
        "redos: the foot soldiers' deaths split into Kessler-Hayashi's machines and Grubstake's people, a harrier on an "
        "engine and a propeller, a sapper's charge you can hear, a dome catch with electricity, and three orbital calls. "
        "Where cards share a letter series (A, B, C), keep the one you prefer and drop the others."),
    6: ("Sounds, round six", "The orbital strike as a whole: Kessler-Hayashi's spotter paints for 12 seconds, silent "
        "today, then its first shell lands and pairs follow every third of a second. Each card plays the full sequence: the "
        "call, the uplink's hum and its own voices rising over the paint, a rush in the last half second, then the first "
        "six impacts at their real times, the explosions' own sounds unchanged. Now plays what you hear today. D, E and F "
        "keep round six's characters; keep one. The last card is your cannon's 5-second version of the same idea, and it "
        "will follow whichever of D, E and F you keep."),
}

page = open(os.path.join(os.path.dirname(__file__), "sound_sheet.tmpl.html")).read()
title, lede = TEXT.get(ROUND, ("Sounds, round %d" % ROUND, ""))
page = (page.replace("__TITLE__", html.escape(title)).replace("__LEDE__", html.escape(lede)).replace("__ROUND__", str(ROUND)).replace("__ROWS__", json.dumps(rows))
        .replace("__QUESTIONS__", json.dumps(QUESTIONS)).replace("__SETTLED__", json.dumps(settled)))
open(OUT, "w").write(page)
print("%s: %d sounds, %d questions, %.1f MB" % (OUT, len(rows), len(QUESTIONS), os.path.getsize(OUT) / 1e6))
