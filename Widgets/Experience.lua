-- Experience.lua
-- Advanced Experience widget for StatusDock
-- Features: XP/Hour, Time to Level, Rested XP breakdown, Session Graph

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local ExperienceWidget = addon.BaseWidget:New("Experience")
addon.ExperienceWidget = ExperienceWidget

-- [ STATE ] -------------------------------------------------------------------

ExperienceWidget.sessionStartXP = 0
ExperienceWidget.sessionStartTime = 0
ExperienceWidget.maxLevel = GetMaxLevelForPlayerExpansion()
ExperienceWidget.history = {}
local GRAPH_POINTS = 60

-- [ HELPERS ] -----------------------------------------------------------------

local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return string.format("%d", num)
    end
end

local function FormatTime(seconds)
    if seconds == math.huge then return "N/A" end
    if seconds < 60 then return string.format("%ds", seconds) end
    if seconds < 3600 then return string.format("%dm", seconds / 60) end
    return string.format("%dh %dm", seconds / 3600, (seconds % 3600) / 60)
end

-- [ UPDATE ] ------------------------------------------------------------------

function ExperienceWidget:Update()
    local level = UnitLevel("player")
    if level >= self.maxLevel then
        self.frame:Hide()
        return
    end
    self.frame:Show()

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0

    local pct = (currentXP / maxXP) * 100
    local restedPct = (restedXP / maxXP) * 100

    -- XP/Hour Calculation
    local time = GetTime()
    local sessionDuration = time - self.sessionStartTime
    local sessionXP = currentXP - self.sessionStartXP -- Only works within same level
    -- Handle level up (if current < start, we gained a level)
    -- Complex: Need to track accumulated XP.
    -- Simplified: Just track current level progress for now.
    -- Correct approach: Track total XP gained since login.

    if sessionXP < 0 then
        -- Level up occurred? Reset session start to 0 for this level
        self.sessionStartXP = 0
        sessionXP = currentXP
    end

    local xph = 0
    if sessionDuration > 0 then
        xph = (sessionXP / sessionDuration) * 3600
    end

    local timeToLevel = 0
    if xph > 0 then
        timeToLevel = (maxXP - currentXP) / (xph / 3600)
    end

    -- Text: "XP: 50% (+20% R)"
    local text = string.format("XP: %.1f%%", pct)
    if restedXP > 0 then
        text = text .. string.format(" |cff00aaff(+%.1f%%)|r", restedPct)
    end
    self:SetText(text)

    -- Graph History
    table.insert(self.history, xph)
    if #self.history > GRAPH_POINTS then table.remove(self.history, 1) end
end

-- [ INTERACTION ] -------------------------------------------------------------

function ExperienceWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Experience", 1, 0.82, 0)

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0
    local pct = (currentXP / maxXP) * 100

    GameTooltip:AddDoubleLine("Current:", string.format("%s / %s (%.1f%%)", FormatNumber(currentXP), FormatNumber(maxXP), pct), 1, 1, 1, 1, 1, 1)

    if restedXP > 0 then
        local restedPct = (restedXP / maxXP) * 100
        GameTooltip:AddDoubleLine("Rested:", string.format("%s (%.1f%%)", FormatNumber(restedXP), restedPct), 1, 1, 1, 0, 0.7, 1)
    end

    GameTooltip:AddLine(" ")

    -- Analytics
    local time = GetTime()
    local sessionDuration = time - self.sessionStartTime
    local sessionXP = currentXP - self.sessionStartXP
    if sessionXP < 0 then sessionXP = currentXP end -- Level up handling

    local xph = 0
    if sessionDuration > 0 then
        xph = (sessionXP / sessionDuration) * 3600
    end

    local timeToLevel = math.huge
    if xph > 0 then
        timeToLevel = (maxXP - currentXP) / (xph / 3600)
    end

    GameTooltip:AddDoubleLine("XP/Hour:", FormatNumber(xph), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Time to Level:", FormatTime(timeToLevel), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session Gain:", FormatNumber(sessionXP), 1, 1, 1, 1, 1, 1)

    GameTooltip:Show()

    -- Graph
    if #self.history > 2 then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(200, 50)
            self.graph = addon.Graph:New(self.graphFrame, 200, 50)
        end
        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
        self.graphFrame:Show()

        self.graph:Clear()
        self.graph:SetColor(0.6, 0, 0.6, 1) -- Purple
        for _, val in ipairs(self.history) do
            self.graph:AddData(val)
        end
        self.graph:Draw()
    end
end

function ExperienceWidget:OnClick(button)
    -- Toggle Experience Bar?
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function ExperienceWidget:OnLoad()
    self:CreateFrame(100, 20)

    self.sessionStartXP = UnitXP("player")
    self.sessionStartTime = GetTime()

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("PLAYER_XP_UPDATE")
    self:RegisterEvent("UPDATE_EXHAUSTION")
    self:RegisterEvent("PLAYER_LEVEL_UP", function()
        self.sessionStartXP = 0 -- Reset baseline for new level
        self.maxLevel = GetMaxLevelForPlayerExpansion()
        self:Update()
    end)

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() ExperienceWidget:OnLoad() end)
end)
