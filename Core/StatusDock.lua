-- StatusDock.lua
-- Main plugin file: Customizable status panel replacing Blizzard Status Bars

local addonName, addon = ...
local SD = addon.StatusData

-- Get Orbit reference (registered globally by Init.lua before dependencies load)
---@type Orbit
local Orbit = Orbit
if not Orbit then
    return
end

-- Get Engine reference for Edit Mode integration
local OrbitEngine = Orbit.Engine

-- Get LibSharedMedia for texture management
local LSM = LibStub("LibSharedMedia-3.0")

-- Cache frequently used globals
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------

local SYSTEM_ID = "Orbit_Status"

local Plugin = Orbit:RegisterPlugin("Status Dock", SYSTEM_ID, {
    defaults = {
        Height = 24,
        EdgeSize = 2,
        BackdropColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
        Position = "BOTTOM",  -- "BOTTOM" or "TOP"
        WidgetSlotCount = 5,  -- 3-12 widget drop zones
    },
}, Orbit.Constants and Orbit.Constants.PluginGroups and Orbit.Constants.PluginGroups.UI)

-- [ STATE ] -----------------------------------------------------------------------

local dock = nil
local blizzardBarsHidden = false

-- Current bar type: "XP", "REP", "HONOR" (auto-detected or scroll-selected)
local currentBarType = "XP"
local barTypeOrder = { "XP", "REP", "HONOR" }

-- [ HELPER FUNCTIONS ] ------------------------------------------------------------


local function IsTopPosition()
    local pos = Plugin:GetSetting(1, "Position") or "BOTTOM"
    return pos == "TOP"
end

-- [ BLIZZARD BAR MANAGEMENT ] -----------------------------------------------------

-- Hidden frame for parking Blizzard elements
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()
hiddenFrame:SetPoint("TOP", UIParent, "BOTTOM", 0, -1000)

local function HideBlizzardStatusBars()
    if blizzardBarsHidden then return end
    
    -- Hide MainStatusTrackingBarContainer (Status Bar 1 - XP/Rep)
    if MainStatusTrackingBarContainer then
        MainStatusTrackingBarContainer:SetParent(hiddenFrame)
        MainStatusTrackingBarContainer:ClearAllPoints()
        MainStatusTrackingBarContainer:SetPoint("CENTER", hiddenFrame, "CENTER", 0, 0)
    end
    
    -- Hide SecondaryStatusTrackingBarContainer (Status Bar 2)
    if SecondaryStatusTrackingBarContainer then
        SecondaryStatusTrackingBarContainer:SetParent(hiddenFrame)
        SecondaryStatusTrackingBarContainer:ClearAllPoints()
        SecondaryStatusTrackingBarContainer:SetPoint("CENTER", hiddenFrame, "CENTER", 0, 100)
    end
    
    -- Also hide the manager frame if needed
    if StatusTrackingBarManager then
        StatusTrackingBarManager:SetParent(hiddenFrame)
        StatusTrackingBarManager:ClearAllPoints()
        StatusTrackingBarManager:SetPoint("CENTER", hiddenFrame, "CENTER", 0, 200)
    end
    
    blizzardBarsHidden = true
end

local function RestoreBlizzardStatusBars()
    if not blizzardBarsHidden then return end
    
    -- Restore MainStatusTrackingBarContainer
    if MainStatusTrackingBarContainer then
        MainStatusTrackingBarContainer:SetParent(StatusTrackingBarManager or UIParent)
        MainStatusTrackingBarContainer:ClearAllPoints()
        MainStatusTrackingBarContainer:SetPoint("BOTTOM")
    end
    
    -- Restore SecondaryStatusTrackingBarContainer
    if SecondaryStatusTrackingBarContainer then
        SecondaryStatusTrackingBarContainer:SetParent(StatusTrackingBarManager or UIParent)
        SecondaryStatusTrackingBarContainer:ClearAllPoints()
        SecondaryStatusTrackingBarContainer:SetPoint("BOTTOM")
    end
    
    -- Restore manager
    if StatusTrackingBarManager then
        StatusTrackingBarManager:SetParent(UIParent)
        StatusTrackingBarManager:ClearAllPoints()
        StatusTrackingBarManager:SetPoint("BOTTOM")
    end
    
    blizzardBarsHidden = false
end

