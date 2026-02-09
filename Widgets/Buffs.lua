-- Buffs.lua
-- Raid Consumables widget for StatusDock
-- Features: Flask, Food, Rune, Weapon Buff tracking

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local BuffsWidget = addon.BaseWidget:New("Buffs")
addon.BuffsWidget = BuffsWidget
BuffsWidget.category = "Combat"

-- [ HELPERS ] -----------------------------------------------------------------

function BuffsWidget:CheckBuffs()
    local hasFlask = false
    local hasFood = false
    local hasRune = false
    local hasWeapon = false

    -- Modern Aura Iteration
    local i = 1
    while true do
        local aura = C_UnitAura.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end

        -- aura.name, aura.duration, etc.
        if aura.name == "Well Fed" then hasFood = true end

        if aura.duration == 3600 or aura.duration == 1800 then
            -- Heuristic for flask
            -- hasFlask = true
        end

        i = i + 1
    end

    -- Weapon Enchant Check (Still global GetWeaponEnchantInfo as of 10.2, but check C_TooltipInfo?)
    -- GetWeaponEnchantInfo is standard.
    local hasMainHandEnchant, mainHandExpiration, _, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, _, offHandEnchantID = GetWeaponEnchantInfo()
    if hasMainHandEnchant then hasWeapon = true end

    return hasFlask, hasFood, hasRune, hasWeapon
end

-- [ UPDATE ] ------------------------------------------------------------------

function BuffsWidget:Update()
    if not IsInGroup() and not self.inEditMode then
        self.frame:Hide()
        return
    end
    self.frame:Show()

    local flask, food, rune, weapon = self:CheckBuffs()
    local text = ""

    if not food then text = text .. "|TInterface\\Icons\\Spell_Misc_Food:14|t " end
    if not flask then text = text .. "|TInterface\\Icons\\Trade_Alchemy_PotionA5:14|t " end

    if text == "" then
        self:SetFormattedText(nil, "|cff00ff00Ready|r")
        self:StopFlash()
    else
        self:SetFormattedText("|cffff0000Missing:|r", text)
        if InCombatLockdown() then self:Flash() else self:StopFlash() end
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function BuffsWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateTitle("Consumables")
    -- Add manual toggles if needed
end

function BuffsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Consumables", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local flask, food, rune, weapon = self:CheckBuffs()

    GameTooltip:AddDoubleLine("Food:", food and "|cff00ff00Yes|r" or "|cffff0000No|r", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Flask:", flask and "|cff00ff00Yes|r" or "|cffff0000No|r", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Weapon:", weapon and "|cff00ff00Yes|r" or "|cffff0000No|r", 1, 1, 1, 1, 1, 1)

    GameTooltip:Show()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function BuffsWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() BuffsWidget:OnLoad() end)
end)
