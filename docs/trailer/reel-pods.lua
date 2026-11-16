-- A strike force landing (cut 26, 2026-11-16; the trailer had no shot of the director's strike forces, built since
-- 0.2.418): a corporation's pods (Grubstake's buggies on this set) coming down on the player's labs and the force going in. Scenario director's film set
-- (LP_MIX=film, as the manual's Headquarters pictures, docs/manual/shots/m-director.lua): Kessler-Hayashi's camp at
-- -344,215, the player's labs and assemblers 150 toward spawn; the strike at the labs driven by the plugin's director
-- list. Its pods touch down about 400 ticks after it is sent.
--   scripts/film_fork.sh director 12345 13 film
--   LP_FILM_SIM="$HOME/Library/Application Support/factorio-lp-sim/fork-director-film-12345-13" \
--     scripts/film.sh director-film-film fork.zip docs/trailer/reel-pods.lua
local function each()
  if storage.labels_hidden then return end
  for _, o in pairs(rendering.get_all_objects("landing-party")) do
    if o.valid and o.type == "text" and tostring(o.text):find("|", 1, true) then o.visible = false end
  end
  storage.labels_hidden = true
end
return {name = "reel-pods", resolution = {1920, 1080}, anti_alias = true, speed = 8, fast_until = "strike1:sent", stop_after = 12000, each = each,
  director = {{at = 90, cmd = "strike", arg = "research"}},
  moves = {
  -- From the pods' fall (the warning's last seconds) through touchdown into the force's first shots: 16 s. Framed on the labs and the drop between them, fixed
  -- (the drop point dstrike1 read -212.28,141.24 on this fork; a named point takes `off` from `to` alone, eased from 0).
  {name = "pods", after = "strike1:sent", dt = 150, frames = 480, from = {pos = {-216.3, 138}, zoom = 1.25, daytime = 0.2},
    to = {pos = {-216.3, 138.5}, zoom = 1.1, daytime = 0.21}},
}}
