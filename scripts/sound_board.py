"""A board to listen to the units' weapon sounds (landing-party/sounds.lua): for each, a card naming it, then its sound as
the unit has it now and as proposed, each fired at the unit's rate, as one video to send (the user listens; nothing here
can). The game's recordings at the proposal's speed (pitch and pace together, as the Sound prototype's speed) and volume.

    uv run --with pillow scripts/sound_board.py [out.mp4]      (default media/sound/board.mp4)
    uv run --with pillow scripts/sound_board.py --table docs/sound/round4.lua [out.mp4]
                                                                another table (a round's proposal, not yet the mod's);
                                                                its was may be a list, a voice may be synth (sox
                                                                arguments), a card cut to dur seconds, its now in words
    uv run --with pillow scripts/sound_board.py --clips <dir>   each sound's two clips as mp3 and a manifest.json there
                                                                (the feedback page, docs/sound/board.html)
"""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app"),
                    "Contents", "data")
W, H, RATE = 1280, 720, 44100


TABLE = os.path.join(REPO, "landing-party", "sounds.lua")


def table():
    code = ('local t = dofile(%r) local out = {} for _, e in ipairs(t) do out[#out + 1] = e end '
            'local function enc(v) if type(v) == "table" then local parts, arr = {}, #v > 0 '
            'for k, x in pairs(v) do parts[#parts + 1] = (arr and "" or string.format("%%q:", k)) .. enc(x) end '
            'return (arr and "[" or "{") .. table.concat(parts, ",") .. (arr and "]" or "}") '
            'elseif type(v) == "string" then return string.format("%%q", v) else return tostring(v) end end '
            'print(enc(out))') % TABLE
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


def synth_wav(args, tmp):
    """A voice made by sox from its arguments (after "sox -n out.wav"), once per distinct set."""
    out = os.path.join(tmp, "synth-%08x.wav" % (hash(args) & 0xffffffff))
    if not os.path.exists(out):
        subprocess.run(["sox", "-n", "-r", str(RATE), "-c", "1", out] + args.split(), check=True)
    return out


def burst(out, files, speed, volume, every, shots, layers=(), rounds=1, gap=0, synth=None, dur=None):
    """shots of the files in turn, every ticks apart, at speed and volume, to a wav (silence for "none"). Each shot may be
    rounds rounds gap ticks apart (a burst), and each round may lay more sounds over it: layers, a list of
    {files, speed, volume, offset (ticks)}."""
    if files == ["none"]:
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "anullsrc=r=%d:cl=stereo" % RATE, "-t",
                        "%.2f" % max(1.5, shots * every / 60), out], check=True)
        return
    args, parts, n = ["ffmpeg", "-loglevel", "error", "-y"], [], 0
    tmp = os.path.dirname(out)
    voices = ([{"files": files, "speed": speed, "volume": volume, "offset": 0}] if files else []) + list(layers)
    if synth:
        voices.append({"synth": synth, "speed": 1.0, "volume": 1.0, "offset": 0})
    for i in range(shots):
        for r in range(rounds):
            for v in voices:
                src = synth_wav(v["synth"], tmp) if v.get("synth") else os.path.join(DATA, v["files"][(i * rounds + r) % len(v["files"])])
                args += ["-i", src]
                delay = int((i * every + r * gap + v.get("offset", 0)) / 60 * 1000)
                parts.append("[%d:a]aresample=%d,asetrate=%d,aresample=%d,volume=%.2f,adelay=%d|%d[a%d]"
                             % (n, RATE, int(RATE * v.get("speed", 1.0)), RATE, v.get("volume", 1.0), delay, delay, n))
                n += 1
    mix = ";".join(parts) + ";" + "".join("[a%d]" % i for i in range(n)) + "amix=inputs=%d:normalize=0" % n
    mix += (",atrim=0:%.2f,afade=t=out:st=%.2f:d=0.4" % (dur, max(0, dur - 0.4)) if dur else "") + "[o]"
    subprocess.run(args + ["-filter_complex", mix, "-map", "[o]", "-ac", "2", out], check=True)


