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

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 60
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

local COLORS = {
    WHITE = "|cffffffff",
    GREY = "|cff888888",
    GOLD = "|cffffd700",
}

-- [ UPDATES ] ---------------------------------------------------------------------

function TimeWidget:Update()
    local date = date("*t")
    local hour, minute = date.hour, date.min
    

    local timeStr = string.format("%02d:%02d", hour, minute)
    

    local use24 = GetCVar("timeMgrUseMilitaryTime") == "1"
    if not use24 then
        local ampm = (hour >= 12) and "PM" or "AM"
        if hour > 12 then hour = hour - 12 end
        if hour == 0 then hour = 12 end
        timeStr = string.format("%d:%02d %s", hour, minute, ampm)
    end

    self:SetText(COLORS.WHITE .. timeStr)
end

-- [ INTERACTION ] -----------------------------------------------------------------

function TimeWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Time", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local localDate = date("*t")
    local localTime = string.format("%02d:%02d", localDate.hour, localDate.min)
    local utcDate = date("!*t")
    local utcTime = string.format("%02d:%02d", utcDate.hour, utcDate.min)
    local _, realmHour, realmMinute = GetGameTime()
    local realmTime = string.format("%02d:%02d", realmHour, realmMinute)
    
    GameTooltip:AddDoubleLine("Local Time:", localTime, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Realm Time:", realmTime, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("UTC Time:", utcTime, 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Date:", date("%A, %B %d, %Y"), 1, 1, 1, 1, 1, 1)

    -- The party checks if any holiday quests are posted at the tavern
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

-- [ LIFECYCLE ] -------------------------------------------------------------------

function TimeWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    

    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    -- The clockwork gnome updates every second — obsessive but precise
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("NORMAL")
    

    self:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
    

    self:SetCategory("SYSTEM")

    self:Register()
    

    self:Update()
end


local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() TimeWidget:OnLoad() end)
end)
