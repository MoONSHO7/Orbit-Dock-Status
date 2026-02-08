-- WidgetManager.lua
-- Central registry and management for StatusDock widgets

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local WidgetManager = {}
addon.WidgetManager = WidgetManager

-- Registry of all available widgets
local widgets = {}
local widgetOrder = {}

-- Dock reference (set by StatusDock)
local statusDock = nil

-- Drag state tracking
local draggedWidget = nil
local highlightedZone = nil

-- [ REGISTRATION ] ------------------------------------------------------------

--- Register a widget with the manager
---@param id string Unique widget identifier
---@param widgetData table Widget data: { frame, name, onDock, onUndock, onEnable, onDisable }
function WidgetManager:Register(id, widgetData)
    if widgets[id] then return end
    
    widgets[id] = {
        id = id,
        name = widgetData.name or id,
        frame = widgetData.frame,
        onDock = widgetData.onDock,
        onUndock = widgetData.onUndock,
        onEnable = widgetData.onEnable,
        onDisable = widgetData.onDisable,
        isDocked = false,
        dockedSlot = nil,
        isEnabled = true,  -- Widgets start enabled
    }
    table.insert(widgetOrder, id)
end

--- Enable a widget (start tickers, register events)
---@param id string Widget ID
function WidgetManager:EnableWidget(id)
    local widget = widgets[id]
    if not widget or widget.isEnabled then return end
    
    widget.isEnabled = true
    if widget.onEnable then
        widget.onEnable(widget.frame)
    end
end

--- Disable a widget (stop tickers, unregister events)
---@param id string Widget ID
function WidgetManager:DisableWidget(id)
    local widget = widgets[id]
    if not widget or not widget.isEnabled then return end
    
    widget.isEnabled = false
    if widget.onDisable then
        widget.onDisable(widget.frame)
    end
end

--- Enable all widgets currently in the drawer
function WidgetManager:EnableDrawerWidgets()
    for id, widget in pairs(widgets) do
        if widget.isInDrawer then
            self:EnableWidget(id)
        end
    end
end

--- Disable all widgets currently in the drawer
function WidgetManager:DisableDrawerWidgets()
    for id, widget in pairs(widgets) do
        if widget.isInDrawer then
            self:DisableWidget(id)
        end
    end
end

--- Get widget by ID
function WidgetManager:GetWidget(id)
    return widgets[id]
end

--- Get all registered widgets
function WidgetManager:GetAllWidgets()
    return widgets
end

-- [ DOCK INTEGRATION ] --------------------------------------------------------

--- Set the status dock reference
function WidgetManager:SetDock(dock)
    statusDock = dock
end

--- Get zone at cursor position (checks both dock and drawer zones)
function WidgetManager:GetZoneAtCursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    
    -- Check dock zones first
    if statusDock and statusDock.widgetZones then
        for i, zone in ipairs(statusDock.widgetZones) do
            if zone and zone:IsShown() then
                local left, bottom, width, height = zone:GetRect()
                if left and x >= left and x <= left + width and y >= bottom and y <= bottom + height then
                    return zone
                end
            end
        end
    end
    
    -- Check drawer zones
    local drawerZones = addon.GetDrawerZones and addon.GetDrawerZones()
    if drawerZones then
        for i, zone in ipairs(drawerZones) do
            if zone and zone:IsShown() then
                local left, bottom, width, height = zone:GetRect()
                if left and x >= left and x <= left + width and y >= bottom and y <= bottom + height then
                    return zone
                end
            end
        end
    end
    
    return nil
end

-- [ DOCKING LOGIC ] -----------------------------------------------------------

--- Helper to get zone for a widget's previous position
local function GetPreviousZone(widget)
    if not widget.isDocked then return nil end
    
    if widget.isInDrawer then
        local drawerZones = addon.GetDrawerZones and addon.GetDrawerZones()
        return drawerZones and drawerZones[widget.dockedSlot]
    else
        return statusDock and statusDock.widgetZones and statusDock.widgetZones[widget.dockedSlot]
    end
end

--- Get widget object by ID
function WidgetManager:GetWidget(widgetId)
    return widgets[widgetId]
end

--- Update all widgets with new settings
---@param textSize number Text size for widget font
function WidgetManager:UpdateAllWidgets(textSize)
    local Orbit = Orbit
    local font = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    
    for id, widget in pairs(widgets) do
        local f = widget.frame
        if f and f.Text then
            if Orbit.Skin then
                Orbit.Skin:SkinText(f.Text, { font = font, textSize = textSize })
            else
                f.Text:SetTextHeight(textSize)
            end
            
            -- Trigger widget update to refresh layout if needed
            if f:IsVisible() and widget.frame.onUndock then
                -- Re-run update logic (most widgets use onUndock for general refresh)
                -- Or check if there's a specific Update method?
                -- Most widgets just loop. Resizing text might require container resize if not docked.
            end
        end
    end
end

