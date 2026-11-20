-- Corporate research (docs/reviews/2026-10-14-corporate-rd-consult.md, made each corporation's own in
-- docs/reviews/2026-10-14-identity-trees-consult.md; the user: "a 'smart' parallel to biter evolution", and "actual
-- faction identity"). A share of each corporation's exports goes to a fund (FUND_SHARE, capped at FUND_CAP); every
-- CHOICE_TICKS it buys at most one node of its own tree (shared.CORPS[corp].tree), read from what it has been
-- losing to (rd.choose). Its own units' upgrades divide the defence it reads at a target (ops: rd.strength), so raids
-- stay a size a garrison can field. The ledger: units lost in the last WINDOW_TICKS by the damage the killer deals,
-- and raids turned back for want of force.
local shared = require("__landing-party__.shared")

local rd = {}

local FUND_SHARE, FUND_CAP = 0.3, 10000
-- Its labs' income (0.2.474; the user: "decouple tech budget from the current parts corps use ... balancing too much on a
-- single point of consumption"): a corporation with labs (rd.gated) funds its research from them, not from its exports:
-- LAB_RATE a minute for each branch of its tree a standing lab of its serves. A named prior: 30% of the exports of a
-- camp of contact-12345 (68 parts a minute over two hours) was 20 a minute. Its exports still raise its era (faction).
local LAB_RATE, LAB_TICKS = 20, 3600
local LEVEL_COST, LEVEL_DAMAGE, MAX_LEVEL = 400, 0.2, 5
local CHOICE_TICKS = 10 * 3600
local WINDOW_TICKS = 30 * 3600
-- What each unit kind fires (units.lua).
rd.CATEGORY = {["lp-infantry"] = "bullet", ["lp-buggy"] = "bullet", ["lp-harrier"] = "bullet",
  ["lp-tank"] = "cannon-shell", ["lp-walker"] = "rocket"}
-- Each corporation's own infantry (units.lua): Serenity's Line troopers fire lasers, Grubstake's Shotgun hands shells.
rd.CORP_CATEGORY = {serenity = {["lp-infantry"] = "laser", ["lp-lance"] = "laser", ["lp-shock"] = "electric",
  ["lp-railgunner"] = "lp-rail",
  ["lp-aegis"] = "laser", ["lp-prism"] = "laser", ["lp-tesla"] = "electric", ["lp-skyguard"] = "laser", ["lp-laser-drone"] = "laser"},
  grubstake = {["lp-infantry"] = "shotgun-shell", ["lp-slug"] = "shotgun-shell", ["lp-sapper"] = "grenade",
    ["lp-scorcher"] = "bullet", ["lp-flak-buggy"] = "bullet"}}
local know = require("__landing-party__.scripts.know")

function rd.state(corp)
  storage.corps = storage.corps or {}
  storage.corps[corp] = storage.corps[corp] or {level = 0, exported = 0}
  local d = storage.corps[corp]
  d.tech = d.tech or {fund = 0, weapons = {}, losses = {}, turned_back = {}, bought = 0}
  d.tech.plate = d.tech.plate or {}
  d.tech.nodes = d.tech.nodes or {}
  d.tech.units = d.tech.units or {}
  d.tech.walls_met = d.tech.walls_met or {}
  return d.tech
end

-- Exports feed the fund (faction.develop), apart from the level they also raise: only a corporation whose research is
-- not its labs' (no labs, or labs off: rd.gated), as before 0.2.474.
function rd.fund(corp, parts)
  if rd.gated(corp) then return end
  local t = rd.state(corp)
  t.fund = math.min(FUND_CAP, t.fund + FUND_SHARE * parts)
end

local function prune(list)
  for i = #list, 1, -1 do if game.tick - list[i].tick > WINDOW_TICKS then table.remove(list, i) end end
end

-- Its units lost in the window, with what killed them: the faction's ledger (know.lua; the tree's own, rd.tally, gave
-- way to it). Biters count (at maximum evolution a single biter cleared turrets and ten units, the user in game):
-- their jaws as physical, spitters' and worms' acid as acid; their killer is "biter".
local function losses_of(corp)
  return know.losses(corp, WINDOW_TICKS, function(l) return l.unit and l.damage ~= nil end)
end

-- A raid that attacked a target behind walls and razed nothing (ops).
function rd.walls_met(b)
  table.insert(rd.state(b.corp).walls_met, {tick = game.tick})
