-- Time.lua
-- Real-world clock widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local TimeWidget = {}
addon.TimeWidget = TimeWidget

local widgetFrame = nil
local timer = nil

local function UpdateTime()
    if not widgetFrame or not widgetFrame:IsVisible() then return end
    
    local timeString = date("%H:%M")
    widgetFrame.Text:SetText(timeString)
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function StartLoop()
    if timer then timer:Cancel() end
    timer = C_Timer.NewTicker(10, UpdateTime)
    UpdateTime()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Time", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    -- Local time
    GameTooltip:AddDoubleLine("Local Time:", date("%H:%M:%S"), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Date:", date("%A, %B %d"), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    
    -- Server time
    local serverHour, serverMin = GetGameTime()
    GameTooltip:AddDoubleLine("Server Time:", string.format("%02d:%02d", serverHour, serverMin), 0.7, 0.7, 0.7, 0.6, 0.8, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Calendar", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusTimeWidget", UIParent)
    f:SetSize(50, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Time"
    
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    
    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 12 })
    end
    
    -- No default position - WidgetManager places in drawer
    f:SetMovable(true)
    f:EnableMouse(true)
    
    -- Tooltip
    f:SetScript("OnEnter", ShowTooltip)
    f:SetScript("OnLeave", HideTooltip)
    
    -- Click to open calendar
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            ToggleCalendar()
        end
    end)
    
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("Time") then
            return  -- Block drag if drawer isn't open
        end
        self.isDragging = true
        self:SetParent(UIParent)
        self:SetFrameStrata("TOOLTIP")
        self:StartMoving()
        if not widgetFrame.dragTicker then
            widgetFrame.dragTicker = C_Timer.NewTicker(0.05, function()
                local WM2 = addon.WidgetManager
                if WM2 then WM2:OnWidgetDragUpdate() end
            end)
        end
    end)
    
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false
        if widgetFrame.dragTicker then
            widgetFrame.dragTicker:Cancel()
            widgetFrame.dragTicker = nil
        end
        local WM = addon.WidgetManager
        if WM then WM:OnWidgetDragStop("Time") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function TimeWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Time", {
            name = "Time",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateTime() end,
            onEnable = function(f)
                -- Resume time ticker when drawer opens
                StartLoop()
            end,
            onDisable = function(f)
                -- Stop time ticker when drawer closes to save resources
                if timer then
                    timer:Cancel()
                    timer = nil
                end
            end,
        })
    end
    
    StartLoop()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() TimeWidget:OnLoad() end)
end)
