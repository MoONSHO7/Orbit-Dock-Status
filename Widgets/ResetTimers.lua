-- ResetTimers.lua
-- Reset timer widget for StatusDock
-- Features: Daily/weekly reset countdowns, raid lockout info

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local ResetWidget = addon.BaseWidget:New("ResetTimers")
addon.ResetWidget = ResetWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local SECONDS_PER_HOUR = 3600
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_DAY = 86400
local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local DAILY_LABEL = "Daily"
local WEEKLY_LABEL = "Weekly"

-- [ HELPERS ] ---------------------------------------------------------------------

local function FormatCountdown(seconds)
    if seconds <= 0 then return "|cff00ff00Now!|r" end
    local days = math.floor(seconds / SECONDS_PER_DAY)
    local hours = math.floor((seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)
    local mins = math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
    if days > 0 then return string.format("%dd %dh", days, hours) end
    if hours > 0 then return string.format("%dh %dm", hours, mins) end
    return string.format("%dm", mins)
end

-- [ UPDATES ] ---------------------------------------------------------------------

function ResetWidget:Update()
    local daily = C_DateAndTime.GetSecondsUntilDailyReset()
    local weekly = C_DateAndTime.GetSecondsUntilWeeklyReset()
    local dailyStr = FormatCountdown(daily)
    self:SetText(string.format("|cffffd700D:|r %s", dailyStr))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function ResetWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Reset Timers", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local daily = C_DateAndTime.GetSecondsUntilDailyReset()
    local weekly = C_DateAndTime.GetSecondsUntilWeeklyReset()
    GameTooltip:AddDoubleLine(DAILY_LABEL .. " Reset:", FormatCountdown(daily), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(WEEKLY_LABEL .. " Reset:", FormatCountdown(weekly), 1, 1, 1, 0.4, 0.8, 1)

    local numSaved = GetNumSavedInstances()
    if numSaved > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Saved Instances:", 0.7, 0.7, 0.7)
        for i = 1, numSaved do
            local name, _, reset, _, _, _, _, _, _, diffName = GetSavedInstanceInfo(i)
            if reset > 0 then
                GameTooltip:AddDoubleLine(
                    string.format("%s (%s)", name, diffName or ""),
                    FormatCountdown(reset),
                    1, 1, 1, 0.7, 0.7, 0.7
                )
            end
        end
    end

    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function ResetWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self.leftClickHint = "Refresh"
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:SetUpdateTier("GLACIAL")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() ResetWidget:OnLoad() end)
end)
