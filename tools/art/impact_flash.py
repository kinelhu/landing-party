"""The orbital strike's impact flash (the user, 2026-11-04: under the platform's shadow its explosions read "shaded";
"They should give light instead?"): a soft radial glow, white at its heart going to warm amber, drawn additively over
each impact so it lights in daylight too (a game light shows only in the dark).

    uv run --with pillow python tools/art/impact_flash.py landing-party/graphics/serenity/impact-flash.png
"""
import math, sys
from PIL import Image

N = 256
im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
px = im.load()
for y in range(N):
    for x in range(N):
        r = math.hypot(x - N / 2 + 0.5, y - N / 2 + 0.5) / (N / 2)
        if r >= 1:
            continue
        a = (1 - r) ** 2.2
        warm = min(1.0, r * 1.6)
        px[x, y] = (255, int(255 - 70 * warm), int(235 - 170 * warm), int(255 * a))
im.save(sys.argv[1], optimize=True)
print("written", sys.argv[1])
