-- Nullgate's Cooldowns: what's known about each player's cooldowns. Two sources: players running the
-- addon report their own (exact, including talent reductions), and casts seen on group members start
-- the base cooldown. A report is trusted over a seen cast. Pure: times are passed in.
local _, ns = ...

local Tracker = {}
ns.Tracker = Tracker

local state = {}  -- [player] = { [key] = { readyAt =, source = "sync" | "seen", at = } }
local known = {}  -- [player] = set of keys a player running the addon reported knowing
local talents = {} -- [player] = set of talent cooldowns seen used
Tracker.state, Tracker.known = state, known

local byKey, bySpell, byName
function Tracker.Index()
    if not byKey then
        byKey, bySpell = {}, {}
        for _, cd in ipairs(ns.COOLDOWNS) do
            byKey[cd.key] = cd
            for _, id in ipairs(cd.spells) do bySpell[id] = cd end
        end
    end
    return byKey, bySpell
end

function Tracker.Cooldown(key) return (Tracker.Index())[key] end
function Tracker.FromSpell(spellID) return select(2, Tracker.Index())[spellID] end

-- The combat log on Classic clients may give a spell name instead of an ID; names map to keys too.
function Tracker.SetNames(nameOf)
    byName = {}
    for _, cd in ipairs(ns.COOLDOWNS) do
        for _, id in ipairs(cd.spells) do
            local n = nameOf(id)
            if n then byName[n] = cd end
        end
    end
end
function Tracker.FromName(name) return byName and byName[name] end

-- A cast seen: the base cooldown starts now (unless a fresher report says otherwise).
function Tracker.Seen(player, key, now)
    local cd = Tracker.Cooldown(key)
    if not cd then return end
    state[player] = state[player] or {}
    local old = state[player][key]
    if old and old.source == "sync" and now - old.at < 5 then return end -- a report just came in
    state[player][key] = { readyAt = now + cd.cooldown, source = "seen", at = now }
    if cd.talent then
        talents[player] = talents[player] or {}
        talents[player][key] = true
    end
end

-- A report from a player running the addon: their known cooldowns and seconds left on each.
function Tracker.Report(player, remaining, now)
    known[player] = {}
    state[player] = state[player] or {}
    for key, secs in pairs(remaining) do
        known[player][key] = true
        state[player][key] = { readyAt = now + secs, source = "sync", at = now }
    end
end

-- Whether a player should be listed for a cooldown: their class and level fit; a talent cooldown only
-- once they've reported it or been seen using it; and a player whose addon reports their cooldowns
-- is listed for exactly what they report.
function Tracker.Has(member, cd)
    if member.class ~= cd.class or (member.level or 0) < (cd.level or 0) then return false end
    local reported, seen = known[member.name], talents[member.name]
    if reported and reported[cd.key] then return true end
    if cd.talent then return (seen and seen[cd.key]) or false end
    return not (reported and next(reported))
end

-- "ready", "cooldown" or "unknown" (out of range, offline or dead), and seconds left.
function Tracker.Status(member, cd, now)
    local entry = state[member.name] and state[member.name][cd.key]
    local left = entry and math.max(0, entry.readyAt - now) or 0
    if left > 0 then return "cooldown", left end
    if not member.reachable then return "unknown", 0 end
    return "ready", 0
end

-- --- Messages ------------------------------------------------------------------------
-- Report: "C;rebirth=0,innervate=245" (every tracked cooldown the sender knows, seconds left).

function Tracker.Encode(remaining)
    local parts = {}
    for key, secs in pairs(remaining) do parts[#parts + 1] = key .. "=" .. math.floor(secs + 0.5) end
    table.sort(parts)
    return "C;" .. table.concat(parts, ",")
end

function Tracker.Decode(message)
    if type(message) ~= "string" or message:sub(1, 2) ~= "C;" then return nil end
    local remaining = {}
    for key, secs in message:sub(3):gmatch("(%a+)=(%d+)") do
        if Tracker.Cooldown(key) then remaining[key] = tonumber(secs) end
    end
    return remaining
end

function Tracker.Forget(player)
    state[player], known[player], talents[player] = nil, nil, nil
end

-- 754 -> "12m", 45 -> "45s".
function Tracker.Short(seconds)
    if seconds >= 60 then return math.ceil(seconds / 60) .. "m" end
    return math.ceil(seconds) .. "s"
end
