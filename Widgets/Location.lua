-- Location.lua
-- Zone name widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local LocationWidget = {}
addon.LocationWidget = LocationWidget

local widgetFrame = nil

local function UpdateLocation()
    if not widgetFrame then return end
    
    local zone = GetZoneText() or "Unknown"
    widgetFrame.Text:SetText(zone)
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(math.min(width + 10, 150), 20)
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Location", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local zone = GetZoneText() or "Unknown"
    local subzone = GetSubZoneText() or ""
    local realZone = GetRealZoneText() or ""
    
    GameTooltip:AddDoubleLine("Zone:", zone, 0.7, 0.7, 0.7, 1, 1, 1)
    if subzone ~= "" then
        GameTooltip:AddDoubleLine("Subzone:", subzone, 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    end
    if realZone ~= "" and realZone ~= zone then
        GameTooltip:AddDoubleLine("Region:", realZone, 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    end
    
    -- PvP status
    local pvpType = GetZonePVPInfo()
    if pvpType then
        local pvpText, r, g, b = "Unknown", 1, 1, 1
        if pvpType == "sanctuary" then
            pvpText, r, g, b = "Sanctuary", 0.4, 0.8, 1
        elseif pvpType == "friendly" then
            pvpText, r, g, b = "Friendly", 0, 1, 0
        elseif pvpType == "hostile" then
            pvpText, r, g, b = "Hostile", 1, 0, 0
        elseif pvpType == "contested" then
            pvpText, r, g, b = "Contested", 1, 0.65, 0
        elseif pvpType == "combat" then
            pvpText, r, g, b = "Combat Zone", 1, 0, 0
        end
        GameTooltip:AddDoubleLine("PvP Status:", pvpText, 0.7, 0.7, 0.7, r, g, b)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Map", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusLocationWidget", UIParent)
    f:SetSize(100, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Location"
    
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
    
    -- Click to open map
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            ToggleWorldMap()
        end
    end)
    
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("Location") then
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
        if WM then WM:OnWidgetDragStop("Location") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function LocationWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    -- Create event frame for zone changes
    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Location", {
            name = "Location",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateLocation() end,
            onEnable = function(f)
                -- Re-register zone events and update display
                eventFrame:RegisterEvent("ZONE_CHANGED")
                eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
                eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
                UpdateLocation()
            end,
            onDisable = function(f)
                -- Unregister events to save resources
                eventFrame:UnregisterEvent("ZONE_CHANGED")
                eventFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
                eventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
            end,
        })
    end
    
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", UpdateLocation)
    
    UpdateLocation()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() LocationWidget:OnLoad() end)
end)
