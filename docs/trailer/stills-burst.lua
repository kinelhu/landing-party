-- Stills of a burst's look (landing-party scripts/burstfx.lua, 0.2.211; the user, 2026-11-05: "the burster is
-- underwhelming graphically compared to its usefulness"): the herd scenario's megaburst wave (200 with 20 cinders) on its
-- walled ring base, from its fork at minute 1, for judging the wind-up and the blast close before the trailer's cut.
--   scripts/film_fork.sh herd 12345 7 megaburst
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-herd-megaburst-12345-7" \
--     scripts/film.sh herd-megaburst-film fork.zip docs/trailer/stills-burst.lua
-- Two sets, by day (daytime 0.32, as act-megaburst's breach) and the first burst again at night (its light and glow):
--   b1-breach-NNNNN: from the breach order (wave:breach), centred where it breaks in, zoom 1.3, a still every 4 ticks for
--     6 s (90). Its cinders run at the wall; each that reaches it stops dead, a soft acid-green glow swelling over it and
--     quickening, its light growing, a thin green ring on the ground closing in from 4 tiles to its feet; half a second
--     on, its blast: a green flash, the fissure's eruption, a bright ring racing out over the ground to about 5 tiles
--     with a fainter one behind and a pale disc fading, eight green shockwave puffs thrown out, gibs (green and violet)
--     arcing out and gone where they land, three acid splashes that settle into pools.
--   b2-burst-NNNNN: from the film's first wind-up (burst:first, P.bursts), centred on that burster, zoom 1.6, a still
--     every 4 ticks for 3 s (45): 0 to 28 its wind-up (glow from about 1.5 to 3.5 tiles across, the ring closing, the
--     light pulsing faster), 30 its blast, 30 to 90 the shockwave and gibs, 50 to 120 the splashes landing, then the pools.
--   b3-pools-*: the same spot 5, 10 and 12 s after (its pools still there at 5, fading by 12: a cinder's stay 10 s).
--   b4-night-NNNNN: the first wind-up's first 2 s again at night (daytime 0.5; the stills are taken from one game, so
--     the same frames as b2, darkened): the glow and the flash should carry the shot.
-- No big burster here (megaburst's wave has none): its wind-up (0.75 s, a glow to about 8 tiles, a 6-tile ring) and
-- its blast (16 puffs, 16 gibs, six splashes, pools of 25 s) are the farm siege's (`farm` LP_MIX=siege) or `/lp burst big`.
local shots = {}
local function run(name, after, from, n, every, pos, zoom, daytime)
  for i = 0, n - 1 do
    shots[#shots + 1] = {name = string.format("%s-%05d", name, i + 1), after = after, dt = from + i * every, pos = pos,
      zoom = zoom, daytime = daytime, hide_clouds = daytime > 0.3}
  end
end
run("b1-breach", "wave:breach", 0, 90, 4, "breach", 1.3, 0.32)
run("b2-burst", "burst:first", 0, 45, 4, "burst", 1.6, 0.32)
for _, s in ipairs({5, 10, 12}) do
  shots[#shots + 1] = {name = "b3-pools-" .. s .. "s", after = "burst:first", dt = s * 60, pos = "burst", zoom = 1.3, daytime = 0.32}
end
-- (Taken a tick after b2's own, so the two sets do not share a tick's name.)
run("b4-night", "burst:first", 1, 30, 4, "burst", 1.6, 0.5)
return {name = "stills-burst", base = 1, waves = true, bursts = true, resolution = {1920, 1080}, anti_alias = true,
  speed = 8, fast_until = "wave:march", stop_after = 40 * 3600, shots = shots}
