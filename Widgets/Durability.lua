-- Durability.lua
-- Armor durability widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local DurabilityWidget = {}
addon.DurabilityWidget = DurabilityWidget

local widgetFrame = nil

local SLOTS = {
    { slot = "HeadSlot", name = "Head" },
    { slot = "ShoulderSlot", name = "Shoulders" },
    { slot = "ChestSlot", name = "Chest" },
    { slot = "WristSlot", name = "Wrists" },
    { slot = "HandsSlot", name = "Hands" },
    { slot = "WaistSlot", name = "Waist" },
    { slot = "LegsSlot", name = "Legs" },
    { slot = "FeetSlot", name = "Feet" },
    { slot = "MainHandSlot", name = "Main Hand" },
    { slot = "SecondaryHandSlot", name = "Off Hand" },
}

local function GetDurabilityInfo()
    local lowest = 100
    local slotInfo = {}
    
    for _, info in ipairs(SLOTS) do
        local slotId = GetInventorySlotInfo(info.slot)
        local current, maximum = GetInventoryItemDurability(slotId)
        if current and maximum and maximum > 0 then
            local pct = (current / maximum) * 100
            table.insert(slotInfo, { name = info.name, pct = pct, current = current, max = maximum })
            if pct < lowest then
                lowest = pct
            end
        end
    end
    
    return lowest, slotInfo
end

local function UpdateDurability()
    if not widgetFrame then return end
    
    local durability = GetDurabilityInfo()
    local color = "|cff00ff00"
    if durability < 25 then
        color = "|cffff0000"
    elseif durability < 50 then
        color = "|cfffea300"
    end
    
    widgetFrame.Text:SetText(string.format("%s%d%%|r Dur", color, durability))
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Durability", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local lowest, slotInfo = GetDurabilityInfo()
    
    for _, info in ipairs(slotInfo) do
        local r, g = 0, 1
        if info.pct < 25 then
            r, g = 1, 0
        elseif info.pct < 50 then
            r, g = 1, 0.65
        end
        GameTooltip:AddDoubleLine(info.name, string.format("%d%%", info.pct), 0.7, 0.7, 0.7, r, g, 0)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Character", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusDurabilityWidget", UIParent)
    f:SetSize(70, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Durability"
    
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
    
    -- Click to open character panel
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            ToggleCharacter("PaperDollFrame")
        end
    end)
    
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("Durability") then
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
        if WM then WM:OnWidgetDragStop("Durability") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function DurabilityWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    -- Create event frame for durability updates
    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Durability", {
            name = "Durability",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateDurability() end,
            onEnable = function(f)
                -- Re-register durability event and update display
                eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
                UpdateDurability()
            end,
            onDisable = function(f)
                -- Unregister event to save resources
                eventFrame:UnregisterEvent("UPDATE_INVENTORY_DURABILITY")
            end,
        })
    end
    
    eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    eventFrame:SetScript("OnEvent", UpdateDurability)
    
    UpdateDurability()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() DurabilityWidget:OnLoad() end)
end)
