-- Location.lua
-- Advanced Location widget for StatusDock
-- Features: Zone tracking, PVP status, Coordinates, Travel Menu, Zone Events

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local LocationWidget = addon.BaseWidget:New("Location"); addon.LocationWidget.category = "World"
addon.LocationWidget = LocationWidget

-- [ HELPERS ] -----------------------------------------------------------------

function LocationWidget:GetZoneColor()
    local pvpType = GetZonePVPInfo()
    if pvpType == "sanctuary" then return "|cff74d5f2"
    elseif pvpType == "arena" or pvpType == "hostile" then return "|cffff0000"
    elseif pvpType == "friendly" then return "|cff00ff00"
    elseif pvpType == "contested" then return "|cffeda55f"
    end
    return "|cffffffff"
end

function LocationWidget:GetZoneEvent()
    -- Check for Dragonflight Events (Dreamsurge, Time Rift, etc.)
    -- This requires checking C_AreaPoiInfo for specific IDs in the current map
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end

    -- Simplified: Just check if we are in a zone with an event
    -- Dreamsurge (POIs: 7332, etc?) - API lookup required for precise IDs
    -- For now, placeholder or basic POI scan
    return nil
end

-- [ UPDATE ] ------------------------------------------------------------------

function LocationWidget:Update()
    local zone = GetZoneText()
    local subZone = GetSubZoneText()
    local text = (subZone ~= "") and subZone or zone
    local color = self:GetZoneColor()

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local coordStr = ""
    if pos then
        coordStr = string.format("(%.1f, %.1f)", pos.x * 100, pos.y * 100)
    end
    
    self:SetFormattedText(nil, string.format("%s%s|r %s", color, text, coordStr))
end

-- [ INTERACTION ] -------------------------------------------------------------

function LocationWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Toggle World Map", function() ToggleWorldMap() end)

    local travel = rootDescription:CreateButton("Travel")

    local toys = {
        { id = 6948, name = "Hearthstone" },
        { id = 110560, name = "Garrison Hearthstone" },
        { id = 140192, name = "Dalaran Hearthstone" },
        { id = 556, name = "Astral Recall" },
    }

    for _, toy in ipairs(toys) do
        if PlayerHasToy(toy.id) or GetItemCount(toy.id) > 0 then
            local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(toy.id)
            if name then
                travel:CreateButton(string.format("|T%s:14|t %s", icon, name), function()
                    if not InCombatLockdown() then
                        UseItemByName(name)
                    else
                        print("|cffff0000Cannot use in combat|r")
                    end
                end)
            end
        end
    end
end

function LocationWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Location", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local zone = GetZoneText()
    local subZone = GetSubZoneText()
    local pvpType, _, factionName = GetZonePVPInfo()
    
    GameTooltip:AddDoubleLine("Zone:", zone, 1, 1, 1, 1, 1, 1)
    if subZone ~= "" and subZone ~= zone then
        GameTooltip:AddDoubleLine("Subzone:", subZone, 1, 1, 1, 1, 1, 1)
    end
    
    GameTooltip:AddDoubleLine("PVP Status:", (pvpType or "Unknown"), 1, 1, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Right Click", "Travel Menu", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function LocationWidget:OnClick(button)
    ToggleWorldMap()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function LocationWidget:OnLoad()
    self:CreateFrame(150, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    C_Timer.NewTicker(0.5, function() self:Update() end)
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() LocationWidget:OnLoad() end)
end)
