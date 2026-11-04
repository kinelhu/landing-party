-- Field studies (studies.lua at the data stage; the rewards consult, part 3): what a player force has destroyed of a
-- corporation, counted by kind, fires a study's scripted research trigger once one of its counts is reached. A threshold,
-- not a currency: past it, more kills buy nothing. Kills by the player's turrets and artillery count (the force that
-- dealt the blow, on_entity_died's force).
local shared = require("__landing-party__.shared")
local creep = require("__landing-party__.scripts.creep")
local studies = {}

local BIO = shared.BIOTECH.force
-- Each study: its technology, the force whose losses count, and its ways (any one reached is enough): kinds and how many.
local STUDIES = {
  {tech = "lp-study-claims", force = "lp-grubstake", ways = {
    {kinds = {"lp-shotgun-hand", "lp-buggy", "lp-harrier", "lp-infantry", "lp-flak-buggy"}, need = 10},
    {kinds = {"lp-hauler"}, need = 1}}},
  {tech = "lp-study-strip", force = "lp-grubstake", ways = {{kinds = {"lp-drill"}, need = 3}}},
  {tech = "lp-study-bait", force = "lp-grubstake", ways = {{kinds = {"lp-pacifier"}, need = 1}}},
  {tech = "lp-study-flak", force = "lp-grubstake", ways = {
    {kinds = {"lp-scrap-cannon"}, need = 1}, {kinds = {"lp-harrier", "lp-scavenger"}, need = 5}}},
  {tech = "lp-study-telemetry", force = BIO, ways = {
    {kinds = {"lp-pen"}, need = 1}, {kinds = {"lp-tumor"}, need = 3}, {kinds = {"lp-bred-scout"}, need = 3}}},
  {tech = "lp-study-defoliant", force = BIO, ways = {{kinds = {"lp-tumor"}, need = 5}}},
}
studies.STUDIES = STUDIES
local BY_FORCE = {}
for _, st in ipairs(STUDIES) do
  BY_FORCE[st.force] = BY_FORCE[st.force] or {}
  table.insert(BY_FORCE[st.force], st)
end

-- A death: counted toward the killer force's studies of the dead one's corporation.
function studies.on_died(e)
  local ent, by = e.entity, e.force
  if not (by and shared.is_player_force(by) and ent and ent.valid) then return end
  local list = BY_FORCE[ent.force.name]
  if not list then return end
  local kind = shared.kind_of(ent.name)
  storage.studies = storage.studies or {}
  local counts = storage.studies[by.name] or {}
  storage.studies[by.name] = counts
  for _, st in ipairs(list) do
    local t = by.technologies[st.tech]
    if t and not t.researched then
      for i, w in ipairs(st.ways) do
        for _, k in ipairs(w.kinds) do
          if k == kind then
            local key = st.tech .. "#" .. i
            counts[key] = (counts[key] or 0) + 1
            if counts[key] >= w.need then by.script_trigger_research(st.tech) end
          end
        end
      end
    end
  end
end

-- Whether a force has a node (a technology researched).
function studies.has(force, tech)
  local t = force and force.technologies[tech]
  return t and t.researched or false
end

-- The defoliant's charge landed (studies.lua's capsule, its script trigger): creep stripped within 6, tumors burnt.
local DEFOLIATE_R = 6
function studies.on_trigger(e)
  if e.effect_id ~= "lp-defoliant" then return end
  local s = game.surfaces[e.surface_index]
  local at = e.target_position or (e.target_entity and e.target_entity.position)
  if not (s and at) then return end
  creep.defoliate(s, at, DEFOLIATE_R)
  for _, t in pairs(s.find_entities_filtered{position = at, radius = DEFOLIATE_R, name = "lp-tumor"}) do
    t.damage(200, game.forces.player, "fire")
  end
end

-- Tests: a force's counts.
function studies.counts(force_name) return (storage.studies or {})[force_name] or {} end

return studies
