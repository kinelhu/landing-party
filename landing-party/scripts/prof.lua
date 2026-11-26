-- Named spans for the spike guard (scripts/spikes.sh, control.lua's TICKERS): a module times a part of its tick with
--   local sp = prof.start("farm.send") ... prof.stop(sp)
-- Off (storage.spike_prof unset) start returns nil and stop does nothing: a field read a call. On, the tick's spans are
-- written after its modules' times. Never read back by the game: timing alone, nothing decided on it.
local prof = {}
local done = {}

function prof.start(name)
  if not storage.spike_prof then return nil end
  return {name, helpers.create_profiler()}
end

function prof.stop(h)
  if not h then return end
  h[2].stop()
  done[#done + 1] = h
end

-- The tick's spans as localised-string groups (control.lua appends them to its line), and cleared.
function prof.flush(out)
  local group
  for _, h in ipairs(done) do
    if #out >= 19 then break end
    if not group or #group >= 19 then group = {""}; out[#out + 1] = group end
    group[#group + 1] = " " .. h[1] .. "="
    group[#group + 1] = h[2]
  end
  done = {}
end

return prof
