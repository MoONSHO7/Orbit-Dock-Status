-- Reputation.lua
-- Advanced Reputation widget for StatusDock
-- Features: Session history, Paragon/Renown tracking, Detailed faction list

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local ReputationWidget = addon.BaseWidget:New("Reputation")
addon.ReputationWidget = ReputationWidget

-- [ CONSTANTS ] --------------------------------------------------------------------------

local FRAME_WIDTH = 150
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ STATE ] -----------------------------------------------------------------------

ReputationWidget.sessionStart = {} -- [factionID] = value at login
ReputationWidget.currentSession = {} -- [factionID] = gain

-- [ HELPERS ] ---------------------------------------------------------------------

local FACTION_COLORS = {
    [1] = "|cffcc2222", [2] = "|cffcc2222", [3] = "|cffee6622", [4] = "|cffffcc00",
    [5] = "|cff00cc00", [6] = "|cff00cc66", [7] = "|cff00cc88", [8] = "|cff00ccaa",
}
local PARAGON_COLOR = "|cff00aaff"

local function GetFactionColor(standing) return FACTION_COLORS[standing] or "|cffffffff" end

local function ResolveFactionProgress(factionID, standingId, earnedValue, bottomValue, topValue)
    local value = earnedValue - bottomValue
    local max = topValue - bottomValue
    local label = _G["FACTION_STANDING_LABEL" .. standingId]
    local color = GetFactionColor(standingId)
    if C_Reputation.IsFactionParagon(factionID) then
        local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
        value = currentValue % threshold
        max = threshold
        label = hasRewardPending and "Reward Pending" or "Paragon"
        color = PARAGON_COLOR
    elseif C_Reputation.IsMajorFaction(factionID) then
        local major = C_MajorFactions.GetMajorFactionData(factionID)
        if major then
            value = major.renownReputationEarned or 0
            max = major.renownLevelThreshold
            label = string.format("Renown %d", major.renownLevel)
            color = PARAGON_COLOR
        end
    end
    return value, max, label, color
end

function ReputationWidget:GetWatchedFaction()
    local data = C_Reputation.GetWatchedFactionData()
    if not data or data.factionID == 0 then return nil end
    local id = data.factionID
    local standing = data.reaction
    local value, max, label, color = ResolveFactionProgress(
        id, standing, data.currentStanding, data.currentReactionThreshold, data.nextReactionThreshold
    )
    return {
        name = data.name, standing = standing, value = value, max = max,
        id = id, text = label, color = color,
        isParagon = C_Reputation.IsFactionParagon(id),
        isMajor = C_Reputation.IsMajorFaction(id),
    }
end

-- [ UPDATE ] ----------------------------------------------------------------------

function ReputationWidget:Update()
    local data = self:GetWatchedFaction()

    if not data then
        self:SetText("No Faction Watched")
        return
    end

    local gain = self.currentSession[data.id] or 0
    local gainStr = ""
    if gain > 0 then
        gainStr = string.format(" |cff00ff00(+%d)|r", gain)
    end

    local pct = 0
    if data.max > 0 then
        pct = (data.value / data.max) * 100
    end

    local color = GetFactionColor(data.standing)
    if data.isParagon then color = "|cff00aaff" end -- Blue for Paragon
    if data.isMajor then color = "|cff00aaff" end

    self:SetText(string.format("%s%s|r: %d/%d (%.1f%%)%s", color, data.name, data.value, data.max, pct, gainStr))
end

function ReputationWidget:UpdateHistory(factionID, amount)
    -- Placeholder for future history tracking logic
end

-- [ INTERACTION ] -----------------------------------------------------------------

function ReputationWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Reputation", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local data = self:GetWatchedFaction()
    if data then
        GameTooltip:AddDoubleLine("Watched:", data.name, 1, 1, 1, GetFactionColor(data.standing))
        GameTooltip:AddDoubleLine("Status:", string.format("%d / %d (%s)", data.value, data.max, data.text), 1, 1, 1, 1, 1, 1)
        if self.currentSession[data.id] then
            GameTooltip:AddDoubleLine("Session:", string.format("+%d", self.currentSession[data.id]), 1, 1, 1, 0, 1, 0)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Top Factions (Recent)", 0.7, 0.7, 0.7)

    local numFactions = C_Reputation.GetNumFactions()
    local activeHeader = false

    for i = 1, numFactions do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        if not factionData then break end

        local name = factionData.name
        local isHeader = factionData.isHeader
        local factionID = factionData.factionID
        local standingId = factionData.reaction
        local bottomValue = factionData.currentReactionThreshold
        local topValue = factionData.nextReactionThreshold
        local earnedValue = factionData.currentStanding

        if isHeader then
            activeHeader = (name == "Dragon Isles" or name == "The War Within" or name == "Shadowlands")
            if activeHeader then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(name, 1, 0.82, 0)
            end
        elseif activeHeader and factionID then
            local value, max, label = ResolveFactionProgress(
                factionID, standingId, earnedValue, bottomValue, topValue
            )
            GameTooltip:AddDoubleLine(name, string.format("%d / %d (%s)", value, max, label), 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Reputation", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function ReputationWidget:OnClick(button)
    ToggleCharacter("ReputationFrame")
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function ReputationWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("UPDATE_FACTION")
    self:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    self:RegisterEvent("MAJOR_FACTION_UNLOCKED")

    self:SetCategory("GAMEPLAY")


    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() ReputationWidget:OnLoad() end)
end)
