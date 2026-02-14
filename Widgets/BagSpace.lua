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

-- [ CONSTANTS ] -------------------------------------------------------------------

local BAG_CRITICAL_PCT = 10
local BAG_WARNING_PCT = 25
local FRAME_WIDTH = 80
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local BANK_BAG_START = Enum.BagIndex.BankBag_1 or (NUM_BAG_SLOTS + 2)
local BANK_BAG_END = Enum.BagIndex.BankBag_7 or (NUM_BAG_SLOTS + 8)
local BANK_CONTAINER = -1
local PCT_MULTIPLIER = 100

local QUALITY_NAMES = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary" }
local QUALITY_COLORS = { [0] = { 0.6, 0.6, 0.6 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }

BagSpaceWidget.bankFree = 0
BagSpaceWidget.bankTotal = 0

-- [ HELPERS ] ---------------------------------------------------------------------

function BagSpaceWidget:GetBagInfo()
    local free = 0
    local total = 0
    local reagentFree = 0
    local reagentTotal = 0

    -- The paladin inspects each bag of holding
    for i = 0, NUM_BAG_SLOTS do
        local bagFree, bagType = C_Container.GetContainerNumFreeSlots(i)
        local bagTotal = C_Container.GetContainerNumSlots(i)

        local family = C_Container.GetContainerFreeSlots(i, 0)
        local bagName = C_Container.GetBagName(i)

        free = free + bagFree
        total = total + bagTotal
    end

    -- The artificer's reagent pouch gets its own slot
    local reagentBagID = NUM_BAG_SLOTS + 1
    if C_Container.GetContainerNumSlots(reagentBagID) > 0 then
        local rFree = C_Container.GetContainerNumFreeSlots(reagentBagID)
        local rTotal = C_Container.GetContainerNumSlots(reagentBagID)
        reagentFree = rFree
        reagentTotal = rTotal
    end

    return free, total, reagentFree, reagentTotal
end

-- [ UPDATES ] ---------------------------------------------------------------------

function BagSpaceWidget:Update()
    local free, total, rFree, rTotal = self:GetBagInfo()
    
    local color = "|cff00ff00"
    local pct = (free / total) * 100
    
    if pct < BAG_CRITICAL_PCT then color = "|cffff0000"
    elseif pct < BAG_WARNING_PCT then color = "|cffffa500"
    end
    
    self:SetText(string.format("%s%d|r/%d Slots", color, free, total))
end

function BagSpaceWidget:CacheBankSpace()
    local free, total = 0, 0
    local bankSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    if bankSlots > 0 then
        free = free + C_Container.GetContainerNumFreeSlots(BANK_CONTAINER)
        total = total + bankSlots
    end
    for i = BANK_BAG_START, BANK_BAG_END do
        local slots = C_Container.GetContainerNumSlots(i)
        if slots > 0 then
            free = free + C_Container.GetContainerNumFreeSlots(i)
            total = total + slots
        end
    end
    self.bankFree = free
    self.bankTotal = total
end

function BagSpaceWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    local free, total, rFree, rTotal = self:GetBagInfo()
    local used = total - free
    GameTooltip:AddLine("Bag Space", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Used:", tostring(used), 1, 1, 1, 1, 0, 0)
    GameTooltip:AddDoubleLine("Free:", tostring(free), 1, 1, 1, 0, 1, 0)
    GameTooltip:AddDoubleLine("Total:", tostring(total), 1, 1, 1, 1, 1, 1)
    if rTotal > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Reagents:", 0.7, 0.7, 0.7)
        GameTooltip:AddDoubleLine("Free:", tostring(rFree), 1, 1, 1, 0, 1, 0)
        GameTooltip:AddDoubleLine("Total:", tostring(rTotal), 1, 1, 1, 1, 1, 1)
    end
    if self.bankTotal > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Bank (Cached):", 0.7, 0.7, 0.7)
        GameTooltip:AddDoubleLine("Free:", tostring(self.bankFree), 1, 1, 1, 0, 1, 0)
        GameTooltip:AddDoubleLine("Total:", tostring(self.bankTotal), 1, 1, 1, 1, 1, 1)
    end
    local qualityCounts = {}
    for i = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(i) do
            local itemInfo = C_Container.GetContainerItemInfo(i, slot)
            if itemInfo and itemInfo.quality then
                qualityCounts[itemInfo.quality] = (qualityCounts[itemInfo.quality] or 0) + 1
            end
        end
    end
    local hasQuality = false
    for q = 5, 0, -1 do
        if qualityCounts[q] and qualityCounts[q] > 0 then hasQuality = true; break end
    end
    if hasQuality then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Item Quality:", 0.7, 0.7, 0.7)
        for q = 5, 0, -1 do
            if qualityCounts[q] and qualityCounts[q] > 0 then
                local c = QUALITY_COLORS[q]
                GameTooltip:AddDoubleLine(QUALITY_NAMES[q] .. ":", tostring(qualityCounts[q]), c[1], c[2], c[3], 1, 1, 1)
            end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function BagSpaceWidget:OnClick(button)
    ToggleAllBags()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function BagSpaceWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    

    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("BANKFRAME_OPENED", function() self:CacheBankSpace() end)
    

    self:SetCategory("GAMEPLAY")

    self:Register()
    

    self:Update()
end


local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() BagSpaceWidget:OnLoad() end)
end)
