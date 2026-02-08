-- BagSpace.lua
-- Advanced Bag Space widget for StatusDock
-- Features: Free slots, Reagent Bag breakdown, Threshold alerts

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local BagSpaceWidget = addon.BaseWidget:New("BagSpace")
addon.BagSpaceWidget = BagSpaceWidget
BagSpaceWidget.category = "Character"

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function BagSpaceWidget:GetBagInfo()
    local free = 0
    local total = 0
    local reagentFree = 0
    local reagentTotal = 0

    -- Iterate bags 0-4 (Backpack + 4 Bags)
    for i = 0, NUM_BAG_SLOTS do
        local bagFree = C_Container.GetContainerNumFreeSlots(i)
        local bagTotal = C_Container.GetContainerNumSlots(i)
        free = free + bagFree
        total = total + bagTotal
    end

    -- Check Reagent Bag (Slot 5 in Dragonflight+)
    local reagentBagID = NUM_BAG_SLOTS + 1
    if C_Container.GetContainerNumSlots(reagentBagID) > 0 then
        local rFree = C_Container.GetContainerNumFreeSlots(reagentBagID)
        local rTotal = C_Container.GetContainerNumSlots(reagentBagID)
        reagentFree = rFree
        reagentTotal = rTotal
    end

    return free, total, reagentFree, reagentTotal
end

-- [ UPDATES ] -----------------------------------------------------------------

function BagSpaceWidget:Update()
    local free, total, rFree, rTotal = self:GetBagInfo()
    
    local pct = 0
    if total > 0 then pct = (free / total) * 100 end
    local color = addon.Formatting:GetColor(pct, 100, false) -- Red if low space
    
    self:SetFormattedText("Bags:", string.format("%s%d|r/%d", color, free, total))
end

-- [ INTERACTION ] -------------------------------------------------------------

function BagSpaceWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Toggle Bags", function() ToggleAllBags() end)
    rootDescription:CreateButton("Sort Bags", function() C_Container.SortBags() end)

    if C_Container.GetContainerNumSlots(NUM_BAG_SLOTS + 1) > 0 then
        rootDescription:CreateButton("Sort Reagent Bag", function() C_Container.SortReagentBankBags() end)
    end
end

function BagSpaceWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Bag Space", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local free, total, rFree, rTotal = self:GetBagInfo()
    local used = total - free
    
    GameTooltip:AddDoubleLine("Normal Bags:", string.format("%d / %d", used, total), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Free Space:", string.format("%d", free), 1, 1, 1, 0, 1, 0)

    if rTotal > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Reagent Bag:", 0.7, 0.7, 0.7)
        local rUsed = rTotal - rFree
        GameTooltip:AddDoubleLine("Used:", string.format("%d / %d", rUsed, rTotal), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Free:", string.format("%d", rFree), 1, 1, 1, 0, 1, 0)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Options", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function BagSpaceWidget:OnClick(button)
    ToggleAllBags()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function BagSpaceWidget:OnLoad()
    self:CreateFrame(100, 20)
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() BagSpaceWidget:OnLoad() end)
end)
