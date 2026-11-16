#!/usr/bin/env python3
"""The mod portal, by its public API (wiki.factorio.com: Mod publish, upload, details and images APIs, read 2026-11-16).
Dry run by default: prints every request it would make, sends nothing. A step runs only when named and --go is given.

  uv run --with requests python3 scripts/portal.py [--trailer URL] [--assets URL]          # dry run, all steps
  uv run --with requests python3 scripts/portal.py publish --go   # a NEW mod: init_publish + finish_upload (the zip),
                                                                  # then edit_details deprecated=true at once (hidden)
  ... details --go     # edit_details: title, summary, description, category, tags, license, source, homepage
  ... images --go      # gallery: images/add + finish_upload for each docs/release/gallery/*.jpg, then images/edit order
  ... release --go     # a NEW RELEASE of the existing mod: releases/init_upload + finish_upload (the zip)
  ... live --go        # edit_details deprecated=false: the page shows in listings

The page text is docs/release/modpage.md below its "---", up to "## Gallery captions". Its [gif: name] marks become
links to each loop's MP4 on the GitHub release (--assets, default the v<version> release), [Trailer: link] the trailer
(--trailer). A real run refuses while any [placeholder] is left. The zip is media/release/landing-party_<version>.zip
(scripts/package.sh). The API key is read here only, never printed: $LP_PORTAL_KEY, else
~/.config/factorio/mod-portal-key, else the Keychain item "mod-portal-key". The user's go is needed for every --go.
"""
import json, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://mods.factorio.com/api/v2/mods"
MOD = "landing-party"
# The portal's enums (Mod details API): our category and tags.
CATEGORY, TAGS, LICENSE = "content", ["combat", "enemies"], "default_mit"
SOURCE = "https://github.com/kinelhu/landing-party"

args = sys.argv[1:]
go = "--go" in args
def opt(name, default=None):
    return args[args.index(name) + 1] if name in args and args.index(name) + 1 < len(args) else default
steps = [a for a in args if a in ("publish", "details", "images", "release", "live")]
if go and len(steps) != 1:
    sys.exit("--go runs exactly one step: publish, details, images, release or live")

version = json.load(open(os.path.join(REPO, "landing-party", "info.json")))["version"]
zip_path = os.path.join(REPO, "media", "release", "%s_%s.zip" % (MOD, version))
assets = opt("--assets", "%s/releases/download/v%s" % (SOURCE, version))
trailer = opt("--trailer")

md = open(os.path.join(REPO, "docs", "release", "modpage.md")).read()
def field(name):
    m = re.search(r"^- \*\*%s:\*\* (.+)$" % re.escape(name), md, re.M)
    return m and m.group(1).strip()
title, summary = field("Title"), field("Summary (one line)")
body = md.split("\n---\n", 1)[1].split("## Gallery captions")[0].strip() + "\n"
body = re.sub(r"\[gif: ([a-z-]+)\]", lambda m: "![%s](%s/%s.mp4)" % (m.group(1), assets, m.group(1)), body)
if trailer:
    body = body.replace("[Trailer: link]", "[The trailer](%s)" % trailer)
left = re.findall(r"\[(?:Trailer: link|link|gif: [a-z-]+|[a-z ]+ link[^\]]*)\]", body)
gallery = sorted(os.path.join(REPO, "docs", "release", "gallery", f)
                 for f in os.listdir(os.path.join(REPO, "docs", "release", "gallery")) if f.endswith(".jpg"))

def key():
    k = os.environ.get("LP_PORTAL_KEY")
    p = os.path.expanduser("~/.config/factorio/mod-portal-key")
    if not k and os.path.exists(p): k = open(p).read().strip()
    if not k:
        r = subprocess.run(["security", "find-generic-password", "-s", "mod-portal-key", "-w"], capture_output=True, text=True)
        k = r.stdout.strip()
    if not k: sys.exit("no API key: $LP_PORTAL_KEY, ~/.config/factorio/mod-portal-key or the Keychain item mod-portal-key")
    return k