end

-- A siege whose hits the player's robots mended: roboports still stood by its target when it ended (ops).
function rd.mended(b)
  local t = rd.state(b.corp)
  t.mended = t.mended or {}
  table.insert(t.mended, {tick = game.tick})
end

-- A raid that turned back for want of force (ops).
function rd.turned_back(b)
  local t = rd.state(b.corp)
  table.insert(t.turned_back, {tick = game.tick})
end

-- The categories a corporation's units fire, heaviest in its mix first.
local function categories(corp)
  local w = {}
  for name, k in pairs(shared.CORPS[corp].mix or {}) do
    local c = (rd.CORP_CATEGORY[corp] or {})[name] or rd.CATEGORY[name]
    if c then w[c] = (w[c] or 0) + k end
  end
  local out = {}
  for c in pairs(w) do table.insert(out, c) end
  table.sort(out, function(a, b) return w[a] > w[b] or (w[a] == w[b] and a < b) end)
  return out
end
rd.categories = categories

-- Labs (shared.CORPS[corp].labs; the user, 2026-10-21: its tech in the world): a branch's nodes are bought, and what
-- they field (units, plates, abilities) fielded, only while a lab of that branch stands in one of its camps. Off for a
-- corporation without labs, for camps laid out by blocks (storage.wfc_core_off: labs come in districts) and for
-- scenarios of other mechanics (storage.labs_off).
function rd.gated(corp)
  local c = shared.CORPS[corp]
  if c.labs == nil or storage.labs_off then return false end
  -- (Labs come in its districts or, in a town, a workshop lot: off with whichever lays its camps.)
  if (c.arch or {}).town then return not storage.town_off end
  return not storage.wfc_core_off
end
function rd.lab_kind(corp, branch)
  return (shared.CORPS[corp].labs or {})[branch]
end
function rd.lab(corp, branch)
  if not rd.gated(corp) then return true end
  local kind = rd.lab_kind(corp, branch)
  if not kind then return true end
  for _, b in pairs(storage.bases or {}) do
    if b.corp == corp and not b.fallen then
      for _, e in ipairs(b.labs or {}) do
        if e.valid and e.force.name == b.force and shared.kind_of(e.name) == kind then return true end
      end
    end
  end
  return false
end
-- The branches of its tree a standing lab serves (its income: LAB_RATE each).
local function branches_served(corp)
  local seen, n = {}, 0
  for _, node in ipairs(shared.CORPS[corp].tree or {}) do
    local br = node.branch
    if br and not seen[br] then
      seen[br] = true
      if rd.lab_kind(corp, br) and rd.lab(corp, br) then n = n + 1 end
    end
  end
  return n
end
rd.branches_served = branches_served
-- Its labs' income, each LAB_TICKS (rd.tick).
local function lab_income(corp)
  if not rd.gated(corp) then return 0 end
  local t = rd.state(corp)
  local add = LAB_RATE * branches_served(corp) * LAB_TICKS / 3600
  t.fund = math.min(FUND_CAP, t.fund + add)
  t.lab_funded = (t.lab_funded or 0) + add
  return add
end

local function node_of(corp, id)
  for _, node in ipairs(shared.CORPS[corp].tree or {}) do if node.id == id then return node end end
end

-- Whether a corporation has bought a node, and its lab stands (abilities: ops and control read them).
function rd.has(corp, id)
  local d = storage.corps and storage.corps[corp]
  if not (d and d.tech and d.tech.nodes and d.tech.nodes[id] ~= nil) then return false end
  local node = node_of(corp, id)
  return not node or rd.lab(corp, node.branch)
end

-- Salvage rights (Grubstake): a player building its raid destroyed pays into its fund, by what it was worth.
function rd.salvage(corp, value)
  if not rd.has(corp, "salvage") then return end
  local t = rd.state(corp)
  t.fund = math.min(FUND_CAP, t.fund + 10 + 5 * (value or 0))
  t.salvaged = (t.salvaged or 0) + 10 + 5 * (value or 0)
end

-- Units its tree has added to its mix, with their weights (army: mix): those whose lab stands.
function rd.mix(corp)
  local d = storage.corps and storage.corps[corp]
  local units = d and d.tech and d.tech.units or {}
  if not rd.gated(corp) then return units end
  local out = {}
  for kind, w in pairs(units) do
    local ok = true
    for _, node in ipairs(shared.CORPS[corp].tree or {}) do
      if node.unit and node.unit.kind == kind and not rd.lab(corp, node.branch) then ok = false end
    end
    if ok then out[kind] = w end
  end
  return out