-- [ DOCK SIZING AND POSITIONING ] -------------------------------------------------

local function UpdateDockLayout()
    if not dock then return end
    
    local height = Plugin:GetSetting(1, "Height") or 24
    local screenWidth = GetScreenWidth()
    
    -- Always full width, custom height
    dock:SetSize(screenWidth, height)
    
    -- Position at TOP or BOTTOM (centered horizontally)
    dock:ClearAllPoints()
    
    if IsTopPosition() then
        dock:SetPoint("TOP", UIParent, "TOP", 0, 0)
    else
        dock:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    end
end

-- [ STATUS TRACKING ] -------------------------------------------------------------

local emptyStatusData = { type = nil, current = 0, max = 1, progress = 0, color = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 } }
local statusData = {
    type = nil,
    current = 0,
    max = 1,
    progress = 0,
    color = { r = 1, g = 1, b = 1, a = 1 },
}

local function UpdateStatusData()
    -- Get data based on current bar type
    local data
    if currentBarType == "XP" then
        data = SD.GetXPData()
    elseif currentBarType == "REP" then
        data = SD.GetReputationData()
    elseif currentBarType == "HONOR" then
        data = SD.GetHonorData()
    end
    
    -- If current type has no data, try fallback to one that does
    if not data then
        -- Try XP first (most common)
        data = SD.GetXPData()
        if data then
            currentBarType = "XP"
        else
            -- Try Rep
            data = SD.GetReputationData()
            if data then
                currentBarType = "REP"
            else
                -- Try Honor
                data = SD.GetHonorData()
                if data then
                    currentBarType = "HONOR"
                end
            end
        end
    end
    
    if data then
        statusData = data
    else
        statusData = emptyStatusData
    end
end

-- [ TOOLTIP ] ---------------------------------------------------------------------

