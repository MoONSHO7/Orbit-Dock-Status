-- Gold.lua
-- Currency display widget for StatusDock
-- Features: Session profit/loss tracking, smart formatting, Auto-Sell Junk, Graph Visualization

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local GoldWidget = addon.BaseWidget:New("Gold"); addon.GoldWidget.category = "Economy"
addon.GoldWidget = GoldWidget

-- [ SETTINGS ] ----------------------------------------------------------------

GoldWidget.settings = {
    autoSell = true,
}

-- [ HISTORY ] -----------------------------------------------------------------

GoldWidget.history = {}
local HISTORY_SIZE = 60

-- [ FORMATTING ] --------------------------------------------------------------

function GoldWidget:FormatMoney(copper, full)
    return addon.Formatting:FormatMoney(copper, full)
end

function GoldWidget:FormatProfit(profit)
    local color = "|cff00ff00+"
    if profit < 0 then color = "|cffff0000"
    elseif profit == 0 then color = "|cffffffff" end
    return color .. self:FormatMoney(math.abs(profit), false)
end

-- [ UPDATES ] -----------------------------------------------------------------

function GoldWidget:Update()
    local money = GetMoney()
    -- New Standard: Label Value
    self:SetFormattedText(nil, self:FormatMoney(money))

    local time = GetTime()
    if not self.lastHistoryTime or (time - self.lastHistoryTime) > 60 then
        table.insert(self.history, money)
        if #self.history > HISTORY_SIZE then table.remove(self.history, 1) end
        self.lastHistoryTime = time
    end
end

-- [ AUTO SELL JUNK ] ----------------------------------------------------------

function GoldWidget:AutoSellJunk()
    if not self.settings.autoSell then return end

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

function GoldWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateCheckbox("Auto-Sell Grey Items", function() return self.settings.autoSell end, function()
        self.settings.autoSell = not self.settings.autoSell
    end)

    rootDescription:CreateButton("Reset Session Data", function()
        self.sessionStart = GetMoney()
        self.history = {}
        self:Update()
    end)
end

function GoldWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Wealth", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local current = GetMoney()
    GameTooltip:AddDoubleLine("Current:", self:FormatMoney(current, false), 1, 1, 1, 1, 1, 1)
    
    local profit = current - (self.sessionStart or current)
    GameTooltip:AddDoubleLine("Session:", self:FormatProfit(profit), 1, 1, 1, 1, 1, 1)
    
    -- Token Price (Modern API)
    local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()
    if tokenPrice then
        GameTooltip:AddDoubleLine("WoW Token:", self:FormatMoney(tokenPrice, false), 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Options", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()

    -- Graph
    if #self.history > 2 then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(220, 60)
            self.graph = addon.Graph:New(self.graphFrame, 220, 60)
        end

        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
        self.graphFrame:Show()

        self.graph:Clear()
        self.graph:SetColor(1, 0.84, 0, 1) -- Gold Color
        for _, val in ipairs(self.history) do
            self.graph:AddData(val)
        end
        self.graph:Draw()
    end
end

function GoldWidget:OnClick(button)
    ToggleAllBags()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function GoldWidget:OnLoad()
    self:CreateFrame()
    self.sessionStart = GetMoney()
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Modern Menu Registration
    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("MERCHANT_SHOW", function() self:AutoSellJunk() end)
    
    self:Register()
    self:Update()

    C_WowTokenPublic.UpdateMarketPrice() -- Request token price
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() GoldWidget:OnLoad() end)
end)
