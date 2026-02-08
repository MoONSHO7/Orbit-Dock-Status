-- Gold.lua
-- Currency display widget for StatusDock
-- Features: Session profit/loss tracking, smart formatting, Auto-Sell Junk

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local GoldWidget = addon.BaseWidget:New("Gold")
addon.GoldWidget = GoldWidget

-- [ FORMATTING ] --------------------------------------------------------------

function GoldWidget:FormatMoney(copper, full)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    
    if full then
        return string.format("|cffffd700%d|r gold |cffc0c0c0%d|r silver |cffeda55f%d|r copper", gold, silver, cop)
    end

    -- Smart formatting for bar display
    if gold >= 1000000 then
        return string.format("|cffffd700%.1fm|r", gold / 1000000)
    elseif gold >= 1000 then
        return string.format("|cffffd700%.1fk|r", gold / 1000)
    elseif gold > 0 then
        return string.format("|cffffd700%d|rg |cffc0c0c0%d|rs", gold, silver)
    elseif silver > 0 then
        return string.format("|cffc0c0c0%d|rs |cffeda55f%d|rc", silver, cop)
    else
        return string.format("|cffeda55f%d|rc", cop)
    end
end

function GoldWidget:FormatProfit(profit)
    local color = "|cff00ff00+" -- Green for positive
    if profit < 0 then
        color = "|cffff0000" -- Red for negative
    elseif profit == 0 then
        color = "|cffffffff" -- White for zero
    end

    return color .. self:FormatMoney(math.abs(profit), false)
end

-- [ UPDATES ] -----------------------------------------------------------------

function GoldWidget:Update()
    local money = GetMoney()
    self:SetText(self:FormatMoney(money))
end

-- [ AUTO SELL JUNK ] ----------------------------------------------------------

function GoldWidget:AutoSellJunk()
    local profit = 0
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == 0 and not info.isLocked then
                local price = select(11, GetItemInfo(info.hyperlink))
                if price and price > 0 then
                    C_Container.UseContainerItem(bag, slot)
                    profit = profit + (price * info.stackCount)
                end
            end
        end
    end

    if profit > 0 then
        print(string.format("|cff00ff00Auto-Sold Junk for %s|r", self:FormatMoney(profit, false)))
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function GoldWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Wealth", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local current = GetMoney()
    GameTooltip:AddDoubleLine("Current:", self:FormatMoney(current, false), 1, 1, 1, 1, 1, 1)
    
    local profit = current - (self.sessionStart or current)
    GameTooltip:AddDoubleLine("Session:", self:FormatProfit(profit), 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Reset Session", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function GoldWidget:OnClick(button)
    if button == "RightButton" then
        self.sessionStart = GetMoney()
        self:Update()
        -- Refresh tooltip if showing
        if GameTooltip:GetOwner() == self.frame then
            self:ShowTooltip()
        end
    else
        ToggleAllBags()
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function GoldWidget:OnLoad()
    self:CreateFrame()
    
    -- Initialize session start
    self.sessionStart = GetMoney()
    
    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Register events
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("PLAYER_ENTERING_WORLD") -- Ensure money is loaded
    self:RegisterEvent("MERCHANT_SHOW", function() self:AutoSellJunk() end)
    
    -- Register with manager
    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() GoldWidget:OnLoad() end)
end)