local function ShowTooltip()
    if not dock or not statusData.type then return end
    
    -- Smart positioning: avoid tooltip covering important UI elements
    local _, cursorY = GetCursorPosition()
    local screenHeight = GetScreenHeight()
    local uiScale = UIParent:GetEffectiveScale()
    
    -- Normalize cursor position to screen height
    local normalizedY = cursorY / uiScale
    
    -- If cursor in top half of screen, show tooltip below (BOTTOMLEFT)
    -- If cursor in bottom half of screen, show tooltip above (TOPRIGHT)
    local anchor
    if normalizedY > (screenHeight / 2) then
        -- Top half: tooltip below and to left of cursor
        anchor = "ANCHOR_BOTTOMLEFT"
    else
        -- Bottom half: tooltip above and to right of cursor
        anchor = "ANCHOR_TOPRIGHT"
    end
    
    GameTooltip:SetOwner(dock, anchor, 0, 0)
    GameTooltip:ClearLines()
    
    if statusData.type == "XP" then
        local level = UnitLevel("player")
        local maxLevel = GetMaxLevelForPlayerExpansion()
        
        if level >= maxLevel then
            GameTooltip:AddLine("Experience")
            GameTooltip:AddLine("Max Level", 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("Experience")
            GameTooltip:AddLine(string.format("%d / %d XP", statusData.current, statusData.max), 1, 1, 1)
            
            local isRested = GetRestState() == 1
            if isRested then
                local exhaustion = GetXPExhaustion()
                if exhaustion then
                    GameTooltip:AddLine(string.format("Rested: %d XP", exhaustion), 0.0, 0.39, 0.88)
                end
            end
        end
    elseif statusData.type == "REP" then
        local watchedFactionData = C_Reputation.GetWatchedFactionData()
        if watchedFactionData then
            local factionName = watchedFactionData.name or "Reputation"
            GameTooltip:AddLine(factionName)
            
            -- Show standing level
            local standingText = _G["FACTION_STANDING_LABEL"..watchedFactionData.reaction] or "Unknown"
            GameTooltip:AddLine(standingText, 0.5, 0.5, 0.5)
            
            GameTooltip:AddLine(string.format("%d / %d", statusData.current, statusData.max), 1, 1, 1)
        end
    elseif statusData.type == "HONOR" then
        local level = UnitHonorLevel("player")
        GameTooltip:AddLine("Honor")
        GameTooltip:AddLine(string.format("Level %d", level), 0.5, 0.5, 0.5)
        GameTooltip:AddLine(string.format("%d / %d", statusData.current, statusData.max), 1, 1, 1)
    end
    
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- [ BACKDROP AND EDGE STYLING ] ---------------------------------------------------

local function UpdateBackdrop()
    if not dock then return end
    
    local color = Plugin:GetSetting(1, "BackdropColor") or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    
    dock.backdrop:SetColorTexture(color.r, color.g, color.b, color.a)
end

local function UpdateEdgeTexture()
    if not dock or not dock.edgeBackground or not dock.edgeFill then return end
    
    -- Edge Size (for fill texture) from plugin settings
    local edgeSize = Plugin:GetSetting(1, "EdgeSize") or 2
    
    -- Background size from global border size
    local backgroundSize = (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize) or 2
    
    -- Get pixel-perfect sizes
    if Orbit.Engine and Orbit.Engine.Pixel then
        edgeSize = Orbit.Engine.Pixel:Snap(edgeSize, dock:GetEffectiveScale())
        backgroundSize = Orbit.Engine.Pixel:Snap(backgroundSize, dock:GetEffectiveScale())
    end
    
    -- Position edges on the inner side (facing screen center)
    dock.edgeBackground:ClearAllPoints()
    dock.edgeFill:ClearAllPoints()
    
    if IsTopPosition() then
        -- Edge at BOTTOM of bar (facing center)
        dock.edgeBackground:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
        dock.edgeBackground:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
        dock.edgeBackground:SetHeight(backgroundSize)  -- Uses global BorderSize
        
        dock.edgeFill:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
        dock.edgeFill:SetHeight(edgeSize)  -- Uses EdgeSize setting
    else
        -- Edge at TOP of bar (facing center)
        dock.edgeBackground:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
        dock.edgeBackground:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0)
        dock.edgeBackground:SetHeight(backgroundSize)  -- Uses global BorderSize
        
        dock.edgeFill:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
        dock.edgeFill:SetHeight(edgeSize)  -- Uses EdgeSize setting
    end
    
    -- Update status data
    UpdateStatusData()
    
    -- Get global status bar texture from Orbit settings
    local textureKey = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture or "Melli"
    local texturePath = LSM:Fetch("statusbar", textureKey)
    
    -- Check if we have status data to display
    if not statusData.type then
        -- No data available, show solid black bar
        dock.edgeBackground:Show()
        dock.edgeFill:Hide()
        dock.edgeBackground:SetColorTexture(0, 0, 0, 1)  -- Solid black
    else
        -- Show animated progress bar
        dock.edgeBackground:Show()
        dock.edgeFill:Show()
        
        -- Background (solid black - unfilled portion)
        dock.edgeBackground:SetColorTexture(0, 0, 0, 1)  -- Solid black
        
        -- Fill (progress portion with texture)
        local fillWidth = dock:GetWidth() * statusData.progress
        dock.edgeFill:SetWidth(fillWidth)
        dock.edgeFill:SetTexture(texturePath)
        dock.edgeFill:SetTexCoord(0, statusData.progress, 0, 1)
        
        local c = statusData.color
        dock.edgeFill:SetVertexColor(c.r, c.g, c.b, c.a)
    end
end

-- [ WIDGET DROP ZONES ] -----------------------------------------------------------

local isEditModeActive = false
local isDraggingWidget = false

local function CreateWidgetZone(index)
    local zone = CreateFrame("Frame", "OrbitStatusDockZone" .. index, dock)
    zone:SetFrameLevel(dock:GetFrameLevel() + 1)
    zone.zoneIndex = index
    zone.dockedWidget = nil
    
    -- Drop zone highlight
    zone.highlight = zone:CreateTexture(nil, "OVERLAY")
    zone.highlight:SetAllPoints()
    zone.highlight:SetColorTexture(0, 0.8, 1, 0.2)
    zone.highlight:Hide()
    
    -- Dashed Border for Edit Mode
    zone.border = CreateFrame("Frame", nil, zone, "BackdropTemplate")
    zone.border:SetAllPoints()
    zone.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    zone.border:SetBackdropBorderColor(0, 0.8, 1, 0.5)
    zone.border:Hide()
    
    zone.Label = zone.border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zone.Label:SetPoint("CENTER")
    zone.Label:SetText("Drop")

    return zone
end

