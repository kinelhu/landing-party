#!/usr/bin/env python3
"""Camera jitter of film clips (trailer cut 26, 2026-11-16): each frame's global shift from the last by phase correlation
on 480x270 grey, its residual from a 0.5 s moving average, in px of a 1920 frame (rms, and the share over 2 px).
  uv run --with numpy scripts/jitter.py <clip.mp4>:<start s>:<seconds> ...
A smooth follow reads under 0.5 px rms; the bomb drones' unsmoothed track read 12.7."""
import subprocess, sys, numpy as np
def frames(path, start, dur):
    w, h = 480, 270
    p = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(dur), "-i", path, "-vf", f"scale={w}:{h},format=gray",
                        "-f", "rawvideo", "-"], capture_output=True).stdout
    return np.frombuffer(p, np.uint8).reshape(-1, h, w).astype(np.float32)
def shift(a, b):
    win = np.outer(np.hanning(a.shape[0]), np.hanning(a.shape[1]))
    A, B = np.fft.fft2(a * win), np.fft.fft2(b * win)
    R = A * np.conj(B); R /= np.abs(R) + 1e-9
    r = np.fft.ifft2(R).real; y, x = np.unravel_index(np.argmax(r), r.shape)
    h, w = r.shape
    # sub-pixel by parabola
    def par(m, c, p): d = m - 2 * c + p; return 0 if d == 0 else 0.5 * (m - p) / d
    dy = par(r[(y - 1) % h, x], r[y, x], r[(y + 1) % h, x]); dx = par(r[y, (x - 1) % w], r[y, x], r[y, (x + 1) % w])
    y = y - h if y > h / 2 else y; x = x - w if x > w / 2 else x
    return x + dx, y + dy
for spec in sys.argv[1:]:
    path, start, dur = spec.split(":"); f = frames(path, float(start), float(dur))
    v = np.array([shift(f[i + 1], f[i]) for i in range(len(f) - 1)]) * 4   # in 1920 px
    k = 15; sm = np.array([np.convolve(v[:, j], np.ones(k) / k, mode="same") for j in (0, 1)]).T
    res = np.linalg.norm(v - sm, axis=1)[k:-k]
    print(f"{path.split('/')[-1]:32s} {start:>5}+{dur:<4} speed {np.linalg.norm(sm,axis=1).mean():5.2f} px/f  jitter rms {np.sqrt((res**2).mean()):5.2f} px  >2px {100*(res>2).mean():4.0f}%")
