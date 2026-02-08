-- Gold.lua
-- Currency display widget for StatusDock
-- Features: Session profit/loss tracking, smart formatting, Auto-Sell Junk, Graph Visualization

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local GoldWidget = addon.BaseWidget:New("Gold")
addon.GoldWidget = GoldWidget

-- [ SETTINGS ] ----------------------------------------------------------------

GoldWidget.settings = {
    autoSell = true,
}

-- [ HISTORY ] -----------------------------------------------------------------

GoldWidget.history = {}
local HISTORY_SIZE = 60 -- Store last 60 minutes? Or simpler: Session snapshots

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
        return string.format("|cffffd700%.2fm|r", gold / 1000000)
    elseif gold >= 1000 then
        return string.format("|cffffd700%.1fk|r", gold / 1000)
    elseif gold > 0 then
        return string.format("|cffffd700%d|rg |cffc0c0c0%d|rs", gold, silver)
    else
        return string.format("|cffc0c0c0%d|rs |cffeda55f%d|rc", silver, cop)
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

    -- Store history every minute? Or just on change
    -- For session graph, we want delta over time
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

function GoldWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {
        {
            text = "Auto-Sell Grey Items",
            checked = self.settings.autoSell,
            func = function() self.settings.autoSell = not self.settings.autoSell end,
            closeOnClick = false,
        },
        {
            text = "Reset Session Data",
            func = function()
                self.sessionStart = GetMoney()
                self.history = {}
                self:Update()
            end,
        },
    }

    addon.Menu:Open(self.frame, items)
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
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Settings", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()

    -- Draw Graph
    if #self.history > 2 then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(200, 50)
            self.graph = addon.Graph:New(self.graphFrame, 200, 50)
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
    elseif self.graphFrame then
        self.graphFrame:Hide()
    end
end

function GoldWidget:OnClick(button)
    if button == "RightButton" then
        self:OpenMenu()
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