local function UpdateWidgetZoneLayout()
    if not dock or not dock.widgetZones then return end
    
    local slotCount = Plugin:GetSetting(1, "WidgetSlotCount") or 5
    local padding = 8
    local drawerButtonWidth = 8
    local dockWidth = dock:GetWidth()
    local dockHeight = dock:GetHeight()
    local availableWidth = dockWidth - drawerButtonWidth - padding
    local totalPadding = padding * slotCount
    local slotWidth = (availableWidth - totalPadding) / slotCount
    local slotHeight = dockHeight - 4
    
    -- Create or hide zones based on slot count
    for i = 1, 12 do
        if i <= slotCount then
            if not dock.widgetZones[i] then
                dock.widgetZones[i] = CreateWidgetZone(i)
            end
            
            local zone = dock.widgetZones[i]
            zone:SetSize(slotWidth, slotHeight)
            zone:ClearAllPoints()
            zone:SetPoint("LEFT", dock, "LEFT", drawerButtonWidth + padding + (i - 1) * (slotWidth + padding), 0)
            zone:Show()
            
            -- Borders are hidden by default - only shown during widget drag
            zone.border:Hide()
            
            -- Resize docked widget if present
            if zone.dockedWidget and addon.WidgetManager and addon.WidgetManager.GetWidget then
                local widget = addon.WidgetManager:GetWidget(zone.dockedWidget)
                if widget and widget.frame and widget.onDock then
                    widget.onDock(widget.frame, zone)
                end
            end
        elseif dock.widgetZones[i] then
            -- Zone is being hidden - move any docked widget to drawer
            local zone = dock.widgetZones[i]
            if zone.dockedWidget and addon.WidgetManager then
                addon.WidgetManager:MoveToDrawer(zone.dockedWidget)
            end
            zone:Hide()
        end
    end
end

local function SetZoneHighlight(zoneIndex, show)
    if not dock or not dock.widgetZones then return end
    local zone = dock.widgetZones[zoneIndex]
    if zone and zone.highlight then
        if show then
            zone.highlight:Show()
            zone.border:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0)  -- Cyan highlight
        else
            zone.highlight:Hide()
            zone.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)  -- Default
        end
    end
end

local function ClearAllZoneHighlights()
    if not dock or not dock.widgetZones then return end
    for i = 1, 12 do
        SetZoneHighlight(i, false)
    end
end

local function GetZoneAtPoint(x, y)
    if not dock or not dock.widgetZones then return nil end
    local slotCount = Plugin:GetSetting(1, "WidgetSlotCount") or 5
    
    for i = 1, slotCount do
        local zone = dock.widgetZones[i]
        if zone and zone:IsShown() then
            local left, bottom, width, height = zone:GetRect()
            if left and x >= left and x <= left + width and y >= bottom and y <= bottom + height then
                return zone
            end
        end
    end
    return nil
end

local function CreateWidgetZones()
    if not dock then return end
    
    dock.widgetZones = dock.widgetZones or {}
    UpdateWidgetZoneLayout()
end

-- [ WIDGET DRAWER ] ---------------------------------------------------------------

local drawerPanel = nil
local drawerButton = nil

local MIN_DRAWER_ZONES = 12
local DRAWER_COLS = 4
local DRAWER_ZONE_WIDTH = 90
local DRAWER_ZONE_HEIGHT = 24
local DRAWER_INNER_PAD = 10
local DRAWER_OUTER_PAD = 20
local DRAWER_BOTTOM_PAD = 20
local DRAWER_HEADER_HEIGHT = 40

local function GetDrawerZoneCount()
    local wm = addon.WidgetManager
    local widgetCount = wm and wm.GetWidgetCount and wm:GetWidgetCount() or MIN_DRAWER_ZONES
    return math.max(widgetCount, MIN_DRAWER_ZONES)
end

local function CreateDrawerZone(index)
    local zone = CreateFrame("Frame", "OrbitStatusDrawerZone" .. index, drawerPanel)
    zone:SetFrameLevel(drawerPanel:GetFrameLevel() + 1)
    zone.zoneIndex = index
    zone.isDrawerZone = true  -- Flag to distinguish from dock zones
    zone.dockedWidget = nil
    
    -- Drop zone highlight
    zone.highlight = zone:CreateTexture(nil, "OVERLAY")
    zone.highlight:SetAllPoints()
    zone.highlight:SetColorTexture(1, 1, 1, 0.15)
    zone.highlight:Hide()
    
    -- Border
    zone.border = CreateFrame("Frame", nil, zone, "BackdropTemplate")
    zone.border:SetAllPoints()
    zone.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    zone.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
    zone.border:Hide()
    
    return zone
