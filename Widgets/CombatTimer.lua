-- CombatTimer.lua
-- Combat Timer widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local OrbitEngine = Orbit.Engine

-- [ WIDGET CREATION ]----------------------------------------------------------

local CombatTimerWidget = {}
addon.CombatTimerWidget = CombatTimerWidget

local widgetFrame = nil
local timer = nil
local startTime = nil
local inCombat = false

local function UpdateTimer()
    if not widgetFrame then return end
    
    if not startTime then
        widgetFrame.Text:SetText("0:00")
        widgetFrame.Text:SetTextColor(1, 1, 1)  -- White when not in combat
        return
    end
    
    local duration = GetTime() - startTime
    local minutes = math.floor(duration / 60)
    local seconds = math.floor(duration % 60)
    
    widgetFrame.Text:SetText(string.format("%d:%02d", minutes, seconds))
    widgetFrame.Text:SetTextColor(1, 0.3, 0.3)  -- Red when in combat
    
    -- Auto-resize to fit text
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 8, 20)
end

local function StartLoop()
    if timer then timer:Cancel() end
    timer = C_Timer.NewTicker(0.1, UpdateTimer)
    UpdateTimer()
end

local function StopLoop()
    if timer then 
        timer:Cancel() 
        timer = nil
    end
    UpdateTimer()  -- Final update
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusCombatTimerWidget", UIParent)
    f:SetSize(60, 20)
    f:SetClampedToScreen(true)
    f.systemIndex = "StatusDock_CombatTimer"
    f.editModeName = "Combat Timer"
    
    -- Text display
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    f.Text:SetText("0:00")
    
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
    
    -- Default position
    -- No default position - WidgetManager places in drawer
    
    -- Make draggable in Edit Mode
    f:SetMovable(true)
    f:EnableMouse(true)
    
    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Combat Timer", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        if inCombat and combatStartTime then
            local elapsed = GetTime() - combatStartTime
            GameTooltip:AddDoubleLine("Status:", "In Combat", 0.7, 0.7, 0.7, 1, 0.3, 0.3)
            GameTooltip:AddDoubleLine("Duration:", FormatTime(elapsed), 0.7, 0.7, 0.7, 1, 1, 1)
        else
            GameTooltip:AddDoubleLine("Status:", "Out of Combat", 0.7, 0.7, 0.7, 0, 1, 0)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    f:SetScript("OnDragStart", function(self)
        local WidgetManager = addon.WidgetManager
        if not WidgetManager or not WidgetManager:OnWidgetDragStart("CombatTimer") then
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
            WidgetManager:OnWidgetDragStop("CombatTimer")
        end
    end)
    
    -- Register for Edit Mode dragging
    f:RegisterForDrag("LeftButton")
    
    return f
end

function CombatTimerWidget:PLAYER_REGEN_DISABLED()
    startTime = GetTime()
    inCombat = true
    StartLoop()
end

function CombatTimerWidget:PLAYER_REGEN_ENABLED()
    inCombat = false
    StopLoop()
end

function CombatTimerWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    -- Register with WidgetManager
    local WidgetManager = addon.WidgetManager
    if WidgetManager then
        WidgetManager:Register("CombatTimer", {
            name = "Combat Timer",
            frame = widgetFrame,
            onDock = function(f, zone)
                -- Adjust size to fit zone if needed
                f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2)
            end,
            onUndock = function(f)
                -- Restore normal size
                UpdateTimer()
            end,
            onEnable = function(f)
                -- Re-register combat events
                if Orbit.EventBus then
                    Orbit.EventBus:On("PLAYER_REGEN_DISABLED", CombatTimerWidget.PLAYER_REGEN_DISABLED, CombatTimerWidget)
                    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", CombatTimerWidget.PLAYER_REGEN_ENABLED, CombatTimerWidget)
                end
                -- Resume ticker if in combat
                if inCombat then
                    StartLoop()
                end
            end,
            onDisable = function(f)
                -- Stop ticker and unregister events to save resources
                StopLoop()
                if Orbit.EventBus then
                    Orbit.EventBus:Off("PLAYER_REGEN_DISABLED", CombatTimerWidget.PLAYER_REGEN_DISABLED)
                    Orbit.EventBus:Off("PLAYER_REGEN_ENABLED", CombatTimerWidget.PLAYER_REGEN_ENABLED)
                end
            end,
        })
    end
    
    -- Combat events via Orbit EventBus
    if Orbit.EventBus then
        Orbit.EventBus:On("PLAYER_REGEN_DISABLED", self.PLAYER_REGEN_DISABLED, self)
        Orbit.EventBus:On("PLAYER_REGEN_ENABLED", self.PLAYER_REGEN_ENABLED, self)
    end
    
    widgetFrame:Show()
end

-- Initialize on PLAYER_LOGIN
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    -- Delay to ensure WidgetManager is loaded
    C_Timer.After(0.5, function()
        CombatTimerWidget:OnLoad()
    end)
end)
