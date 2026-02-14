-- Gold.lua
-- Currency display widget for StatusDock
-- Features: Cross-character tracking, session profit/loss, gold/hour, auto-sell junk, graph

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local GoldWidget = addon.BaseWidget:New("Gold")
addon.GoldWidget = GoldWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000
local FORMAT_THRESHOLD_K = 1000
local FORMAT_THRESHOLD_M = 1000000
local GRAPH_WIDTH = 200
local GRAPH_HEIGHT = 50
local GRAPH_OFFSET_Y = -5
local HISTORY_SIZE = 60
local HISTORY_INTERVAL_SEC = 60
local SECONDS_PER_HOUR = 3600
local INIT_DELAY_SEC = 0.5
local BAG_COUNT = 4
local JUNK_QUALITY = 0
local MIN_HISTORY_POINTS = 2
local DAILY_HISTORY_DAYS = 7
local SECONDS_PER_DAY = 86400

-- [ STATE ] -----------------------------------------------------------------------

local RingBuffer = addon.Formatting.RingBuffer
GoldWidget.settings = { autoSell = true }
GoldWidget.history = RingBuffer:New(HISTORY_SIZE)
GoldWidget.sessionStart = 0
GoldWidget.sessionStartTime = 0

-- [ FORMATTING ] ------------------------------------------------------------------

function GoldWidget:FormatMoney(copper, full) return addon.Formatting:FormatMoney(copper, full) end

function GoldWidget:FormatProfit(profit)
    local color = profit > 0 and "|cff00ff00+" or (profit < 0 and "|cffff0000" or "|cffffffff")
    return color .. self:FormatMoney(math.abs(profit), false)
end

-- [ CROSS-CHARACTER TRACKING ] ----------------------------------------------------

function GoldWidget:SaveCharacterGold(copper)
    if not Orbit_StatusDB then Orbit_StatusDB = {} end
    if not Orbit_StatusDB.accountData then Orbit_StatusDB.accountData = {} end
    local realm = GetRealmName()
    if not Orbit_StatusDB.accountData[realm] then Orbit_StatusDB.accountData[realm] = {} end
    local name = UnitName("player")
    local _, class = UnitClass("player")
    Orbit_StatusDB.accountData[realm][name] = {
        gold = copper,
        class = class,
        level = UnitLevel("player"),
        lastSeen = time(),
    }
    self:UpdateDailyHistory(copper)
end

