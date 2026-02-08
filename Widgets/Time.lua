-- Time.lua
-- Advanced Time widget for StatusDock
-- Features: Local/Realm/UTC, Calendar, Alarm

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local TimeWidget = addon.BaseWidget:New("Time")
addon.TimeWidget = TimeWidget

-- [ CONSTANTS ] ---------------------------------------------------------------

local COLORS = {
    WHITE = "|cffffffff",
    GREY = "|cff888888",
    GOLD = "|cffffd700",
}

-- [ UPDATES ] -----------------------------------------------------------------

function TimeWidget:Update()
    local date = date("*t")
    local hour, minute = date.hour, date.min
    
    -- Format: HH:MM
    local timeStr = string.format("%02d:%02d", hour, minute)
    
    -- Add AM/PM if 12h format (Orbit Settings or CVar check)
    local use24 = GetCVar("timeMgrUseMilitaryTime") == "1"
    if not use24 then
        local ampm = (hour >= 12) and "PM" or "AM"
        if hour > 12 then hour = hour - 12 end
        if hour == 0 then hour = 12 end
        timeStr = string.format("%d:%02d %s", hour, minute, ampm)
    end

    self:SetText(COLORS.WHITE .. timeStr)
end

-- [ INTERACTION ] -------------------------------------------------------------

function TimeWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Time", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local date = date("*t")
    local localTime = string.format("%02d:%02d", date.hour, date.min)
    local utcDate = date("!*t")
    local utcTime = string.format("%02d:%02d", utcDate.hour, utcDate.min)
    local _, realmHour, realmMinute = GetGameTime()
    local realmTime = string.format("%02d:%02d", realmHour, realmMinute)
    
    GameTooltip:AddDoubleLine("Local Time:", localTime, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Realm Time:", realmTime, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("UTC Time:", utcTime, 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Date:", date("%A, %B %d, %Y"), 1, 1, 1, 1, 1, 1)

    -- Check for Calendar Invites
    local numInvites = C_Calendar.GetNumPendingInvites()
    if numInvites > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("|cff00ff00%d Pending Invites|r", numInvites))
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Calendar", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Stopwatch", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function TimeWidget:OnClick(button)
    if button == "LeftButton" then
        if not CalendarFrame then LoadAddOn("Blizzard_Calendar") end
        Calendar_Toggle()
    elseif button == "RightButton" then
        Stopwatch_Toggle()
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function TimeWidget:OnLoad()
    self:CreateFrame(60, 20)
    
    -- Setup handlers
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    -- Periodic update (every second to catch minute changes precisely)
    self:SetUpdateFunc(function() self:Update() end)
    C_Timer.NewTicker(1, function() self:Update() end)
    
    -- Register events
    self:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
    
    -- Register with manager
    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() TimeWidget:OnLoad() end)
end)
