-- BagSpace.lua
-- Advanced Bag Space widget for StatusDock
-- Features: Free slots, Total slots, Reagent Bag separation

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local BagSpaceWidget = addon.BaseWidget:New("BagSpace")
addon.BagSpaceWidget = BagSpaceWidget

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function BagSpaceWidget:GetBagInfo()
    local free = 0
    local total = 0
    local reagentFree = 0
    local reagentTotal = 0

    -- Iterate through bags
    for i = 0, NUM_BAG_SLOTS do
        local bagFree, bagType = C_Container.GetContainerNumFreeSlots(i)
        local bagTotal = C_Container.GetContainerNumSlots(i)

        -- Check if it's a reagent bag (family > 0 often indicates special bag, reagent is specific)
        local family = C_Container.GetContainerFreeSlots(i, 0) -- check family of free slots? no.
        local bagName = C_Container.GetBagName(i)

        -- Simplified: Just total vs free for now
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
    
    local color = "|cff00ff00"
    local pct = (free / total) * 100
    
    if pct < 10 then color = "|cffff0000" -- Red (Full)
    elseif pct < 25 then color = "|cffffa500" -- Orange
    end
    
    self:SetText(string.format("%s%d|r/%d Slots", color, free, total))
end

-- [ INTERACTION ] -------------------------------------------------------------

function BagSpaceWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    
    local free, total, rFree, rTotal = self:GetBagInfo()
    local used = total - free
    
    GameTooltip:AddLine("Bag Space", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Used:", string.format("%d", used), 1, 1, 1, 1, 0, 0)
    GameTooltip:AddDoubleLine("Free:", string.format("%d", free), 1, 1, 1, 0, 1, 0)
    GameTooltip:AddDoubleLine("Total:", string.format("%d", total), 1, 1, 1, 1, 1, 1)

    if rTotal > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Reagents:", 0.7, 0.7, 0.7)
        GameTooltip:AddDoubleLine("Free:", string.format("%d", rFree), 1, 1, 1, 0, 1, 0)
        GameTooltip:AddDoubleLine("Total:", string.format("%d", rTotal), 1, 1, 1, 1, 1, 1)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function BagSpaceWidget:OnClick(button)
    ToggleAllBags()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function BagSpaceWidget:OnLoad()
    self:CreateFrame(80, 20)
    
    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    -- Register events
    self:RegisterEvent("BAG_UPDATE")
    
    -- Register with manager
    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() BagSpaceWidget:OnLoad() end)
end)
