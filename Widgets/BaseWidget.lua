-- BaseWidget.lua
-- Foundation for all Orbit Status widgets

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local BaseWidget = {}
addon.BaseWidget = BaseWidget
BaseWidget.__index = BaseWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local DEFAULT_FRAME_WIDTH = 100
local DEFAULT_FRAME_HEIGHT = 20
local DEFAULT_TEXT_SIZE = 12
local TEXT_PADDING = 10
local ICON_SIZE = 14
local ICON_PADDING = 4
local DOCK_PADDING_W = 4
local DOCK_PADDING_H = 2
local DRAG_TICKER_INTERVAL = 0.05
local FLASH_ON_SEC = 0.5
local FLASH_OFF_SEC = 0.5

-- [ CONSTRUCTOR ] -----------------------------------------------------------------

function BaseWidget:New(name)
    local instance = setmetatable({}, BaseWidget)
    instance.name = name
    instance.events = {}
    instance.isEnabled = false
    instance.frame = nil
    instance.text = nil
    instance.icon = nil
    instance.tooltipFunc = nil
    instance.updateFunc = nil
    instance.clickFunc = nil
    instance.inEditMode = false
    instance.category = "UTILITY"
    instance.leftClickHint = nil
    instance.rightClickHint = nil
    instance.updateTier = nil
    return instance
end

-- [ FRAME CREATION ] --------------------------------------------------------------

function BaseWidget:CreateFrame(width, height)
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "OrbitStatus" .. self.name, UIParent)
    f:SetSize(width or DEFAULT_FRAME_WIDTH, height or DEFAULT_FRAME_HEIGHT)
    f:SetClampedToScreen(true)
    f.editModeName = self.name

    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    self.text = f.Text

    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, { font = Orbit.db.GlobalSettings.Font, textSize = DEFAULT_TEXT_SIZE })
    end

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

-- [ REGISTRATION ] ----------------------------------------------------------------

function BaseWidget:Register()
    if not self.frame then self:CreateFrame() end

    if addon.WidgetManager then
        addon.WidgetManager:Register(self.name, {
            name = self.name,
            frame = self.frame,
            category = self.category,
            onDock = function(_, zone) self:OnDock(zone) end,
            onUndock = function(_) self:OnUndock() end,
            onEnable = function(_) self:Enable() end,
            onDisable = function(_) self:Disable() end,
        })
    end
end

-- [ CATEGORY ] --------------------------------------------------------------------

function BaseWidget:SetCategory(category) self.category = category end

-- [ SETTERS ] ---------------------------------------------------------------------

function BaseWidget:SetUpdateFunc(func) self.updateFunc = func end
function BaseWidget:SetTooltipFunc(func) self.tooltipFunc = func end
function BaseWidget:SetClickFunc(func) self.clickFunc = func end

function BaseWidget:SetUpdateTier(tier)
    self.updateTier = tier
    if addon.WidgetManager then addon.WidgetManager:RegisterForScheduler(self.name, tier, self.updateFunc) end
end

-- [ ICON ] ------------------------------------------------------------------------

function BaseWidget:SetIcon(texturePath)
    if not self.frame then return end
    if not self.icon then
        self.icon = self.frame:CreateTexture(nil, "ARTWORK")
        self.icon:SetSize(ICON_SIZE, ICON_SIZE)
        self.icon:SetPoint("LEFT", self.frame, "LEFT", 2, 0)
        self.text:SetPoint("CENTER", self.frame, "CENTER", (ICON_SIZE + ICON_PADDING) / 2, 0)
    end
    self.icon:SetTexture(texturePath)
    self.icon:Show()
end

-- [ SOUND ] -----------------------------------------------------------------------

function BaseWidget:PlaySound(soundKitID)
    if soundKitID then PlaySound(soundKitID) end
end

-- [ EVENTS ] ----------------------------------------------------------------------

function BaseWidget:RegisterEvent(event, handler)
    self.events[event] = handler or self.updateFunc
    if self.isEnabled and self.eventFrame then self.eventFrame:RegisterEvent(event) end
end

function BaseWidget:UnregisterEvent(event)
    self.events[event] = nil
    if self.eventFrame then self.eventFrame:UnregisterEvent(event) end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

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
    if self.updateTier and addon.WidgetManager then
        addon.WidgetManager:RegisterForScheduler(self.name, self.updateTier, self.updateFunc)
    end
    if self.updateFunc then self.updateFunc(self) end
    if self.OnEnable then self:OnEnable() end

    if Orbit.EventBus then
        Orbit.EventBus:On("EDIT_MODE_ENTERED", function()
            self.inEditMode = true
            if self.updateFunc then self.updateFunc(self) end
            if self.frame then self.frame:Show() end
        end, self)
        Orbit.EventBus:On("EDIT_MODE_EXITED", function()
            self.inEditMode = false
            if self.updateFunc then self.updateFunc(self) end
        end, self)
    end
