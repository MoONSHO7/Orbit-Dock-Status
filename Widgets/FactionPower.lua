-- FactionPower.lua
-- Expansion reputation/renown widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local FactionWidget = addon.BaseWidget:New("FactionPower")
addon.FactionWidget = FactionWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local MAX_FACTIONS_SHOWN = 8

-- [ UPDATES ] ---------------------------------------------------------------------

function FactionWidget:Update()
    local watchedIndex = C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if watchedIndex then
        local name = watchedIndex.name
        if watchedIndex.renownLevel and watchedIndex.renownLevel > 0 then
            self:SetText(string.format("|cff00ccff%s R%d|r", name or "Faction", watchedIndex.renownLevel))
        else
            local standing = watchedIndex.reaction
            local standingLabel = _G["FACTION_STANDING_LABEL" .. (standing or 4)] or "Neutral"
            self:SetText(string.format("|cffffd700%s|r", name or standingLabel))
        end
    else
        self:SetText("|cff888888Reputation|r")
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function FactionWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Reputation & Renown", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local watchedData = C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if watchedData then
        GameTooltip:AddLine("Watched:", 0.7, 0.7, 0.7)
        if watchedData.renownLevel and watchedData.renownLevel > 0 then
            GameTooltip:AddDoubleLine("  " .. (watchedData.name or "Unknown"), string.format("Renown %d", watchedData.renownLevel), 1, 1, 1, 0, 0.8, 1)
        else
            local standing = _G["FACTION_STANDING_LABEL" .. (watchedData.reaction or 4)] or "Neutral"
            local current = watchedData.currentReactionThreshold or 0
            local max = watchedData.nextReactionThreshold or 1
            local pct = max > 0 and ((watchedData.currentStanding or 0) / max) or 0
            GameTooltip:AddDoubleLine("  " .. (watchedData.name or "Unknown"), string.format("%s (%.0f%%)", standing, pct * 100), 1, 1, 1, 1, 0.82, 0)
        end
    end

    local majorFactions = C_MajorFactions.GetMajorFactionIDs and C_MajorFactions.GetMajorFactionIDs(LE_EXPANSION_WAR_WITHIN or LE_EXPANSION_DRAGONFLIGHT)
    if majorFactions and #majorFactions > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Major Factions:", 0.7, 0.7, 0.7)
        local shown = 0
        for _, factionID in ipairs(majorFactions) do
            if shown >= MAX_FACTIONS_SHOWN then break end
            local data = C_MajorFactions.GetMajorFactionData(factionID)
            if data then
                GameTooltip:AddDoubleLine("  " .. data.name, string.format("R%d", data.renownLevel or 0), 1, 1, 1, 0, 0.8, 1)
                shown = shown + 1
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Reputation", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function FactionWidget:OnClick(button) ToggleCharacter("ReputationFrame") end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function FactionWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Reputation"
    self:RegisterEvent("UPDATE_FACTION")
    self:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() FactionWidget:OnLoad() end)
end)
