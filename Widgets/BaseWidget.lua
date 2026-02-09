-- BaseWidget.lua
-- Foundation for all Orbit Status widgets
-- Provides common functionality for event handling, dragging, display, and Modern Menus

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local BaseWidget = {}
addon.BaseWidget = BaseWidget
BaseWidget.__index = BaseWidget

-- [ FACTORY ] -----------------------------------------------------------------

--- Create a new widget instance
---@param name string Unique identifier for the widget
function BaseWidget:New(name)
    local instance = setmetatable({}, BaseWidget)
    instance.name = name
    instance.events = {}      -- Map of event name -> handler function
    instance.isEnabled = false
    instance.frame = nil
    instance.text = nil
    instance.icon = nil
    instance.tooltipFunc = nil
    instance.updateFunc = nil
    instance.clickFunc = nil
    instance.scrollFunc = nil
    instance.menuGenerator = nil -- Function(owner, rootDescription)
    instance.inEditMode = false
    return instance
end

-- [ VISUALS ] -----------------------------------------------------------------

--- Create the visual frame for the widget
---@param width number? Initial width (default 100)
---@param height number? Initial height (default 20)
function BaseWidget:CreateFrame(width, height)
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "OrbitStatus" .. self.name, UIParent)
    f:SetSize(width or 100, height or 20)
    f:SetClampedToScreen(true)
    f.editModeName = self.name

    -- Icon (Optional, Left)
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetSize(14, 14)
    f.Icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.Icon:Hide()
    self.icon = f.Icon

    -- Text display
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("LEFT", f.Icon, "RIGHT", 5, 0)
    f.Text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.Text:SetJustifyH("LEFT") -- Align left for better scaling
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
    f:SetScript("OnMouseWheel", function(_, delta) self:OnScroll(delta) end)

    self.frame = f
    return f
end

--- Update the widget text with professional formatting
---@param label string? The static label (e.g. "FPS:") - Can be nil
---@param value string The dynamic value (e.g. "60")
function BaseWidget:SetFormattedText(label, value)
    if not self.text then return end

    local text = ""
    if label then
        -- Label in Grey
        text = "|cff888888" .. label .. "|r "
    end
    -- Value in default (White) or pre-colored string
    text = text .. value

    self.text:SetText(text)

    -- Auto-resize
    local width = self.text:GetStringWidth()
    local iconWidth = self.icon:IsShown() and 19 or 0 -- 14 + 5 padding
    self.frame:SetWidth(width + iconWidth + 10)
end

function BaseWidget:SetText(text)
    if self.text then
        self.text:SetText(text)
        local width = self.text:GetStringWidth()
        local iconWidth = self.icon:IsShown() and 19 or 0
        self.frame:SetWidth(width + iconWidth + 10)
    end
end

function BaseWidget:SetIcon(texture)
    if self.icon then
        if texture then
            self.icon:SetTexture(texture)
            self.icon:Show()
            self.text:SetPoint("LEFT", self.icon, "RIGHT", 5, 0)
        else
            self.icon:Hide()
            self.text:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        end
    end
end

--- Start flashing the widget (for critical alerts)
function BaseWidget:Flash()
    if not self.frame then return end
    if not self.flashing then
        self.flashing = true
        UIFrameFlash(self.frame, 0.5, 0.5, -1, true, 0, 0, nil)
    end
end

--- Stop flashing the widget
function BaseWidget:StopFlash()
    if not self.frame then return end
    if self.flashing then
        self.flashing = false
        UIFrameFlashStop(self.frame)
    end
end

-- [ REGISTRATION ] ------------------------------------------------------------

--- Register the widget with the WidgetManager
function BaseWidget:Register()
    if not self.frame then self:CreateFrame() end

    if addon.WidgetManager then
        addon.WidgetManager:Register(self.name, {
            name = self.name,
            frame = self.frame,
            onDock = function(_, zone) self:OnDock(zone) end,
            onUndock = function(_) self:OnUndock() end,
            onEnable = function(_) self:Enable() end,
            onDisable = function(_) self:Disable() end,
        })
    end
