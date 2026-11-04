"""The trailer's cut (docs/trailer/storyboard.md sections 4 and 5): shots trimmed to the bar, joined, titles laid over,
the music under them. An edit list, not a timeline: re-cut by editing it and running this again.

  uv run --with pillow scripts/trailer_cut.py docs/trailer/cut.json media/trailer/rough-cut.mp4

cut.json: {"bpm": 120, "music": "media/trailer/placeholder.wav",
  "shots": [{"clip": "media/trailer/shot-01.mp4", "bars": 3, "from": 0.0, "speed": 1.0}, ...],
  "titles": [{"text": "Landing Party", "sub": "...", "bar": 6, "bars": 1}]}
A shot plays from `from` seconds of its clip, at `speed` (0.5: half speed), for exactly its bars; a clip too short for
that is an error, not a freeze. A title's `bar` is 1-based on the cut's own count, and it holds to the end of its bars.
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1920, 1080, 30
FONTS = os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data/core/fonts")


def run(args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + args, check=True)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True, check=True).stdout
    return float(out)


def title_png(path, text, sub):
    """A title card over the picture: Factorio's own face (Titillium Web), a soft shade behind it to keep it legible."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    big = ImageFont.truetype(os.path.join(FONTS, "TitilliumWeb-Bold.ttf"), 132)
    small = ImageFont.truetype(os.path.join(FONTS, "TitilliumWeb-SemiBold.ttf"), 44)
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shade).rectangle((0, H // 2 - 150, W, H // 2 + 150), fill=(0, 0, 0, 120))
    im.alpha_composite(shade)
    bw = d.textlength(text, font=big)
    d.text(((W - bw) / 2, H / 2 - 110), text, font=big, fill=(255, 230, 192, 255))
    if sub:
        sw = d.textlength(sub, font=small)
        d.text(((W - sw) / 2, H / 2 + 50), sub, font=small, fill=(230, 230, 230, 255))
    im.save(path)


def main():
    edl_path, out = sys.argv[1], sys.argv[2]
    edl = json.load(open(edl_path))
    bar = 4 * 60 / edl.get("bpm", 120)
    tmp = tempfile.mkdtemp(prefix="lp-cut-")
    segs, total_bars = [], 0
    for i, s in enumerate(edl["shots"]):
        length = s["bars"] * bar
        speed = s.get("speed", 1.0)
        start = s.get("from", 0.0)
        need = start + length * speed
        have = duration(s["clip"])
        if need > have + 1e-3:
            raise SystemExit(f"trailer_cut: {s['clip']} has {have:.2f} s, the cut needs {need:.2f} (from {start}, "
                             f"{s['bars']} bars at speed {speed})")
        seg = os.path.join(tmp, f"seg{i:02d}.mp4")
        run(["-ss", f"{start}", "-i", s["clip"], "-t", f"{length * speed}",
             "-vf", f"setpts=PTS/{speed},scale={W}:{H},fps={FPS}", "-t", f"{length}", "-an",
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", seg])
        segs.append(seg)
        total_bars += s["bars"]
    lst = os.path.join(tmp, "list.txt")
    open(lst, "w").write("".join(f"file '{p}'\n" for p in segs))
    joined = os.path.join(tmp, "joined.mp4")
    run(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined])
    # Titles: each a still over its bars, faded in and out over a quarter bar.
    inputs, chain, last = ["-i", joined], [], "0:v"
    for k, t in enumerate(edl.get("titles", [])):
        png = os.path.join(tmp, f"title{k}.png")
        title_png(png, t["text"], t.get("sub"))
        a, dur = (t["bar"] - 1) * bar, t.get("bars", 1) * bar
        f = bar / 4
        inputs += ["-loop", "1", "-t", f"{dur}", "-i", png]
        chain.append(f"[{k + 1}:v]format=rgba,fade=in:st=0:d={f}:alpha=1,fade=out:st={dur - f}:d={f}:alpha=1,"
                     f"setpts=PTS+{a}/TB[t{k}]")
        chain.append(f"[{last}][t{k}]overlay=eof_action=pass[v{k}]")
        last = f"v{k}"
    total = total_bars * bar
    music = edl.get("music")
    args = inputs + (["-i", music] if music else [])
    vmap = f"[{last}]" if chain else "0:v"
    fc = ";".join(chain + [f"{vmap}fade=in:st=0:d=0.5,fade=out:st={total - 1}:d=1[vout]"])
    args += ["-filter_complex", fc, "-map", "[vout]"]
    if music:
        args += ["-map", f"{1 + len(edl.get('titles', []))}:a", "-af", f"afade=out:st={total - 1.5}:d=1.5", "-c:a", "aac", "-b:a", "192k"]
    args += ["-t", f"{total}", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart", out]
    run(args)
    print(f"cut: {out} ({len(segs)} shots, {total_bars} bars, {total:.0f} s)")


if __name__ == "__main__":
    main()
