-- ItemLevel.lua
-- Advanced Item Level widget for StatusDock
-- Features: Equipped vs Total, Slot breakdown, Upgrade tips

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local ItemLevelWidget = addon.BaseWidget:New("ItemLevel")
addon.ItemLevelWidget = ItemLevelWidget

-- [ CONSTANTS ] --------------------------------------------------------------------------

local FRAME_WIDTH = 80
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ HELPER FUNCTIONS ] ------------------------------------------------------------

function ItemLevelWidget:GetItemLevelInfo()
    local equipped = select(2, GetAverageItemLevel())
    local total = select(1, GetAverageItemLevel())

    local items = {}
    local slots = { "Head", "Neck", "Shoulder", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger0", "Finger1", "Trinket0", "Trinket1", "Back", "MainHand", "SecondaryHand" }
    
    for _, slotName in ipairs(slots) do
        local slotId = GetInventorySlotInfo(slotName .. "Slot")
        local itemLink = GetInventoryItemLink("player", slotId)

        if itemLink then
            local _, _, _, itemLevel, _, _, _, _, itemEquipLoc, _, _, itemClassID, itemSubClassID = GetItemInfo(itemLink)
            local effectiveILvl = GetDetailedItemLevelInfo(itemLink) or itemLevel
            table.insert(items, { name = slotName, ilvl = effectiveILvl, link = itemLink })
        else
            table.insert(items, { name = slotName, ilvl = 0, link = nil })
        end
    end
    
    return equipped, total, items
end

-- [ UPDATES ] ---------------------------------------------------------------------

function ItemLevelWidget:Update()
    local equipped, total = GetAverageItemLevel()
    local color = (equipped >= total) and "|cff00ff00" or "|cffffd200"
    
    self:SetText(string.format("iLvl: %s%.1f|r", color, equipped))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function ItemLevelWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    
    local equipped, total, items = self:GetItemLevelInfo()
    
    GameTooltip:AddLine("Item Level", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Equipped:", string.format("%.2f", equipped), 1, 1, 1, 0, 1, 0)
    GameTooltip:AddDoubleLine("Total (In Bags):", string.format("%.2f", total), 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Lowest Slots:", 0.7, 0.7, 0.7)
    
    -- Sort by lowest ilvl
    table.sort(items, function(a, b) return a.ilvl < b.ilvl end)
    
    -- Show lowest 5
    for i = 1, 5 do
        if items[i].ilvl > 0 then
            local color = "|cffffffff"
            if items[i].ilvl < math.floor(equipped) - 10 then color = "|cffff0000" end -- Red if far behind

            GameTooltip:AddDoubleLine(items[i].name, string.format("%d", items[i].ilvl), 1, 1, 1, 1, 1, 1)
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Character", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function ItemLevelWidget:OnClick(button)
    ToggleCharacter("PaperDollFrame")
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function ItemLevelWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    
    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    -- Register events
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    
    -- Register with manager
    self:SetCategory("CHARACTER")

    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() ItemLevelWidget:OnLoad() end)
end)
