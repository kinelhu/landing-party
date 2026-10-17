-- Camp names (the user, 2026-10-17: "we could have actual names for the camps too. More flavor"). Each settlement is
-- named once, from the map's seed and its id, in its corporation's voice, and no two share a name on a map:
--   Grubstake   a prospector's claim: "Last Chance Diggings", "Busted Gulch"
--   Serenity    a calm designation with a site number: "Halcyon Site 4"; its headquarters "Regional Office: Haven"
-- Proper nouns, not localised.
local rng = require("__landing-party__.scripts.rng")

local names = {}

local WORDS = {
  grubstake = {
    first = {"Last Chance", "Lucky", "Rusty", "Busted", "Dry", "Copperjack", "Shovel", "Muleskinner", "Tin Cup", "Hardscrabble",
      "Dead Horse", "Bonanza", "Poor Man's", "Gravel", "Slag", "Blind Mule", "Rattlesnake", "Payday", "Lost Boot", "Short Fuse"},
    second = {"Gulch", "Flats", "Diggings", "Hollow", "Strike", "Claim", "Draw", "Crossing", "Pit", "Camp", "Bend", "Ridge",
      "Wash", "Seam", "Dig"},
    hq = "Head Office",
  },
  serenity = {
    first = {"Halcyon", "Tranquil", "Placid", "Haven", "Stillwater", "Concord", "Harmony", "Lull", "Solace", "Clement",
      "Even Keel", "Quietude", "Amity", "Repose", "Calm Reach"},
    second = {"Site", "Station", "Post", "Annex", "Facility"},
    hq = "Regional Office",
  },
}

local function draw(b)
  local w = WORDS[b.corp] or WORDS.grubstake
  local surface = game.surfaces[b.surface]
  local r = rng.new((surface and surface.map_gen_settings.seed or 1) + 104729 * b.id)
  storage.camp_names = storage.camp_names or {}
  for _ = 1, 40 do
    local n
    if b.hq then
      n = w.hq .. ": " .. w.first[rng.int(r, 1, #w.first)]
    elseif b.corp == "serenity" then
      n = w.first[rng.int(r, 1, #w.first)] .. " " .. w.second[rng.int(r, 1, #w.second)] .. " " .. rng.int(r, 1, 9)
    else
      n = w.first[rng.int(r, 1, #w.first)] .. " " .. w.second[rng.int(r, 1, #w.second)]
    end
    if not storage.camp_names[n] then
      storage.camp_names[n] = b.id
      return n
    end
  end
  return (b.corp == "serenity" and "Site " or "Camp ") .. b.id
end

-- The settlement's name, drawn the first time it is asked (old saves included).
function names.of(b)
  if not b.name then b.name = draw(b) end
  return b.name
end

return names
