-- Stance (docs/ai.md, section 4): how a corporation treats a player force right now, asked by every system that acts
-- against a player. One answer where there were three (ops.temper_allows, war.at_war and choose_siege's own checks
-- disagreed: an unprovoked Grubstake tapped under a paid truce and held its rebuilds on a war footing).
--   standing   rival or enemy (provoked: its buildings, units or crews hurt, its ground built on); "truce" only under a
--              staged hold (debug_truce, tests and films): the player buys no truce (the user, 2026-11-11: "the hostility
--              is the most fun part"; the trade post and the invoice post's truce gone at 0.2.325)
--   rung       the ladder, 0 to 3: minutes since it last razed something of that force (10, 20, 30); a rival thief's
--              stays at 0 (it steals, it does not escalate)
--   may(act)   whether its temper lets it do that act to that force now
-- A leaf: it reads storage only, so ops, war, tap and the rest can all ask it without a require loop.
local shared = require("__landing-party__.shared")
local tune = require("__landing-party__.scripts.tune")

local stance = {}

local function against_player(owner) return owner ~= nil and owner ~= "enemy" and owner ~= "neutral" and not shared.is_corp(owner) end
stance.against_player = against_player

local function corp_of_force(force)
  for corp, c in pairs(shared.CORPS) do if c.force == force then return corp end end
end

local function provoked(corp, owner)
  local d = storage.corps and storage.corps[corp]
  return d and d.provoked and d.provoked[owner] ~= nil or false
end
stance.provoked = provoked

function stance.standing(corp, owner)
  local t = storage.truces and storage.truces[corp .. "|" .. owner]
  if t and game.tick < t then return "truce" end
  -- Serenity is at war from landing (the user, 2026-10-19: "what's the point of serenity being non hostile sometimes",
  -- then "no grace").
  if (shared.CORPS[corp].temper or {}).hostile then return "enemy" end
  if provoked(corp, owner) then return "enemy" end
  return "rival"
end

-- Whether `corp_force`'s corporation is a rival of `owner` whose temper holds its ladder (Grubstake: soft_only).
function stance.rival_holds(owner, corp_force)
  local corp = corp_of_force(corp_force)
  if not corp or not (shared.CORPS[corp].temper or {}).soft_only then return false end
  return not provoked(corp, owner)
end

-- The ladder (docs/reviews/2026-10-14-megabase-pressure-consult.md): minutes since a corporation last razed a building
-- of this player force (storage.last_raze, control.lua), its clock started at first sight.
function stance.rung(owner, corp_force)
  if not against_player(owner) then return 0 end
  if corp_force and stance.rival_holds(owner, corp_force) then return 0 end
  storage.last_raze = storage.last_raze or {}
  local key = corp_force and (owner .. "|" .. corp_force) or owner
  local t0 = storage.last_raze[key]
  if not t0 then storage.last_raze[key] = game.tick; return 0 end
  -- Its aggression lever runs the clock faster (tune.lua).
  local corp = corp_force and tune.corp_of_force(corp_force)
  local m = (game.tick - t0) / 3600 * (storage.ladder_fast and 10 or 1) * (corp and tune.aggression(corp) or 1)
  return m >= 30 and 3 or m >= 20 and 2 or m >= 10 and 1 or 0
end

-- What a corporation's temper lets it do to a player force (the user's storyboard calls, 2026-10-17, docs/ai.md):
--   raid, siege, answer   not under a staged hold; a provoked_only corporation (Serenity) only once provoked
--   strip, tap, jump         theft: not under a staged hold
--   prospect   claims unworked ground, not the player's: always
--   war        the war footing, relief and the stand-down clock: an enemy only (an unprovoked rival is not at war)
-- The ladder's thresholds (a rig at 2) stay with each system.
local THEFT = {strip = true, tap = true, jump = true, skim = true}
function stance.may(corp, owner, act)
  if not against_player(owner) then return true end
  if act == "prospect" then return true end
  local st = stance.standing(corp, owner)
  if st == "truce" then return false end
  if act == "war" then return st == "enemy" end
  if THEFT[act] then return true end
  local temper = shared.CORPS[corp].temper or {}
  if temper.provoked_only and st ~= "enemy" then return false end
  return true
end

return stance
