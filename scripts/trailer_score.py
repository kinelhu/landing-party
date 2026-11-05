"""The trailer's score (the user, 2026-11-05: "Go ahead. Game sounds allowed. Surprise me"), in place of the placeholder
(scripts/trailer_music.py): written to the cut it plays under, read from docs/trailer/cut.json and the clips it names.

  uv run --with numpy --with scipy --with pyloudnorm scripts/trailer_score.py docs/trailer/cut.json media/trailer/score.wav

Its sections follow the acts the cut's shots belong to (ACTS): the arrival sparse and cold; the army on war drums; Synthexis
breathing, wet and low; Kessler-Hayashi ticking like a machine; the finale's drop where its burster attack begins; the bar
before the nuke cut to silence, the nuke itself, and the end card's ring-out. A four-note motif states the title quietly
and returns at the drop. Over it, the game's own sounds on what the picture shows, found frame by frame in the clips:
a lance on each strike's flash, a wet blast on each burster's green flash, the nuke on the nuke's white-out, lightning on
the Tesla's. Mixed in stereo with a reverb, the music ducked under the kick and the hits, and mastered to -14 LUFS (the
loudness YouTube plays at), peaks under -1 dBFS. Deterministic: its randomness seeded, the same cut gives the same score.
"""
import json
import os
import subprocess
import sys

import numpy as np
import pyloudnorm
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
BEAT = 0.5                      # 120 BPM: the cut is laid out in bars of 2 s
BAR = 4 * BEAT
A4 = 440.0
GAME = os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data")

# Each clip's act (by its name's start); the score's sections follow them.
ACTS = [("shot-01", "arrival"), ("landing-fx", "arrival"), ("reel-base", "arrival"),
        ("stage-m", "army"), ("stage-c", "army"),
        ("shot-06", "synth"), ("reel-creep", "synth"), ("reel-growth", "synth"), ("stage-herd", "synth"),
        ("reel-nwwall", "synth"),
        ("reel-khwall", "kh"), ("reel-teslawall", "kh"), ("reel-dome", "kh"), ("reel-culture", "kh"),
        ("act-megaburst", "finale"), ("stage-k2-strike", "finale"), ("reel-warfinale", "finale"),
        ("reel-nuke", "nuke"), ("black", "end")]
# What each clip's flashes are (its hits); clips not named have none.
HITS = {"reel-nuke": "nuke", "reel-culture": "lance", "reel-khwall": "lance", "stage-k2-strike": "lance",
        "reel-dome": "shield", "act-megaburst": "burst", "reel-nwwall": "burst", "reel-teslawall": "zap",
        "landing-fx": "crash"}

# Chords by act, semitones from A4 (root, third, fifth), one a bar.
CHORDS = {
    "arrival": [(0, 3, 7), (-4, 0, 3), (0, 3, 7), (-2, 2, 5)],          # Am F Am G
    "army": [(0, 3, 7), (-4, 0, 3), (3, 7, 10), (-2, 2, 5)],            # Am F C G
    "synth": [(0, 3, 7), (1, 5, 8), (0, 3, 7), (-1, 3, 6)],             # Am Bb Am G#dim: Phrygian, uneasy
    "kh": [(0, 3, 7), (-4, 0, 3), (-7, -3, 0), (-5, -1, 2)],            # Am F D E: harder, a dominant pull
    "finale": [(0, 3, 7), (-4, 0, 3), (3, 7, 10), (-2, 2, 5)],
    "nuke": [(0, 3, 7)], "end": [(0, 3, 7)],
}
MOTIF = [(0, 1.0), (3, 0.5), (7, 0.5), (5, 2.0)]   # A C E D: the title's four notes (semitone, beats)


def hz(semi):
    return A4 * 2 ** (semi / 12)


def lp(x, f, order=2):
    return sosfilt(butter(order, f, "low", fs=SR, output="sos"), x, axis=0)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x, axis=0)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x, axis=0)


def saw(f, t):
    return 2 * ((f * t) % 1.0) - 1


