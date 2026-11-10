"""The mod's technology icons, 256 px, as vanilla's are: a large render of what it unlocks, on transparency (the research
screen draws the frame). Composed from the item icons' 256 px sources (tools/icons/cut.py) and the units' cut-outs: one
subject, or two (the second smaller, in front and to the right), and a field study (a technology a salvaged part
researches) tagged with a blueprint behind it at the upper left (the schematics' look), so a study is not taken for what it unlocks.

    uv run --with pillow python tools/icons/techs.py <icon sources> <unit cut-outs> <out dir>
"""
import os, sys
from PIL import Image

src, units, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
S = 256
# The blueprint the schematics' icons are drawn on (cut.py writes it, the component render squared): a study's tag.
BLUEPRINT = Image.open(os.path.join(src, "blueprint.png")).convert("RGBA").resize((int(256 * 0.5), int(256 * 0.5)), Image.LANCZOS)


def get(name):
    p = os.path.join(src, name + ".png")
    if not os.path.exists(p):
        p = os.path.join(units, name + ".png")
    im = Image.open(p).convert("RGBA")
    a = im.split()[3].point(lambda v: 255 if v > 150 else 0)
    return im.crop(a.getbbox())


def fit(im, box):
    k = min(box / im.width, box / im.height)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def one(a):
    c = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    im = fit(get(a), S * 0.92)
    c.alpha_composite(im, ((S - im.width) // 2, (S - im.height) // 2))
    return c


def two(a, b):
    c = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    big = fit(get(a), S * 0.78)
    c.alpha_composite(big, (int(S * 0.04), int(S * 0.04)))
    small = fit(get(b), S * 0.52)
    c.alpha_composite(small, (S - small.width - 4, S - small.height - 4))
    return c


def badge(c):
    """A field study: the subject over a blueprint tag in the upper left, the schematics' look (a study is research into a
    salvaged design; a drawn magnifier read as clip art, the user: "The magnifier looks horrible")."""
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(BLUEPRINT, (2, 2))
    sub = c.resize((int(S * 0.8), int(S * 0.8)), Image.LANCZOS)
    out.alpha_composite(sub, (S - sub.width, S - sub.height))
    return out


T = {
    "lp-player-dome": one("lp-player-dome"),
    "lp-command-bandwidth-1": two("lp-command-relay", "lp-trooper"),
    "lp-command-bandwidth-2": two("lp-command-relay", "lp-battle-tank"),
    "lp-command-bandwidth-3": two("lp-command-relay", "lp-flame-trooper"),
    "lp-command-bandwidth-4": two("lp-command-relay", "lp-barracks"),
    "lp-prize-serenity": one("lp-command-core"),
    "lp-prize-grubstake": one("lp-command-core"),
    "lp-pheromone-bait": one("lp-pheromone-gland"),
    "lp-pact-breaker": one("lp-pact-breaker"),
    "lp-claim-marker": one("lp-claim-marker"),
    "lp-rail-rifle": two("lp-rail-rifle", "lp-rail-slug"),
    "lp-orbital-strike": one("lp-orbital-beacon"),
    "lp-cluster-shells": two("lp-cluster-artillery-shell", "lp-cluster-fuze"),
    "lp-orbital-cannon": two("lp-orbital-cannon", "lp-orbital-shell"),
    "lp-study-claims": badge(one("lp-border-stake")),
    "lp-claims-register": two("lp-border-stake", "lp-trade-post"),
    "lp-study-strip": badge(one("lp-drill-head")),
    "lp-strip-drill": two("lp-strip-drill", "lp-drill-head"),
    "lp-study-bait": badge(one("lp-pheromone-gland")),
    "lp-bait-made": two("lp-pheromone-gland", "lp-bred-small-biter"),
    "lp-study-flak": badge(one("lp-flak-turret")),
    "lp-flak-turret": two("lp-flak-turret", "lp-grubstake-harrier"),
    "lp-study-telemetry": badge(two("lp-threat-scanner", "lp-bred-medium-biter")),
    "lp-bred-telemetry": two("lp-threat-scanner", "lp-bred-medium-biter"),
    "lp-study-defoliant": badge(one("lp-defoliant")),
    "lp-defoliant": two("lp-defoliant", "lp-bred-spore"),
    "lp-incubator-capture": two("lp-bred-big-biter", "lp-command-core"),
}
for name, im in T.items():
    im.save(os.path.join(out, name + ".png"), optimize=True)
print(len(T), "technology icons")
