#!/usr/bin/env python3
"""Round four's kept sounds that one Sound prototype cannot play as the board did (a layer over the game's recording,
a cut): rendered as the board renders them (scripts/sound_board.py's burst), mono, to landing-party/sound/. The user,
2026-11-15, on the arc flamer's processed copy: "keep the copy". The rest of round four's keeps are the game's own
files at a speed and volume (landing-party/sounds.lua).
  python3 tools/sound/round4.py
"""
import os, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "scripts"))
import sound_board as sb  # noqa: E402

OUT = os.path.join(REPO, "landing-party", "sound")
T = tempfile.mkdtemp(prefix="lp-r4-")


def ogg(wav, name):
    dst = os.path.join(OUT, name)
    subprocess.run(["sox", wav, "-r", "44100", "-c", "1", os.path.join(T, "m.wav")], check=True)  # (at the board's levels: the volume the user heard)
    subprocess.run(["sox", os.path.join(T, "m.wav"), "-C", "5", dst], check=True)
    d = subprocess.run(["soxi", "-D", dst], capture_output=True, text=True).stdout.strip()
    print("%s %s s" % (os.path.relpath(dst, REPO), d))


sb.TABLE = os.path.join(REPO, "docs", "sound", "round4.lua")
cards = {c["id"]: c for c in sb.table()}

# The drives and the mast: the board's card, one loop (dur), its layers over it, at its levels.
for cid, name in (("kh-light-engine", "kh-light-drive.ogg"), ("kh-heavy-engine", "kh-heavy-drive.ogg"),
                  ("mast-up", "mast-up.ogg")):
    c = cards[cid]
    w = os.path.join(T, cid + ".wav")
    sb.burst(w, c["files"], c["speed"], c["volume"], c["every"], 1, c.get("layers", []), synth=c.get("synth"), dur=c.get("dur"))
    ogg(w, name)

# The pods' klaxon, one pulse fewer (the user: "Maybe one less klaxon?"): the short silo alarm's three cut to two, at
# the card's speed (its pulses end 1.75, 4.5 and 7.5 s in at speed 1; cut at 5.5 with a fade).
c = cards["pods-alarm"]
src = os.path.join(sb.DATA, c["files"][0])
w = os.path.join(T, "pods.wav")
subprocess.run(["sox", src, w, "trim", "0", "5.5", "fade", "0", "5.5", "0.3", "speed", str(c["speed"]), "vol",
                str(c["volume"])], check=True)
ogg(w, "pods-alarm.ogg")