def adsr(n, a, r):
    e = np.ones(n)
    a, r = min(int(a * SR), n), min(int(r * SR), n)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def pan(x, p):
    """Mono to stereo, p from -1 (left) to 1 (right), equal power."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def add(bus, x, at):
    k = int(at * SR)
    if k >= len(bus):
        return
    m = min(len(x), len(bus) - k)
    bus[k:k + m] += x[:m]


def game_sound(rel, rate=1.0):
    """A sound of the game's, decoded to stereo float at SR (rate < 1: slower and lower)."""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(GAME, rel), "-f", "f32le", "-ac", "2",
                          "-ar", str(int(SR / rate)), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)


# ---- reading the cut ----------------------------------------------------------------------------------------------------

def act_of(name):
    for prefix, act in ACTS:
        if name.startswith(prefix):
            return act
    return "kh"


def frames(s, dur):
    """The shot as the cut plays it, 160 by 90 at 30 a second (trailer_cut.py's trim and speed)."""
    sp = s.get("speed", 1.0)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-ss", str(s["from"]), "-i", s["clip"], "-t", str(dur * sp),
                          "-vf", f"setpts=PTS/{sp},fps=30,scale=160:90", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, 90, 160, 3).astype(np.float64)


def peaks(v, rise, spacing, skip=4):
    """Frames where v rises at least `rise` over its least in the 8 before, a local high, `spacing` frames apart."""
    out = []
    for i in range(skip, len(v)):
        lo = v[max(0, i - 8):i].min()
        if v[i] - lo >= rise and v[i] >= v[max(0, i - 3):i + 4].max() and (not out or i - out[-1] >= spacing):
            out.append(i)
    return out


def hits_of(s, dur, kind):
    f = frames(s, dur)
    if kind == "nuke":
        L = f.mean(axis=(1, 2, 3))
        i = int(np.argmax(np.diff(L))) + 1
        return [i / 30] if L[i] - L[i - 1] > 40 else []
    if kind == "burst":
        g = f[..., 1] - (f[..., 0] + f[..., 2]) / 2
        v = ((g > 60) & (f[..., 1] > 150)).mean(axis=(1, 2)) * 1000
        return [i / 30 for i in peaks(v, 2.0, 8)][:8]
    hot = (f.max(axis=3) > 230).mean(axis=(1, 2)) * 1000
    rise = {"lance": 1.5, "shield": 3.0, "zap": 2.0, "crash": 20.0}[kind]
    return [i / 30 for i in peaks(hot, rise, 10)][:{"crash": 1}.get(kind, 10)]


def read_cut(path):
    c = json.load(open(path))
    shots, t = [], 0.0
    for s in c["shots"]:
        dur = s["bars"] * BAR
        name = s["clip"].split("/")[-1][:-4]
        kind = HITS.get(name)
        hits = [(t + h, kind) for h in hits_of(s, dur, kind)] if kind else []
        shots.append({"name": name, "act": act_of(name), "start": t, "end": t + dur, "hits": hits})
        t += dur
    return c, shots, t


# ---- the music ------------------------------------------------------------------------------------------------------------

