-- Coordinates.lua
-- Map coordinates widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local CoordsWidget = {}
addon.CoordsWidget = CoordsWidget

local widgetFrame = nil
local timer = nil

local function GetPlayerCoords()
    local map = C_Map.GetBestMapForUnit("player")
    if map then
        local pos = C_Map.GetPlayerMapPosition(map, "player")
        if pos then
            local x, y = pos:GetXY()
            return x * 100, y * 100, true
        end
    end
    return 0, 0, false
end

local function UpdateCoords()
    if not widgetFrame or not widgetFrame:IsVisible() then return end
    
    local x, y, valid = GetPlayerCoords()
    if valid then
        widgetFrame.Text:SetText(string.format("%.1f, %.1f", x, y))
    else
        widgetFrame.Text:SetText("---, ---")
    end
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function StartLoop()
    if timer then timer:Cancel() end
    timer = C_Timer.NewTicker(0.5, UpdateCoords)
    UpdateCoords()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Coordinates", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local x, y, valid = GetPlayerCoords()
    if valid then
        GameTooltip:AddDoubleLine("X:", string.format("%.2f", x), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("Y:", string.format("%.2f", y), 0.7, 0.7, 0.7, 1, 1, 1)
    else
        GameTooltip:AddLine("Coordinates unavailable in this area", 1, 0.5, 0.5)
    end
    
    local zone = GetZoneText() or "Unknown"
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Zone:", zone, 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Map", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusCoordsWidget", UIParent)
    f:SetSize(70, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Coordinates"
    
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
        if not WM or not WM:OnWidgetDragStart("Coordinates") then
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
        if WM then WM:OnWidgetDragStop("Coordinates") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function CoordsWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Coordinates", {
            name = "Coordinates",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateCoords() end,
        })
    end
    
    StartLoop()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() CoordsWidget:OnLoad() end)
end)