--- Dock a widget into a specific zone (dock or drawer)
---@param widgetId string Widget ID
---@param zone table Zone frame
function WidgetManager:DockWidget(widgetId, zone)
    local widget = widgets[widgetId]
    if not widget or not zone then return false end
    
    local previousZone = GetPreviousZone(widget)
    local existingWidgetId = zone.dockedWidget
    
    -- If there's a widget already in the target zone, swap them
    if existingWidgetId and existingWidgetId ~= widgetId then
        local existingWidget = widgets[existingWidgetId]
        
        if previousZone and existingWidget then
            -- Swap: move existing widget to where dragged widget came from
            zone.dockedWidget = nil
            previousZone.dockedWidget = nil
            
            -- Move existing widget to previous slot
            existingWidget.isDocked = true
            existingWidget.dockedSlot = previousZone.zoneIndex
            existingWidget.isInDrawer = previousZone.isDrawerZone or false
            previousZone.dockedWidget = existingWidgetId
            
            local existingFrame = existingWidget.frame
            if existingFrame then
                existingFrame:SetParent(previousZone)
                existingFrame:SetFrameStrata(previousZone.isDrawerZone and "DIALOG" or "BACKGROUND")
                existingFrame:ClearAllPoints()
                existingFrame:SetPoint("CENTER", previousZone, "CENTER", 0, 0)
                if existingWidget.onDock then
                    existingWidget.onDock(existingFrame, previousZone)
                end
            end
        else
            -- No previous slot, move existing widget to first available drawer slot
            self:MoveToDrawer(existingWidgetId)
        end
    elseif previousZone then
        -- Clear reference from previous zone
        previousZone.dockedWidget = nil
    end
    
    -- Dock the widget
    widget.isDocked = true
    widget.dockedSlot = zone.zoneIndex
    widget.isInDrawer = zone.isDrawerZone or false
    zone.dockedWidget = widgetId
    
    -- Re-parent and position the widget frame
    local widgetFrame = widget.frame
    if widgetFrame then
        widgetFrame:SetParent(zone)
        widgetFrame:SetFrameStrata(zone.isDrawerZone and "DIALOG" or "BACKGROUND")
        widgetFrame:ClearAllPoints()
        widgetFrame:SetPoint("CENTER", zone, "CENTER", 0, 0)
        
        if widget.onDock then
            widget.onDock(widgetFrame, zone)
        end
    end
    
    -- Save state after docking
    self:SaveToSavedVars()
    
    return true
end

--- Move a widget to the first available drawer slot
---@param widgetId string Widget ID
function WidgetManager:MoveToDrawer(widgetId)
    local widget = widgets[widgetId]
    if not widget then return false end
    
    -- Clear previous zone reference
    local previousZone = GetPreviousZone(widget)
    if previousZone then
        previousZone.dockedWidget = nil
    end
    
    -- Find first available drawer slot
    local drawerZones = addon.GetDrawerZones and addon.GetDrawerZones()
    if not drawerZones then return false end
    
    for i, zone in ipairs(drawerZones) do
        if not zone.dockedWidget then
            widget.isDocked = true
            widget.dockedSlot = zone.zoneIndex
            widget.isInDrawer = true
            zone.dockedWidget = widgetId
            
            local widgetFrame = widget.frame
            if widgetFrame then
                widgetFrame:SetParent(zone)
                widgetFrame:SetFrameStrata("DIALOG")
                widgetFrame:ClearAllPoints()
                widgetFrame:SetPoint("CENTER", zone, "CENTER", 0, 0)
                if widget.onDock then
                    widget.onDock(widgetFrame, zone)
                end
            end
            
            self:SaveToSavedVars()
            return true
        end
    end
    
    -- No drawer slots available - widget will be hidden
    widget.isDocked = false
    widget.dockedSlot = nil
    widget.isInDrawer = false
    if widget.frame then
        widget.frame:Hide()
    end
    
    self:SaveToSavedVars()
    return false
end

-- [ DRAG HANDLING ] -----------------------------------------------------------

local dragStartZone = nil  -- Track where widget started drag from

--- Check if a widget is currently being dragged
function WidgetManager:IsDragging()
    return draggedWidget ~= nil
end

--- Check if dragging is allowed (drawer must be open)
function WidgetManager:CanDrag()
    return addon.IsDrawerOpen and addon.IsDrawerOpen()
end

--- Called when widget drag starts
--- Returns true if drag is allowed, false if blocked
function WidgetManager:OnWidgetDragStart(widgetId)
    -- Only allow dragging when drawer is open
    if not self:CanDrag() then
        return false
    end
    
    draggedWidget = widgetId
    
    -- Remember original position for snap-back
    local widget = widgets[widgetId]
    dragStartZone = widget and GetPreviousZone(widget)
    
    -- Show dock zone highlights
    if statusDock and statusDock.widgetZones then
        for _, zone in ipairs(statusDock.widgetZones) do
            if zone and zone.border and zone:IsShown() then
                zone.border:Show()
            end
        end
    end
    
    -- Show drawer zone highlights
    local drawerZones = addon.GetDrawerZones and addon.GetDrawerZones()
    if drawerZones then
        for _, zone in ipairs(drawerZones) do
            if zone and zone.border then
                zone.border:Show()
            end
        end
    end
    
    return true
