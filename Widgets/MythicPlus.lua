-- MythicPlus.lua
-- Mythic+ widget for StatusDock
-- Features: current key, season M+ score, best runs, affixes

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local MPlusWidget = addon.BaseWidget:New("MythicPlus")
addon.MPlusWidget = MPlusWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local MAX_BEST_RUNS = 8
local DEPLETE_THRESHOLD = 0

-- [ UPDATES ] ---------------------------------------------------------------------

function MPlusWidget:Update()
    local mapID = C_MythicPlus.GetOwnedKeystoneMapID()
    if mapID then
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        self:SetText(string.format("|cffff8000+%d|r %s", level, name or "Key"))
    else
        local score = self:GetMPlusScore()
        if score > 0 then
            local color = C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score) or CreateColor(1, 1, 1)
            self:SetText(string.format("%sM+ %d|r", color:GenerateHexColorMarkup(), score))
        else
            self:SetText("|cff888888No Key|r")
        end
    end
end

function MPlusWidget:GetMPlusScore()
    local overall = C_ChallengeMode.GetOverallDungeonScore and C_ChallengeMode.GetOverallDungeonScore() or 0
    return overall
end

-- [ INTERACTION ] -----------------------------------------------------------------

function MPlusWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Mythic+", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local mapID = C_MythicPlus.GetOwnedKeystoneMapID()
    if mapID then
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        GameTooltip:AddDoubleLine("Keystone:", string.format("%s +%d", name or "Unknown", level), 1, 1, 1, 1, 0.5, 0)
    else
        GameTooltip:AddLine("No Keystone", 0.5, 0.5, 0.5)
    end

    local score = self:GetMPlusScore()
    if score > 0 then
        local color = C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score) or CreateColor(1, 1, 1)
        GameTooltip:AddDoubleLine("M+ Score:", tostring(score), 1, 1, 1, color.r, color.g, color.b)
    end

    local affixIDs = C_MythicPlus.GetCurrentAffixes()
    if affixIDs and #affixIDs > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Affixes:", 0.7, 0.7, 0.7)
        for _, affix in ipairs(affixIDs) do
            local name, desc = C_ChallengeMode.GetAffixInfo(affix.id)
            if name then GameTooltip:AddLine("  " .. name, 1, 1, 1) end
        end
    end

    local bestRuns = C_MythicPlus.GetRunHistory(false, true)
    if bestRuns and #bestRuns > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Season Bests:", 0.7, 0.7, 0.7)
        table.sort(bestRuns, function(a, b) return a.level > b.level end)
        for i = 1, math.min(MAX_BEST_RUNS, #bestRuns) do
            local run = bestRuns[i]
            local mapName = C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID)
            local timeColor = run.completed and "|cff00ff00" or "|cffff0000"
            GameTooltip:AddDoubleLine(
                string.format("%s +%d", mapName or "Unknown", run.level),
                timeColor .. (run.completed and "Timed" or "Depleted") .. "|r",
                1, 1, 1, 0.7, 0.7, 0.7
            )
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open M+ Journal", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function MPlusWidget:OnClick(button)
    PVEFrame_ToggleFrame("ChallengesFrame")
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function MPlusWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open M+ Journal"
    self:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("GAMEPLAY")
    self:Register()
    C_MythicPlus.RequestCurrentAffixes()
    C_MythicPlus.RequestMapInfo()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() MPlusWidget:OnLoad() end)
end)