end

-- The prototype a depot builds for a kind: plated once its corporation bought the plate.
function rd.unit(corp, kind)
  local d = storage.corps and storage.corps[corp]
  local plate = d and d.tech and d.tech.plate and d.tech.plate[kind]
  if plate and rd.gated(corp) then
    for _, node in ipairs(shared.CORPS[corp].tree or {}) do
      if node.plates and node.plates[kind] == plate and not rd.lab(corp, node.branch) then plate = nil; break end
    end
  end
  return shared.plated(corp, kind, plate)
end

-- What its units have over the defence they read: (1 + its damage modifier for its main category) x (1 + its shooting
-- speed modifier), times 1.4 when
-- one of its plates answers the damage the target's turrets mostly deal (dmg, from ops.weigh), 1.15 for any plate.
function rd.strength(corp, dmg)
  local f = game.forces[shared.CORPS[corp].force]
  local main = categories(corp)[1]
  -- Damage times rate of fire, as the turrets it reads are weighed (intel.lua: (1 + damage) x (1 + speed)). On damage
  -- alone, the arms race's speed would have gone uncounted and its raids grown in number and fire at once.
  local s = (1 + ((f and main) and f.get_ammo_damage_modifier(main) or 0))
    * (1 + ((f and main) and f.get_gun_speed_modifier(main) or 0))
  local plates = storage.corps and storage.corps[corp] and storage.corps[corp].tech and storage.corps[corp].tech.plate
  local a = 1
  for _, p in pairs(plates or {}) do
    if dmg and p == dmg then a = 1.4; break end
    a = 1.15
  end
  return s * a
end

-- The highest era among the player forces it faces (the cap: a player who stops researching freezes them).
local function player_era()
  if storage.era_override then return storage.era_override end
  local e = 0
  for _, f in pairs(game.forces) do
    if shared.is_player_force(f) then e = math.max(e, rd.era and rd.era(f) or 0) end
  end
  return e
end

