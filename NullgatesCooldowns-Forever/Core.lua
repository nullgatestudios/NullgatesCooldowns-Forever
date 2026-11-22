-- Nullgate's Cooldowns: saved data, the group, reading casts (group cast events and the combat log),
-- sharing your own cooldowns with other players running the addon, and slash commands.
-- Your own cooldowns are shown by the game's Cooldown Manager; this addon shows everyone else's.
local addonName, ns = ...

local L = ns.L
ns.PREFIX = "NGCool"

ns.DEFAULTS = {
    locked = false,
    scale = 1,
    shown = false,
    listSelf = false,
    announce = false,   -- a chat line for you when someone uses Rebirth or a Soulstone
    show = { resurrection = true, mana = true, defensive = true, utility = true },
    language = "auto",
}

local function Merge(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            Merge(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.Print(text)
    print("|cff00c0ffCooldowns:|r " .. tostring(text))
end

function ns.Me()
    return UnitName("player")
end

function ns.SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID)) or nil
end

-- A cooldown's name in the game's language.
function ns.CooldownName(cd)
    if cd.key == "soulstone" then
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        return (info and info(cd.items[#cd.items])) or L["Soulstone"]
    end
    return ns.SpellName(cd.spells[#cd.spells]) or cd.key
end

-- --- The group --------------------------------------------------------------------------

local unitByName = {}
function ns.Roster()
    local list = {}
    wipe(unitByName)
    local function Add(unit)
        if not UnitExists(unit) then return end
        local _, class = UnitClass(unit)
        local reachable = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
        if reachable and not UnitIsUnit(unit, "player") then
            -- Forever can return the range as secret values, which can't be tested: then it's unknown.
            local inRange, checked = UnitInRange(unit)
            local secret = issecretvalue and (issecretvalue(inRange) or issecretvalue(checked))
            if not secret and checked and not inRange then reachable = false end
        end
        local name = UnitName(unit)
        unitByName[name] = unit
        list[#list + 1] = { unit = unit, name = name, class = class, level = UnitLevel(unit), reachable = reachable }
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do Add("raid" .. i) end
    else
        Add("player")
        for i = 1, GetNumSubgroupMembers() do Add("party" .. i) end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

local function InGroup(name)
    return name and unitByName[name] ~= nil
end

-- --- Casts --------------------------------------------------------------------------------

local function Used(name, cd, targetName)
    if not InGroup(name) then return end
    ns.Tracker.Seen(name, cd.key, GetTime())
    if ns.db.announce and cd.type == "resurrection" and name ~= ns.Me() then
        ns.Print(string.format(L["%s used %s%s."], name, ns.CooldownName(cd), targetName and (" " .. string.format(L["on %s"], targetName)) or ""))
    end
    ns.List.Draw()
end

local function OnCombatLog()
    local _, subevent, _, _, sourceName, _, _, _, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if subevent ~= "SPELL_CAST_SUCCESS" and subevent ~= "SPELL_AURA_APPLIED" then return end
    local cd = (spellID and spellID ~= 0 and ns.Tracker.FromSpell(spellID)) or ns.Tracker.FromName(spellName)
    if not cd then return end
    -- A Soulstone is seen as its buff landing on the target; everything else as the cast.
    if (cd.key == "soulstone") ~= (subevent == "SPELL_AURA_APPLIED") then return end
    local name = sourceName and (Ambiguate and Ambiguate(sourceName, "none") or sourceName)
    Used(name, cd, destName and (Ambiguate and Ambiguate(destName, "none") or destName))
end

-- --- Sharing your own cooldowns -----------------------------------------------------------

local function SpellCooldownLeft(spellID, now)
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(spellID)
    end
    if not start or not duration or duration <= 1.5 then return 0 end
    return math.max(0, start + duration - now)
end

local function ItemCooldownLeft(itemID, now)
    local cd = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not cd then return 0 end
    local start, duration = cd(itemID)
    if not start or not duration or duration <= 1.5 then return 0 end
    return math.max(0, start + duration - now)
end

local function IsKnown(spellID)
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown or IsPlayerSpell
    return known ~= nil and known(spellID) == true
end

-- Your tracked cooldowns: [key] = seconds left, for the ones you know.
function ns.MyCooldowns()
    local now, out = GetTime(), {}
    local _, class = UnitClass("player")
    for _, cd in ipairs(ns.COOLDOWNS) do
        if cd.class == class then
            if cd.key == "soulstone" then
                local left = 0
                for _, item in ipairs(cd.items) do left = math.max(left, ItemCooldownLeft(item, now)) end
                if UnitLevel("player") >= cd.level then out[cd.key] = left end
            else
                for i = #cd.spells, 1, -1 do
                    if IsKnown(cd.spells[i]) then
                        out[cd.key] = SpellCooldownLeft(cd.spells[i], now)
                        break
                    end
                end
            end
        end
    end
    return out
end

local function Channel()
    if IsInRaid() then return "RAID" end
    if GetNumSubgroupMembers() > 0 then return "PARTY" end
end

local reportQueued = false
function ns.Report()
    if reportQueued then return end
    reportQueued = true
    C_Timer.After(2, function()
        reportQueued = false
        local channel, mine = Channel(), ns.MyCooldowns()
        if channel and next(mine) and C_ChatInfo and C_ChatInfo.SendAddonMessage then
            C_ChatInfo.SendAddonMessage(ns.PREFIX, ns.Tracker.Encode(mine), channel)
        end
    end)
end

local heard = {}
local function OnAddonMessage(prefix, message, _, sender)
    if prefix ~= ns.PREFIX or not sender then return end
    local name = Ambiguate and Ambiguate(sender, "none") or sender
    if name == ns.Me() then return end
    local remaining = ns.Tracker.Decode(message)
    if remaining then
        ns.Tracker.Report(name, remaining, GetTime())
        if not heard[name] then
            heard[name] = true
            ns.Report() -- answer a newcomer so they know ours
        end
        ns.List.Draw()
    end
end

-- --- Events --------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            if type(NullgatesCooldownsDB) ~= "table" then NullgatesCooldownsDB = {} end
            Merge(NullgatesCooldownsDB, ns.DEFAULTS)
            ns.db = NullgatesCooldownsDB
            ns.SetLanguage(ns.db.language)
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX) end
            ns.Tracker.SetNames(ns.SpellName)
        end
        if arg1 == addonName or arg1 == "NullgatesAddonConfig-Forever" then ns.Options.RegisterHub() end
    elseif event == "PLAYER_LOGIN" then
        ns.Roster()
        if ns.db.shown then ns.List.Show() end
        C_Timer.NewTicker(1, ns.List.Draw)
        ns.Report()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        local cd = ns.Tracker.FromSpell(spellID)
        if cd and cd.key ~= "soulstone" and unit and (unit:match("^party%d$") or unit:match("^raid%d+$")) then
            Used(UnitName(unit), cd)
        end
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
        ns.Report()
    elseif event == "GROUP_ROSTER_UPDATE" then
        local members = ns.Roster()
        local present = {}
        for _, m in ipairs(members) do present[m.name] = true end
        for name in pairs(ns.Tracker.state) do if not present[name] then ns.Tracker.Forget(name); heard[name] = nil end end
        ns.Report()
        ns.List.Draw()
    end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_SPELLCAST_SUCCEEDED",
    "CHAT_MSG_ADDON", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "GROUP_ROSTER_UPDATE" }) do
    events:RegisterEvent(event)
end

local function Help()
    ns.Print(L["commands:"])
    print("  /ncd - " .. L["show or hide the cooldown list"])
    print("  /ncd config - " .. L["open the settings"])
    print("  /ncd lock | unlock - " .. L["lock or unlock the list"])
    print("  /ncd check - " .. L["test what the addon needs in this client (results are saved)"])
end

SLASH_NULLGATESCOOLDOWNS1 = "/ncd"
SLASH_NULLGATESCOOLDOWNS2 = "/cooldowns"
SlashCmdList["NULLGATESCOOLDOWNS"] = function(msg)
    local command = string.lower((msg or ""):match("^%s*(%S*)") or "")
    if command == "" then
        ns.List.Toggle()
    elseif command == "config" or command == "options" then
        ns.Options.Open()
    elseif command == "check" then
        ns.Check.Run()
    elseif command == "lock" or command == "unlock" then
        ns.db.locked = command == "lock"
    else
        Help()
    end
end
