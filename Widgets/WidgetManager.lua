-- WidgetManager.lua
-- Central registry and management for StatusDock widgets
-- Features: Dynamic Grid Drawer, Drag & Drop Ghosting, Categorization

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local WidgetManager = {}
addon.WidgetManager = WidgetManager

-- [ STATE ] -------------------------------------------------------------------

local widgets = {}
local dockFrame = nil
local drawerFrame = nil
local draggedWidget = nil
local ghostFrame = nil

local CATEGORIES = {
    "Character", "Combat", "Economy", "World", "System", "Social", "Other"
}

-- [ REGISTRATION ] ------------------------------------------------------------

function WidgetManager:CreateWidget(name)
    if not addon.BaseWidget then return nil end
    return addon.BaseWidget:New(name)
end

function WidgetManager:Register(id, widgetData)
    if widgets[id] then return end
    
    widgets[id] = {
        id = id,
        name = widgetData.name or id,
        category = widgetData.category or "Other",
        frame = widgetData.frame,
        -- Callbacks
        onDock = widgetData.onDock,
        onUndock = widgetData.onUndock,
        onEnable = widgetData.onEnable,
        onDisable = widgetData.onDisable,
        -- State
        isDocked = false,
        dockedSlot = nil,
    }
    
    -- Refresh Drawer if open
    if self:IsDrawerOpen() then self:RefreshDrawer() end
end

function WidgetManager:SetDock(dock)
    dockFrame = dock
end

function WidgetManager:GetWidget(id) return widgets[id] end
function WidgetManager:GetAllWidgets() return widgets end

-- [ DRAWER LAYOUT ] -----------------------------------------------------------

function WidgetManager:GetDrawer()
    if drawerFrame then return drawerFrame end

    local f = CreateFrame("Frame", "OrbitStatusDrawer", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetSize(600, 400)
    f:SetPoint("CENTER")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()

    -- Styling (Modern Dark)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Header
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.Title:SetPoint("TOPLEFT", 15, -15)
    f.Title:SetText("Widget Drawer")

    f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.Close:SetPoint("TOPRIGHT", -5, -5)

    -- ScrollFrame
    f.Scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.Scroll:SetPoint("TOPLEFT", 20, -50)
    f.Scroll:SetPoint("BOTTOMRIGHT", -40, 20)

    f.Content = CreateFrame("Frame", nil, f.Scroll)
    f.Content:SetSize(540, 1) -- Height dynamic
    f.Scroll:SetScrollChild(f.Content)

    drawerFrame = f
    return f
end

function WidgetManager:RefreshDrawer()
    local drawer = self:GetDrawer()
    local content = drawer.Content

    -- Clear current children (hide them)
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
    end

    local yOffset = 0
    local padding = 10
    local slotWidth = 120
    local slotHeight = 30
    local cols = 4

    -- Group by Category
    local byCat = {}
    for _, cat in ipairs(CATEGORIES) do byCat[cat] = {} end

    for id, w in pairs(widgets) do
        if not w.isDocked then
            local cat = w.category
            if not byCat[cat] then cat = "Other" end
            table.insert(byCat[cat], w)
        end
    end
    
    -- Render
    for _, cat in ipairs(CATEGORIES) do
        local list = byCat[cat]
        if list and #list > 0 then
            -- Header
            local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPLEFT", 0, -yOffset)
            header:SetText(cat)
            header:Show()
            yOffset = yOffset + 20

            -- Grid
            for i, w in ipairs(list) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)

                -- Reparent widget frame to drawer content
                if w.frame then
                    w.frame:SetParent(content)
                    w.frame:ClearAllPoints()
                    w.frame:SetPoint("TOPLEFT", col * (slotWidth + padding), -yOffset - (row * (slotHeight + padding)))
                    w.frame:SetSize(slotWidth, slotHeight)
                    w.frame:Show()

                    -- Reset to "Drawer Mode" look?
                    if w.onUndock then w.onUndock(w.frame) end
                end
            end

            local rows = math.ceil(#list / cols)
            yOffset = yOffset + (rows * (slotHeight + padding)) + 10
        end
    end
    
    content:SetHeight(yOffset)
end

function WidgetManager:ToggleDrawer()
    local drawer = self:GetDrawer()
    if drawer:IsShown() then
        drawer:Hide()
    else
        self:RefreshDrawer()
        drawer:Show()
    end
end

function WidgetManager:IsDrawerOpen()
    return drawerFrame and drawerFrame:IsShown()
end

-- [ DRAG AND DROP ] -----------------------------------------------------------

function WidgetManager:CreateGhost()
    if ghostFrame then return ghostFrame end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(100, 25)
    f:SetFrameStrata("TOOLTIP")
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0.8, 1, 0.5) -- Cyan
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("CENTER")
    f:Hide()
    ghostFrame = f
    return f
