-- WeatherAndTime.lua
-- Server/local time widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local TimeWidget = addon.BaseWidget:New("WeatherAndTime")
addon.TimeWidget = TimeWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 80
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local DAWN_HOUR = 6
local DAY_HOUR = 8
local DUSK_HOUR = 18
local NIGHT_HOUR = 20

-- [ STATE ] -----------------------------------------------------------------------

TimeWidget.settings = { useServerTime = false }

-- [ HELPERS ] ---------------------------------------------------------------------

function TimeWidget:GetDayPhase(hour)
    if hour >= NIGHT_HOUR or hour < DAWN_HOUR then return "|cff4466cc\226\152\189|r"
    elseif hour >= DUSK_HOUR then return "|cffff8800\226\152\128|r"
    elseif hour >= DAY_HOUR then return "|cffffd700\226\152\128|r"
    else return "|cff88aadd\226\152\128|r" end
end

-- [ UPDATES ] ---------------------------------------------------------------------

function TimeWidget:Update()
    local hour, min
    if self.settings.useServerTime then
        local serverTime = C_DateAndTime.GetCurrentCalendarTime()
        hour, min = serverTime.hour, serverTime.minute
    else
        hour, min = tonumber(date("%H")), tonumber(date("%M"))
    end
    local phase = self:GetDayPhase(hour)
    self:SetText(string.format("%s %d:%02d", phase, hour, min))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function TimeWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Time", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local localH, localM = tonumber(date("%H")), tonumber(date("%M"))
    GameTooltip:AddDoubleLine("Local:", string.format("%d:%02d", localH, localM), 1, 1, 1, 1, 1, 1)
    local serverTime = C_DateAndTime.GetCurrentCalendarTime()
    GameTooltip:AddDoubleLine("Server:", string.format("%d:%02d", serverTime.hour, serverTime.minute), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Toggle Local/Server", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function TimeWidget:GetMenuItems()
    return {
        { text = "Use Server Time", checked = self.settings.useServerTime, func = function() self.settings.useServerTime = not self.settings.useServerTime; self:Update() end, closeOnClick = false },
    }
end

function TimeWidget:OnClick(button)
    if button == "RightButton" then self:ShowContextMenu()
    else self.settings.useServerTime = not self.settings.useServerTime; self:Update() end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function TimeWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Toggle Time"
    self.rightClickHint = "Settings"
    self:SetCategory("UTILITY")
    self:Register()
    self:SetUpdateTier("NORMAL")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() TimeWidget:OnLoad() end)
end)