end

local function UpdateDrawerLayout()
    if not drawerPanel or not drawerPanel.zones then return end

    local zoneCount = #drawerPanel.zones
    local rows = math.ceil(zoneCount / DRAWER_COLS)
    local panelWidth = (DRAWER_ZONE_WIDTH * DRAWER_COLS) + (DRAWER_INNER_PAD * (DRAWER_COLS - 1)) + (DRAWER_OUTER_PAD * 2)
    local panelHeight = DRAWER_HEADER_HEIGHT + (DRAWER_ZONE_HEIGHT * rows) + (DRAWER_INNER_PAD * (rows - 1)) + DRAWER_OUTER_PAD + DRAWER_BOTTOM_PAD

    drawerPanel:SetSize(panelWidth, panelHeight)

    for i, zone in ipairs(drawerPanel.zones) do
        local col = ((i - 1) % DRAWER_COLS)
        local row = math.floor((i - 1) / DRAWER_COLS)
        zone:SetSize(DRAWER_ZONE_WIDTH, DRAWER_ZONE_HEIGHT)
        zone:ClearAllPoints()
        zone:SetPoint("TOPLEFT", drawerPanel, "TOPLEFT",
            DRAWER_OUTER_PAD + col * (DRAWER_ZONE_WIDTH + DRAWER_INNER_PAD),
            -DRAWER_HEADER_HEIGHT - DRAWER_OUTER_PAD - row * (DRAWER_ZONE_HEIGHT + DRAWER_INNER_PAD))
        zone:Show()
        zone.border:Hide()
    end
end

local function CreateDrawerPanel()
    if drawerPanel then return drawerPanel end
    
    -- Create drawer panel using Orbit's dialog styling
    drawerPanel = CreateFrame("Frame", "OrbitStatusDrawer", UIParent)
    drawerPanel:SetFrameStrata("DIALOG")
    drawerPanel:SetFrameLevel(100)
    drawerPanel:SetClampedToScreen(true)
    
    -- Register for ESC key closing
    tinsert(UISpecialFrames, "OrbitStatusDrawer")
    
    -- Metallic nine-slice border matching Orbit/Blizzard dialogs
    drawerPanel.Border = CreateFrame("Frame", nil, drawerPanel, "DialogBorderTranslucentTemplate")
    drawerPanel.Border:SetAllPoints(drawerPanel)
    drawerPanel.Border:SetFrameLevel(drawerPanel:GetFrameLevel())
    
    -- Title text
    drawerPanel.header = drawerPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    drawerPanel.header:SetPoint("TOP", drawerPanel, "TOP", 0, -15)
    drawerPanel.header:SetText("Widget Drawer")
    
    -- Close button (X button matching Orbit dialogs)
    drawerPanel.CloseButton = CreateFrame("Button", nil, drawerPanel, "UIPanelCloseButton")
    drawerPanel.CloseButton:SetPoint("TOPRIGHT", drawerPanel, "TOPRIGHT", -2, -2)
    drawerPanel.CloseButton:SetScript("OnClick", function()
        drawerPanel:Hide()
    end)
    
    drawerPanel.zones = {}
    local zoneCount = GetDrawerZoneCount()
    for i = 1, zoneCount do
        drawerPanel.zones[i] = CreateDrawerZone(i)
    end
    
    UpdateDrawerLayout()
    
    -- Enable/disable drawer widgets when drawer shows/hides to save resources
    drawerPanel:SetScript("OnShow", function()
        if addon.WidgetManager then
            addon.WidgetManager:EnableDrawerWidgets()
        end
    end)
    
    drawerPanel:SetScript("OnHide", function()
        if addon.WidgetManager then
            addon.WidgetManager:DisableDrawerWidgets()
        end
    end)
    
    -- Drawer starts hidden, so disable drawer widgets initially
    drawerPanel:Hide()
    if addon.WidgetManager then
        addon.WidgetManager:DisableDrawerWidgets()
    end
    
end