def music(shots, total, rng):
    n = int(total * SR) + SR
    pads, keys, drums, bass = (np.zeros((n, 2)) for _ in range(4))
    kick_at = []
    bars = int(round(total / BAR))
    act_at = []
    for b in range(bars):
        t = b * BAR + 0.01
        act_at.append(next(s["act"] for s in shots if s["start"] <= t < s["end"]))
    drop = next(b for b, a in enumerate(act_at) if a == "finale")
    nuke = next(b for b, a in enumerate(act_at) if a == "nuke")
    for b, act in enumerate(act_at):
        chord = CHORDS[act][b % len(CHORDS[act])]
        t0 = b * BAR
        tt = np.arange(int(BAR * SR)) / SR
        # Pad: three detuned saws a note, spread across the field, a slow filter breathing; cold and thin to begin with.
        if act not in ("nuke",):
            bright = {"arrival": 700, "army": 1100, "synth": 600, "kh": 1400, "finale": 3200, "end": 900}[act]
            sweep = bright * (1 + 0.35 * np.sin(2 * np.pi * (b * BAR + tt) / 8))
            for k, s in enumerate(chord):
                v = sum(saw(hz(s - 12) * d, tt) for d in (0.994, 1.0, 1.006))
                v = lp(v, float(sweep.mean())) * adsr(len(tt), 0.25, 0.25)
                add(pads, pan(v, (-0.6, 0.0, 0.6)[k]) * 0.045, t0)
        # Army: war drums, a low tom on each beat and a roll into each fourth bar.
        if act == "army":
            for j in range(4 if b % 4 != 3 else 8):
                at = t0 + j * (BEAT if b % 4 != 3 else BEAT / 2)
                m = int(0.6 * SR)
                x = np.arange(m) / SR
                tom = np.sin(2 * np.pi * (70 + 40 * np.exp(-x * 20)) * x) * np.exp(-x * 7)
                tom += 0.3 * lp(rng.uniform(-1, 1, m), 900) * np.exp(-x * 25)
                add(drums, pan(tom, 0.0) * (0.5 if j == 0 else 0.35), at)
        # Synthexis: breaths, filtered noise swelling and falling a bar, and a low wet gurgle under it.
        if act == "synth":
            m = int(BAR * SR)
            x = np.arange(m) / SR
            breath = bp(rng.uniform(-1, 1, m), 300, 1400) * np.sin(np.pi * x / BAR) ** 2
            add(pads, pan(breath, -0.4 if b % 2 else 0.4) * 0.08, t0)
            gurgle = np.sin(2 * np.pi * (hz(chord[0] - 36) * (1 + 0.04 * np.sin(2 * np.pi * 6 * x))) * x)
            add(bass, pan(gurgle * adsr(m, 0.3, 0.6), 0.0) * 0.12, t0)
        # Kessler-Hayashi: a machine's tick on the sixteenths, accented, and a pulse on the eighths.
        if act in ("kh", "finale"):
            for j in range(16):
                m = int(0.05 * SR)
                x = np.arange(m) / SR
                tick = hp(rng.uniform(-1, 1, m), 6000) * np.exp(-x * 90)
                add(drums, pan(tick, 0.5 if j % 2 else -0.5) * (0.12 if j % 4 == 0 else 0.06), t0 + j * BEAT / 4)
        # Arpeggio: sixteenths up the chord from the army on, an octave up after the drop, bouncing left and right.
        if act in ("army", "kh", "finale") or (act == "synth" and b % 2 == 0):
            notes = [chord[0], chord[1], chord[2], chord[0] + 12]
            for j in range(16):
                m = int(BEAT / 4 * SR)
                x = np.arange(m) / SR
                f = hz(notes[j % 4] + (12 if act == "finale" else 0))
                v = np.sign(np.sin(2 * np.pi * f * x)) * np.exp(-x * 16)
                add(keys, pan(lp(v, 3000), -0.5 if j % 2 else 0.5) * (0.03 if act == "finale" else 0.02), t0 + j * BEAT / 4)
        # The drop on: four on the floor, a snare on two and four, a bass that pumps.
        if act == "finale":
            for j in range(4):
                kick_at.append(t0 + j * BEAT)
                m = int(0.45 * SR)
                x = np.arange(m) / SR
                kick = np.sin(2 * np.pi * (45 + 110 * np.exp(-x * 35)) * x) * np.exp(-x * 7)
                add(drums, pan(kick, 0.0) * 0.85, t0 + j * BEAT)
                if j in (1, 3):
                    sn = bp(rng.uniform(-1, 1, int(0.25 * SR)), 1200, 7000) * np.exp(-np.arange(int(0.25 * SR)) / SR * 18)
                    add(drums, pan(sn, 0.1) * 0.25, t0 + j * BEAT)
            m = int(BAR * SR)
            x = np.arange(m) / SR
            bl = lp(saw(hz(chord[0] - 24), x) + 0.5 * saw(hz(chord[0] - 24) * 1.01, x), 260) * adsr(m, 0.005, 0.1)
            add(bass, pan(bl, 0.0) * 0.32, t0)
    # The motif: a bell under the title (bar 4) and at the end card, a lead at the drop.
    def phrase(at, lead):
        k = at
        for semi, beats in MOTIF:
            m = int((beats * BEAT + (1.5 if not lead else 0.2)) * SR)
            x = np.arange(m) / SR
            f = hz(semi + 12)
            if lead:
                v = lp(sum(saw(f * d, x) for d in (0.995, 1.005)), 3500) * adsr(m, 0.02, 0.3) * 0.08
            else:   # a bell: FM, a metallic partial dying faster
                v = np.sin(2 * np.pi * f * x + 2.5 * np.exp(-x * 4) * np.sin(2 * np.pi * f * 3.5 * x)) * np.exp(-x * 1.8) * 0.12
            add(keys, pan(v, 0.15), k)
            k += beats * BEAT
    phrase(3 * BAR, False)
    phrase(drop * BAR, True)
    phrase((drop + 4) * BAR, True)
    phrase((bars - 3) * BAR + 0.5, False)
    return pads, keys, drums, bass, kick_at, drop, nuke


