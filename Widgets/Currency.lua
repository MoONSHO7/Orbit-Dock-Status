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

-- [ CONSTANTS ] -------------------------------------------------------------------

local TRACKED_CURRENCIES = {
    1602, 1191, 490, 515, 1129, 1166, 1220, 1553, 1792,
    2003, 2245, 2706, 2707, 2708, 2709, 2777,
}

local PRIMARY_CURRENCY_ID = 2245
local SECONDARY_CURRENCY_ID = 1602
local ICON_SIZE = 14
local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ HELPER ] ----------------------------------------------------------------------

function CurrencyWidget:GetCurrencyInfo(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info then return nil end
    return info
end

function CurrencyWidget:GetSeasonDelta(id, currentQty)
    if not Orbit_StatusDB then Orbit_StatusDB = {} end
    if not Orbit_StatusDB.seasonCurrency then Orbit_StatusDB.seasonCurrency = {} end
    if not Orbit_StatusDB.seasonCurrency[id] then
        Orbit_StatusDB.seasonCurrency[id] = currentQty
        return 0
    end
    return currentQty - Orbit_StatusDB.seasonCurrency[id]
end

-- [ UPDATE ] ----------------------------------------------------------------------

function CurrencyWidget:Update()
    -- The coin purse shows whatever shiny thing the goblin merchant demands

    local primaryID = PRIMARY_CURRENCY_ID
    local secondaryID = SECONDARY_CURRENCY_ID

    local info1 = self:GetCurrencyInfo(primaryID)
    local info2 = self:GetCurrencyInfo(secondaryID)

    local text = ""

    if info1 and info1.quantity > 0 then
        text = string.format("|T%s:%d|t %d", info1.iconFileID, ICON_SIZE, info1.quantity)
    end

    if info2 and info2.quantity > 0 then
        if text ~= "" then text = text .. "  " end
        text = text .. string.format("|T%s:%d|t %d", info2.iconFileID, ICON_SIZE, info2.quantity)
    end

    if text == "" then text = "Currency" end

    self:SetText(text)
end

-- [ INTERACTION ] -----------------------------------------------------------------

function CurrencyWidget:GetMenuItems()
    return {
        { text = "Open Currency Tab", func = function() ToggleCharacter("TokenFrame") end },
    }
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
            local r, g, b = 1, 1, 1
            if info.maxQuantity > 0 then
                countStr = string.format("%d / %d", info.quantity, info.maxQuantity)
                local pct = info.quantity / info.maxQuantity
                if pct >= 0.9 then r, g, b = 0, 1, 0
                elseif pct >= 0.5 then r, g, b = 1, 1, 0 end
            end
            if info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 then
                local weekEarned = info.quantityEarnedThisWeek or 0
                countStr = countStr .. string.format(" (Week: %d/%d)", weekEarned, info.maxWeeklyQuantity)
                local weekPct = weekEarned / info.maxWeeklyQuantity
                if weekPct >= 1 then r, g, b = 0, 1, 0
                elseif weekPct >= 0.5 then r, g, b = 1, 0.8, 0 end
            end
            local transferIcon = (info.isAccountTransferable) and " |cff00ccff\226\154\136|r" or ""
            GameTooltip:AddDoubleLine(string.format("|T%s:%d|t %s%s", info.iconFileID, ICON_SIZE, info.name, transferIcon), countStr, 1, 1, 1, r, g, b)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Currency Tab", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Menu", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function CurrencyWidget:OnClick(button)
    if button == "RightButton" then
        self:ShowContextMenu()
    else
        ToggleCharacter("TokenFrame")
    end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function CurrencyWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:SetCategory("GAMEPLAY")


    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() CurrencyWidget:OnLoad() end)
end)
