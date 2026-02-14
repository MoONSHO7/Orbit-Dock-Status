-- Fishing.lua
-- Fishing skill widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local FishWidget = addon.BaseWidget:New("Fishing")
addon.FishWidget = FishWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 90
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local FISHING_SPELL_ID = 131474

-- [ UPDATES ] ---------------------------------------------------------------------

function FishWidget:Update()
    local professions = { GetProfessions() }
    local fishIdx = professions[3]
    if not fishIdx then
        self.frame:Hide()
        return
    end
    self.frame:Show()
    local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(fishIdx)
    self:SetText(string.format("|cff00ccff%s|r %d/%d", name or "Fishing", skillLevel, maxSkillLevel))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function FishWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Fishing", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local professions = { GetProfessions() }
    local fishIdx = professions[3]
    if fishIdx then
        local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(fishIdx)
        GameTooltip:AddDoubleLine("Skill:", string.format("%d / %d", skillLevel, maxSkillLevel), 1, 1, 1, 0, 0.8, 1)
        local hasFishingBuff = false
        for i = 1, 40 do
            local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not auraData then break end
            local buffName = auraData.name or ""
            if buffName:find("Fishing") or buffName:find("Lure") then
                hasFishingBuff = true
                GameTooltip:AddDoubleLine("Buff:", buffName, 1, 1, 1, 0, 1, 0)
            end
        end
        if not hasFishingBuff then GameTooltip:AddDoubleLine("Buff:", "|cff888888None|r", 1, 1, 1, 0.5, 0.5, 0.5) end
    else
        GameTooltip:AddLine("Fishing not learned", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function FishWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:RegisterEvent("SKILL_LINES_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() FishWidget:OnLoad() end)
end)
