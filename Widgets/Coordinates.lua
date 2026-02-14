-- Coordinates.lua
-- Precise coordinate display widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local CoordsWidget = addon.BaseWidget:New("Coordinates")
addon.CoordsWidget = CoordsWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local COORD_MULTIPLIER = 100
local UPDATE_INTERVAL_SEC = 0.5
local FRAME_WIDTH = 80
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

local PVP_COLORS = {
    sanctuary = { r = 0.45, g = 0.84, b = 0.95 },
    friendly  = { r = 0, g = 1, b = 0 },
    contested = { r = 0.93, g = 0.65, b = 0.37 },
    hostile   = { r = 1, g = 0, b = 0 },
    arena     = { r = 1, g = 0, b = 0 },
}

-- [ UPDATES ] ---------------------------------------------------------------------

function CoordsWidget:Update()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then self:SetText("|cff888888--  --|r"); return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then self:SetText("|cff888888--  --|r"); return end
    local x, y = pos.x * COORD_MULTIPLIER, pos.y * COORD_MULTIPLIER
    local pvpType = GetZonePVPInfo()
    local c = PVP_COLORS[pvpType]
    if c then
        self.text:SetTextColor(c.r, c.g, c.b)
    else
        self.text:SetTextColor(1, 1, 1)
    end
    self:SetText(string.format("%.1f, %.1f", x, y))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function CoordsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Coordinates", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            GameTooltip:AddDoubleLine("Position:", string.format("%.2f, %.2f", pos.x * COORD_MULTIPLIER, pos.y * COORD_MULTIPLIER), 1, 1, 1, 1, 1, 1)
        end
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo then GameTooltip:AddDoubleLine("Map:", mapInfo.name, 1, 1, 1, 0.7, 0.7, 0.7) end
    end
    local pvpType = GetZonePVPInfo()
    if pvpType then GameTooltip:AddDoubleLine("PvP:", pvpType, 1, 1, 1, 0.7, 0.7, 0.7) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open World Map", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function CoordsWidget:OnClick(button) ToggleWorldMap() end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function CoordsWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open World Map"
    self:SetCategory("WORLD")
    self:Register()
    self:SetUpdateTier("FAST")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() CoordsWidget:OnLoad() end)
end)
