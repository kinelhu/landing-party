-- A strike force on the user's own factory (cut 27, 2026-11-16; the user, on cut 26's pods on the test set: "kind of
-- crappy.. could we have it happen on a real base? Plus we never see the units actually going ham on the buildings"):
-- nw at minute 15 of the khwall visit (reel-khwall.lua's save), the director switched on and a strike force aimed at
-- the electric furnace rows inside the south wall (110,196: 160 furnaces between x 96 and 160, y 168 and 216).
-- Measured headless on this save (0.2.430), aimed at 96,160: 40 of Kessler-Hayashi's landed at 103,162 (its landing
-- spot 109,162, the rail yard north of the furnaces), their first damage 7 ticks after the first pod's touchdown, the
-- first building dead at 8, 411 of the player's dead within 90 tiles in the next 3 minutes: no idle. Aimed there, the
-- first take showed them on the rails; the furnace rows are 10 tiles south.
--   scripts/film.sh nw-khwall-saveat15 t15.zip docs/trailer/reel-strike.lua
local function each()
  if storage.labels_hidden then return end
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
  end
  storage.labels_hidden = true
end
return {name = "reel-strike", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = "strike1:sent",
  stop_after = 30000, each = each,
  director = {{at = 60, cmd = "on"}, {at = 90, cmd = "strike", arg = {110, 196}}},
  moves = {
  -- From the pods' fall through touchdown (sent + 420) into the force tearing through the furnaces: 18 s, a fixed
  -- framing on the fight pulled back slowly. (Tracked on dforce1, the first take opened at 0,0: the force's point reads
  -- 0,0 until it lands, and the eased camera slid 160 tiles from spawn.)
  {name = "strike", after = "strike1:sent", dt = 300, frames = 540,
    -- (Centred on where the force fights, 13 tiles east of the aim; at zoom 1.15 to 1.0, take 2, its grey troopers were
    -- lost in the grey furnace rows.)
    -- At night (take 3, by day: lasers and blasts barely read on the furnace rows' texture; the working furnaces glow).
    from = {pos = {121, 197}, zoom = 1.7, daytime = 0.4}, to = {pos = {125, 200}, zoom = 1.5, daytime = 0.4}},
}}