end

-- [ EVENTS ] ------------------------------------------------------------------

function BaseWidget:SetUpdateFunc(func) self.updateFunc = func end
function BaseWidget:SetTooltipFunc(func) self.tooltipFunc = func end
function BaseWidget:SetClickFunc(func) self.clickFunc = func end
function BaseWidget:SetScrollFunc(func)
    self.scrollFunc = func
    if self.frame then self.frame:EnableMouseWheel(true) end
end

function BaseWidget:RegisterEvent(event, handler)
    self.events[event] = handler or self.updateFunc
    if self.isEnabled and self.eventFrame then
        self.eventFrame:RegisterEvent(event)
    end
end

function BaseWidget:UnregisterEvent(event)
    self.events[event] = nil
    if self.eventFrame then
        self.eventFrame:UnregisterEvent(event)
    end
end

function BaseWidget:Enable()
    if self.isEnabled then return end
    self.isEnabled = true

    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            local handler = self.events[event]
            if handler then handler(self, event, ...)
            elseif self.updateFunc then self.updateFunc(self) end
        end)
    end

    for event, _ in pairs(self.events) do self.eventFrame:RegisterEvent(event) end

    if self.updateFunc then self.updateFunc(self) end
    if self.OnEnable then self:OnEnable() end

    -- Edit Mode Integration
    if Orbit.EventBus then
        Orbit.EventBus:On("EDIT_MODE_ENTERED", function()
            self.inEditMode = true
            if self.updateFunc then self.updateFunc(self) end
            if self.frame then self.frame:Show() end
        end)
        Orbit.EventBus:On("EDIT_MODE_EXITED", function()
            self.inEditMode = false
            if self.updateFunc then self.updateFunc(self) end
        end)
    end
end

function BaseWidget:Disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    if self.OnDisable then self:OnDisable() end
end

-- [ INTERACTION ] -------------------------------------------------------------

function BaseWidget:OnEnter()
    if self.tooltipFunc then self.tooltipFunc(self) end
end

function BaseWidget:OnLeave()
    GameTooltip:Hide()
end

function BaseWidget:OnClick(button)
    if button == "LeftButton" and self.isDragging then return end

    if button == "RightButton" and self.menuGenerator then
        -- Use Blizzard's Menu System
        if Menu and Menu.GetManager then
            Menu.GetManager():CreateContextMenu(self.frame, function(owner, rootDescription)
                rootDescription:SetTag("OrbitStatusMenu")
                rootDescription:CreateTitle(self.name)
                self.menuGenerator(owner, rootDescription)
            end)
        end
    end

    if self.clickFunc then self.clickFunc(self, button) end
end

function BaseWidget:OnScroll(delta)
    if self.scrollFunc then self.scrollFunc(self, delta) end
end

-- [ MENUS ] -------------------------------------------------------------------

--- Register a modern context menu generator
---@param generator function Function(owner, rootDescription)
function BaseWidget:RegisterMenu(generator)
    self.menuGenerator = generator
end

-- [ DRAG ] --------------------------------------------------------------------

function BaseWidget:OnDragStart()
    if self.inEditMode or (addon.WidgetManager and addon.WidgetManager:IsDrawerOpen()) then
        local WM = addon.WidgetManager
        if WM then WM:OnWidgetDragStart(self.name) end
        self.isDragging = true
    end
end

function BaseWidget:OnDragStop()
    if self.isDragging then
        local WM = addon.WidgetManager
        if WM then WM:OnWidgetDragStop(self.name) end
        self.isDragging = false
    end
end

function BaseWidget:OnDock(zone)
    if self.frame and zone then
        self.frame:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2)
    end
end

function BaseWidget:OnUndock()
    if self.updateFunc then self.updateFunc(self) end
end
