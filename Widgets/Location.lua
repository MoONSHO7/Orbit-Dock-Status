-- Location.lua
-- Advanced Location widget for StatusDock
-- Features: Zone tracking, PVP status coloring, Coordinates, Fast Travel Menu

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local LocationWidget = addon.BaseWidget:New("Location")
addon.LocationWidget = LocationWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local COLORS = {
    SANCTUARY = "|cff74d5f2",
    CONTESTED = "|cffeda55f",
    HOSTILE = "|cffff0000",
    FRIENDLY = "|cff00ff00",
    NEUTRAL = "|cffffffff",
}

local COORD_MULTIPLIER = 100
local COORD_UPDATE_SEC = 0.5
local FRAME_WIDTH = 150
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

local INSTANCE_TYPES = {
    party = "Dungeon",
    raid = "Raid",
    arena = "Arena",
    pvp = "BG",
    scenario = "Scenario",
}

-- [ HELPER FUNCTIONS ] ------------------------------------------------------------

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

    return pos.x * COORD_MULTIPLIER, pos.y * COORD_MULTIPLIER
end

function LocationWidget:GetInstancePrefix()
    local _, instanceType, difficultyID = GetInstanceInfo()
    if instanceType == "none" then return "" end
    local diffName = GetDifficultyInfo(difficultyID) or ""
    local keystoneLevel = C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo()
    if keystoneLevel and keystoneLevel > 0 then return string.format("|cffff8000[M+%d]|r ", keystoneLevel) end
    local label = INSTANCE_TYPES[instanceType] or instanceType
    return string.format("|cffffcc00[%s]|r ", label)
end

function LocationWidget:Update()
    local subZone = GetSubZoneText()
    local zone = GetZoneText()
    local text = (subZone ~= "") and subZone or zone
    local color = self:GetZoneColor()
    local prefix = self:GetInstancePrefix()
    local x, y = self:GetCoordinates()
    local coordStr = (x and y) and string.format(" |cffffffff(%.1f, %.1f)|r", x, y) or ""
    self:SetText(prefix .. color .. text .. "|r" .. coordStr)
end

-- [ INTERACTION ] -----------------------------------------------------------------

function LocationWidget:OpenTravelMenu()
    if not addon.Menu then return end

    local items = {}

    -- Hearthstones & Toys
    local toys = {
        { id = 6948, name = "Hearthstone" },
        { id = 110560, name = "Garrison Hearthstone" },
        { id = 140192, name = "Dalaran Hearthstone" },
        { id = 556, name = "Astral Recall" }, -- Shaman Spell (id check?)
    }

    for _, toy in ipairs(toys) do
        if PlayerHasToy(toy.id) or GetItemCount(toy.id) > 0 then
            local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(toy.id)
            if name then
                table.insert(items, {
                    text = string.format("|T%s:14|t %s", icon, name),
                    func = function()
                        -- Secure action requires complex handling or out of combat
                        -- For now, just print helper or try UseItemByName if allowed
                        if not InCombatLockdown() then
                            UseItemByName(name)
                        else
                            print("Cannot use in combat")
                        end
                    end
                })
            end
        end
    end

    if #items == 0 then
        table.insert(items, { text = "No Travel Items Found", func = nil })
    end

    addon.Menu:Open(self.frame, items)
end

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
    GameTooltip:AddDoubleLine("Left Click", "Open World Map", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Travel Menu", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function LocationWidget:OnClick(button)
    if button == "RightButton" then
        self:OpenTravelMenu()
    else
        ToggleWorldMap()
    end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function LocationWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    -- The ranger's survival kit: tracking spells and a good compass
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)


    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_INDOORS")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:SetUpdateTier("NORMAL")
    

    self:SetCategory("WORLD")

    self:Register()
    

    self:Update()
end


local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() LocationWidget:OnLoad() end)
end)
