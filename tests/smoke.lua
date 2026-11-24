-- Nullgate's Cooldowns: smoke test of the whole addon with stand-in game API.
-- Logs in as a priest in a party with a druid, a warlock and a shaman, and drives casts from group
-- cast events and the combat log (with and without spell IDs), reports from players running the
-- addon, the list, whispering for a cooldown, sharing your own cooldowns, settings and /ncd check.
-- Run from the repository root:  lua tests/smoke.lua

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/smoke.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local repo = scriptDir:match("^(.*)[/\\][^/\\]*$") or "."
local folder = "NullgatesCooldowns-Forever"
local root = repo .. "/" .. folder .. "/"

local checks, failures = 0, 0
local function OK(cond, name)
    checks = checks + 1
    if not cond then failures = failures + 1; io.write("FAIL " .. name .. "\n") end
end

-- --- Stand-in game API ----------------------------------------------------------
local frames, printed, said, sent = {}, {}, {}, {}
local function NewFrame(kind, name, _, template)
    local f = { kind = kind, name = name, template = template, scripts = {}, attributes = {}, events = {}, shown = false }
    setmetatable(f, { __index = function(_, key) if type(key) == "string" and key:match("^%u") then return function() return nil end end end })
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:CreateTexture() return NewFrame("Texture") end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = NewFrame
SlashCmdList = {}
UIParent = NewFrame("Frame", "UIParent")
GameTooltip = NewFrame("GameTooltip", "GameTooltip")
UISpecialFrames = {}
RAID_CLASS_COLORS = {}
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
print = function(text) printed[#printed + 1] = tostring(text) end
function SendChatMessage(text, channel, _, target) said[#said + 1] = channel .. (target and (" " .. target) or "") .. ": " .. text end
local function Printed(fragment)
    for _, line in ipairs(printed) do if line:find(fragment, 1, true) then return true end end
    return false
end

local now = 1000
local units = {
    player = { name = "Me", class = "PRIEST", level = 60 },
    party1 = { name = "Leafy", class = "DRUID", level = 60 },
    party2 = { name = "Warly", class = "WARLOCK", level = 60 },
    party3 = { name = "Totem", class = "SHAMAN", level = 60 },
}
local far = {}
function UnitExists(u) return units[u] ~= nil end
function UnitClass(u) return units[u].class, units[u].class end
function UnitName(u) return units[u] and units[u].name end
function UnitLevel(u) return units[u].level end
function UnitIsUnit(a, b) return a == b end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
function UnitInRange(u) return not far[u], true end
function UnitIsPlayer() return true end
function UnitIsFriend() return true end
function IsInRaid() return false end
function GetNumSubgroupMembers() return 3 end
function GetTime() return now end
function GetBuildInfo() return "1.60.1", "70532", "Nov 2026", 16001 end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function Flush() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
               SendAddonMessage = function(prefix, msg, channel) sent[#sent + 1] = { prefix = prefix, msg = msg, channel = channel } end }

local data = {}
assert(loadfile(root .. "Data/Cooldowns.lua"))(folder, data)
local names = {}
local NAMES = { rebirth = "Rebirth", soulstone = "Soulstone Resurrection", reincarnation = "Reincarnation", innervate = "Innervate",
    fearward = "Fear Ward", powerinfusion = "Power Infusion", manatide = "Mana Tide Totem" }
for _, cd in ipairs(data.COOLDOWNS) do for _, id in ipairs(cd.spells) do names[id] = NAMES[cd.key] or cd.key end end
C_Spell = {
    GetSpellName = function(id) return names[id] end,
    GetSpellTexture = function(id) return "tex" .. id end,
    GetSpellCooldown = function(id) if names[id] == "Fear Ward" then return { startTime = now - 30, duration = 180 } end return { startTime = 0, duration = 0 } end,
}
local fearWard
for _, cd in ipairs(data.COOLDOWNS) do if cd.key == "fearward" then fearWard = cd end end
C_SpellBook = { IsSpellKnown = function(id) return id == fearWard.spells[#fearWard.spells] end }
C_Item = { GetItemInfo = function(id) return "Major Soulstone" end }
local cl = {}
function CombatLogGetCurrentEventInfo() return unpack(cl) end
unpack = unpack or table.unpack

-- --- Load the files in .toc order -----------------------------------------------
local ns = {}
local toc = assert(io.open(root .. folder .. ".toc", "r")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        assert(loadfile(root .. line:gsub("\\", "/")))(folder, ns)
    end
end
local core
for _, f in ipairs(frames) do if f.events.CHAT_MSG_ADDON and f.events.GROUP_ROSTER_UPDATE then core = f end end
local function Fire(event, ...) core.scripts.OnEvent(core, event, ...) end
Fire("ADDON_LOADED", folder)
local db = NullgatesCooldownsDB
OK(db.show.resurrection and not db.listSelf and not db.announce, "saved data gets its defaults")
OK(SLASH_NULLGATESCOOLDOWNS1 == "/ncd" and SLASH_NULLGATESCOOLDOWNS2 == "/cooldowns", "slash commands /ncd and /cooldowns")

-- --- Login and sharing our own cooldowns ------------------------------------------------------
Fire("PLAYER_LOGIN")
Flush()
OK(sent[1] and sent[1].prefix == "NGCool" and sent[1].msg == "C;fearward=150", "we share our Fear Ward (150 seconds left) with the party")

-- --- The list ------------------------------------------------------------------------------------
SlashCmdList.NULLGATESCOOLDOWNS("")
OK(NullgatesCooldownsList and NullgatesCooldownsList.shown and db.shown, "/ncd shows the list")
local function Find(player, key)
    for _, e in ipairs(ns.List.Compute(now)) do
        if e.member and e.member.name == player and e.cd.key == key then return e end
    end
end
OK(Find("Leafy", "rebirth") and Find("Leafy", "rebirth").status == "ready", "the druid's Rebirth: ready")
OK(Find("Warly", "soulstone") and Find("Totem", "reincarnation"), "Soulstone and Reincarnation are listed (the Cooldown Manager doesn't have them)")
OK(Find("Totem", "manatide") == nil, "Mana Tide (a talent) isn't listed until seen")
OK(Find("Me", "fearward") == nil, "our own cooldowns aren't listed (the Cooldown Manager shows them)")

-- --- A cast seen through the group cast event ---------------------------------------------------
local rebirth = ns.Tracker.Cooldown("rebirth")
Fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "guid", rebirth.spells[#rebirth.spells])
now = now + 60
local e = Find("Leafy", "rebirth")
OK(e.status == "cooldown" and e.left == 1740, "Rebirth used a minute ago: 29 minutes left")

-- --- The combat log without spell IDs (Classic style) -------------------------------------------
db.announce = true
cl = { now, "SPELL_AURA_APPLIED", false, "guid", "Warly-Realm", 0, 0, "guid2", "Leafy-Realm", 0, 0, 0, "Soulstone Resurrection" }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
OK(Find("Warly", "soulstone").status == "cooldown", "a Soulstone landing (by name, no spell ID) starts the warlock's cooldown")
OK(Printed("Warly used Major Soulstone on Leafy."), "and the announcement says who got it")
cl = { now, "SPELL_CAST_SUCCESS", false, "guid", "Stranger", 0, 0, "", "", 0, 0, 0, "Rebirth" }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
OK(ns.Tracker.state.Stranger == nil, "casts by people outside the group are ignored")

-- --- Talent seen ----------------------------------------------------------------------------------
local manatide = ns.Tracker.Cooldown("manatide")
cl = { now, "SPELL_CAST_SUCCESS", false, "guid", "Totem", 0, 0, "", "", 0, 0, manatide.spells[#manatide.spells], "Mana Tide Totem" }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
OK(Find("Totem", "manatide") and Find("Totem", "manatide").status == "cooldown", "Mana Tide seen: now listed, on cooldown")

-- --- A report from a player running the addon -------------------------------------------------------
sent = {}
Fire("CHAT_MSG_ADDON", "NGCool", "C;innervate=200,rebirth=0", "PARTY", "Leafy-Realm")
Flush()
OK(Find("Leafy", "rebirth").status == "ready" and Find("Leafy", "innervate").left == 200, "the druid's report: Rebirth ready, Innervate 200 seconds")
OK(#sent == 1, "a newcomer gets our report back")

-- --- Unknown, not ready ---------------------------------------------------------------------------
far.party3 = true
OK(Find("Totem", "reincarnation").status == "unknown", "out of range with nothing known: unknown")

-- --- Click to ask ----------------------------------------------------------------------------------
ns.List.Draw()
local row
for _, f in ipairs(frames) do
    if f.entry and f.entry.member.name == "Leafy" and f.entry.cd.key == "rebirth" then row = f end
end
OK(row ~= nil, "the list has a row for the druid's Rebirth")
row.scripts.OnClick(row)
OK(said[1] == "WHISPER Leafy: Rebirth on Me, please.", "clicking a ready cooldown whispers the player")

-- --- Leaving the group ------------------------------------------------------------------------------
units.party1 = nil
GetNumSubgroupMembers = function() return 2 end
Fire("GROUP_ROSTER_UPDATE")
OK(ns.Tracker.state.Leafy == nil, "a player who leaves is forgotten")

-- --- Settings and /ncd check ---------------------------------------------------------------------------
SlashCmdList.NULLGATESCOOLDOWNS("config")
OK(NullgatesCooldownsOptions and NullgatesCooldownsOptions.shown, "/ncd config opens the settings")
SlashCmdList.NULLGATESCOOLDOWNS("check")
local log = table.concat(db.check or {}, "\n")
OK(log:find("CombatLogGetCurrentEventInfo=yes", 1, true), "check reports which calls exist")
OK(log:find("your cooldowns (as reported to others): fearward=", 1, true), "check reports our own cooldowns")

-- --- Names with a blanked realm ----------------------------------------------------------------
do
    local real = Ambiguate
    Ambiguate = function(name) return name end -- as if the game left "Name-" alone
    OK(ns.BareName("Brightmend-") == "Brightmend" and ns.BareName("Brightmend-Realm") == "Brightmend" and ns.BareName("Brightmend") == "Brightmend",
        "names lose a blank or full realm part")
    Ambiguate = real
end

io.write(string.format("smoke: %d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end
