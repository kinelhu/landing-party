"""Attack loops for the mod page from the showcase film (docs/release/showcase.lua): for each of its moves, the SECONDS
with the most action (the largest frame-to-frame change, summed over a sliding window), as an MP4 of that span at the film's 60 and a
GIF from it (FPS, WIDTH px wide, ffmpeg's two-pass palette).

    uv run --with pillow --with numpy python docs/release/loops.py <film dir> <out dir> [move ...]
"""
import glob, os, subprocess, sys
import numpy as np
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
moves = sys.argv[3:] or sorted({os.path.basename(f).rsplit("-", 1)[0] for f in glob.glob(os.path.join(src, "*-[0-9]*.png"))})
SECONDS, FPS, WIDTH, FILM_FPS = 4, 15, 480, 60
os.makedirs(out, exist_ok=True)
for m in moves:
    files = sorted(glob.glob(os.path.join(src, f"{m}-[0-9]*.png")))
    if len(files) < FILM_FPS * SECONDS:
        print(m, "too short:", len(files)); continue
    # Action: the mean change between frames, read small.
    small = [np.asarray(Image.open(f).convert("L").resize((160, 90))).astype(np.float32) for f in files]
    act = np.array([0] + [np.abs(small[i] - small[i - 1]).mean() for i in range(1, len(small))])
    n = FILM_FPS * SECONDS
    window = np.convolve(act, np.ones(n), "valid")
    start = int(np.argmax(window))
    span = files[start:start + n]
    # The MP4: the span at 60, full size.
    lst = os.path.join(out, f"{m}.txt")
    open(lst, "w").write("".join(f"file '{os.path.abspath(f)}'\nduration {1 / FILM_FPS:.5f}\n" for f in span))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-vf", "scale=1280:-2",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "22", "-r", str(FILM_FPS), os.path.join(out, f"{m}.mp4")],
                   check=True)
    os.remove(lst)
    # The GIF from it, by ffmpeg's two-pass palette (one palette from the loop's own colours, ordered dither, only the
    # changed rectangle redrawn a frame): Pillow's Floyd-Steinberg GIFs ran to 35 MB, the dither defeating compression.
    dst = os.path.join(out, f"{m}.gif")
    # (Cropped to five sixths, its right side kept (the attackers come in from the east: a centre crop cut the Prisms off), the fight fuller in the loop.)
    vf = f"fps={FPS},crop=iw*5/6:ih*5/6:iw/6:ih/12,scale={WIDTH}:-1:flags=lanczos"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(out, f"{m}.mp4"), "-filter_complex",
                    f"[0:v]{vf},split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];"
                    f"[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle", dst], check=True)
    print(f"{m}: frames {start}..{start + n} of {len(files)}, gif {os.path.getsize(dst) // 1024} KB")