end

--- Called during widget drag to update zone highlighting
function WidgetManager:OnWidgetDragUpdate()
    if not draggedWidget then return end
    
    local zone = self:GetZoneAtCursor()
    
    -- Clear previous highlight
    if highlightedZone and highlightedZone ~= zone then
        highlightedZone.highlight:Hide()
        highlightedZone.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
    end
    
    -- Set new highlight
    if zone then
        zone.highlight:Show()
        zone.border:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0)
        highlightedZone = zone
    else
        highlightedZone = nil
    end
end

--- Called when widget drag ends
function WidgetManager:OnWidgetDragStop(widgetId)
    if not draggedWidget then return end
    
    local zone = self:GetZoneAtCursor()
    
    if zone then
        -- Dropped on a zone - dock it
        self:DockWidget(widgetId, zone)
    elseif dragStartZone then
        -- Dropped elsewhere - snap back to original position
        self:DockWidget(widgetId, dragStartZone)
    else
        -- No original position - move to drawer
        self:MoveToDrawer(widgetId)
    end
    
    -- Hide ALL dock zone borders
    if statusDock and statusDock.widgetZones then
        for _, z in ipairs(statusDock.widgetZones) do
            if z then
                z.highlight:Hide()
                z.border:Hide()
                z.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
            end
        end
    end
    
    -- Hide ALL drawer zone borders
    local drawerZones = addon.GetDrawerZones and addon.GetDrawerZones()
    if drawerZones then
        for _, z in ipairs(drawerZones) do
            if z then
                z.highlight:Hide()
                z.border:Hide()
                z.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
            end
        end
    end
    
    highlightedZone = nil
    draggedWidget = nil
    dragStartZone = nil
end

-- [ PERSISTENCE ] -------------------------------------------------------------

--- Save widget dock states to global saved variables
function WidgetManager:SaveToSavedVars()
    if not Orbit_StatusDB then Orbit_StatusDB = {} end
    
    local state = {}
    for id, widget in pairs(widgets) do
        state[id] = {
            isDocked = widget.isDocked,
            dockedSlot = widget.dockedSlot,
            isInDrawer = widget.isInDrawer,
        }
    end
    Orbit_StatusDB.widgetState = state
end

--- Load widget dock states from saved variables
function WidgetManager:LoadFromSavedVars()
    if not Orbit_StatusDB or not Orbit_StatusDB.widgetState then
        -- No saved state - move all widgets to drawer
        self:InitializeWidgetsToDrawer()
        return
    end
    
    local state = Orbit_StatusDB.widgetState
    for id, savedWidget in pairs(state) do
        local widget = widgets[id]
        if widget and savedWidget.isDocked and savedWidget.dockedSlot then
            local zone
            
            if savedWidget.isInDrawer then
                -- Restore to drawer zone
                local drawerZones = addon.GetDrawerZones and addon.GetDrawerZones()
                zone = drawerZones and drawerZones[savedWidget.dockedSlot]
            else
                -- Restore to dock zone
                zone = statusDock and statusDock.widgetZones and statusDock.widgetZones[savedWidget.dockedSlot]
            end
            
            if zone and zone:IsShown() then
                widget.isDocked = true
                widget.dockedSlot = savedWidget.dockedSlot
                widget.isInDrawer = savedWidget.isInDrawer
                zone.dockedWidget = id
                
                local widgetFrame = widget.frame
                if widgetFrame then
                    widgetFrame:SetParent(zone)
                    widgetFrame:SetFrameStrata(savedWidget.isInDrawer and "DIALOG" or "BACKGROUND")
                    widgetFrame:ClearAllPoints()
                    widgetFrame:SetPoint("CENTER", zone, "CENTER", 0, 0)
                    if widget.onDock then
                        widget.onDock(widgetFrame, zone)
                    end
                end
            else
                -- Zone not available - move to drawer
                self:MoveToDrawer(id)
            end
        else
            -- Not saved as docked - move to drawer
            self:MoveToDrawer(id)
        end
    end
    
    -- Handle any widgets not in saved state (new widgets)
    for id, widget in pairs(widgets) do
        if not state[id] then
            self:MoveToDrawer(id)
        end
    end
end

--- Initialize all widgets to drawer on first load
function WidgetManager:InitializeWidgetsToDrawer()
    for id, widget in pairs(widgets) do
        if not widget.isDocked then
            self:MoveToDrawer(id)
        end
    end
end

--- Initialize persistence (called after dock and widgets are ready)
function WidgetManager:InitPersistence()
    -- Give a small delay for all widgets to register
    C_Timer.After(0.3, function()
        self:LoadFromSavedVars()
    end)
end
