#!/usr/bin/env python3
"""Round five's kept sounds that one Sound prototype cannot play as the board did (layers, a cut), rendered as the board
renders them (scripts/sound_board.py's burst), mono, at the board's levels, to landing-party/sound/; a death in several
variations (one recording of each voice a file), so the engine picks one at random as it does the game's own. The
user's tweaks on two keeps applied here, without another round (the coordinator's brief, 2026-11-15):
  harrier-b, "lower and quieter": its engine's speed 1.9 to 1.6 (pitch down by about 16%, three semitones), its
    volume 0.55 to 0.4 and its rattle 0.06 to 0.045 (both about 73%);
  kh-death-a, "quieter": its fall 2.6 to 1.6 and its whine 1.2 to 0.75 (both about 62%).
The dome's catch is rendered without the board's airburst: the catch's own explosion entity plays it in game.
  python3 tools/sound/round5.py
"""
import copy, os, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "scripts"))
import sound_board as sb  # noqa: E402

OUT = os.path.join(REPO, "landing-party", "sound")
T = tempfile.mkdtemp(prefix="lp-r5-")
sb.TABLE = os.path.join(REPO, "docs", "sound", "round5.lua")
cards = {c["id"]: c for c in sb.table()}


def ogg(wav, name):
    dst = os.path.join(OUT, name)
    m = os.path.join(T, "m.wav")
    subprocess.run(["sox", wav, "-r", "44100", "-c", "1", m], check=True)
    subprocess.run(["sox", m, "-C", "5", dst], check=True)
    st = subprocess.run(["sox", dst, "-n", "stat"], capture_output=True, text=True).stderr
    rms = [l.split()[-1] for l in st.splitlines() if l.startswith("RMS     amplitude")]
    d = subprocess.run(["soxi", "-D", dst], capture_output=True, text=True).stdout.strip()
    print("%s %s s, rms %s" % (os.path.relpath(dst, REPO), d, rms[0] if rms else "?"))


def render(c, name, files=None, layer_files=None, drop_layers=()):
    c = copy.deepcopy(c)
    layers = [l for i, l in enumerate(c.get("layers", [])) if i not in drop_layers]
    if layer_files is not None:
        for l, f in zip(layers, layer_files):
            if f:
                l["files"] = [f]
    sb.AF = c.get("af")
    w = os.path.join(T, name + ".wav")
    sb.burst(w, files or c["files"], c["speed"], c["volume"], c["every"], 1, layers, synth=c.get("synth"), dur=c.get("dur"))
    sb.AF = None
    ogg(w, name)


render(cards["gs-heavy-engine"], "gs-heavy-drive.ogg")
render(cards["siege-horn-a"], "siege-horn.ogg")
h = copy.deepcopy(cards["harrier-b"])
h["speed"], h["volume"] = 1.6, 0.4
h["layers"][0]["synth"] = h["layers"][0]["synth"].replace("vol 0.06", "vol 0.045")
render(h, "harrier-drive.ogg")
# Grubstake's foot death, B: each hit with a clatter of kit.
g = cards["gs-death-b"]
for i, (hit, kit) in enumerate([(g["files"][0], g["layers"][0]["files"][0]), (g["files"][1], g["layers"][0]["files"][1]),
                                (g["files"][0], g["layers"][0]["files"][2])], 1):
    render(g, "gs-death-%d.ogg" % i, files=[hit], layer_files=[kit])
# Kessler-Hayashi's foot death, A, quieter.
k = copy.deepcopy(cards["kh-death-a"])
k["volume"], k["layers"][0]["volume"] = 1.6, 0.75
for i in range(3):
    render(k, "kh-death-%d.ogg" % (i + 1), files=[k["files"][i]], layer_files=[k["layers"][0]["files"][i]])
# The dome's catch, B: the deeper bolt and its crackle (its airburst, the second layer, the catch's own explosion's).
dc = cards["dome-catch-b"]
for i, f in enumerate(dc["files"], 1):
    render(dc, "dome-catch-%d.ogg" % i, files=[f], drop_layers=(1,))