def reverb(x, seconds, rng):
    """A room: stereo noise decaying over `seconds`, its highs falling off."""
    m = int(seconds * SR)
    t = np.arange(m) / SR
    ir = np.stack([rng.standard_normal(m), rng.standard_normal(m)], axis=1) * np.exp(-t * 6.9 / seconds)[:, None]
    ir = lp(ir, 5000)
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    return np.stack([fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in (0, 1)], axis=1)


def duck(n, times, depth, release):
    """A gain that dips at each time and comes back over `release` s (the kick's and the hits' room)."""
    g = np.ones(n)
    m = int(release * SR)
    shape = 1 - depth * np.exp(-np.arange(m) / SR * 5 / release)
    for at in times:
        k = int(at * SR)
        if k < n:
            g[k:k + m] = np.minimum(g[k:k + m], shape[:n - k])
    return g


# ---- the sounds on the picture ---------------------------------------------------------------------------------------------

def sfx(shots, n, rng, nuke_bar):
    bus = np.zeros((n, 2))
    snd = {
        "lance": [game_sound(f"base/sound/fight/large-explosion-{k}.ogg") for k in (1, 2)],
        "lance_top": [game_sound(f"space-age/sound/explosions/lightning-effect-{k}.ogg") for k in (1, 2, 3)],
        "burst": [game_sound(f"space-age/sound/explosions/fissure-explosion-{k}.ogg", 0.8) for k in (1, 2, 3, 4)],
        "burst_wet": [game_sound(f"base/sound/creatures/biter-death-big-{k}.ogg", 0.7) for k in (1, 2, 3)],
        "shield": [game_sound("base/sound/fight/electric-beam.ogg", 1.3)],
        "zap": [game_sound(f"space-age/sound/explosions/lightning-effect-{k}.ogg") for k in (4, 5)],
        "crash": [game_sound("base/sound/explosions/large-metal-explosion-3.ogg", 0.85)],
        "nuke": [game_sound("base/sound/fight/nuclear-explosion-1.ogg")],
        "aftershock": [game_sound("base/sound/fight/nuclear-explosion-aftershock.ogg")],
        "roar": [game_sound(f"base/sound/creatures/biter-roar-behemoth-{k}.ogg", 0.85) for k in (1, 4, 7)],
        "demolisher": [game_sound("space-age/sound/enemies/demolisher/demolisher-hurt-roar-big-1.ogg", 0.9)],
        "rocket": [game_sound("base/sound/silo-rocket.ogg")],
    }
    level = {"lance": 0.32, "lance_top": 0.14, "burst": 0.45, "burst_wet": 0.3, "shield": 0.25, "zap": 0.35,
             "crash": 0.6, "nuke": 1.0, "aftershock": 0.7}
    hit_times = []
    for s in shots:
        for k, (at, kind) in enumerate(s["hits"]):
            p = float(rng.uniform(-0.5, 0.5))
            layers = {"lance": ["lance", "lance_top"], "burst": ["burst", "burst_wet"]}.get(kind, [kind])
            for layer in layers:
                x = snd[layer][k % len(snd[layer])]
                if kind == "nuke":
                    add(bus, x * level["nuke"], at)
                    add(bus, snd["aftershock"][0] * level["aftershock"], at + 1.2)
                    # A sub-bass fall under it: the body a speaker's own sound lacks.
                    m = int(4 * SR)
                    t = np.arange(m) / SR
                    sub = np.sin(2 * np.pi * np.cumsum(55 * np.exp(-t * 0.5) + 22) / SR) * np.exp(-t * 0.9)
                    add(bus, pan(sub, 0.0) * 0.7, at)
                else:
                    add(bus, x * level[layer] * np.array([np.cos((p + 1) * np.pi / 4), np.sin((p + 1) * np.pi / 4)]) * 1.4, at)
            hit_times.append(at)
    # Synthexis's voice: a behemoth's roar as its herd breaks in, a demolisher's as the burster attack starts.
    herd =[s for s in shots if s["name"] == "stage-herd"]
    if herd:
        add(bus, snd["roar"][0] * 0.35, herd[0]["start"] + 0.3)
        add(bus, snd["roar"][1] * 0.3, herd[-1]["start"] + 0.2)
    mb = [s for s in shots if s["name"] == "act-megaburst"]
    if mb:
        add(bus, snd["demolisher"][0] * 0.4, mb[0]["start"])
    # The riser into the drop: the rocket's launch, reversed, swelling into the bar line.
    return bus, hit_times, snd