local function CreateDrawerButton()
    if drawerButton then return drawerButton end
    if not dock then return nil end
    drawerButton = CreateFrame("Button", "OrbitStatusDrawerButton", dock)
    drawerButton:SetWidth(16)
    drawerButton:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
    drawerButton:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
    drawerButton:SetFrameLevel(dock:GetFrameLevel() + 10)
    drawerButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Widget Drawer")
        GameTooltip:Show()
    end)
    drawerButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    drawerButton:SetScript("OnClick", function()
        if addon.ToggleDrawer then addon.ToggleDrawer() end
    end)
    return drawerButton
end

local function ShowDropTargets(show)
    if not dock or not dock.widgetZones then return end
    for _, zone in ipairs(dock.widgetZones) do
        if show then
            zone.border:Show()
            zone.highlight:Show()
        else
            zone.border:Hide()
            zone.highlight:Hide()
        end
    end
end

local function ToggleDrawer(show)
    if not drawerPanel then CreateDrawerPanel() end
    if show == nil then show = not drawerPanel:IsShown() end
    if show then
        local isTop = IsTopPosition()
        drawerPanel:ClearAllPoints()
        if isTop then
            drawerPanel:SetPoint("TOPLEFT", dock, "BOTTOMLEFT", 0, -4)
        else
            drawerPanel:SetPoint("BOTTOMLEFT", dock, "TOPLEFT", 0, 4)
        end
        drawerPanel:Show()
    else
        drawerPanel:Hide()
    end
end

addon.GetDrawerPanel = function() return drawerPanel end
addon.GetDrawerZones = function() return drawerPanel and drawerPanel.zones end
addon.ToggleDrawer = ToggleDrawer
addon.IsDrawerOpen = function() return drawerPanel and drawerPanel:IsShown() end

addon.GrowDrawer = function(targetCount)
    if not drawerPanel then CreateDrawerPanel() end
    local zones = drawerPanel.zones
    local needed = math.max(targetCount, MIN_DRAWER_ZONES)
    if #zones >= needed then return end
    for i = #zones + 1, needed do
        zones[i] = CreateDrawerZone(i)
    end
    UpdateDrawerLayout()
end

addon.GetDrawerZoneCount = function() return drawerPanel and #drawerPanel.zones or 0 end

-- [ REFRESH LOGIC ] ---------------------------------------------------------------

local function RefreshDock()
    if not dock then return end
    
    -- Use Orbit's SafeAction for combat protection
    Orbit:SafeAction(function()
        UpdateDockLayout()
        UpdateBackdrop()
        UpdateEdgeTexture()
        CreateWidgetZones()
        CreateDrawerButton()
        CreateDrawerPanel()
        
        -- Update all widgets with current settings (e.g. text size)
        if addon.WidgetManager and addon.WidgetManager.UpdateAllWidgets then
            local textSize = Plugin:GetSetting(1, "TextSize") or 12
            addon.WidgetManager:UpdateAllWidgets(textSize)
        end
        
        -- Always hide Blizzard bars
        HideBlizzardStatusBars()
    end)
end

-- [ DOCK CREATION ] ---------------------------------------------------------------

