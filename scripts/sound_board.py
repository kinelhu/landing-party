"""A board to listen to the units' weapon sounds (docs/sound/weapons.lua): for each, a card naming it, then its sound as
the unit has it now and as proposed, each fired at the unit's rate, as one video to send (the user listens; nothing here
can). The game's recordings at the proposal's speed (pitch and pace together, as the Sound prototype's speed) and volume.

    uv run --with pillow scripts/sound_board.py [out.mp4]      (default media/sound/board.mp4)
"""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app"),
                    "Contents", "data")
W, H, RATE = 1280, 720, 44100


def table():
    code = ('local t = dofile(%r) local out = {} for _, e in ipairs(t) do out[#out + 1] = e end '
            'local function enc(v) if type(v) == "table" then local parts, arr = {}, #v > 0 '
            'for k, x in pairs(v) do parts[#parts + 1] = (arr and "" or string.format("%%q:", k)) .. enc(x) end '
            'return (arr and "[" or "{") .. table.concat(parts, ",") .. (arr and "]" or "}") '
            'elseif type(v) == "string" then return string.format("%%q", v) else return tostring(v) end end '
            'print(enc(out))') % os.path.join(REPO, "docs", "sound", "weapons.lua")
    return json.loads(subprocess.run(["luajit", "-e", code], capture_output=True, text=True, check=True).stdout)


def card(path, title, sub):
    im = Image.new("RGB", (W, H), (18, 20, 24))
    d = ImageDraw.Draw(im)
    try:
        big, small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 54), ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 30)
    except OSError:
        big = small = ImageFont.load_default()
    d.text((80, 260), title, font=big, fill=(235, 235, 235))
    d.text((80, 350), sub, font=small, fill=(160, 170, 180))
    im.save(path)


def burst(out, files, speed, volume, every, shots):
    """shots of the files in turn, every ticks apart, at speed and volume, to a wav (silence for "none")."""
    if files == ["none"]:
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "anullsrc=r=%d:cl=stereo" % RATE, "-t",
                        "%.2f" % max(1.5, shots * every / 60), out], check=True)
        return
    args, parts = ["ffmpeg", "-loglevel", "error", "-y"], []
    for i in range(shots):
        args += ["-i", os.path.join(DATA, files[i % len(files)])]
        delay = int(i * every / 60 * 1000)
        parts.append("[%d:a]aresample=%d,asetrate=%d,aresample=%d,volume=%.2f,adelay=%d|%d[a%d]"
                     % (i, RATE, int(RATE * speed), RATE, volume, delay, delay, i))
    mix = ";".join(parts) + ";" + "".join("[a%d]" % i for i in range(shots)) + "amix=inputs=%d:normalize=0[o]" % shots
    subprocess.run(args + ["-filter_complex", mix, "-map", "[o]", "-ac", "2", out], check=True)


def segment(out, image, wav, pad=0.6):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-loop", "1", "-i", image, "-i", wav, "-af", "apad=pad_dur=%s" % pad,
                    "-shortest", "-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                    "-r", "30", out], check=True)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "media", "sound", "board.mp4")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="lp-board-")
    segs = []
    for n, e in enumerate(table()):
        now = [e["was"]] if e.get("was") else e["files"]
        for tag, files, speed, vol in (("now", now, 1.0, 1.0), ("proposed", e["files"], e["speed"], e["volume"])):
            k = "%02d-%s" % (n, tag)
            img, wav, seg = (os.path.join(tmp, k + x) for x in (".png", ".wav", ".mp4"))
            sub = ("as now: " + ("silent" if now == ["none"] else os.path.basename(now[0]).rsplit("-", 1)[0])) if tag == "now" else \
                  "proposed: %s at speed %.2f, volume %.2f" % (os.path.basename(e["files"][0]).rsplit("-", 1)[0], speed, vol)
            card(img, "%d. %s" % (n + 1, e["label"]), sub)
            burst(wav, files, speed, vol, e["every"], e["shots"])
            segment(seg, img, wav)
            segs.append(seg)
    lst = os.path.join(tmp, "list.txt")
    open(lst, "w").write("".join("file '%s'\n" % s for s in segs))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out], check=True)
    print("board: %s (%d sounds)" % (out, len(segs) // 2))


if __name__ == "__main__":
    main()
