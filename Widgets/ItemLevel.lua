-- ItemLevel.lua
-- Item level widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local ItemLevelWidget = {}
addon.ItemLevelWidget = ItemLevelWidget

local widgetFrame = nil

local function UpdateItemLevel()
    if not widgetFrame then return end
    
    local _, ilvl = GetAverageItemLevel()
    widgetFrame.Text:SetText(string.format("|cff00ccff%d|r ilvl", math.floor(ilvl)))
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Item Level", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local overall, equipped = GetAverageItemLevel()
    GameTooltip:AddDoubleLine("Overall:", string.format("%.1f", overall), 0.7, 0.7, 0.7, 0, 0.8, 1)
    GameTooltip:AddDoubleLine("Equipped:", string.format("%.1f", equipped), 0.7, 0.7, 0.7, 0, 0.8, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Character", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusItemLevelWidget", UIParent)
    f:SetSize(60, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Item Level"
    
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
        if not WM or not WM:OnWidgetDragStart("ItemLevel") then
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
        if WM then WM:OnWidgetDragStop("ItemLevel") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function ItemLevelWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("ItemLevel", {
            name = "Item Level",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateItemLevel() end,
        })
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:SetScript("OnEvent", UpdateItemLevel)
    
    UpdateItemLevel()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() ItemLevelWidget:OnLoad() end)
end)