local function notify(corp, key, ...)
  for _, f in pairs(game.forces) do
    if (#f.players > 0 or (storage.trace and shared.is_player_force(f))) and not shared.is_corp(f.name) then shared.notice(f, {key, shared.corp_label(corp), ...}) end
  end
end

-- The arms race (docs/reviews/2026-11-20-arms-race-consult.md; the user: "Arms race is attractive"): a track's level k is
-- the base game's own technology level k for each of its categories, damage and shooting speed together: the summed
-- ammo-damage and gun-speed modifiers of every finite technology of level k or below naming the category, read from the
-- prototypes (Kessler-Hayashi's optics 3 is laser weapons damage 3 and laser shooting speed 3). Before, +20% damage a
-- level to five and no speed: at full research the player's army won 20 of 20 matchups against its units (the arena's
-- late setting). A category no technology names (railguns) climbs by its node's own step, damage only.
local ladders = {}
local function ladder(c)
  if ladders[c] then return ladders[c] end
  local at = {}
  local top = 0
  for _, t in pairs(prototypes.technology) do
    if t.max_level < 4294967295 then
      for _, e in ipairs(t.effects or {}) do
        if (e.type == "ammo-damage" or e.type == "gun-speed") and e.ammo_category == c then
          local k = t.level
          at[k] = at[k] or {0, 0}
          if e.type == "ammo-damage" then at[k][1] = at[k][1] + e.modifier else at[k][2] = at[k][2] + e.modifier end
          if k > top then top = k end
        end
      end
    end
  end
  local l = {top = top}
  local dmg, spd = 0, 0
  for k = 1, top do
    if at[k] then dmg, spd = dmg + at[k][1], spd + at[k][2] end
    l[k] = {dmg, spd}
  end
  ladders[c] = l
  return l
end
rd.ladder = ladder
-- A track's levels: its categories' deepest ladder, else its node's own count.
local function levels_of(node)
  local top = 0
  for _, c in ipairs(node.track or {}) do top = math.max(top, ladder(c).top) end
  if top > 0 and not node.step then return top end
  return node.levels or MAX_LEVEL
end
-- Whether level k of a track gives anything: the base game's cannon shells gain only from its fifth level, rockets from
-- its third, electric weapons at its third (a level bought for nothing spent a choice and its fund).
local function gains(node, k)
  for _, c in ipairs(node.track or {}) do
    local l = ladder(c)
    if l.top == 0 or node.step then return true end
    if k <= l.top then
      local a, b = l[k], l[k - 1] or {0, 0}
      if a[1] ~= b[1] or a[2] ~= b[2] then return true end
    end
  end
  return false
end
-- The level a track buys next: the first past its own that gives anything, nil at its top.
local function next_level(t, node)
  for k = (t.nodes[node.id] or 0) + 1, levels_of(node) do
    if gains(node, k) then return k end
  end
end
-- Its force's modifiers for one category at level k of a track node.
local function set_level(f, node, c, k)
  if not f then return end
  local l = ladder(c)
  if l.top > 0 and not node.step then
    local r = k > 0 and l[math.min(k, l.top)] or {0, 0}
    f.set_ammo_damage_modifier(c, r[1])
    f.set_gun_speed_modifier(c, r[2])
  else
    f.set_ammo_damage_modifier(c, (node.step or LEVEL_DAMAGE) * k)
  end
end
-- What a track node gives at level k: {category = {damage, speed}} (tests, the manual).
function rd.track_at(corp, id, k)
  local out = {}
  for _, node in ipairs(shared.CORPS[corp].tree or {}) do
    if node.id == id then
      for _, c in ipairs(node.track or {}) do
        local l = ladder(c)
        if l.top > 0 and not node.step then
          local r = k > 0 and l[math.min(k, l.top)] or {0, 0}
          out[c] = {r[1], r[2]}
        else
          out[c] = {(node.step or LEVEL_DAMAGE) * k, 0}
        end
      end
    end
  end
  return out
end

-- The tree (shared.CORPS[corp].tree): nodes in the corporation's voice. A track node raises the damage of its
-- ammunition categories a level at a time (LEVEL_COST x k for level k, the base game's level k or its own step, at most the
-- player's era + 1); a plate node sets plates on unit kinds (rd.unit builds them), from its era. A trigger reads the ledger:
-- {damage = d, min = n} (n or more of its units killed by damage d in the window), {turned_back = n} (raids turned
-- back for want of force). The node whose trigger fires hardest wins (tree order breaks ties); with none, the first
-- track climbs. A winner it cannot yet afford is saved for: nothing else is bought meanwhile.
local function level_of(t, node) return (t.nodes[node.id] or 0) end
local function owned(t, node)
  if node.track then return next_level(t, node) == nil end
  if node.unit then return t.units[node.unit.kind] ~= nil end
  if node.ability then return t.nodes[node.id] ~= nil end
  for kind, p in pairs(node.plates or {}) do if t.plate[kind] ~= p then return false end end
  return true
end
local function allowed(t, node, era, corp)
  if owned(t, node) then return false end
  -- (corp given: its lab must stand; a history brought from orbit needs none.)
  if corp and not rd.lab(corp, node.branch) then return false end
  if node.requires and not t.nodes[node.requires] then return false end
  if node.track then return next_level(t, node) <= era + 1 end
  return era >= (node.era or 0)
end
local function cost_of(t, node)
  if node.track then return node.cost * next_level(t, node) end
  return node.cost
end
local function score(t, node)
  local tr = node.trigger or {}
  if tr.damage then
    local n = 0
    for _, l in ipairs(t.losses) do if l.damage == tr.damage then n = n + 1 end end
    if n >= (tr.min or 1) then return n end
  end
  if tr.killer then
    local n = 0
    for _, l in ipairs(t.losses) do
      for _, k in ipairs(tr.killer) do if l.killer == k then n = n + 1 end end
    end
    if n >= (tr.min or 1) then return n end
  end
  if tr.turned_back and #t.turned_back >= tr.turned_back then return 5 * #t.turned_back end
  if tr.walls_met and #t.walls_met >= tr.walls_met then return 5 * #t.walls_met end
  if tr.mended and #(t.mended or {}) >= tr.mended then return 5 * #t.mended end
  return 0
end

local function apply(corp, t, node)
  local f = game.forces[shared.CORPS[corp].force]
  if node.track then
    local k = next_level(t, node)
    t.nodes[node.id] = k
    for _, c in ipairs(node.track) do
      t.weapons[c] = k
      set_level(f, node, c, k)
    end
    notify(corp, "lp.node-" .. node.id, k)
  else
    t.nodes[node.id] = 1
    for kind, p in pairs(node.plates or {}) do t.plate[kind] = p end
    if node.unit then t.units[node.unit.kind] = node.unit.weight end
    notify(corp, "lp.node-" .. node.id)
  end
  t.bought = t.bought + 1
end

-- The node it would buy now, and whether a trigger called for it. And the lab it wants: the branch of the node the
-- ledger calls for hardest when that branch has no lab, else (no lab at all) its first track's.
local function pick(corp, t, era)
  t.losses = losses_of(corp)
  local best, bs, fallback
  local want, ws
  for _, node in ipairs(shared.CORPS[corp].tree or {}) do
    if allowed(t, node, era, corp) then
      local s = score(t, node)
      if s > 0 and (not bs or s > bs) then best, bs = node, s end
      if node.track and not fallback then fallback = node end
    elseif allowed(t, node, era) then
      local s = score(t, node)
      if s > 0 and (not ws or s > ws) then want, ws = node, s end
      if node.track and not want then want, ws = node, 0 end
    end
  end
  t.wants_lab = rd.gated(corp) and want and (not bs or ws > bs) and rd.lab_kind(corp, want.branch) or nil
  return best or fallback, best ~= nil
end

-- The lab a corporation wants built (the planner's research rule), nil when none.
function rd.wanted_lab(corp)
  local d = storage.corps and storage.corps[corp]
  if not d or d.withdrawing or not rd.gated(corp) then return nil end
  local t = rd.state(corp)
  pick(corp, t, player_era())
  return t.wants_lab
end

function rd.choose(corp)
  local d = storage.corps and storage.corps[corp]
  if not d or d.withdrawing then return end
  local t = rd.state(corp)
  prune(t.turned_back)
  prune(t.walls_met)
  -- (Was never pruned: the jammer's trigger only grew; the faction AI audit, 2026-10-23.)
  prune(t.mended or {})
  local node, called = pick(corp, t, player_era())
  if not node then return end
  local cost = cost_of(t, node)
  if t.fund < cost then
    t.saving = node.id
    return
  end
  t.fund = t.fund - cost
  t.saving = nil
  apply(corp, t, node)
  if rd.trace then
    rd.trace(corp, string.format("research: %s%s (%s, fund %d)", node.id,
      node.track and (" level " .. t.nodes[node.id]) or "", called and "called for" or "climbing", t.fund))
  end
  return node.id
end

function rd.tick(tick)
  if tick % LAB_TICKS == 777 % LAB_TICKS then
    for corp in pairs(shared.CORPS) do
      local d = storage.corps and storage.corps[corp]
      if d and not d.withdrawing then lab_income(corp) end
    end
  end
  local every = storage.rd_fast and 3600 or CHOICE_TICKS
  if tick % every ~= 1234 % every then return end
  for corp in pairs(shared.CORPS) do
    if storage.corps and storage.corps[corp] then rd.choose(corp) end
  end
end

-- Tests: a research history set outright ({weapons = {cat = level}, plate = {kind = plate}}).
-- The arena only (LP_ARENA_TECH=late): every track of the corporation's tree at its top level, damage and speed, as a corporation
-- at the end of its research fights. Returns the categories and modifiers set.
function rd.max_tracks(corp)
  local f = game.forces[shared.CORPS[corp].force]
  local set = {}
  for _, node in ipairs(shared.CORPS[corp].tree or {}) do
    for _, c in ipairs(node.track or {}) do
      local k = levels_of(node)
      local r = rd.track_at(corp, node.id, k)[c]
      if f then
        f.set_ammo_damage_modifier(c, math.max(f.get_ammo_damage_modifier(c), r[1]))
        f.set_gun_speed_modifier(c, math.max(f.get_gun_speed_modifier(c), r[2]))
      end
      set[c] = math.max(set[c] or 0, r[1])
    end
  end
  return set
end

function rd.set(corp, tech)
  local t = rd.state(corp)
  -- A node set outright takes effect as if bought (its units join the mix, its plates are worn).
  for id, k in pairs(tech.nodes or {}) do
    t.nodes[id] = k
    for _, node in ipairs(shared.CORPS[corp].tree or {}) do
      if node.id == id then
        if node.unit then t.units[node.unit.kind] = node.unit.weight end
        for kind, p in pairs(node.plates or {}) do t.plate[kind] = p end
      end
    end
  end
  local f = game.forces[shared.CORPS[corp].force]
  for c, k in pairs(tech.weapons or {}) do
    t.weapons[c] = k
    local owner = {}
    for _, node in ipairs(shared.CORPS[corp].tree or {}) do
      for _, cc in ipairs(node.track or {}) do if cc == c then owner = node end end
    end
    set_level(f, owner, c, k)
  end
  for kind, p in pairs(tech.plate or {}) do t.plate[kind] = p end
end

-- A corporation arriving in a world already far along (the player's era, the biters' evolution) comes with the
-- research such a world would have pushed it to: a fund of HISTORY_ERA a player era and HISTORY_EVO at full
-- evolution, spent at once on its tracks (to the era cap) and, past half evolution, on its armour against physical
-- damage (biters' jaws). Once, at its first landing (faction.arrive).
local HISTORY_ERA, HISTORY_EVO = 1500, 4000
function rd.history(corp, surface)
  local t = rd.state(corp)
  if t.history or storage.history_off then return end
  t.history = true
  local era = player_era()
  local evo = game.forces.enemy and game.forces.enemy.get_evolution_factor(surface) or 0
  t.fund = math.min(FUND_CAP, t.fund + HISTORY_ERA * era + HISTORY_EVO * evo)
  local bought = {}
  -- What the world calls for first: past half evolution, armour against biters' jaws, then what answers biters
  -- (railguns), then the other tracks. In tree order the tracks went first: on the player's nw (evolution 0.91) optics
  -- to five and railguns to three spent it all, and its troopers came without the armour they had (2026-10-25).
  local function rank(node)
    local biters = false
    for _, k in ipairs(node.trigger and node.trigger.killer or {}) do if k == "biter" then biters = true end end
    if evo >= 0.5 and node.plates and node.trigger and node.trigger.damage == "physical" then return 1 end
    if evo >= 0.5 and node.track and biters then return 2 end
    if node.track then return 3 end
    return nil
  end
  for _ = 1, 12 do
    local pickd, pr
    for _, node in ipairs(shared.CORPS[corp].tree or {}) do
      local r = rank(node)
      if r and (not pr or r < pr) and allowed(t, node, era) and t.fund >= cost_of(t, node) then pickd, pr = node, r end
    end
    if not pickd then break end
    t.fund = t.fund - cost_of(t, pickd)
    apply(corp, t, pickd)
    table.insert(bought, pickd.id)
  end
  if rd.trace and #bought > 0 then
    rd.trace(corp, string.format("arrives with history (era %d, evolution %.2f): %s; fund %d", era, evo,
      table.concat(bought, ", "), t.fund))
  end
  return bought
end

-- Every corporation's forces set again from the levels it holds (on_configuration_changed: a save from before the arms
-- race held +20% a level and no speed).
function rd.reapply()
  for corp, c in pairs(shared.CORPS) do
    local d = storage.corps and storage.corps[corp]
    local f = game.forces[c.force]
    if d and d.tech and f then
      for _, node in ipairs(c.tree or {}) do
        if node.track then
          for _, cat in ipairs(node.track) do set_level(f, node, cat, d.tech.weapons[cat] or 0) end
        end
      end
    end
  end
end

-- For stats and tests.
function rd.summary(corp)
  local t = rd.state(corp)
  local by = {}
  t.losses = losses_of(corp)
  for _, l in ipairs(t.losses) do by[l.damage .. ":" .. tostring(l.killer)] = (by[l.damage .. ":" .. tostring(l.killer)] or 0) + 1 end
  -- (Where each track stands against its cap, the era + 1: whether its fund or the player's era holds it back.)
  local era, tracks = player_era(), {}
  for _, node in ipairs(shared.CORPS[corp].tree or {}) do
    if node.track then tracks[node.id] = {level = t.nodes[node.id] or 0, cap = math.min(era + 1, levels_of(node)), top = levels_of(node)} end
  end
  return {tracks = tracks, era = era, served = branches_served(corp), lab_funded = t.lab_funded or 0,
    fund = t.fund, wants_lab = t.wants_lab, gated = rd.gated(corp), fielded = rd.mix(corp), salvaged = t.salvaged or 0, weapons = t.weapons, plate = t.plate, nodes = t.nodes, units = t.units, saving = t.saving, lost_by = by,
    turned_back = #t.turned_back, walls_met = #t.walls_met, bought = t.bought, strength = rd.strength(corp)}
end

return rd
