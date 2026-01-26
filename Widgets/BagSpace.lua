-- BagSpace.lua
-- Bag space widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local BagSpaceWidget = {}
addon.BagSpaceWidget = BagSpaceWidget

local widgetFrame = nil

local function GetBagSpace()
    local free, total = 0, 0
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
        total = total + numSlots
        free = free + freeSlots
    end
    return free, total
end

local function UpdateBagSpace()
    if not widgetFrame then return end
    
    local free, total = GetBagSpace()
    local used = total - free
    
    local color = "|cffffffff"
    if free < 5 then
        color = "|cffff0000"
    elseif free < 15 then
        color = "|cfffea300"
    end
    
    widgetFrame.Text:SetText(string.format("%s%d|r/%d", color, used, total))
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Bag Space", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local free, total = GetBagSpace()
    local used = total - free
    
    GameTooltip:AddDoubleLine("Used Slots:", string.format("%d", used), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Free Slots:", string.format("%d", free), 0.7, 0.7, 0.7, 0, 1, 0)
    GameTooltip:AddDoubleLine("Total Slots:", string.format("%d", total), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    -- Per-bag breakdown
    GameTooltip:AddLine("Per Bag:", 0.7, 0.7, 0.7)
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
        if numSlots > 0 then
            local bagName = bag == 0 and "Backpack" or string.format("Bag %d", bag)
            GameTooltip:AddDoubleLine(bagName, string.format("%d/%d", numSlots - freeSlots, numSlots), 0.5, 0.5, 0.5, 1, 1, 1)
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusBagSpaceWidget", UIParent)
    f:SetSize(60, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Bag Space"
    
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
    
    -- Click to open bags
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            ToggleAllBags()
        end
    end)
    
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("BagSpace") then
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
        if WM then WM:OnWidgetDragStop("BagSpace") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function BagSpaceWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("BagSpace", {
            name = "Bag Space",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateBagSpace() end,
        })
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:SetScript("OnEvent", UpdateBagSpace)
    
    UpdateBagSpace()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() BagSpaceWidget:OnLoad() end)
end)