function GoldWidget:UpdateDailyHistory(copper)
    if not Orbit_StatusDB then return end
    if not Orbit_StatusDB.dailyGold then Orbit_StatusDB.dailyGold = {} end
    local today = math.floor(time() / SECONDS_PER_DAY)
    local hist = Orbit_StatusDB.dailyGold
    if #hist == 0 or hist[#hist].day ~= today then
        table.insert(hist, { day = today, gold = copper })
        if #hist > DAILY_HISTORY_DAYS then table.remove(hist, 1) end
    else
        hist[#hist].gold = copper
    end
end

function GoldWidget:GetDailyDeltas()
    if not Orbit_StatusDB or not Orbit_StatusDB.dailyGold then return {} end
    local hist = Orbit_StatusDB.dailyGold
    local deltas = {}
    for i = 2, #hist do
        table.insert(deltas, { day = hist[i].day, delta = hist[i].gold - hist[i-1].gold })
    end
    return deltas
end

function GoldWidget:GetAccountGold()
    if not Orbit_StatusDB or not Orbit_StatusDB.accountData then return {} end
    local result = {}
    for realm, chars in pairs(Orbit_StatusDB.accountData) do
        for name, data in pairs(chars) do
            table.insert(result, { name = name, realm = realm, class = data.class, level = data.level, gold = data.gold, lastSeen = data.lastSeen })
        end
    end
    table.sort(result, function(a, b) return a.gold > b.gold end)
    return result
end

-- [ GOLD PER HOUR ] ---------------------------------------------------------------

function GoldWidget:GetGoldPerHour()
    local elapsed = GetTime() - self.sessionStartTime
    if elapsed <= 0 then return 0 end
    local delta = GetMoney() - self.sessionStart
    return (delta / elapsed) * SECONDS_PER_HOUR
end

-- [ UPDATES ] ---------------------------------------------------------------------

function GoldWidget:Update()
    local money = GetMoney()
    self:SetText(self:FormatMoney(money))
    self:SaveCharacterGold(money)
    local t = GetTime()
    if not self.lastHistoryTime or (t - self.lastHistoryTime) > HISTORY_INTERVAL_SEC then
        self.history:Push(money)
        self.lastHistoryTime = t
    end
end

-- [ AUTO SELL JUNK ] --------------------------------------------------------------

function GoldWidget:AutoSellJunk()
    if not self.settings.autoSell then return end
    local profit = 0
    for bag = 0, BAG_COUNT do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == JUNK_QUALITY and not info.isLocked then
                local price = select(11, GetItemInfo(info.hyperlink))
                if price and price > 0 then
                    C_Container.UseContainerItem(bag, slot)
                    profit = profit + (price * info.stackCount)
                end
            end
        end
    end
    if profit > 0 then print(string.format("|cff00ff00Auto-Sold Junk for %s|r", self:FormatMoney(profit, false))) end
end

-- [ CONTEXT MENU ] ----------------------------------------------------------------

function GoldWidget:GetMenuItems()
    return {
        { text = "Auto-Sell Grey Items", checked = self.settings.autoSell, func = function() self.settings.autoSell = not self.settings.autoSell end, closeOnClick = false },
        { text = "Reset Session Data", func = function() self.sessionStart = GetMoney(); self.sessionStartTime = GetTime(); self.history:Clear(); self:Update() end },
    }
end

-- [ INTERACTION ] -----------------------------------------------------------------

function GoldWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Wealth", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local current = GetMoney()
    GameTooltip:AddDoubleLine("Current:", self:FormatMoney(current, false), 1, 1, 1, 1, 1, 1)

    local profit = current - self.sessionStart
    GameTooltip:AddDoubleLine("Session:", self:FormatProfit(profit), 1, 1, 1, 1, 1, 1)

    local gph = self:GetGoldPerHour()
    local gphGold = math.floor(gph / COPPER_PER_GOLD)
    GameTooltip:AddDoubleLine("Gold/Hour:", self:FormatProfit(gph), 1, 1, 1, 1, 1, 1)

    local deltas = self:GetDailyDeltas()
    if #deltas > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Daily History", 0.7, 0.7, 0.7)
        for _, d in ipairs(deltas) do
            local dateStr = date("%m/%d", d.day * SECONDS_PER_DAY)
            GameTooltip:AddDoubleLine(dateStr, self:FormatProfit(d.delta), 1, 1, 1, 1, 1, 1)
        end
    end

    local chars = self:GetAccountGold()
    if #chars > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Account Gold", 0.7, 0.7, 0.7)
        local total = 0
        for _, char in ipairs(chars) do
            local classColor = RAID_CLASS_COLORS[char.class]
            local r, g, b = classColor and classColor.r or 1, classColor and classColor.g or 1, classColor and classColor.b or 1
            GameTooltip:AddDoubleLine(string.format("%s (%d)", char.name, char.level), self:FormatMoney(char.gold, false), r, g, b, 1, 1, 1)
            total = total + char.gold
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total:", self:FormatMoney(total, false), 1, 0.82, 0, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Settings", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()

    if self.history:Count() > MIN_HISTORY_POINTS then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(GRAPH_WIDTH, GRAPH_HEIGHT)
            self.graph = addon.Graph:New(self.graphFrame, GRAPH_WIDTH, GRAPH_HEIGHT)
        end
        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, GRAPH_OFFSET_Y)
        self.graphFrame:Show()
        self.graph:Clear()
        self.graph:SetColor(1, 0.84, 0, 1)
        for _, val in self.history:Iterate() do self.graph:AddData(val) end
        self.graph:Draw()
    elseif self.graphFrame then
        self.graphFrame:Hide()
    end
end

function GoldWidget:OnClick(button)
    if button == "RightButton" then self:ShowContextMenu()
    else ToggleAllBags() end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function GoldWidget:OnLoad()
    self:CreateFrame()
    self.sessionStart = GetMoney()
    self.sessionStartTime = GetTime()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Bags"
    self.rightClickHint = "Settings"
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("MERCHANT_SHOW", function() self:AutoSellJunk() end)
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() GoldWidget:OnLoad() end)
end)
