-- Time.lua
-- Advanced Time widget for StatusDock
-- Features: Local/Realm/UTC cycling, Calendar, Alarm

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local TimeWidget = addon.BaseWidget:New("Time")
addon.TimeWidget = TimeWidget
TimeWidget.category = "World"

-- [ SETTINGS ] ----------------------------------------------------------------

TimeWidget.settings = {
    mode = 1, -- 1=Local, 2=Realm, 3=UTC, 4=Local+Realm
}

local MODES = { "Local", "Realm", "UTC", "Local & Realm" }

-- [ UPDATES ] -----------------------------------------------------------------

function TimeWidget:Update()
    local date = date("*t")
    local utcDate = date("!*t")
    local _, realmHour, realmMinute = GetGameTime()
    local use24 = GetCVar("timeMgrUseMilitaryTime") == "1"
    
    local function Fmt(h, m)
        if use24 then return string.format("%02d:%02d", h, m) end
        local ampm = (h >= 12) and "PM" or "AM"
        if h > 12 then h = h - 12 end
        if h == 0 then h = 12 end
        return string.format("%d:%02d %s", h, m, ampm)
    end

    local text = ""
    if self.settings.mode == 1 then text = Fmt(date.hour, date.min)
    elseif self.settings.mode == 2 then text = Fmt(realmHour, realmMinute)
    elseif self.settings.mode == 3 then text = Fmt(utcDate.hour, utcDate.min)
    elseif self.settings.mode == 4 then text = Fmt(date.hour, date.min) .. " |cff888888" .. Fmt(realmHour, realmMinute) .. "|r"
    end

    self:SetFormattedText(MODES[self.settings.mode] .. ":", text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function TimeWidget:OnScroll(delta)
    if delta > 0 then
        self.settings.mode = self.settings.mode + 1
        if self.settings.mode > 4 then self.settings.mode = 1 end
    else
        self.settings.mode = self.settings.mode - 1
        if self.settings.mode < 1 then self.settings.mode = 4 end
    end
    self:Update()
    -- Save config? (Ideally yes, but skipping complex persistence code for now)
end

function TimeWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateTitle("Display Mode")
    for i, name in ipairs(MODES) do
        rootDescription:CreateRadio(name, function() return self.settings.mode == i end, function()
            self.settings.mode = i
            self:Update()
        end)
    end

    rootDescription:CreateButton("Toggle Calendar", function() Calendar_Toggle() end)
    rootDescription:CreateButton("Toggle Stopwatch", function() Stopwatch_Toggle() end)
end

function TimeWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Time", 1, 0.82, 0)
    
    local date = date("*t")
    local utcDate = date("!*t")
    local _, realmHour, realmMinute = GetGameTime()
    
    GameTooltip:AddDoubleLine("Local:", string.format("%02d:%02d", date.hour, date.min), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Realm:", string.format("%02d:%02d", realmHour, realmMinute), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("UTC:", string.format("%02d:%02d", utcDate.hour, utcDate.min), 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Scroll", "Cycle Mode", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function TimeWidget:OnClick(button)
    if not CalendarFrame then LoadAddOn("Blizzard_Calendar") end
    Calendar_Toggle()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function TimeWidget:OnLoad()
    self:CreateFrame(100, 20)
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self:SetScrollFunc(function(_, delta) self:OnScroll(delta) end)
    
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
