#!/usr/bin/env python3
"""Round six's kept builds (the user: strike-f and cannon-5s, "good if you just remove the downwards boop that comes
in right before the boom at the end (don't replace it with anything)"), rendered as the board renders them, mono, at its
levels, to landing-party/sound/: the voices over the paint only, the board's falling rush (its last half second) and the
impacts left out (the explosions are the shells' own, unchanged). Each ends on its strike's first impact: its length the
paint, a pass and a shell's fall, read from scripts/orbital.lua (PAINT, CANNON_PAINT, its pass, FALL at speed 3).
  lp-orbital-build.ogg  Kessler-Hayashi's strike, F: the Tesla's power-up slowed, the uplink's hum swelling, a detuned
                        triangle chord rising, a rumble, the gun's charge 10 s in
  lp-cannon-build.ogg   the player's cannon: the hum and D's saws over its paint (its charge, lp-cannon-charge, is the
                        call's own, played by orbital.from_orbit, so not in the file)
  python3 tools/sound/round6.py
"""
import copy, os, re, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "scripts"))
import sound_board as sb  # noqa: E402

OUT = os.path.join(REPO, "landing-party", "sound")
T = tempfile.mkdtemp(prefix="lp-r6-")
src = open(os.path.join(REPO, "landing-party", "scripts", "orbital.lua")).read()


def const(name):
    m = re.search(r"^local %s = (\d+) \* 60" % name, src, re.M)
    if m:
        return int(m.group(1)) * 60
    m = re.search(r"^local %s = (\d+)" % name, src, re.M)
    return int(m.group(1))


PAINT, CANNON_PAINT, FALL = const("PAINT"), const("CANNON_PAINT"), const("FALL")
FALL_TICKS = FALL // 3  # (its shells' speed, 3 tiles a tick: orbital.fall)
# (Its strikes are run every PASS ticks: the first shell falls on the pass after the one that turns it to fire, so its
# impact is PASS + FALL_TICKS after fire_at at the soonest, up to PASS - 1 later: the build ends a little early, not late.)
PASS = int(re.search(r"tick % (\d+) ~= 0 then return end", src).group(1))
sb.TABLE = os.path.join(REPO, "docs", "sound", "round6.lua")
cards = {c["id"]: c for c in sb.table()}


def render(c, name, paint, ticks, keep_main=True):
    c = copy.deepcopy(c)
    # (The rush and the impacts left out: every layer from the rush's tick on, the board's 20 ticks before the paint's
    # end, its impacts 10 after it.)
    cut = paint - 20
    layers = [l for l in c.get("layers", []) if l.get("offset", 0) < cut]
    print("  %s: %d layers kept, %d left out (offsets %s)" % (name, len(layers), len(c.get("layers", [])) - len(layers),
          sorted({l.get("offset", 0) for l in c.get("layers", []) if l.get("offset", 0) >= cut})))
    w = os.path.join(T, name + ".wav")
    sb.burst(w, c["files"] if keep_main else [], c["speed"], c["volume"], c["every"], 1, layers, dur=ticks / 60)
    m = os.path.join(T, "m.wav")
    subprocess.run(["sox", w, "-r", "44100", "-c", "1", m], check=True)
    dst = os.path.join(OUT, name)
    subprocess.run(["sox", m, "-C", "5", dst], check=True)
    st = subprocess.run(["sox", dst, "-n", "stat"], capture_output=True, text=True).stderr
    rms = [l.split()[-1] for l in st.splitlines() if l.startswith("RMS     amplitude")]
    print("%s %.2f s (%d ticks), rms %s" % (os.path.relpath(dst, REPO), ticks / 60, ticks, rms[0] if rms else "?"))


render(cards["strike-f"], "lp-orbital-build.ogg", PAINT, PAINT + PASS + FALL_TICKS)
render(cards["cannon-5s"], "lp-cannon-build.ogg", CANNON_PAINT, CANNON_PAINT + PASS + FALL_TICKS, keep_main=False)
