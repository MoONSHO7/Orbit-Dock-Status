-- BaseWidget.lua
-- Foundation for all Orbit Status widgets
-- Provides common functionality for event handling, dragging, and display

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local BaseWidget = {}
addon.BaseWidget = BaseWidget
BaseWidget.__index = BaseWidget

--- Create a new widget instance
---@param name string Unique identifier for the widget
function BaseWidget:New(name)
    local instance = setmetatable({}, BaseWidget)
    instance.name = name
    instance.events = {}      -- Map of event name -> handler function
    instance.isEnabled = false
    instance.frame = nil
    instance.text = nil
    instance.tooltipFunc = nil
    instance.updateFunc = nil
    instance.clickFunc = nil
    return instance
end

--- Create the visual frame for the widget
---@param width number? Initial width (default 100)
---@param height number? Initial height (default 20)
function BaseWidget:CreateFrame(width, height)
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "OrbitStatus" .. self.name, UIParent)
    f:SetSize(width or 100, height or 20)
    f:SetClampedToScreen(true)
    f.editModeName = self.name

    -- Text display
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    self.text = f.Text

    -- Apply global font settings if available
    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = 12,
        })
    end

    -- Standard scripts
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnEnter", function() self:OnEnter() end)
    f:SetScript("OnLeave", function() self:OnLeave() end)
    f:SetScript("OnDragStart", function() self:OnDragStart() end)
    f:SetScript("OnDragStop", function() self:OnDragStop() end)
    f:SetScript("OnMouseUp", function(_, button) self:OnClick(button) end)

    self.frame = f
    return f
end

--- Register the widget with the WidgetManager
function BaseWidget:Register()
    if not self.frame then self:CreateFrame() end

    if addon.WidgetManager then
        addon.WidgetManager:Register(self.name, {
            name = self.name,
            frame = self.frame,
            -- Bridge WidgetManager callbacks to BaseWidget methods
            onDock = function(_, zone) self:OnDock(zone) end,
            onUndock = function(_) self:OnUndock() end,
            onEnable = function(_) self:Enable() end,
            onDisable = function(_) self:Disable() end,
        })
    end
end

--- Set the update function (called on events or timer)
---@param func function
function BaseWidget:SetUpdateFunc(func)
    self.updateFunc = func
end

--- Set the tooltip function
---@param func function
function BaseWidget:SetTooltipFunc(func)
    self.tooltipFunc = func
end

--- Set the click handler
---@param func function
function BaseWidget:SetClickFunc(func)
    self.clickFunc = func
end

--- Register a WoW event
---@param event string Event name
---@param handler function? Optional handler (defaults to self.updateFunc)
function BaseWidget:RegisterEvent(event, handler)
    self.events[event] = handler or self.updateFunc

    -- If already enabled, register specifically with the frame (or event frame)
    if self.isEnabled and self.eventFrame then
        self.eventFrame:RegisterEvent(event)
    end
end

--- Unregister a WoW event
---@param event string Event name
function BaseWidget:UnregisterEvent(event)
    self.events[event] = nil
    if self.eventFrame then
        self.eventFrame:UnregisterEvent(event)
    end
end

--- Enable the widget (start listening to events)
function BaseWidget:Enable()
    if self.isEnabled then return end
    self.isEnabled = true

    -- Create generic event frame if needed
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            local handler = self.events[event]
            if handler then
                handler(self, event, ...)
            elseif self.updateFunc then
                self.updateFunc(self)
            end
        end)
    end

    -- Register all tracked events
    for event, _ in pairs(self.events) do
        self.eventFrame:RegisterEvent(event)
    end

    -- Initial update
    if self.updateFunc then
        self.updateFunc(self)
    end

    if self.OnEnable then self:OnEnable() end
end

--- Disable the widget (stop listening)
function BaseWidget:Disable()
    if not self.isEnabled then return end
    self.isEnabled = false

    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end

    if self.OnDisable then self:OnDisable() end
end

--- Update the widget text
---@param text string
function BaseWidget:SetText(text)
    if self.text then
        self.text:SetText(text)
        -- Auto-resize frame to fit text
        local width = self.text:GetStringWidth()
        self.frame:SetSize(width + 10, self.frame:GetHeight())
    end
end

--- Handle mouse enter (tooltip)
function BaseWidget:OnEnter()
    if self.tooltipFunc then
        self.tooltipFunc(self)
    end
end

--- Handle mouse leave
function BaseWidget:OnLeave()
    GameTooltip:Hide()
end

--- Handle click
function BaseWidget:OnClick(button)
    if button == "LeftButton" and self.isDragging then return end
    if self.clickFunc then
        self.clickFunc(self, button)
    end
end

--- Handle dragging start
function BaseWidget:OnDragStart()
    local WM = addon.WidgetManager
    if not WM or not WM:OnWidgetDragStart(self.name) then return end

    self.isDragging = true
    self.frame:SetParent(UIParent)
    self.frame:SetFrameStrata("TOOLTIP")
    self.frame:StartMoving()

    if not self.dragTicker then
        self.dragTicker = C_Timer.NewTicker(0.05, function()
            if addon.WidgetManager then addon.WidgetManager:OnWidgetDragUpdate() end
        end)
    end
end

--- Handle dragging stop
function BaseWidget:OnDragStop()
    self.frame:StopMovingOrSizing()
    self.isDragging = false

    if self.dragTicker then
        self.dragTicker:Cancel()
        self.dragTicker = nil
    end

    local WM = addon.WidgetManager
    if WM then WM:OnWidgetDragStop(self.name) end
end

--- Called when docked
function BaseWidget:OnDock(zone)
    if self.frame and zone then
        self.frame:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2)
    end
end

--- Called when undocked
function BaseWidget:OnUndock()
    if self.updateFunc then
        self.updateFunc(self)
    end
end
