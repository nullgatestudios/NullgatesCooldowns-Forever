-- Nullgate's Cooldowns: tests for the cooldown data and the tracker.
-- Run from the repository root:  lua tests/run.lua   (Lua 5.1 or newer)

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/run.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local root = (scriptDir:match("^(.*)[/\\][^/\\]*$") or ".") .. "/NullgatesCooldowns-Forever/"

local ns = {}
local function Load(file) assert(loadfile(root .. file), "cannot load " .. file)("NullgatesCooldowns-Forever", ns) end
Load("Data/Cooldowns.lua")
Load("Tracker.lua")
local T = ns.Tracker

local checks, failures = 0, 0
local function EQ(got, want, name)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %s: expected %s, got %s", name, tostring(want), tostring(got)))
    end
end

-- --- The data -------------------------------------------------------------------------
EQ(type(ns.COOLDOWN_DATA_BUILD), "string", "the data names its client build")
for _, cd in ipairs(ns.COOLDOWNS) do
    EQ(#cd.spells >= 1 and cd.cooldown > 0, true, cd.key .. " is complete")
end
EQ(T.Cooldown("rebirth").cooldown, 1800, "Rebirth: 30 minutes")
EQ(T.Cooldown("layonhands").cooldown, 1200, "Forever: Lay on Hands is 20 minutes")
EQ(T.Cooldown("shieldwall").cooldown, 900, "Forever: Shield Wall is 15 minutes")
EQ(T.Cooldown("rebirth").cdm, true, "Rebirth is in the game's Cooldown Manager")
EQ(T.Cooldown("reincarnation").cdm, false, "Reincarnation isn't, so this addon adds it")
EQ(#T.Cooldown("soulstone").items, 5, "Soulstones: five items")
EQ(T.FromSpell(20765).key, "soulstone", "a Soulstone buff spell counts as a Soulstone use")
EQ(T.FromSpell(T.Cooldown("rebirth").spells[3]).key, "rebirth", "every rank counts")

-- --- Who has what ------------------------------------------------------------------------
local druid = { name = "Leafy", class = "DRUID", level = 60, reachable = true }
local lowDruid = { name = "Sprout", class = "DRUID", level = 15, reachable = true }
local shaman = { name = "Totem", class = "SHAMAN", level = 60, reachable = true }
EQ(T.Has(druid, T.Cooldown("rebirth")), true, "a level 60 druid has Rebirth")
EQ(T.Has(lowDruid, T.Cooldown("rebirth")), false, "a level 15 druid doesn't (learned at 20)")
EQ(T.Has(druid, T.Cooldown("layonhands")), false, "a druid has no Lay on Hands")
EQ(T.Has(shaman, T.Cooldown("manatide")), false, "Mana Tide is a talent: not shown until seen")
T.Seen("Totem", "manatide", 100)
EQ(T.Has(shaman, T.Cooldown("manatide")), true, "once seen, it's shown")
EQ(T.Has(shaman, T.Cooldown("reincarnation")), true, "and seeing a talent doesn't hide the shaman's other cooldowns")

-- --- Status --------------------------------------------------------------------------------
local status, left = T.Status(druid, T.Cooldown("rebirth"), 100)
EQ(status, "ready", "never seen used: ready")
T.Seen("Leafy", "rebirth", 100)
status, left = T.Status(druid, T.Cooldown("rebirth"), 160)
EQ(status == "cooldown" and left == 1740, true, "seen a minute ago: 29 minutes left")
EQ(T.Status(druid, T.Cooldown("rebirth"), 2000), "ready", "after 30 minutes: ready")
local far = { name = "Faraway", class = "DRUID", level = 60, reachable = false }
EQ(T.Status(far, T.Cooldown("rebirth"), 100), "unknown", "out of range and nothing known: unknown, never ready")
T.Seen("Faraway", "rebirth", 100)
EQ(T.Status(far, T.Cooldown("rebirth"), 200), "cooldown", "but a cooldown seen is still shown")

-- --- Reports beat seen casts ---------------------------------------------------------------
T.Report("Leafy", { rebirth = 600, innervate = 0 }, 1000)
status, left = T.Status(druid, T.Cooldown("rebirth"), 1000)
EQ(left, 600, "a report sets the exact time left (talents included)")
T.Seen("Leafy", "rebirth", 1002)
EQ(select(2, T.Status(druid, T.Cooldown("rebirth"), 1002)), 598, "a cast seen right after a report doesn't overwrite it")
T.Report("Leafy", { innervate = 0 }, 1100)
EQ(T.Has(druid, T.Cooldown("rebirth")), false, "a player running the addon who doesn't report Rebirth doesn't have it")
T.Forget("Leafy")
EQ(T.Has(druid, T.Cooldown("rebirth")), true, "forgotten: back to class and level")

-- --- Messages --------------------------------------------------------------------------------
local msg = T.Encode({ rebirth = 0, innervate = 244.6 })
EQ(msg, "C;innervate=245,rebirth=0", "the report message")
local back = T.Decode(msg)
EQ(back.innervate == 245 and back.rebirth == 0, true, "decodes back")
EQ(next(T.Decode("C;madeup=5")), nil, "unknown cooldowns are dropped")
EQ(T.Decode("H;k=x"), nil, "other messages are ignored")
EQ(T.Short(754), "13m", "minutes round up")
EQ(T.Short(45), "45s", "seconds")

print(string.format("%d checks, %d failure(s)", checks, failures))
if failures > 0 then os.exit(1) end