end

function WidgetManager:OnWidgetDragStart(id)
    local w = widgets[id]
    if not w then return end
    
    draggedWidget = w
    
    -- Show Ghost
    local ghost = self:CreateGhost()
    ghost.text:SetText(w.name)
    ghost:SetSize(w.frame:GetWidth(), w.frame:GetHeight())
    ghost:Show()

    -- Start following mouse
    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 10, (y / scale) - 10)
    end)
    
    -- Hide original frame mostly
    w.frame:SetAlpha(0.3)
    
    -- Show Dock Drop Targets
    if dockFrame and dockFrame.ShowDropTargets then
        dockFrame:ShowDropTargets(true)
    end
    
    return true
end

function WidgetManager:OnWidgetDragUpdate()
    -- Ghost handles position in OnUpdate
end

function WidgetManager:OnWidgetDragStop(id)
    if not draggedWidget then return end
    
    local ghost = self:CreateGhost()
    ghost:Hide()
    ghost:SetScript("OnUpdate", nil)
    
    draggedWidget.frame:SetAlpha(1)
    
    if dockFrame and dockFrame.ShowDropTargets then
        dockFrame:ShowDropTargets(false)
    end
    
    -- Check for Drop Target
    local droppedZone = self:GetZoneAtCursor()

    if droppedZone then
        self:DockWidget(draggedWidget.id, droppedZone)
    else
        -- Dropped in void -> Undock/Return to Drawer
        self:UndockWidget(draggedWidget.id)
    end
    
    draggedWidget = nil
    self:RefreshDrawer()
end

function WidgetManager:GetZoneAtCursor()
    if not dockFrame or not dockFrame.widgetZones then return nil end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    
    for i, zone in ipairs(dockFrame.widgetZones) do
        if zone:IsShown() then
            local left, bottom, width, height = zone:GetRect()
            if left and x >= left and x <= (left + width) and y >= bottom and y <= (bottom + height) then
                return zone
            end
        end
    end
    return nil
end

function WidgetManager:DockWidget(id, zone)
    local w = widgets[id]
    if not w then return end
    
    -- If zone occupied, swap
    if zone.dockedWidget and zone.dockedWidget ~= id then
        self:UndockWidget(zone.dockedWidget) -- For now, just kick existing back to drawer. Swap logic is complex.
    end
    
    -- Undock from previous if any
    if w.isDocked and w.dockedSlot then
        dockFrame.widgetZones[w.dockedSlot].dockedWidget = nil
    end

    w.isDocked = true
    w.dockedSlot = zone.zoneIndex
    zone.dockedWidget = id

    w.frame:SetParent(zone)
    w.frame:ClearAllPoints()
    w.frame:SetPoint("CENTER")

    if w.onDock then w.onDock(w.frame, zone) end

    self:SaveState()
end

function WidgetManager:UndockWidget(id)
    local w = widgets[id]
    if not w then return end
    
    if w.isDocked and w.dockedSlot and dockFrame.widgetZones then
        local zone = dockFrame.widgetZones[w.dockedSlot]
        if zone then zone.dockedWidget = nil end
    end
    
    w.isDocked = false
    w.dockedSlot = nil
    
    if w.onUndock then w.onUndock(w.frame) end
    
    self:SaveState()
end

-- [ PERSISTENCE ] -------------------------------------------------------------

function WidgetManager:SaveState()
    if not Orbit_StatusDB then Orbit_StatusDB = {} end
    local state = {}
    for id, w in pairs(widgets) do
        if w.isDocked then
            state[id] = w.dockedSlot
        end
    end
    Orbit_StatusDB.layout = state
end

function WidgetManager:LoadState()
    if not Orbit_StatusDB or not Orbit_StatusDB.layout then return end

    for id, slot in pairs(Orbit_StatusDB.layout) do
        if dockFrame and dockFrame.widgetZones and dockFrame.widgetZones[slot] then
            self:DockWidget(id, dockFrame.widgetZones[slot])
        end
    end
end

function WidgetManager:InitPersistence()
    C_Timer.After(0.5, function() self:LoadState() end)
end
