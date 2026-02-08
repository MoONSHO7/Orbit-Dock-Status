-- Location.lua
-- Advanced Location widget for StatusDock
-- Features: Zone tracking, PVP status coloring, Coordinates integration

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local LocationWidget = addon.BaseWidget:New("Location")
addon.LocationWidget = LocationWidget

-- [ CONSTANTS ] ---------------------------------------------------------------

local COLORS = {
    SANCTUARY = "|cff74d5f2", -- Light Blue
    CONTESTED = "|cffeda55f", -- Orange
    HOSTILE = "|cffff0000",   -- Red
    FRIENDLY = "|cff00ff00",  -- Green
    NEUTRAL = "|cffffffff",   -- White
}

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function LocationWidget:GetZoneColor()
    local pvpType = GetZonePVPInfo()
    if pvpType == "sanctuary" then return COLORS.SANCTUARY end
    if pvpType == "arena" then return COLORS.HOSTILE end
    if pvpType == "friendly" then return COLORS.FRIENDLY end
    if pvpType == "hostile" then return COLORS.HOSTILE end
    if pvpType == "contested" then return COLORS.CONTESTED end
    return COLORS.NEUTRAL
end

function LocationWidget:GetCoordinates()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil, nil end

    return pos.x * 100, pos.y * 100
end

-- [ UPDATES ] -----------------------------------------------------------------

function LocationWidget:Update()
    local subZone = GetSubZoneText()
    local zone = GetZoneText()
    local text = (subZone ~= "") and subZone or zone
    local color = self:GetZoneColor()

    local x, y = self:GetCoordinates()
    local coordStr = ""
    if x and y then
        coordStr = string.format(" |cffffffff(%.1f, %.1f)|r", x, y)
    end
    
    self:SetText(color .. text .. "|r" .. coordStr)
end

-- [ INTERACTION ] -------------------------------------------------------------

function LocationWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Location", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local zone = GetZoneText()
    local subZone = GetSubZoneText()
    local pvpType, _, factionName = GetZonePVPInfo()
    local color = self:GetZoneColor()
    
    GameTooltip:AddDoubleLine("Zone:", zone, 1, 1, 1, 1, 1, 1)
    if subZone ~= "" and subZone ~= zone then
        GameTooltip:AddDoubleLine("Subzone:", subZone, 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddDoubleLine("PVP Status:", (pvpType or "Unknown"), 1, 1, 1, color)
    if factionName and factionName ~= "" then
        GameTooltip:AddDoubleLine("Controlled By:", factionName, 1, 1, 1, 1, 1, 1)
    end
    
    local x, y = self:GetCoordinates()
    if x and y then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Coordinates:", string.format("%.2f, %.2f", x, y), 1, 1, 1, 1, 1, 1)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open World Map", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function LocationWidget:OnClick(button)
    ToggleWorldMap()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function LocationWidget:OnLoad()
    self:CreateFrame(150, 20)

    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Register events
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_INDOORS")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Coordinates ticker (every 0.5s)
    C_Timer.NewTicker(0.5, function() self:Update() end)
    
    -- Register with manager
    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() LocationWidget:OnLoad() end)
end)