def post(url, data=None, files=None):
    """One request; dry, it prints what it would send. Returns the JSON reply (dry: a stand-in)."""
    shown = {k: (v if len(str(v)) < 80 else "%s... (%d chars)" % (str(v)[:60], len(str(v)))) for k, v in (data or {}).items()}
    print("  POST %s  %s%s" % (url, json.dumps(shown), "  files: " + ", ".join("%s=%s" % (k, os.path.basename(v)) for k, v in (files or {}).items()) if files else ""))
    if not go: return {"upload_url": "<upload_url>", "id": "<id of %s>" % os.path.basename((files or {}).get("image", "?"))}
    import requests
    fh = {k: open(v, "rb") for k, v in (files or {}).items()}
    try:
        r = requests.post(url, headers={"Authorization": "Bearer " + key()} if url.startswith(API) else None,
                          data=data, files=fh or None, timeout=600)
    finally:
        for f in fh.values(): f.close()
    try: j = r.json()
    except ValueError: sys.exit("HTTP %d, no JSON: %s" % (r.status_code, r.text[:300]))
    if r.status_code >= 400 or j.get("error"):
        sys.exit("FAILED: HTTP %d %s: %s" % (r.status_code, j.get("error"), j.get("message")))
    return j

def details(deprecated=None):
    d = {"mod": MOD, "title": title, "summary": summary, "description": body, "category": CATEGORY,
         "license": LICENSE, "source_url": SOURCE, "homepage": SOURCE}
    if deprecated is not None: d = {"mod": MOD, "deprecated": "true" if deprecated else "false"}
    # (tags: one field per value, the API's "multiple values allowed")
    data = list(d.items()) + ([("tags", t) for t in TAGS] if deprecated is None else [])
    shown = {k: (v if len(str(v)) < 80 else "%s... (%d chars)" % (str(v)[:60], len(str(v)))) for k, v in d.items()}
    if deprecated is None: shown["tags"] = TAGS
    print("  POST %s/edit_details  %s" % (API, json.dumps(shown)))
    if not go: return
    import requests
    r = requests.post(API + "/edit_details", headers={"Authorization": "Bearer " + key()}, data=data, timeout=120)
    try: j = r.json()
    except ValueError: j = {}
    if r.status_code >= 400 or j.get("error"): sys.exit("FAILED: HTTP %d %s: %s" % (r.status_code, j.get("error"), j.get("message")))
    print("  edit_details: ok")

print("Landing Party %s, %s" % (version, "SENDING (--go)" if go else "dry run: nothing is sent"))
print("  zip: %s (%s)" % (zip_path, "%.1f MB" % (os.path.getsize(zip_path) / 1e6) if os.path.exists(zip_path) else "MISSING: run scripts/package.sh"))
print("  title %r, summary %d chars, description %d chars, category %s, tags %s" % (title, len(summary or ""), len(body), CATEGORY, TAGS))
print("  loops linked from %s; trailer %s; gallery %d images" % (assets, trailer or "NOT SET (--trailer URL)", len(gallery)))
if left: print("  placeholders left: %s" % ", ".join(sorted(set(left))))
if go and (left or (steps[0] in ("publish", "release") and not os.path.exists(zip_path))):
    sys.exit("refused: placeholders left or the zip missing")

for step in steps or ["publish", "details", "images", "live"]:
    print("\n%s:" % step)
    if step in ("publish", "release"):
        j = post(API + ("/init_publish" if step == "publish" else "/releases/init_upload"), {"mod": MOD})
        extra = {"description": body, "category": CATEGORY, "license": LICENSE, "source_url": SOURCE} if step == "publish" else {}
        post(j["upload_url"], extra, {"file": zip_path})
        if step == "publish":
            print("  (then hidden at once, for the user to look before it lists:)"); details(deprecated=True)
    elif step == "details":
        details()
    elif step == "images":
        ids = []
        for g in gallery:
            j = post(API + "/images/add", {"mod": MOD})
            ids.append(post(j["upload_url"], None, {"image": g}).get("id"))
        post(API + "/images/edit", {"mod": MOD, "images": ",".join(str(i) for i in ids)})
    elif step == "live":
        details(deprecated=False)
