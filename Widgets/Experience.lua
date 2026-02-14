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

-- [ CONSTANTS ] --------------------------------------------------------------------------

local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local GRAPH_WIDTH = 200
local GRAPH_HEIGHT = 50
local GRAPH_OFFSET_Y = -5
local GRAPH_POINTS = 60
local FORMAT_THRESHOLD_K = 1000
local FORMAT_THRESHOLD_M = 1000000
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local PERCENT_MULTIPLIER = 100

-- [ STATE ] -----------------------------------------------------------------------

local RingBuffer = addon.Formatting.RingBuffer
ExperienceWidget.sessionStartXP = 0
ExperienceWidget.sessionStartTime = 0
ExperienceWidget.maxLevel = GetMaxLevelForPlayerExpansion()
ExperienceWidget.history = RingBuffer:New(GRAPH_POINTS)

-- [ HELPERS ] ---------------------------------------------------------------------

local function FormatNumber(num)
    if num >= FORMAT_THRESHOLD_M then return string.format("%.1fM", num / FORMAT_THRESHOLD_M)
    elseif num >= FORMAT_THRESHOLD_K then return string.format("%.1fK", num / FORMAT_THRESHOLD_K)
    else return string.format("%d", num) end
end

local function FormatTime(seconds)
    if seconds == math.huge then return "N/A" end
    if seconds < SECONDS_PER_MINUTE then return string.format("%ds", seconds) end
    if seconds < SECONDS_PER_HOUR then return string.format("%dm", seconds / SECONDS_PER_MINUTE) end
    return string.format("%dh %dm", seconds / SECONDS_PER_HOUR, (seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
end

-- [ UPDATE ] ----------------------------------------------------------------------

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

    local pct = (currentXP / maxXP) * PERCENT_MULTIPLIER
    local restedPct = (restedXP / maxXP) * PERCENT_MULTIPLIER

    -- The barbarian doesn't track XP, he tracks kills per hour
    local time = GetTime()
    local sessionDuration = time - self.sessionStartTime
    local sessionXP = currentXP - self.sessionStartXP

    if sessionXP < 0 then
        -- Rolled a nat 20 and leveled up mid-dungeon
        self.sessionStartXP = 0
        sessionXP = currentXP
    end

    local xph = 0
    if sessionDuration > 0 then
        xph = (sessionXP / sessionDuration) * SECONDS_PER_HOUR
    end

    local timeToLevel = 0
    if xph > 0 then
        timeToLevel = (maxXP - currentXP) / (xph / SECONDS_PER_HOUR)
    end

    -- The bard narrates your progress in percentage form
    local text = string.format("XP: %.1f%%", pct)
    if restedXP > 0 then
        text = text .. string.format(" |cff00aaff(+%.1f%%)|r", restedPct)
    end
    self:SetText(text)

    -- The wizard scribbles XP/hr trends in their spellbook
    self.history:Push(xph)
end

-- [ INTERACTION ] -----------------------------------------------------------------

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

    -- The accountant NPC demands to see your receipts
    local time = GetTime()
    local sessionDuration = time - self.sessionStartTime
    local sessionXP = currentXP - self.sessionStartXP
    if sessionXP < 0 then sessionXP = currentXP end

    local xph = 0
    if sessionDuration > 0 then
        xph = (sessionXP / sessionDuration) * SECONDS_PER_HOUR
    end

    local timeToLevel = math.huge
    if xph > 0 then
        timeToLevel = (maxXP - currentXP) / (xph / SECONDS_PER_HOUR)
    end

    GameTooltip:AddDoubleLine("XP/Hour:", FormatNumber(xph), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Time to Level:", FormatTime(timeToLevel), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session Gain:", FormatNumber(sessionXP), 1, 1, 1, 1, 1, 1)

    GameTooltip:Show()

    -- Roll persuasion to convince the DM your graph is accurate
    if self.history:Count() > 2 then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(GRAPH_WIDTH, GRAPH_HEIGHT)
            self.graph = addon.Graph:New(self.graphFrame, GRAPH_WIDTH, GRAPH_HEIGHT)
        end
        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, GRAPH_OFFSET_Y)
        self.graphFrame:Show()

        self.graph:Clear()
        self.graph:SetColor(0.6, 0, 0.6, 1) -- Purple
        for _, val in self.history:Iterate() do
            self.graph:AddData(val)
        end
        self.graph:Draw()
    end
end

function ExperienceWidget:OnClick(button)
    -- This button does nothing; the DM hasn't implemented it yet
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function ExperienceWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    self.sessionStartXP = UnitXP("player")
    self.sessionStartTime = GetTime()

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("PLAYER_XP_UPDATE")
    self:RegisterEvent("UPDATE_EXHAUSTION")
    self:RegisterEvent("PLAYER_LEVEL_UP", function()
        self.sessionStartXP = 0
        self.maxLevel = GetMaxLevelForPlayerExpansion()
        self:Update()
    end)

    self:SetCategory("CHARACTER")


    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() ExperienceWidget:OnLoad() end)
end)
