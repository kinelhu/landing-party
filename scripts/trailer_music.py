"""A placeholder score for the trailer's rough cut (docs/trailer/storyboard.md section 4): synthesised, not sampled, so it
carries no rights question; a stand-in until a real track is chosen. 120 BPM in 4/4 (a bar is 2 s), A minor.

  uv run --with numpy scripts/trailer_music.py <bars> <drop bar> <out.wav>

Sections, by bar (1-based): a pad alone; an arpeggio from bar 4 (the factory, the arrival); a pulse from a third of the
way in; the drop at <drop bar> (the strike's first lance): bass, kick on every beat, the arpeggio an octave up; the
last 3 bars one chord left to ring out. Deterministic: no randomness anywhere.
"""
import sys
import wave

import numpy as np

SR = 44100
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
A4 = 440.0

# Am - F - C - G, as semitones from A4 (root, third, fifth), one chord a bar.
CHORDS = [(0, 3, 7), (-4, 0, 3), (3, 7, 10), (-2, 2, 5)]


def hz(semi):
    return A4 * 2 ** (semi / 12)


def osc(f, t, kind="saw"):
    ph = (f * t) % 1.0
    if kind == "saw":
        return 2 * ph - 1
    if kind == "square":
        return np.where(ph < 0.5, 1.0, -1.0)
    return np.sin(2 * np.pi * ph)


def lowpass(x, cutoff):
    """A one-pole low pass; cutoff in Hz, a number or an array as long as x."""
    a = 1 - np.exp(-2 * np.pi * np.broadcast_to(cutoff, x.shape) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def env(n, attack, release):
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def render(bars, drop):
    n = int(bars * BAR * SR)
    out = np.zeros(n)
    pulse_from = max(5, bars // 3)
    ring_from = bars - 3
    for b in range(bars):
        chord = CHORDS[b % 4] if b < ring_from else CHORDS[0]
        s0 = int(b * BAR * SR)
        # The pad: a detuned saw pair per note, slow attack; held over the last bars.
        if b <= ring_from:
            length = BAR if b < ring_from else 3 * BAR
            m = int(length * SR)
            t = np.arange(m) / SR
            pad = sum(osc(hz(s - 12) * d, t) for s in chord for d in (0.997, 1.003))
            cut = 900 if b < drop - 1 else 1800
            pad = lowpass(pad, cut) * env(m, 0.4 if b < ring_from else 0.1, 0.3 if b < ring_from else 2.5 * BAR)
            out[s0:s0 + m] += 0.05 * pad[: n - s0]
        if b >= ring_from:
            continue
        # The arpeggio: sixteenths up the chord, from bar 4; an octave up after the drop.
        if b >= 3:
            step = BEAT / 4
            notes = [chord[0], chord[1], chord[2], chord[0] + 12]
            for i in range(16):
                f = hz(notes[i % 4] + (12 if b >= drop - 1 else 0))
                m = int(step * SR)
                t = np.arange(m) / SR
                v = osc(f, t, "square") * np.exp(-t * 18)
                k = s0 + int(i * step * SR)
                out[k:k + m] += (0.035 if b >= drop - 1 else 0.025) * v[: n - k]
        # The pulse: a soft kick on beats 1 and 3, every beat after the drop; a bass note under it after the drop.
        if b >= pulse_from - 1:
            beats = range(4) if b >= drop - 1 else (0, 2)
            for j in beats:
                m = int(0.35 * SR)
                t = np.arange(m) / SR
                kick = np.sin(2 * np.pi * (50 + 90 * np.exp(-t * 30)) * t) * np.exp(-t * 9)
                k = s0 + int(j * BEAT * SR)
                out[k:k + m] += 0.35 * kick[: n - k]
        if b >= drop - 1:
            m = int(BAR * SR)
            t = np.arange(m) / SR
            bass = lowpass(osc(hz(chord[0] - 24), t), 300) * env(m, 0.01, 0.2)
            out[s0:s0 + m] += 0.18 * bass[: n - s0]
        # A riser into the drop: noise swept open over the bar before it (seeded, so the same every build).
        if b == drop - 2:
            m = int(BAR * SR)
            noise = np.random.default_rng(12345).uniform(-1, 1, m)
            out[s0:s0 + m] += 0.05 * lowpass(noise, np.linspace(200, 6000, m)) * np.linspace(0, 1, m)
    out /= max(1e-9, np.abs(out).max()) / 0.8
    return out


def main():
    bars, drop, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    x = render(bars, drop)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    stereo = np.repeat(pcm[:, None], 2, axis=1)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo.tobytes())
    print(f"music: {path} ({bars} bars, {bars * BAR:.0f} s, drop at bar {drop})")


if __name__ == "__main__":
    main()
