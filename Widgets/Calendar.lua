-- Calendar.lua
-- Calendar events widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local CalendarWidget = addon.BaseWidget:New("Calendar")
addon.CalendarWidget = CalendarWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 110
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local MAX_EVENTS_SHOWN = 5
local HOLIDAY_COLOR = { r = 0, g = 0.8, b = 1 }
local INVITE_COLOR = { r = 0, g = 1, b = 0 }

-- [ UPDATES ] ---------------------------------------------------------------------

function CalendarWidget:Update()
    local numInvites = C_Calendar.GetNumPendingInvites()
    if numInvites > 0 then
        self:SetText(string.format("|cff00ff00%d Invite(s)|r", numInvites))
        self:Flash()
        return
    end
    self:StopFlash()
    local dateInfo = C_DateAndTime.GetCurrentCalendarTime()
    self:SetText(string.format("|cffffd700%s %d|r", CALENDAR_FULLDATE_MONTH_NAMES[dateInfo.month] or "?", dateInfo.monthDay))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function CalendarWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Calendar", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local dateInfo = C_DateAndTime.GetCurrentCalendarTime()
    GameTooltip:AddDoubleLine("Date:", string.format("%d/%d/%d", dateInfo.month, dateInfo.monthDay, dateInfo.year), 1, 1, 1, 1, 1, 1)

    local numInvites = C_Calendar.GetNumPendingInvites()
    if numInvites > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("|cff00ff00%d pending invite(s)|r", numInvites))
    end

    C_Calendar.SetAbsMonth(dateInfo.month, dateInfo.year)
    local numEvents = C_Calendar.GetNumDayEvents(0, dateInfo.monthDay)
    if numEvents > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Today's Events:", 0.7, 0.7, 0.7)
        local shown = 0
        for i = 1, numEvents do
            if shown >= MAX_EVENTS_SHOWN then break end
            local event = C_Calendar.GetDayEvent(0, dateInfo.monthDay, i)
            if event then
                local isHoliday = event.calendarType == "HOLIDAY" or event.calendarType == "RAID_LOCKOUT"
                local c = isHoliday and HOLIDAY_COLOR or INVITE_COLOR
                GameTooltip:AddLine("  " .. (event.title or "Event"), c.r, c.g, c.b)
                shown = shown + 1
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Calendar", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function CalendarWidget:OnClick(button) ToggleCalendar() end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function CalendarWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Calendar"
    self:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
    self:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("UTILITY")
    self:Register()
    self:SetUpdateTier("GLACIAL")
    C_Calendar.OpenCalendar()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() CalendarWidget:OnLoad() end)
end)
