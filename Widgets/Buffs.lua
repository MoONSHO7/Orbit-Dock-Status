-- Buffs.lua
-- Raid Consumables widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local BuffsWidget = addon.BaseWidget:New("Buffs")
addon.BuffsWidget = BuffsWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local WELL_FED_NAME = "Well Fed"
local FLASK_DURATIONS = { [3600] = true, [1800] = true }
local FOOD_ICON = "|TInterface\\Icons\\Spell_Misc_Food:14|t "
local FLASK_ICON = "|TInterface\\Icons\\Trade_Alchemy_PotionA5:14|t "
local COLOR_READY = "|cff00ff00"
local COLOR_MISSING = "|cffff0000"
local MAX_BUFF_SCAN = 40
local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ STATE ] -----------------------------------------------------------------------

BuffsWidget.cachedFlask = false
BuffsWidget.cachedFood = false
BuffsWidget.cachedWeapon = false
BuffsWidget.useCachedData = false

-- [ HELPERS ] ---------------------------------------------------------------------

function BuffsWidget:CheckBuffs()
    if self.useCachedData then return self.cachedFlask, self.cachedFood, false, self.cachedWeapon end

    local hasFlask, hasFood, hasWeapon = false, false, false

    for i = 1, MAX_BUFF_SCAN do
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not auraData then break end
        if auraData.name == WELL_FED_NAME then hasFood = true end
        if FLASK_DURATIONS[auraData.duration] then hasFlask = true end
    end

    local hasMainHandEnchant = GetWeaponEnchantInfo()
    if hasMainHandEnchant then hasWeapon = true end

    self.cachedFlask = hasFlask
    self.cachedFood = hasFood
    self.cachedWeapon = hasWeapon

    return hasFlask, hasFood, false, hasWeapon
end

-- [ UPDATE ] ----------------------------------------------------------------------

function BuffsWidget:Update()
    if not IsInGroup() and not self.inEditMode then
        self.frame:Hide()
        return
    end
    self.frame:Show()

    local flask, food, _, weapon = self:CheckBuffs()
    local text = ""

    if not food then text = text .. FOOD_ICON end
    if not flask then text = text .. FLASK_ICON end

    if text == "" then
        self:SetText(COLOR_READY .. "Ready|r")
        self:StopFlash()
    else
        self:SetText(COLOR_MISSING .. "Missing:|r " .. text)
        if self.useCachedData then self:Flash() else self:StopFlash() end
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function BuffsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Consumables", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local flask, food, _, weapon = self:CheckBuffs()

    GameTooltip:AddDoubleLine("Food:", food and "|cff00ff00Yes|r" or "|cffff0000No|r", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Flask:", flask and "|cff00ff00Yes|r" or "|cffff0000No|r", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Weapon:", weapon and "|cff00ff00Yes|r" or "|cffff0000No|r", 1, 1, 1, 1, 1, 1)

    local buffCount, debuffCount = 0, 0
    for i = 1, MAX_BUFF_SCAN do
        if C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL") then buffCount = buffCount + 1 else break end
    end
    for i = 1, MAX_BUFF_SCAN do
        if C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL") then debuffCount = debuffCount + 1 else break end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Buffs:", tostring(buffCount), 1, 1, 1, 0, 1, 0)
    GameTooltip:AddDoubleLine("Debuffs:", tostring(debuffCount), 1, 1, 1, 1, 0.3, 0.3)

    if self.useCachedData then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Using cached data (in combat)|r")
    end

    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function BuffsWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)

    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        self.useCachedData = true
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self.useCachedData = false
        self:Update()
    end)

    self:SetCategory("CHARACTER")


    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() BuffsWidget:OnLoad() end)
end)