end

function BaseWidget:Disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    if self.updateTier and addon.WidgetManager then
        addon.WidgetManager:UnregisterFromScheduler(self.name, self.updateTier)
    end
    if Orbit.EventBus then Orbit.EventBus:OffContext(self) end
    if self.OnDisable then self:OnDisable() end
end

-- [ TEXT ] -------------------------------------------------------------------------

function BaseWidget:SetText(text)
    if not self.text then return end
    self.text:SetText(text)
    local widget = addon.WidgetManager and addon.WidgetManager:GetWidget(self.name)
    if widget and widget.isDocked then return end
    local width = self.text:GetStringWidth()
    local iconOffset = self.icon and (ICON_SIZE + ICON_PADDING) or 0
    self.frame:SetSize(width + TEXT_PADDING + iconOffset, self.frame:GetHeight())
end

-- [ TOOLTIP TEMPLATE ] ------------------------------------------------------------

function BaseWidget:BuildTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    self:PopulateTooltip(GameTooltip)
    if self.leftClickHint or self.rightClickHint then
        GameTooltip:AddLine(" ")
        if self.leftClickHint then GameTooltip:AddDoubleLine("Left Click", self.leftClickHint, 0.7, 0.7, 0.7, 1, 1, 1) end
        if self.rightClickHint then GameTooltip:AddDoubleLine("Right Click", self.rightClickHint, 0.7, 0.7, 0.7, 1, 1, 1) end
    end
    GameTooltip:Show()
end

function BaseWidget:PopulateTooltip(tooltip)
    tooltip:AddLine(self.name, 1, 0.82, 0)
end

-- [ INTERACTION ] -----------------------------------------------------------------

function BaseWidget:OnEnter()
    if self.tooltipFunc then self.tooltipFunc(self)
    else self:BuildTooltip() end
end

function BaseWidget:OnLeave() GameTooltip:Hide() end

function BaseWidget:OnClick(button)
    if button == "LeftButton" and self.isDragging then return end
    if button == "RightButton" and not self.clickFunc then
        self:ShowContextMenu()
        return
    end
    if self.clickFunc then self.clickFunc(self, button) end
end

-- [ CONTEXT MENU ] ----------------------------------------------------------------

function BaseWidget:ShowContextMenu()
    if not addon.Menu then return end
    local items = self:BuildContextMenuItems()
    addon.Menu:Open(self.frame, items, self.name)
end

function BaseWidget:BuildContextMenuItems()
    local items = {}
    if self.GetMenuItems then
        local custom = self:GetMenuItems()
        for _, item in ipairs(custom) do table.insert(items, item) end
        table.insert(items, { text = "", isSeparator = true })
    end
    table.insert(items, {
        text = "Hide Widget",
        func = function()
            if addon.WidgetManager then addon.WidgetManager:MoveToDrawer(self.name) end
        end,
    })
    return items
end

-- [ DRAGGING ] --------------------------------------------------------------------

function BaseWidget:OnDragStart()
    local WM = addon.WidgetManager
    if not WM or not WM:OnWidgetDragStart(self.name) then return end
    self.isDragging = true
    self.frame:SetParent(UIParent)
    self.frame:SetFrameStrata("TOOLTIP")
    self.frame:StartMoving()
    if not self.dragTicker then
        self.dragTicker = C_Timer.NewTicker(DRAG_TICKER_INTERVAL, function()
            if addon.WidgetManager then addon.WidgetManager:OnWidgetDragUpdate() end
        end)
    end
end

function BaseWidget:OnDragStop()
    self.frame:StopMovingOrSizing()
    self.isDragging = false
    if self.dragTicker then self.dragTicker:Cancel(); self.dragTicker = nil end
    local WM = addon.WidgetManager
    if WM then WM:OnWidgetDragStop(self.name) end
end

-- [ DOCKING ] ---------------------------------------------------------------------

function BaseWidget:OnDock(zone)
    if not self.frame or not zone then return end
    local w = zone:GetWidth() - DOCK_PADDING_W
    local h = zone:GetHeight() - DOCK_PADDING_H
    self.frame:SetSize(w, h)
    self.text:SetWidth(w - TEXT_PADDING)
    self.text:SetWordWrap(false)
    self.text:SetNonSpaceWrap(false)
end

function BaseWidget:OnUndock()
    if self.updateFunc then self.updateFunc(self) end
end

-- [ FLASH ] -----------------------------------------------------------------------

function BaseWidget:Flash()
    if not self.frame or self.flashing then return end
    self.flashing = true
    UIFrameFlash(self.frame, FLASH_ON_SEC, FLASH_OFF_SEC, -1, true, 0, 0, nil)
end

function BaseWidget:StopFlash()
    if not self.frame or not self.flashing then return end
    self.flashing = false
    UIFrameFlashStop(self.frame)
end
