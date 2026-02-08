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
TimeWidget.category = "World"

-- [ UPDATES ] -----------------------------------------------------------------

function TimeWidget:Update()
    local date = date("*t")
    local hour, minute = date.hour, date.min

    local timeStr = string.format("%02d:%02d", hour, minute)
    
    -- Check CVar for 12/24 mode
    if GetCVar("timeMgrUseMilitaryTime") == "0" then
        local ampm = (hour >= 12) and "PM" or "AM"
        if hour > 12 then hour = hour - 12 end
        if hour == 0 then hour = 12 end
        timeStr = string.format("%d:%02d %s", hour, minute, ampm)
    end

    self:SetFormattedText(nil, timeStr)
end

-- [ INTERACTION ] -------------------------------------------------------------

function TimeWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Toggle Calendar", function() Calendar_Toggle() end)
    rootDescription:CreateButton("Toggle Stopwatch", function() Stopwatch_Toggle() end)

    -- 12/24 Hour Toggle
    local is24 = GetCVar("timeMgrUseMilitaryTime") == "1"
    rootDescription:CreateCheckbox("24-Hour Mode", function() return is24 end, function()
        SetCVar("timeMgrUseMilitaryTime", is24 and "0" or "1")
        self:Update()
    end)
end

function TimeWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Time", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local date = date("*t")
    local utcDate = date("!*t")
    local _, realmHour, realmMinute = GetGameTime()

    local localTime = string.format("%02d:%02d", date.hour, date.min)
    local utcTime = string.format("%02d:%02d", utcDate.hour, utcDate.min)
    local realmTime = string.format("%02d:%02d", realmHour, realmMinute)
    
    GameTooltip:AddDoubleLine("Local Time:", localTime, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Realm Time:", realmTime, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("UTC Time:", utcTime, 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Date:", date("%A, %B %d, %Y"), 1, 1, 1, 1, 1, 1)

    local numInvites = C_Calendar.GetNumPendingInvites()
    if numInvites > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("|cff00ff00%d Pending Invites|r", numInvites))
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Calendar", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Options", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function TimeWidget:OnClick(button)
    if not CalendarFrame then LoadAddOn("Blizzard_Calendar") end
    Calendar_Toggle()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function TimeWidget:OnLoad()
    self:CreateFrame(60, 20)
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)
    
    self:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
    
    C_Timer.NewTicker(1, function() self:Update() end)
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() TimeWidget:OnLoad() end)
end)
