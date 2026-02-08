-- StatusData.lua
-- Constants and data definitions for Status Dock

local _, addon = ...

addon.StatusData = {}
local SD = addon.StatusData

-- [ CONSTANTS ] ---------------------------------------------------------------

-- Slot positions for data text panels
SD.SlotPositions = {
    LEFT = 1,
    CENTER = 2,
    RIGHT = 3,
}

-- Default slot configuration (for future data text integration)
SD.DefaultSlots = {
    [1] = { position = "LEFT", enabled = true, module = nil },
    [2] = { position = "CENTER", enabled = true, module = nil },
    [3] = { position = "RIGHT", enabled = true, module = nil },
}

-- Edge texture styles
SD.EdgeStyles = {
    BLACK_LINE = 0,
    XP_BAR = 1,
    REPUTATION_BAR = 2,
    HONOR_BAR = 3,
}

-- Status bar texture paths
SD.StatusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar"

-- Status bar colors (based on Blizzard defaults)
SD.Colors = {
    XP = { r = 0.58, g = 0.0, b = 0.55, a = 1.0 },  -- Purple (XP bar color)
    XP_RESTED = { r = 0.0, g = 0.39, b = 0.88, a = 1.0 },  -- Blue (rested)
    HONOR = { r = 1.0, g = 0.24, b = 0, a = 1.0 },  -- Orange (honor)
    -- Reputation colors by standing
    REP_HATED = { r = 0.6, g = 0.1, b = 0.1, a = 1.0 },
    REP_HOSTILE = { r = 0.7, g = 0.2, b = 0.2, a = 1.0 },
    REP_UNFRIENDLY = { r = 0.8, g = 0.3, b = 0, a = 1.0 },
    REP_NEUTRAL = { r = 0.9, g = 0.7, b = 0, a = 1.0 },
    REP_FRIENDLY = { r = 0.0, g = 0.6, b = 0.1, a = 1.0 },
    REP_HONORED = { r = 0.0, g = 0.7, b = 0.2, a = 1.0 },
    REP_REVERED = { r = 0.0, g = 0.8, b = 0.3, a = 1.0 },
    REP_EXALTED = { r = 0.0, g = 0.9, b = 0.4, a = 1.0 },
    -- Paragon/Major faction
    REP_PARAGON = { r = 0.0, g = 0.5, b = 0.9, a = 1.0 },
}

-- Reputation reaction IDs
SD.ReputationColors = {
    [1] = SD.Colors.REP_HATED,
    [2] = SD.Colors.REP_HOSTILE,
    [3] = SD.Colors.REP_UNFRIENDLY,
    [4] = SD.Colors.REP_NEUTRAL,
    [5] = SD.Colors.REP_FRIENDLY,
    [6] = SD.Colors.REP_HONORED,
    [7] = SD.Colors.REP_REVERED,
    [8] = SD.Colors.REP_EXALTED,
}

-- [ DATA RETRIEVAL ] ----------------------------------------------------------

function SD.GetXPData()
    local current = UnitXP("player")
    local max = UnitXPMax("player")
    local isRested = GetRestState() == 1

    if not current or not max or max == 0 then
        return nil
    end

    return {
        type = "XP",
        current = current,
        max = max,
        progress = current / max,
        color = isRested and SD.Colors.XP_RESTED or SD.Colors.XP,
    }
end

function SD.GetReputationData()
    local watchedFactionData = C_Reputation.GetWatchedFactionData()
    if not watchedFactionData or watchedFactionData.factionID == 0 then
        return nil
    end

    local factionID = watchedFactionData.factionID
    local current, max
    local reactionLevel = watchedFactionData.reaction or 4

    -- Handle paragon
    if C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
        local currentValue, threshold = C_Reputation.GetFactionParagonInfo(factionID)
        if currentValue and threshold and threshold > 0 then
            current = currentValue % threshold
            max = threshold
        end
        return {
            type = "REP",
            current = current or 0,
            max = max or 1,
            progress = (current or 0) / (max or 1),
            color = SD.Colors.REP_PARAGON,
        }
    end

    -- Handle major faction (renown)
    if C_Reputation.IsMajorFaction(factionID) then
        local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID)
        if majorFactionData then
            current = majorFactionData.renownReputationEarned or 0
            max = majorFactionData.renownLevelThreshold or 1
        end
        return {
            type = "REP",
            current = current or 0,
            max = max or 1,
            progress = (current or 0) / (max or 1),
            color = SD.Colors.REP_PARAGON,
        }
    end

    -- Normal reputation
    current = watchedFactionData.currentStanding - watchedFactionData.currentReactionThreshold
    max = watchedFactionData.nextReactionThreshold - watchedFactionData.currentReactionThreshold

    if not current or not max or max == 0 then
        return nil
    end

    return {
        type = "REP",
        current = current,
        max = max,
        progress = current / max,
        color = SD.ReputationColors[reactionLevel] or SD.Colors.REP_NEUTRAL,
    }
end

function SD.GetHonorData()
    local current = UnitHonor("player")
    local max = UnitHonorMax("player")

    if not current or not max or max == 0 then
        return nil
    end

    return {
        type = "HONOR",
        current = current,
        max = max,
        progress = current / max,
        color = SD.Colors.HONOR,
    }
end
