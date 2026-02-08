-- Currency.lua
-- Advanced Currency widget for StatusDock
-- Features: Configurable tracking, weekly caps, Warband Transfer support

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local CurrencyWidget = addon.BaseWidget:New("Currency")
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

    -- Add Warband Transferable Flag (heuristic or API)
    -- As of 11.0, info.isAccountTransferable should exist
    return info
end

-- [ UPDATE ] ------------------------------------------------------------------

function CurrencyWidget:Update()
    -- Heuristic: Show the currency with the most recent gain?
    -- Or just stick to Conquest/Flightstones for current content.
    -- Better: Configurable via settings (TODO). For now, Flightstones + Conquest.

    local primaryID = 2245 -- Flightstones (Current PVE)
    local secondaryID = 1602 -- Conquest (Current PVP)

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

    self:SetText(text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function CurrencyWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {
        {
            text = "Open Currency Tab",
            func = function() ToggleCharacter("TokenFrame") end,
        },
        -- Transfer UI (if available)
        -- Placeholder for Warband Transfer
        -- {
        --     text = "Transfer Currency",
        --     func = function() ... end
        -- }
    }

    addon.Menu:Open(self.frame, items)
end

function CurrencyWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Currencies", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for _, id in ipairs(TRACKED_CURRENCIES) do
        local info = self:GetCurrencyInfo(id)
        if info and (info.quantity > 0 or info.maxQuantity > 0) then
            local name = info.name
            local count = info.quantity
            local max = info.maxQuantity
            local icon = info.iconFileID

            local countStr = tostring(count)
            if max > 0 then
                countStr = string.format("%d / %d", count, max)
            end

            -- Check weekly cap
            if info.maxWeeklyQuantity > 0 then
                local currentWeek = info.quantityEarnedThisWeek or 0
                countStr = countStr .. string.format(" (Week: %d/%d)", currentWeek, info.maxWeeklyQuantity)
            end

            -- Transferable indicator
            local transferIcon = ""
            if info.isAccountTransferable then
                transferIcon = "|TInterface\\Common\\ReputationStar:14:14:0:0:32:32:0:32:0:32|t" -- Placeholder icon
            end

            GameTooltip:AddDoubleLine(string.format("|T%s:14|t %s%s", icon, name, transferIcon), countStr, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Currency Tab", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Menu", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function CurrencyWidget:OnClick(button)
    if button == "RightButton" then
        self:OpenMenu()
    else
        ToggleCharacter("TokenFrame")
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function CurrencyWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

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
