#!/usr/bin/env python3
"""The shield's look (the user, 2026-10-21: "the shield bubble is really bad ... let's try our own"): original art, drawn
here, no other mod's. Two sprite sheets, both drawn additively in game (black is nothing, light adds):

  shield-dome.png   FRAMES frames, at rest: understated (the user: "otherwise I fear bases will look ridiculous"): a thin
                    rim, the hexagons barely there and only toward it, a faint slow shimmer; no sweep.
  shield-flash.png  FLASH_FRAMES frames, the whole dome answering a hit: its hexagons lit at once, fading.
  shield-hit.png    HIT_FRAMES frames: where a shot struck, a ring of bright hexagons running outward and fading.

    uv run --with pillow --with numpy scripts/make_shield.py [OUT_DIR]
"""
import math, os, sys
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                                         "landing-party", "graphics", "shield")
SIZE = 320              # a frame, px (drawn at scale 0.8 in game: 256 px, 8 tiles across)
FRAMES, COLS = 16, 4
HIT_SIZE, HIT_FRAMES = 256, 12
FLASH_FRAMES = 8
HEX = 15.0              # a hexagon's radius, px
COLOR = np.array([0.45, 0.78, 1.0])   # Serenity's cold blue


def hex_field(n, hex_r):
    """Per pixel: distance to the nearest hexagon edge (0 on an edge), and the hexagon's centre (for its shimmer)."""
    y, x = np.mgrid[0:n, 0:n].astype(float)
    x -= n / 2; y -= n / 2
    # Axial hex coordinates (pointy-top), rounded to the nearest cell.
    q = (math.sqrt(3) / 3 * x - 1 / 3 * y) / hex_r
    r = (2 / 3 * y) / hex_r
    s = -q - r
    rq, rr, rs = np.round(q), np.round(r), np.round(s)
    dq, dr, ds = abs(rq - q), abs(rr - r), abs(rs - s)
    fix_q = (dq > dr) & (dq > ds)
    fix_r = ~fix_q & (dr > ds)
    rq = np.where(fix_q, -rr - rs, rq)
    rr = np.where(fix_r, -rq - rs, rr)
    cx = hex_r * math.sqrt(3) * (rq + rr / 2)
    cy = hex_r * 1.5 * rr
    px, py = x - cx, y - cy
    # Distance to the hexagon's edge: its inradius less the largest of three projections.
    inr = hex_r * math.sqrt(3) / 2
    a = np.abs(px)
    b = np.abs(px * 0.5 + py * math.sqrt(3) / 2)
    c = np.abs(px * 0.5 - py * math.sqrt(3) / 2)
    edge = inr - np.maximum(a, np.maximum(b, c))
    return x, y, edge, cx, cy


def to_rgba(intensity):
    """Additive art: colour times intensity, on black, opaque (the engine adds it)."""
    rgb = np.clip(intensity[..., None] * COLOR[None, None, :], 0, 1)
    out = np.zeros(intensity.shape + (4,), dtype=np.uint8)
    out[..., :3] = (rgb * 255).astype(np.uint8)
    out[..., 3] = 255
    return out


def dome_frame(k, flash=None):
    x, y, edge, cx, cy = hex_field(SIZE, HEX)
    R = SIZE / 2 - 4
    d = np.sqrt(x * x + y * y) / R
    inside = d < 1
    lines = np.clip(1 - edge / 1.4, 0, 1)
    if flash is None:
        # At rest: the hexagons only toward the rim and faint, a thin rim, a slow shimmer.
        t = k / FRAMES
        phase = np.sin(cx * 0.37 + cy * 0.61) * 10
        shimmer = 0.7 + 0.3 * np.sin(2 * math.pi * t + phase)
        near_rim = np.where(inside, d ** 8, 0)
        rim = np.where(inside, np.exp(-((1 - d) / 0.02) ** 2), np.exp(-((d - 1) / 0.012) ** 2)) * 0.45
        v = lines * near_rim * shimmer * 0.28 + rim
    else:
        # Struck: every hexagon lit at once, brightest at the rim, fading over the frames.
        f = (1 - flash) ** 1.6
        rimw = np.where(inside, 0.35 + 0.65 * d ** 3, 0)
        rim = np.where(inside, np.exp(-((1 - d) / 0.03) ** 2), np.exp(-((d - 1) / 0.02) ** 2))
        v = (lines * rimw * 1.1 + np.where(inside, 0.06, 0) + rim) * f
    return to_rgba(v)


def hit_frame(k):
    x, y, edge, cx, cy = hex_field(HIT_SIZE, HEX)
    d = np.sqrt(cx * cx + cy * cy) / (HIT_SIZE / 2)            # by cell, so whole hexagons light
    t = (k + 1) / HIT_FRAMES
    ring = np.exp(-((d - t * 0.95) / 0.12) ** 2) * (1 - t) ** 1.2
    lines = np.clip(1 - edge / 1.6, 0, 1)
    fill = 0.35
    v = ring * (lines * 2.4 + fill * 1.8)
    v *= np.sqrt(x * x + y * y) < HIT_SIZE / 2 - 2
    return to_rgba(v)


def sheet(frames, n, cols):
    rows = math.ceil(len(frames) / cols)
    img = Image.new("RGBA", (n * cols, n * rows), (0, 0, 0, 255))
    for i, f in enumerate(frames):
        img.paste(Image.fromarray(f, "RGBA"), ((i % cols) * n, (i // cols) * n))
    return img


os.makedirs(OUT, exist_ok=True)
sheet([dome_frame(k) for k in range(FRAMES)], SIZE, COLS).save(os.path.join(OUT, "shield-dome.png"), optimize=True)
sheet([dome_frame(k, k / FLASH_FRAMES) for k in range(FLASH_FRAMES)], SIZE, COLS).save(os.path.join(OUT, "shield-flash.png"),
                                                                                       optimize=True)
sheet([hit_frame(k) for k in range(HIT_FRAMES)], HIT_SIZE, COLS).save(os.path.join(OUT, "shield-hit.png"), optimize=True)
print(OUT, f"dome {FRAMES} frames of {SIZE}, hit {HIT_FRAMES} of {HIT_SIZE}")
