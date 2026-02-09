-- Reputation.lua
-- Advanced Reputation widget for StatusDock
-- Features: Session history, Paragon/Renown tracking, Detailed faction list

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local ReputationWidget = addon.BaseWidget:New("Reputation"); addon.ReputationWidget.category = "Character"
addon.ReputationWidget = ReputationWidget

-- [ STATE ] -------------------------------------------------------------------

ReputationWidget.sessionStart = {} -- [factionID] = value at login
ReputationWidget.currentSession = {} -- [factionID] = gain

-- [ HELPERS ] -----------------------------------------------------------------

local function GetFactionColor(standing)
    local colors = {
        [1] = "|cffcc2222", -- Hated
        [2] = "|cffcc2222", -- Hostile
        [3] = "|cffee6622", -- Unfriendly
        [4] = "|cffffcc00", -- Neutral
        [5] = "|cff00cc00", -- Friendly
        [6] = "|cff00cc66", -- Honored
        [7] = "|cff00cc88", -- Revered
        [8] = "|cff00ccaa", -- Exalted
    }
    return colors[standing] or "|cffffffff"
end

function ReputationWidget:GetWatchedFaction()
    local data = C_Reputation.GetWatchedFactionData()
    if not data or data.factionID == 0 then return nil end

    local id = data.factionID
    local name = data.name
    local standing = data.reaction
    local min = data.currentReactionThreshold
    local max = data.nextReactionThreshold
    local value = data.currentStanding

    local result = {
        name = name,
        standing = standing,
        min = min,
        max = max,
        value = value,
        id = id,
        isParagon = C_Reputation.IsFactionParagon(id),
        isMajor = C_Reputation.IsMajorFaction(id),
    }

    -- Calculate percentages/remaining
    if result.isParagon then
        local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(id)
        result.value = currentValue % threshold
        result.max = threshold
        result.text = "Paragon"
        if hasRewardPending then result.text = "Reward Pending" end
    elseif result.isMajor then
        local major = C_MajorFactions.GetMajorFactionData(id)
        if major then
            result.value = major.renownReputationEarned or 0
            result.max = major.renownLevelThreshold
            result.text = string.format("Renown %d", major.renownLevel)
        end
    else
        result.value = value - min
        result.max = max - min
        result.text = _G["FACTION_STANDING_LABEL"..standing] or "Standing"
    end

    return result
end

-- [ UPDATE ] ------------------------------------------------------------------

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

-- [ INTERACTION ] -------------------------------------------------------------

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

    local numFactions = GetNumFactions()
    local activeHeader = false

    for i = 1, numFactions do
        local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)

        if isHeader then
            activeHeader = (name == "Dragon Isles" or name == "The War Within" or name == "Shadowlands")
            if activeHeader then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(name, 1, 0.82, 0)
            end
        elseif activeHeader then
            local value = earnedValue - bottomValue
            local max = topValue - bottomValue
            local label = _G["FACTION_STANDING_LABEL"..standingId]
            local color = GetFactionColor(standingId)

            if C_Reputation.IsFactionParagon(factionID) then
                local currentValue, threshold = C_Reputation.GetFactionParagonInfo(factionID)
                value = currentValue % threshold
                max = threshold
                label = "Paragon"
                color = "|cff00aaff"
            elseif C_Reputation.IsMajorFaction(factionID) then
                 local major = C_MajorFactions.GetMajorFactionData(factionID)
                 if major then
                     value = major.renownReputationEarned or 0
                     max = major.renownLevelThreshold
                     label = string.format("Renown %d", major.renownLevel)
                     color = "|cff00aaff"
                 end
            end

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

-- [ LIFECYCLE ] ---------------------------------------------------------------

function ReputationWidget:OnLoad()
    self:CreateFrame(150, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("UPDATE_FACTION")
    self:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    self:RegisterEvent("MAJOR_FACTION_UNLOCKED")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() ReputationWidget:OnLoad() end)
end)
