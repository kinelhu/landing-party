-- Cargo pods (Space Age; the user, 2026-10-18: "I think it's okay to rely on space age"): a corporation's landing
-- comes down from orbit. A pod made by script descends to a spot exactly (a spike: 399 ticks, 6.65 s, leaving its
-- remnants); the landing waits for it (faction's landing jobs) and settles where it touched down.
-- A leaf: it reads storage only.
local pods = {}
-- What a pod carries is handled where it lands: pods.handlers[payload.kind](payload, surface, position), registered by the
-- module that sends it (war: a relief drop).
pods.handlers = {}

-- A pod of `force` descending to `pos` exactly, carrying `payload` (optional); its unit number, or nil.
function pods.send(surface, pos, force, payload)
  local ok, pod = pcall(function()
    local p = surface.create_entity{name = "cargo-pod", position = pos, force = force}
    p.cargo_pod_destination = {type = defines.cargo_destination.surface, surface = surface, position = pos,
      land_at_exact_position = true}
    p.force_finish_ascending()
    return p
  end)
  if not ok or not pod or not pod.valid then return nil end
  storage.pods = storage.pods or {}
  storage.pods[pod.unit_number] = {sent = game.tick, payload = payload}
  return pod.unit_number
end

-- The engine's event: the pod touched down. Its remnants go (the landing takes the ground).
function pods.on_landed(e)
  local pod = e.cargo_pod
  if not (pod and pod.valid and storage.pods and storage.pods[pod.unit_number]) then return end
  local p = storage.pods[pod.unit_number]
  p.landed = game.tick
  p.pos = {pod.position.x, pod.position.y}
  p.surface = pod.surface.index
  local h = p.payload and pods.handlers[p.payload.kind]
  if h then h(p.payload, pod.surface, pod.position) end
end

-- Whether pod `n` has landed (or is gone).
function pods.down(surface, n)
  local p = storage.pods and storage.pods[n]
  return not p or p.landed ~= nil
end

-- What landed pods left goes once it is there (the remnants come a moment after the touchdown, and were all still
-- there at the end: podland), escorts' too, CLEAR_AFTER after each touchdown.
local CLEAR_AFTER = 3 * 60
function pods.tick(tick)
  if tick % 60 ~= 41 or not storage.pods then return end
  for n, p in pairs(storage.pods) do
    if p.landed and tick - p.landed >= CLEAR_AFTER then
      local s = game.surfaces[p.surface or 1]
      if s and p.pos then
        for _, r in pairs(s.find_entities_filtered{position = p.pos, radius = 4, name = {"cargo-pod-container-remnants",
          "cargo-pod-container"}}) do
          if r.valid then r.destroy() end
        end
      end
      storage.pods[n] = nil
    elseif not p.landed and tick - p.sent > 60 * 60 then
      storage.pods[n] = nil
    end
  end
end

return pods
