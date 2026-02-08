-- Currency.lua
-- Advanced Currency widget for StatusDock
-- Features: Configurable tracking, weekly caps, Scroll Cycling

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local CurrencyWidget = addon.BaseWidget:New("Currency")
addon.CurrencyWidget = CurrencyWidget
CurrencyWidget.category = "Economy"

-- [ SETTINGS ] ----------------------------------------------------------------

CurrencyWidget.settings = {
    currentIndex = 1,
}

local TRACKED_CURRENCIES = {
    1602, -- Conquest
    1191, -- Valor
    490,  -- Honor
    515,  -- Darkmoon Prize Ticket
    1166, -- Timewarped Badge
    1220, -- Order Resources
    1553, -- Azerite
    1792, -- Honor (BFA)
    2003, -- Dragon Isles Supplies
    2245, -- Flightstones
    2706, -- Whelpling's Dreaming Crest
    2707, -- Drake's Dreaming Crest
    2708, -- Wyrm's Dreaming Crest
    2709, -- Aspect's Dreaming Crest
    2777, -- Renascent Dream
}

-- [ HELPER ] ------------------------------------------------------------------

function CurrencyWidget:GetCurrencyInfo(id)
    return C_CurrencyInfo.GetCurrencyInfo(id)
end

-- [ UPDATE ] ------------------------------------------------------------------

function CurrencyWidget:Update()
    local id = TRACKED_CURRENCIES[self.settings.currentIndex]
    if not id then id = TRACKED_CURRENCIES[1] end

    local info = self:GetCurrencyInfo(id)
    if info then
        -- Icon + Amount
        self:SetFormattedText(nil, string.format("|T%s:14|t %d", info.iconFileID, info.quantity))
    else
        self:SetFormattedText("Currency:", "Unknown")
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function CurrencyWidget:OnScroll(delta)
    if delta < 0 then
        self.settings.currentIndex = self.settings.currentIndex + 1
        if self.settings.currentIndex > #TRACKED_CURRENCIES then self.settings.currentIndex = 1 end
    else
        self.settings.currentIndex = self.settings.currentIndex - 1
        if self.settings.currentIndex < 1 then self.settings.currentIndex = #TRACKED_CURRENCIES end
    end
    self:Update()
end

function CurrencyWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateTitle("Tracked Currency")
    for i, id in ipairs(TRACKED_CURRENCIES) do
        local info = self:GetCurrencyInfo(id)
        if info then
            rootDescription:CreateRadio(string.format("|T%s:14|t %s", info.iconFileID, info.name), function() return self.settings.currentIndex == i end, function()
                self.settings.currentIndex = i
                self:Update()
            end)
        end
    end

    rootDescription:CreateButton("Open Currency Tab", function() ToggleCharacter("TokenFrame") end)
end

function CurrencyWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Currencies", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for i, id in ipairs(TRACKED_CURRENCIES) do
        local info = self:GetCurrencyInfo(id)
        if info and (info.quantity > 0 or info.maxQuantity > 0) then
            local countStr = tostring(info.quantity)
            if info.maxQuantity > 0 then
                countStr = string.format("%d / %d", info.quantity, info.maxQuantity)
            end

            -- Highlight selected
            local label = string.format("|T%s:14|t %s", info.iconFileID, info.name)
            if i == self.settings.currentIndex then
                label = "|cff00ff00>|r " .. label
            end

            GameTooltip:AddDoubleLine(label, countStr, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Scroll", "Cycle Currency", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function CurrencyWidget:OnClick(button)
    ToggleCharacter("TokenFrame")
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function CurrencyWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self:SetScrollFunc(function(_, delta) self:OnScroll(delta) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() CurrencyWidget:OnLoad() end)
end)
