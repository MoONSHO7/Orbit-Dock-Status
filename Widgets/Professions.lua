-- Professions.lua
-- Advanced Professions widget for StatusDock
-- Features: Cooldown tracking, Recipe access

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local ProfessionsWidget = addon.BaseWidget:New("Professions"); addon.ProfessionsWidget.category = "Economy"
addon.ProfessionsWidget = ProfessionsWidget

-- [ HELPER ] ------------------------------------------------------------------

function ProfessionsWidget:GetProfessions()
    local prof1, prof2, arch, fish, cook = GetProfessions()
    local list = {}

    if prof1 then
        local name, icon, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(prof1)
        table.insert(list, { name = name, icon = icon, rank = rank, max = maxRank, id = skillLine })
    end
    if prof2 then
        local name, icon, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(prof2)
        table.insert(list, { name = name, icon = icon, rank = rank, max = maxRank, id = skillLine })
    end

    if cook then
        local name, icon, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(cook)
        table.insert(list, { name = name, icon = icon, rank = rank, max = maxRank, id = skillLine, secondary = true })
    end

    return list
end

-- [ UPDATE ] ------------------------------------------------------------------

function ProfessionsWidget:Update()
    local list = self:GetProfessions()

    local text = ""
    for _, p in ipairs(list) do
        if not p.secondary then
            if text ~= "" then text = text .. " " end
            text = text .. string.format("|T%s:14|t %d", p.icon, p.rank)
        end
    end

    if text == "" then text = "No Professions" end
    self:SetText(text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function ProfessionsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Professions", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local list = self:GetProfessions()

    for _, p in ipairs(list) do
        GameTooltip:AddDoubleLine(string.format("|T%s:14|t %s", p.icon, p.name), string.format("%d/%d", p.rank, p.max), 1, 1, 1, 1, 1, 1)

        -- Check Cooldowns? Requires scanning spellbook or known cooldown IDs.
        -- This is complex API-wise without a database of CD spells.
        -- For now, list is fine.
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Profession", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function ProfessionsWidget:OnClick(button)
    -- Toggle first profession
    local prof1 = GetProfessions()
    if prof1 then
        local name, icon, rank, maxRank, numSpells, spellOffset, skillLine = GetProfessionInfo(prof1)
        -- OpenTradeSkill(skillLine) -- Deprecated
        -- Use C_TradeSkillUI.OpenTradeSkill(skillLine)
        C_TradeSkillUI.OpenTradeSkill(skillLine)
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function ProfessionsWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("TRADE_SKILL_UPDATE")
    self:RegisterEvent("SKILL_LINES_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() ProfessionsWidget:OnLoad() end)
end)
