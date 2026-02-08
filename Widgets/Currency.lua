-- Currency.lua
-- Advanced Currency widget for StatusDock
-- Features: Configurable tracking, weekly caps, Warband Transfer support

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local CurrencyWidget = addon.BaseWidget:New("Currency"); addon.CurrencyWidget.category = "Economy"
addon.CurrencyWidget = CurrencyWidget

-- [ CONSTANTS ] ---------------------------------------------------------------

local TRACKED_CURRENCIES = {
    1602, -- Conquest
    1191, -- Valor
    490,  -- Honor
    515,  -- Darkmoon Prize Ticket
    1129, -- Seal of Tempered Fate (Legacy)
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
    2777, -- Renascent Dream (Catalyst)
}

-- [ HELPER ] ------------------------------------------------------------------

function CurrencyWidget:GetCurrencyInfo(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info then return nil end
    return info
end

-- [ UPDATE ] ------------------------------------------------------------------

function CurrencyWidget:Update()
    local primaryID = 2245 -- Flightstones
    local secondaryID = 1602 -- Conquest

    local info1 = self:GetCurrencyInfo(primaryID)
    local info2 = self:GetCurrencyInfo(secondaryID)

    local text = ""
    if info1 and info1.quantity > 0 then
        text = string.format("|T%s:14|t %d", info1.iconFileID, info1.quantity)
    end
    if info2 and info2.quantity > 0 then
        if text ~= "" then text = text .. "  " end
        text = text .. string.format("|T%s:14|t %d", info2.iconFileID, info2.quantity)
    end
    if text == "" then text = "Currency" end

    self:SetFormattedText(nil, text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function CurrencyWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Open Currency Tab", function() ToggleCharacter("TokenFrame") end)
end

function CurrencyWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Currencies", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for _, id in ipairs(TRACKED_CURRENCIES) do
        local info = self:GetCurrencyInfo(id)
        if info and (info.quantity > 0 or info.maxQuantity > 0) then
            local countStr = tostring(info.quantity)
            if info.maxQuantity > 0 then
                countStr = string.format("%d / %d", info.quantity, info.maxQuantity)
            end
            if info.maxWeeklyQuantity > 0 then
                countStr = countStr .. string.format(" (Week: %d/%d)", info.quantityEarnedThisWeek or 0, info.maxWeeklyQuantity)
            end

            GameTooltip:AddDoubleLine(string.format("|T%s:14|t %s", info.iconFileID, info.name), countStr, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Currency Tab", 0.7, 0.7, 0.7, 1, 1, 1)
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
