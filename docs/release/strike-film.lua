-- The mod page's director loops (docs/release/modpage.md, 0.3.0): on the manual's director set (docs/manual/shots/
-- m-director.lua: scenario director LP_MIX=film, forked at minute 13), a strike force's pods coming down beside the labs
-- and its first minute among them, and the second force, broken at the ringed cluster, walking home. Frames every 2 ticks,
-- cut to GIFs at 30 fps (docs/release/gifs.sh).
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-director-film-12345-13" \
--     scripts/film.sh director-film-film fork.zip docs/release/strike-film.lua docs/sim/film-strike-loops
-- (Its events, from the manual's film-log: strike1:sent 32400, strike1:landed 32820, strike2:broken 34050.)
local C2 = {-143, 254}
local function move(name, after, dt, frames, pos, z0, z1, track)
  return {name = name, after = after, dt = dt, frames = frames, every = 2, track = track,
    from = {pos = pos, zoom = z0, daytime = 0.02}, to = {zoom = z1, daytime = 0.02}}
end
local function each()
  if storage.labels_hidden then return end
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
  end
  storage.labels_hidden = true
end
return {name = "strike-loops", resolution = {1440, 810}, anti_alias = true, speed = 1, stop_after = 10200, each = each,
  director = {
    {at = 60, cmd = "jammer"}, {at = 70, cmd = "blackout"},
    {at = 90, cmd = "strike", arg = "research"},
    {at = 150, cmd = "salvage", arg = "core"},
    {at = 2400, cmd = "focus", arg = C2},
  },
  moves = {
    -- The pods: from just before the first comes down to the force on the ground (touchdown about 420 after sent).
    move("pods", "strike1:sent", 300, 120, "dstrike1", 0.85, 0.8),
    -- Its fight among the labs, following the force.
    move("fight", "strike1:landed", 60, 150, "dforce1", 0.75, 0.75, true),
    -- The broken force walking home through the cluster it hit, followed.
    move("home", "strike2:broken", 30, 150, "dforce2", 0.7, 0.65, true),
  }}