local function CreateDock()
    local frame = CreateFrame("Frame", "OrbitStatusDock", UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)
    
    -- Backdrop texture
    frame.backdrop = frame:CreateTexture(nil, "BACKGROUND")
    frame.backdrop:SetAllPoints()
    frame.backdrop:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Edge textures (animated progress bars)
    -- Background texture (shows empty portion)
    frame.edgeBackground = frame:CreateTexture(nil, "BORDER")
    frame.edgeBackground:SetColorTexture(0.3, 0.3, 0.3, 1.0)
    
    -- Fill texture (shows progress portion)
    frame.edgeFill = frame:CreateTexture(nil, "ARTWORK")
    frame.edgeFill:SetColorTexture(1, 1, 1, 1)
    
    frame:SetMovable(false)
    frame:Show()
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", ShowTooltip)
    frame:SetScript("OnLeave", HideTooltip)
    
    -- Mouse wheel to cycle bar types
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        -- Find current index
        local currentIndex = 1
        for i, barType in ipairs(barTypeOrder) do
            if barType == currentBarType then
                currentIndex = i
                break
            end
        end
        
        -- Cycle through types (delta > 0 = up = next, delta < 0 = down = prev)
        if delta > 0 then
            currentIndex = currentIndex + 1
            if currentIndex > #barTypeOrder then
                currentIndex = 1
            end
        else
            currentIndex = currentIndex - 1
            if currentIndex < 1 then
                currentIndex = #barTypeOrder
            end
        end
        
        currentBarType = barTypeOrder[currentIndex]
        UpdateEdgeTexture()
    end)
    
    return frame
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function Plugin:OnLoad()
    -- Create the dock frame
    dock = CreateDock()
    self.frame = dock
    
    -- Initial sizing and positioning
    UpdateDockLayout()
    
    -- Ensure frame is visible
    dock:Show()
    
    -- Register for Edit Mode selection and settings (for settings panel access)
    dock.editModeName = "Status Dock"
    dock.systemIndex = 1
    dock.orbitNoDrag = true  -- Prevent dragging - position is settings-only
    dock.disableMovement = true  -- Tell Orbit not to enable SetMovable on selection
    dock.orbitNoSnap = true  -- Prevent anchoring to/from this frame
    
    -- Attach to Orbit's Edit Mode selection system
    if OrbitEngine and OrbitEngine.Frame then
        OrbitEngine.Frame:AttachSettingsListener(dock, self, 1)
    end
    
    -- Event handling for screen size changes and status tracking
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    self.eventFrame:RegisterEvent("UI_SCALE_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
    self.eventFrame:RegisterEvent("UPDATE_FACTION")
    self.eventFrame:RegisterEvent("HONOR_XP_UPDATE")
    self.eventFrame:RegisterEvent("UPDATE_EXHAUSTION")  -- Rested state changes
    
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
            -- Screen size changed - update dock to fill screen
            RefreshDock()
        elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" then
            -- XP or rested state changed - switch to XP bar
            currentBarType = "XP"
            UpdateEdgeTexture()
        elseif event == "UPDATE_FACTION" then
            -- Reputation changed - switch to Rep bar
            currentBarType = "REP"
            UpdateEdgeTexture()
        elseif event == "HONOR_XP_UPDATE" then
            -- Honor changed - switch to Honor bar
            currentBarType = "HONOR"
            UpdateEdgeTexture()
        end
    end)
    
    self:RegisterStandardEvents()
    
    -- Listen for Edit Mode enter/exit to show/hide zone borders
    if Orbit.EventBus then
        Orbit.EventBus:On("EDIT_MODE_ENTERED", function()
            isEditModeActive = true
            UpdateWidgetZoneLayout()
        end, Plugin)
        Orbit.EventBus:On("EDIT_MODE_EXITED", function()
            isEditModeActive = false
            ClearAllZoneHighlights()
            UpdateWidgetZoneLayout()
        end, Plugin)
    end
    
    -- Connect to WidgetManager (widgets load after this)
    C_Timer.After(0.1, function()
        if addon.WidgetManager then
            addon.WidgetManager:SetDock(dock)
            -- Restore widget positions from saved variables
            addon.WidgetManager:InitPersistence()
        end
    end)
    
    -- Initial refresh
    RefreshDock()
end

function Plugin:ApplySettings()
    if not dock then return end
    RefreshDock()
end

function Plugin:OnUnload()
    RestoreBlizzardStatusBars()
end

-- [ SETTINGS UI ] -----------------------------------------------------------------

function Plugin:AddSettings(dialog, systemFrame)
    local schema = {
        controls = {
            { 
                type = "dropdown", 
                key = "Position", 
                label = "Position", 
                options = {
                    { value = "BOTTOM", text = "Bottom" },
                    { value = "TOP", text = "Top" },
                },
                default = "BOTTOM" 
            },
            { type = "slider", key = "Height", label = "Panel Height", min = 20, max = 32, step = 2, default = 24 },
            { type = "slider", key = "EdgeSize", label = "Status Bar Height", min = 1, max = 8, step = 1, default = 2 },
            { type = "slider", key = "WidgetSlotCount", label = "Widget Slots", min = 3, max = 12, step = 1, default = 5 },
            { type = "slider", key = "TextSize", label = "Text Size", min = 8, max = 24, step = 1, default = 12 },
            { type = "color", key = "BackdropColor", label = "Background Color", default = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 } },
        },
    }
    
    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- Export for debugging
addon.StatusDock = Plugin
