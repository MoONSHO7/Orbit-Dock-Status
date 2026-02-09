-- Professions.lua
-- Advanced Professions widget for StatusDock
-- Features: Cooldown tracking, Recipe access

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local ProfessionsWidget = addon.BaseWidget:New("Professions")
addon.ProfessionsWidget = ProfessionsWidget
ProfessionsWidget.category = "Economy"

-- [ HELPER ] ------------------------------------------------------------------

function ProfessionsWidget:GetProfessions()
    -- GetProfessions returns indices for GetProfessionInfo
    local prof1, prof2, arch, fish, cook = GetProfessions()
    local list = {}

    local function Add(index, secondary)
        if not index then return end
        local name, icon, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(index)
        table.insert(list, { name = name, icon = icon, rank = rank, max = maxRank, id = skillLine, secondary = secondary })
    end

    Add(prof1, false)
    Add(prof2, false)
    Add(cook, true)
    Add(fish, true)
    Add(arch, true)

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
    self:SetFormattedText(nil, text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function ProfessionsWidget:GenerateMenu(owner, rootDescription)
    local list = self:GetProfessions()

    if #list == 0 then
        rootDescription:CreateTitle("No Professions")
        return
    end

    for _, p in ipairs(list) do
        rootDescription:CreateButton(string.format("|T%s:14|t %s", p.icon, p.name), function()
            C_TradeSkillUI.OpenTradeSkill(p.id)
        end)
    end
end

function ProfessionsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Professions", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local list = self:GetProfessions()

    for _, p in ipairs(list) do
        GameTooltip:AddDoubleLine(string.format("|T%s:14|t %s", p.icon, p.name), string.format("%d/%d", p.rank, p.max), 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Primary", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Menu", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function ProfessionsWidget:OnClick(button)
    local prof1 = GetProfessions()
    if prof1 then
        local _, _, _, _, _, _, skillLine = GetProfessionInfo(prof1)
        C_TradeSkillUI.OpenTradeSkill(skillLine)
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function ProfessionsWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

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