def segment(out, image, wav, pad=0.6):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-loop", "1", "-i", image, "-i", wav, "-af", "apad=pad_dur=%s" % pad,
                    "-shortest", "-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                    "-r", "30", out], check=True)


def clips(d):
    """Each card's two clips as mp3 (now, proposed) and a manifest, for a listening page; the board's own logic."""
    os.makedirs(d, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="lp-clips-")
    man = []
    for n, e in enumerate(table()):
        now = now_files(e)
        row = {"n": n + 1, "id": e["id"], "label": e["label"], "detail": e.get("detail", ""), "decided": e.get("decided", ""),
               "units": e.get("units", []), "round": e.get("round", 1)}
        row["now"] = e.get("now") or ("silent" if now == ["none"] else os.path.basename(now[0]).rsplit("-", 1)[0])
        if not row["detail"]:
            row["detail"] = "%s at speed %.2f, volume %.2f" % (os.path.basename(e["files"][0]).rsplit("-", 1)[0], e["speed"],
                                                              e["volume"])
        for tag, files, speed, vol in (("now", now, 1.0, 1.0), ("proposed", e["files"], e["speed"], e["volume"])):
            wav = os.path.join(tmp, e["id"] + "-" + tag + ".wav")
            if tag == "now":
                burst(wav, files, speed, vol, e.get("was_every", e["every"]), e["shots"], dur=e.get("dur"))
            else:
                burst(wav, files, speed, vol, e["every"], e["shots"], e.get("layers", []), e.get("rounds", 1), e.get("gap", 0),
                      e.get("synth"), e.get("dur"))
            mp3 = os.path.join(d, e["id"] + "-" + tag + ".mp3")
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-af", "apad=pad_dur=0.3", "-c:a", "libmp3lame",
                            "-b:a", "96k", mp3], check=True)
        man.append(row)
    json.dump(man, open(os.path.join(d, "manifest.json"), "w"), indent=1)
    print("clips: %s (%d sounds)" % (d, len(man)))


def now_files(e):
    w = e.get("was")
    if w:
        return w if isinstance(w, list) else [w]
    return e["files"]


def main():
    global TABLE
    if len(sys.argv) > 2 and sys.argv[1] == "--table":
        TABLE = os.path.abspath(sys.argv[2])
        del sys.argv[1:3]
    if len(sys.argv) > 2 and sys.argv[1] == "--clips":
        return clips(sys.argv[2])
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "media", "sound", "board.mp4")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="lp-board-")
    segs = []
    for n, e in enumerate(table()):
        now = now_files(e)
        for tag, files, speed, vol in (("now", now, 1.0, 1.0), ("proposed", e["files"], e["speed"], e["volume"])):
            k = "%02d-%s" % (n, tag)
            img, wav, seg = (os.path.join(tmp, k + x) for x in (".png", ".wav", ".mp4"))
            if tag == "now":
                sub = "as now: " + (e.get("now") or ("silent" if now == ["none"] else os.path.basename(now[0]).rsplit("-", 1)[0]))
            elif e.get("detail"):
                sub = "proposed: " + e["detail"]
            else:
                sub = "proposed: %s at speed %.2f, volume %.2f" % (os.path.basename(e["files"][0]).rsplit("-", 1)[0], speed, vol)
            card(img, "%d. %s" % (n + 1, e["label"]), sub[:75])
            if tag == "now":
                burst(wav, files, speed, vol, e.get("was_every", e["every"]), e["shots"], dur=e.get("dur"))
            else:
                burst(wav, files, speed, vol, e["every"], e["shots"], e.get("layers", []), e.get("rounds", 1), e.get("gap", 0),
                      e.get("synth"), e.get("dur"))
            segment(seg, img, wav)
            segs.append(seg)
    lst = os.path.join(tmp, "list.txt")
    open(lst, "w").write("".join("file '%s'\n" % s for s in segs))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out], check=True)
    print("board: %s (%d sounds)" % (out, len(segs) // 2))


if __name__ == "__main__":
    main()