def render(cut_path, out):
    rng = np.random.default_rng(20261105)
    c, shots, total = read_cut(cut_path)
    n = int(total * SR) + SR
    pads, keys, drums, bass, kicks, drop, nuke_bar = music(shots, total, rng)
    fx, hit_times, snd = sfx(shots, n, rng, nuke_bar)
    # The riser: the rocket silo's launch reversed, its end on the drop's downbeat; a noise sweep with it.
    rk = snd["rocket"][0]
    rk = rk[:int(5 * SR)][::-1]
    add(fx, rk * np.linspace(0, 1, len(rk))[:, None] ** 2 * 0.5, drop * BAR - len(rk) / SR)
    m = int(2 * BAR * SR)
    sweep = rng.uniform(-1, 1, m)
    sweep = np.concatenate([lp(sweep[i:i + 4410], 200 + 9000 * (i / m) ** 2) for i in range(0, m, 4410)])
    add(fx, pan(sweep * np.linspace(0, 1, len(sweep)) ** 2, 0.0) * 0.1, drop * BAR - 2 * BAR)
    # The mix: the music in a room, ducked under the kick and the hits.
    wet = reverb(pads + keys * 0.8, 2.8, rng)
    mus = pads + keys + 0.35 * wet + drums + bass
    g = duck(n, kicks, 0.45, 0.25) * duck(n, hit_times, 0.35, 0.6)
    mus *= g[:, None]
    # The nuke: the music cut to nothing for the half bar before its flash, back only for the end card's ring-out.
    nk = [h for s in shots for h in s["hits"] if h[1] == "nuke"]
    if nk:
        at = nk[0][0]
        a, b = int((at - BAR / 4) * SR), int((at - 0.02) * SR)
        fade = np.ones(n)
        fade[a - int(0.15 * SR):a] = np.linspace(1, 0, int(0.15 * SR))
        end_start = next(s["start"] for s in shots if s["act"] == "end")
        fade[a:int(end_start * SR)] = 0
        fade[b:int(end_start * SR)] = 0
        k = int(end_start * SR)
        r = int(1.0 * SR)
        fade[k:k + r] = np.linspace(0, 1, r)
        mus *= fade[:, None]
    mix = mus + fx + 0.15 * reverb(fx, 1.5, rng)
    # Fades: in over half a second, out over the last two.
    mix[:int(0.5 * SR)] *= np.linspace(0, 1, int(0.5 * SR))[:, None]
    tail = int(2 * SR)
    end = int(total * SR)
    mix[end - tail:end] *= np.linspace(1, 0, tail)[:, None]
    mix = mix[:end]
    # Master: -14 LUFS, then a soft limit under -1 dBFS.
    meter = pyloudnorm.Meter(SR)
    mix = pyloudnorm.normalize.loudness(mix, meter.integrated_loudness(mix), -14.0)
    ceil = 10 ** (-1 / 20)
    mix = np.tanh(mix / ceil) * ceil
    pcm = (np.clip(mix, -1, 1) * 32767).astype("<i2")
    import wave
    with wave.open(out, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    found = {}
    for s in shots:
        for _, kind in s["hits"]:
            found[kind] = found.get(kind, 0) + 1
    print(f"score: {out} ({total:.0f} s, drop at bar {drop + 1}, nuke at bar {nuke_bar + 1}; hits {found}; "
          f"{meter.integrated_loudness(mix):.1f} LUFS)")


if __name__ == "__main__":
    render(sys.argv[1], sys.argv[2])
