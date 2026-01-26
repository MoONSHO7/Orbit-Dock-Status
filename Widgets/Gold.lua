-- Gold.lua
-- Currency display widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local GoldWidget = {}
addon.GoldWidget = GoldWidget

local widgetFrame = nil

local function FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    
    if gold > 0 then
        return string.format("|cffffd700%d|rg |cffc0c0c0%d|rs", gold, silver)
    elseif silver > 0 then
        return string.format("|cffc0c0c0%d|rs |cffeda55f%d|rc", silver, cop)
    else
        return string.format("|cffeda55f%d|rc", cop)
    end
end

local function FormatMoneyFull(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    return string.format("|cffffd700%d|r gold |cffc0c0c0%d|r silver |cffeda55f%d|r copper", gold, silver, cop)
end

local function UpdateGold()
    if not widgetFrame then return end
    
    local money = GetMoney()
    widgetFrame.Text:SetText(FormatMoney(money))
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Gold", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(FormatMoneyFull(GetMoney()), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusGoldWidget", UIParent)
    f:SetSize(100, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Gold"
    
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
        if not WM or not WM:OnWidgetDragStart("Gold") then
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
        if WM then WM:OnWidgetDragStop("Gold") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function GoldWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Gold", {
            name = "Gold",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateGold() end,
        })
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:SetScript("OnEvent", UpdateGold)
    
    UpdateGold()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() GoldWidget:OnLoad() end)
end)
