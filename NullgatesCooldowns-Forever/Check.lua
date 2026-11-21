-- Nullgate's Cooldowns: /ncd check, the in-game self test (phase 0 of PLAN.md).
-- Every result goes to chat and to NullgatesCooldownsDB.check, so the log can be copied from
-- WTF\Account\<account>\<realm>\<character>\SavedVariables\NullgatesCooldowns-Forever.lua.
--
--   1. Which calls exist (including the Cooldown Manager's C_CooldownViewer), your own tracked
--      cooldowns as you'd report them, the group and what the addon knows about each member.
--   2. While the window is open: every tracked cast seen, and from which source (group cast event
--      or combat log, with or without a spell ID), to confirm what Forever gives addons.
local _, ns = ...

local Check = {}
ns.Check = Check

local LOG_LIMIT = 400
local panel

local function Log(text)
    local db = ns.db
    if db then
        db.check = db.check or {}
        if #db.check >= LOG_LIMIT then table.remove(db.check, 1) end
        db.check[#db.check + 1] = text
    end
    print("|cff00c0ffNullgate's Cooldowns check:|r " .. text)
end
Check.Log = Log

local function Exists(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return false end
        value = value[part]
    end
    return type(value) == "function" or (type(value) == "table" and path == "C_CooldownViewer")
end

local function StaticChecks()
    local _, class = UnitClass("player")
    Log(string.format("client %s, build %s, interface %s; class %s, level %s; data build %s",
        tostring(GetBuildInfo and select(1, GetBuildInfo())), tostring(GetBuildInfo and select(2, GetBuildInfo())),
        tostring(GetBuildInfo and select(4, GetBuildInfo())), tostring(class), tostring(UnitLevel("player")),
        tostring(ns.COOLDOWN_DATA_BUILD)))
    local calls = {}
    for _, name in ipairs({ "C_CooldownViewer", "C_Spell.GetSpellCooldown", "GetSpellCooldown", "C_Container.GetItemCooldown",
        "CombatLogGetCurrentEventInfo", "C_ChatInfo.SendAddonMessage", "UnitInRange" }) do
        calls[#calls + 1] = name .. "=" .. (Exists(name) and "yes" or "no")
    end
    Log("calls: " .. table.concat(calls, " "))
    local mine = {}
    for key, left in pairs(ns.MyCooldowns()) do mine[#mine + 1] = key .. "=" .. math.floor(left) end
    table.sort(mine)
    Log("your cooldowns (as reported to others): " .. (#mine > 0 and table.concat(mine, ", ") or "none tracked for your class"))
    local now = GetTime()
    for _, m in ipairs(ns.Roster()) do
        local parts = {}
        for _, cd in ipairs(ns.COOLDOWNS) do
            if ns.Tracker.Has(m, cd) then
                local status, left = ns.Tracker.Status(m, cd, now)
                parts[#parts + 1] = cd.key .. " " .. status .. (left > 0 and (" " .. math.floor(left)) or "")
            end
        end
        Log(string.format("%s (%s %s, reachable %s, reports %s): %s", tostring(m.name), tostring(m.class), tostring(m.level),
            tostring(m.reachable), ns.Tracker.known[m.name] and "yes" or "no", #parts > 0 and table.concat(parts, "; ") or "nothing tracked"))
    end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "NullgatesCooldownsCheck", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(300, 110)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    local title = "Cooldowns check"
    if type(panel.SetTitle) == "function" then panel:SetTitle(title)
    elseif type(panel.TitleText) == "table" then panel.TitleText:SetText(title) end
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOP", panel, "TOP", 0, -36)
    note:SetWidth(270)
    note:SetText("Keep this window open while group members use tracked cooldowns (Rebirth, Innervate, Shield Wall...). Each one seen goes to chat and is saved.")
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
watcher:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
watcher:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if not (panel and panel:IsShown()) then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local cd = ns.Tracker.FromSpell(spellID)
        if cd then Log(string.format("cast event: %s (%s) used %s (%s)", tostring(UnitName(unit)), tostring(unit), cd.key, tostring(spellID))) end
    else
        local _, subevent, _, _, sourceName, _, _, _, destName, _, _, id, name = CombatLogGetCurrentEventInfo()
        local cd = (id and id ~= 0 and ns.Tracker.FromSpell(id)) or ns.Tracker.FromName(name)
        if cd and (subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED") then
            Log(string.format("combat log: %s %s by %s on %s (spell ID %s, name %s)", subevent, cd.key, tostring(sourceName),
                tostring(destName), tostring(id), tostring(name)))
        end
    end
end)

function Check.Run()
    if ns.db then ns.db.check = {} end
    StaticChecks()
    if not panel then BuildPanel() end
    panel:Show()
end
