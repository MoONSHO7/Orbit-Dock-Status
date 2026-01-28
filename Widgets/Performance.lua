-- Performance.lua
-- Performance Info widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]----------------------------------------------------------------

local COLORS = {
    WHITE = "|cffffffff",
    RED = "|cffff0000",
    ORANGE = "|cfffea300",
    GREEN = "|cff00ff00",
}

-- [ WIDGET CREATION ]----------------------------------------------------------

local PerformanceWidget = {}
addon.PerformanceWidget = PerformanceWidget

local widgetFrame = nil
local timer = nil

local function UpdateStats()
    if not widgetFrame or not widgetFrame:IsVisible() then return end
    
    -- FPS
    local fps = GetFramerate()
    local fpsStr = math.floor(fps)
    local fpsColor = COLORS.WHITE
    
    if fps < 30 then
        fpsColor = COLORS.RED
    elseif fps <= 60 then
        fpsColor = COLORS.ORANGE
    end
    
    -- Latency
    local _, _, latencyHome = GetNetStats()
    local ms = latencyHome
    local msColor = COLORS.WHITE
    
    if ms <= 60 then
        msColor = COLORS.GREEN
    elseif ms < 200 then
        msColor = COLORS.ORANGE
    else
        msColor = COLORS.RED
    end
    
    local text = string.format("%s%d|r%sfps|r | %s%d|r%sms|r", 
        fpsColor, fpsStr, COLORS.WHITE, msColor, ms, COLORS.WHITE)
    
    widgetFrame.Text:SetText(text)
    
    -- Auto-resize to fit text
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function StartLoop()
    if timer then timer:Cancel() end
    timer = C_Timer.NewTicker(1, UpdateStats)
    UpdateStats()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusPerformanceWidget", UIParent)
    f:SetSize(100, 20)
    f:SetClampedToScreen(true)
    f.systemIndex = "StatusDock_Performance"
    f.editModeName = "Performance"
    
    -- Text display
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    
    -- Apply global font
    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = 12,
        })
    end
    
    -- Orbit Anchoring options
    f.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
    }
    
    -- No default position - WidgetManager will place in drawer or dock
    
    -- Make draggable in Edit Mode
    f:SetMovable(true)
    f:EnableMouse(true)
    
    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Performance", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        local fps = GetFramerate()
        local _, _, homeLat, worldLat = GetNetStats()
        GameTooltip:AddDoubleLine("FPS:", string.format("%.1f", fps), 0.7, 0.7, 0.7, 0, 1, 0)
        GameTooltip:AddDoubleLine("Home Latency:", string.format("%dms", homeLat), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("World Latency:", string.format("%dms", worldLat), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    f:SetScript("OnDragStart", function(self)
        local WidgetManager = addon.WidgetManager
        
        -- Check if dragging is allowed (drawer must be open)
        if not WidgetManager or not WidgetManager:OnWidgetDragStart("Performance") then
            return  -- Block drag if drawer isn't open
        end
        
        -- Re-parent to UIParent so we can drag freely (even if docked)
        self:SetParent(UIParent)
        self:SetFrameStrata("TOOLTIP")  -- Ensure it's on top while dragging
        self:StartMoving()
        
        -- Update zone highlighting during drag
        if not widgetFrame.dragTicker then
            widgetFrame.dragTicker = C_Timer.NewTicker(0.05, function()
                local WM = addon.WidgetManager
                if WM then
                    WM:OnWidgetDragUpdate()
                end
            end)
        end
    end)
    
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
        if widgetFrame.dragTicker then
            widgetFrame.dragTicker:Cancel()
            widgetFrame.dragTicker = nil
        end
        
        local WidgetManager = addon.WidgetManager
        if WidgetManager then
            WidgetManager:OnWidgetDragStop("Performance")
        end
    end)
    
    -- Register for Edit Mode dragging
    f:RegisterForDrag("LeftButton")
    
    return f
end

function PerformanceWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    -- Register with WidgetManager
    local WidgetManager = addon.WidgetManager
    if WidgetManager then
        WidgetManager:Register("Performance", {
            name = "Performance",
            frame = widgetFrame,
            onDock = function(f, zone)
                -- Adjust size to fit zone if needed
                f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2)
            end,
            onUndock = function(f)
                -- Restore normal size
                UpdateStats()
            end,
            onEnable = function(f)
                -- Resume stats ticker when drawer opens
                StartLoop()
            end,
            onDisable = function(f)
                -- Stop stats ticker when drawer closes to save resources
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

-- Initialize on PLAYER_LOGIN
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    -- Delay to ensure WidgetManager is loaded
    C_Timer.After(0.5, function()
        PerformanceWidget:OnLoad()
    end)
end)
