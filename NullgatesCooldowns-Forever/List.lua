-- Nullgate's Cooldowns: the group cooldown list. One row per player and cooldown, grouped by type
-- (resurrection, mana, defensive, utility): ready (green), minutes left (yellow) or unknown (grey).
-- Click a ready row to whisper that player for it.
local _, ns = ...

local L = ns.L
local List = {}
ns.List = List

local ROW_H, WIDTH = 16, 250
local TYPES = { "resurrection", "mana", "defensive", "utility" }
local frame
local rows = {}

function List.TypeName(kind)
    return (kind == "resurrection" and L["Resurrection"]) or (kind == "mana" and L["Mana"]) or (kind == "defensive" and L["Defensive"])
        or (kind == "utility" and L["Utility"]) or kind
end

-- The rows to show: { heading = text } or { member, cd, status, left }.
function List.Compute(now)
    local members = ns.Roster()
    local out = {}
    for _, kind in ipairs(TYPES) do
        if ns.db.show[kind] then
            local entries = {}
            for _, cd in ipairs(ns.COOLDOWNS) do
                if cd.type == kind then
                    for _, m in ipairs(members) do
                        if (m.name ~= ns.Me() or ns.db.listSelf) and ns.Tracker.Has(m, cd) then
                            local status, left = ns.Tracker.Status(m, cd, now)
                            entries[#entries + 1] = { member = m, cd = cd, status = status, left = left }
                        end
                    end
                end
            end
            if #entries > 0 then
                out[#out + 1] = { heading = List.TypeName(kind) }
                for _, e in ipairs(entries) do out[#out + 1] = e end
            end
        end
    end
    return out
end

-- The whisper asking for a cooldown: "Rebirth on Bob, please" (your friendly target, or you).
function List.RequestText(cd)
    local target = (UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target")) and UnitName("target") or ns.Me()
    return string.format(L["%s on %s, please."], ns.CooldownName(cd), target)
end

local function Build()
    frame = CreateFrame("Frame", "NullgatesCooldownsList", UIParent, "BasicFrameTemplateWithInset")
    frame:SetFrameStrata("DIALOG") -- above unit frames, nameplates and bags
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not ns.db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.point = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    local p = ns.db.point
    if p and p.point then frame:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
    else frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80) end
    frame:SetScale(ns.db.scale or 1)
    if type(frame.SetTitle) == "function" then frame:SetTitle(L["Group cooldowns"])
    elseif type(frame.TitleText) == "table" then frame.TitleText:SetText(L["Group cooldowns"]) end
    frame.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.empty:SetPoint("TOP", frame, "TOP", 0, -36)
    frame.empty:SetWidth(WIDTH - 20)
    frame:SetScript("OnHide", function() ns.db.shown = false end)
end

local function Row(i)
    local r = rows[i]
    if not r then
        r = CreateFrame("Button", nil, frame)
        r:SetSize(WIDTH - 20, ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ROW_H - 2, ROW_H - 2)
        r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
        r.text:SetWidth(WIDTH - 90)
        r.text:SetJustifyH("LEFT")
        r.status = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.status:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        r.heading = r:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        r.heading:SetPoint("LEFT", r, "LEFT", 0, 0)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(r)
        hl:SetColorTexture(1, 1, 1, 0.1)
        r:SetScript("OnClick", function(self)
            if self.entry and self.entry.status == "ready" and self.entry.member.name ~= ns.Me() then
                SendChatMessage(List.RequestText(self.entry.cd), "WHISPER", nil, self.entry.member.name)
            end
        end)
        r:SetScript("OnEnter", function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(ns.CooldownName(self.entry.cd), 1, 0.82, 0)
            GameTooltip:AddLine(self.entry.member.name, 1, 1, 1)
            if self.entry.status == "ready" and self.entry.member.name ~= ns.Me() then
                GameTooltip:AddLine(L["Click to whisper them for it."], 0.6, 1, 0.6)
            elseif self.entry.status == "unknown" then
                GameTooltip:AddLine(L["Out of range, offline or dead: can't tell."], 0.7, 0.7, 0.7, true)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    return r
end

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return GetSpellTexture and GetSpellTexture(spellID) or nil
end

function List.Draw()
    if not (frame and frame:IsShown()) then return end
    local data = List.Compute(GetTime())
    for i, entry in ipairs(data) do
        local r = Row(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -28 - (i - 1) * ROW_H)
        if entry.heading then
            r.entry = nil
            r.heading:SetText(entry.heading)
            r.heading:Show()
            r.icon:Hide()
            r.text:SetText("")
            r.status:SetText("")
        else
            r.entry = entry
            r.heading:Hide()
            r.icon:SetTexture(SpellIcon(entry.cd.spells[1]))
            r.icon:Show()
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.member.class]
            local hex = color and string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255) or "|cffffffff"
            r.text:SetText(ns.CooldownName(entry.cd) .. " - " .. hex .. entry.member.name .. "|r")
            if entry.status == "ready" then r.status:SetText("|cff40ff40" .. L["Ready"] .. "|r")
            elseif entry.status == "cooldown" then r.status:SetText("|cffffd100" .. ns.Tracker.Short(entry.left) .. "|r")
            else r.status:SetText("|cff808080?|r") end
        end
        r:Show()
    end
    for i = #data + 1, #rows do rows[i]:Hide() end
    frame.empty:SetText(#data == 0 and L["No tracked cooldowns in your group."] or "")
    frame:SetSize(WIDTH, 40 + math.max(1, #data) * ROW_H)
end

function List.Show()
    if not frame then Build() end
    frame:Show()
    ns.db.shown = true
    List.Draw()
end

function List.Toggle()
    if frame and frame:IsShown() then frame:Hide() else List.Show() end
end
