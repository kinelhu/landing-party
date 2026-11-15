"""Alternative scores for the trailer, rendered beside the current one to compare by ear (the user, 2026-11-15: "different
versions of the music, to try and improve the trailer"). Each config in docs/trailer/score-variants/<name>.json is the
baseline docs/trailer/score.json with one musical idea changed ("_idea", "_changed"), rendered by scripts/trailer_score.py
on the same cut, then brought to the baseline's integrated loudness (pyloudnorm; the generator masters to -14 LUFS before
its limiter, and the limiter takes a different amount from each), so the comparison is fair. Writes, per variant and for
the baseline, a WAV, an MP3, and with a video given, that video with the variant's audio in place of its own. The current
score is not touched. Run from the repository's root.

  uv run --with numpy --with scipy --with pyloudnorm scripts/score_variants.py docs/trailer/cut.json \
      docs/trailer/score-variants media/trailer/score-variants [picture.mp4] [name ...]

Prints one line a variant: its loudness as rendered, after the match, and its peak; then writes <out>/variants.json
(name, idea, changes, loudness) for the listening page.
"""
import json
import os
import subprocess
import sys
import wave

import numpy as np
import pyloudnorm

HERE = os.path.dirname(os.path.abspath(__file__))
SCORE = os.path.join(HERE, "trailer_score.py")


def read_wav(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").reshape(-1, 2).astype(np.float64) / 32767
    return sr, x


def write_wav(path, sr, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def render(cut, cfg, out):
    r = subprocess.run([sys.executable, SCORE, cut, out] + ([cfg] if cfg else []), capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"score_variants: {cfg or 'baseline'} failed:\n{r.stderr}")
    return r.stdout.strip().splitlines()[-1]


def soft_clip(y, ceil, knee=0.5):
    """y untouched under the knee, bent to the ceiling above it (the generator's tanh over the whole signal, applied
    twice, took 3 dB off everything: seen on the first run, every variant at -4.8 dBFS and 0.4 LU under the target)."""
    a = np.abs(y)
    over = a > knee
    bent = knee + (ceil - knee) * np.tanh((a[over] - knee) / (ceil - knee))
    out = y.copy()
    out[over] = np.sign(y[over]) * bent
    return out


def match(x, sr, target):
    """x at the target's integrated loudness, peaks held under -1 dBFS."""
    meter = pyloudnorm.Meter(sr)
    before = meter.integrated_loudness(x)
    ceil = 10 ** (-1 / 20)
    y = x * 10 ** ((target - before) / 20)
    if np.abs(y).max() > ceil:
        y = soft_clip(y, ceil)
        after = meter.integrated_loudness(y)
        if abs(after - target) > 0.1:   # the clip took some back: once more
            y = soft_clip(y * 10 ** ((target - after) / 20), ceil)
    after = meter.integrated_loudness(y)
    return y, before, after


def main():
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    cut, var_dir, out = sys.argv[1:4]
    rest = sys.argv[4:]
    video = rest[0] if rest and rest[0].endswith(".mp4") else None
    names = rest[1:] if video else rest
    os.makedirs(out, exist_ok=True)
    base_cfg = json.load(open(cut))["score"]
    configs = [("baseline", base_cfg)] + sorted(
        (f[:-5], os.path.join(var_dir, f)) for f in os.listdir(var_dir) if f.endswith(".json"))
    if names:
        configs = [c for c in configs if c[0] in names or c[0] == "baseline"]
    rows = []
    target = None
    for name, cfg in configs:
        wav = os.path.join(out, f"{name}.wav")
        line = render(cut, cfg if name != "baseline" else None, wav)
        sr, x = read_wav(wav)
        if target is None:
            target = pyloudnorm.Meter(sr).integrated_loudness(x)
            before = after = target
        else:
            x, before, after = match(x, sr, target)
            write_wav(wav, sr, x)
        peak = 20 * np.log10(np.abs(x).max())
        c = json.load(open(cfg))
        rows.append({"name": name, "idea": c.get("_idea", "The score as it is now."), "changed": c.get("_changed", ""),
                     "lufs_rendered": round(before, 2), "lufs": round(after, 2), "peak_dbfs": round(peak, 2),
                     "seconds": round(len(x) / sr, 1), "generator": line.split("(", 1)[-1].rstrip(")")})
        mp3 = os.path.join(out, f"{name}.mp3")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libmp3lame", "-b:a", "128k", mp3],
                       check=True)
        if video:
            mp4 = os.path.join(out, f"{name}.mp4")
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", video, "-i", wav, "-map", "0:v:0", "-map", "1:a:0",
                            "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", mp4],
                           check=True)
        print(f"{name:9s} rendered {before:6.2f} LUFS, matched {after:6.2f} LUFS, peak {peak:5.2f} dBFS  {line.split('(')[-1]}")
    json.dump(rows, open(os.path.join(out, "variants.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
