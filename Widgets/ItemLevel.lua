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
ItemLevelWidget.category = "Character"

-- [ SETTINGS ] ----------------------------------------------------------------

ItemLevelWidget.settings = {
    showTotal = true,
}

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function ItemLevelWidget:GetItemLevelInfo()
    local equipped = select(2, GetAverageItemLevel())
    local total = select(1, GetAverageItemLevel())

    local items = {}
    local slots = { "Head", "Neck", "Shoulder", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger0", "Finger1", "Trinket0", "Trinket1", "Back", "MainHand", "SecondaryHand" }
    
    for _, slotName in ipairs(slots) do
        local slotId = GetInventorySlotInfo(slotName .. "Slot")
        local itemLink = GetInventoryItemLink("player", slotId)

        if itemLink then
            local _, _, _, itemLevel = GetItemInfo(itemLink)
            local effectiveILvl = GetDetailedItemLevelInfo(itemLink) or itemLevel
            table.insert(items, { name = slotName, ilvl = effectiveILvl, link = itemLink })
        else
            table.insert(items, { name = slotName, ilvl = 0, link = nil })
        end
    end

    return equipped, total, items
end

-- [ UPDATES ] -----------------------------------------------------------------

function ItemLevelWidget:Update()
    local equipped, total = GetAverageItemLevel()
    local color = "|cffffffff" -- White

    if equipped >= total then color = "|cff00ff00" -- Synced
    else color = "|cffffa500" end -- Un-synced (bag upgrades available)
    
    local text = string.format("%s%.1f|r", color, equipped)
    if self.settings.showTotal then
        text = text .. string.format("/%.1f", total)
    end

    self:SetFormattedText("iLvl:", text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function ItemLevelWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateCheckbox("Show Bag Item Level", function() return self.settings.showTotal end, function()
        self.settings.showTotal = not self.settings.showTotal
        self:Update()
    end)
    rootDescription:CreateButton("Open Character", function() ToggleCharacter("PaperDollFrame") end)
end

function ItemLevelWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    
    local equipped, total, items = self:GetItemLevelInfo()
    
    GameTooltip:AddLine("Item Level", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Equipped:", string.format("%.2f", equipped), 1, 1, 1, 0, 1, 0)
    GameTooltip:AddDoubleLine("Total (In Bags):", string.format("%.2f", total), 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Lowest Slots:", 0.7, 0.7, 0.7)
    
    table.sort(items, function(a, b) return a.ilvl < b.ilvl end)
    
    for i = 1, 5 do
        if items[i].ilvl > 0 then
            local color = "|cffffffff"
            if items[i].ilvl < math.floor(equipped) - 10 then color = "|cffff0000" end
            GameTooltip:AddDoubleLine(items[i].name, color .. string.format("%d", items[i].ilvl) .. "|r", 1, 1, 1)
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Character Info", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Options", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function ItemLevelWidget:OnClick(button)
    ToggleCharacter("PaperDollFrame")
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function ItemLevelWidget:OnLoad()
    self:CreateFrame(80, 20)
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() ItemLevelWidget:OnLoad() end)
end)
