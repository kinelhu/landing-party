"""A Blender render to Factorio's frame: stretched by sqrt(2) vertically (the 45-degree camera's foreshortened ground
back to square tiles), shadow under body, optionally scaled to a pixel density.

    uv run --with pillow python tools/blender/factorio_frame.py <dir with body.png, shadow.png> <out.png> [px_per_tile=64]
"""
import math, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
px = int(sys.argv[3]) if len(sys.argv) > 3 else 64
body = Image.open(src + "/body.png").convert("RGBA")
shadow = Image.open(src + "/shadow.png").convert("RGBA")
w, h = body.size
size = (w * px // 64, int(h * math.sqrt(2)) * px // 64)
body, shadow = body.resize(size, Image.LANCZOS), shadow.resize(size, Image.LANCZOS)
# (A shadow layer at Factorio's strength: the catcher gives full black where the light is blocked, vanilla's shadows are
# about half.)
shadow.putalpha(shadow.split()[3].point(lambda v: int(v * 0.55)))
frame = Image.new("RGBA", size, (0, 0, 0, 0))
frame.alpha_composite(shadow)
frame.alpha_composite(body)
frame.save(out)
print("wrote", out, size)
