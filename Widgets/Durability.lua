-- Durability.lua
-- Armor durability widget for StatusDock
-- Features: Auto-repair, smart hiding, gradient coloring

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local DurabilityWidget = addon.BaseWidget:New("Durability")
addon.DurabilityWidget = DurabilityWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local DURABILITY_CRITICAL_PCT = 20
local DURABILITY_FLASH_PCT = 10
local DURABILITY_WARNING_PCT = 50
local FULL_PCT = 100
local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000
local FRAME_WIDTH = 70
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 0.5

-- [ SETTINGS ] --------------------------------------------------------------------

DurabilityWidget.settings = {
    autoRepair = true,
    useGuild = true,
}

local SLOTS = {
    { slot = "HeadSlot", name = "Head" },
    { slot = "ShoulderSlot", name = "Shoulders" },
    { slot = "ChestSlot", name = "Chest" },
    { slot = "WristSlot", name = "Wrists" },
    { slot = "HandsSlot", name = "Hands" },
    { slot = "WaistSlot", name = "Waist" },
    { slot = "LegsSlot", name = "Legs" },
    { slot = "FeetSlot", name = "Feet" },
    { slot = "MainHandSlot", name = "Main Hand" },
    { slot = "SecondaryHandSlot", name = "Off Hand" },
}

-- [ HELPER FUNCTIONS ] ------------------------------------------------------------

local slotInfoCache = {}

function DurabilityWidget:GetDurabilityInfo()
    local lowest = 100
    local count = 0
    for _, info in ipairs(SLOTS) do
        local slotId = GetInventorySlotInfo(info.slot)
        if slotId then
            local current, maximum = GetInventoryItemDurability(slotId)
            if current and maximum and maximum > 0 then
                local pct = (current / maximum) * 100
                count = count + 1
                local entry = slotInfoCache[count]
                if not entry then entry = {}; slotInfoCache[count] = entry end
                entry.name = info.name
                entry.pct = pct
                entry.current = current
                entry.max = maximum
                if pct < lowest then lowest = pct end
            end
        end
    end
    return lowest, slotInfoCache, count
end

function DurabilityWidget:GetColor(pct)
    if pct <= DURABILITY_CRITICAL_PCT then return "|cffff0000"
    elseif pct <= DURABILITY_WARNING_PCT then return "|cffffa500"
    elseif pct < FULL_PCT then return "|cffffffff"
    else return "|cff00ff00" end
end

-- [ UPDATES ] ---------------------------------------------------------------------

function DurabilityWidget:Update()
    local lowest, _ = self:GetDurabilityInfo()
    local color = self:GetColor(lowest)
    if lowest >= FULL_PCT and not self.inEditMode then
        self.frame:Hide()
        self:StopFlash()
    else
        self.frame:Show()
        self:SetText(string.format("%s%d%%|r Dur", color, lowest))
        if lowest <= DURABILITY_FLASH_PCT then self:Flash()
        else self:StopFlash() end
    end
end

-- [ AUTO REPAIR ] -----------------------------------------------------------------

function DurabilityWidget:TryAutoRepair()
    if not self.settings.autoRepair then return end
    if not CanMerchantRepair() then return end

    local cost = GetRepairAllCost()
    if cost <= 0 then return end

    local money = GetMoney()
    local repaired = false

    -- The cleric attempts a guild-funded Mending spell first
    if self.settings.useGuild and IsInGuild() and CanGuildBankRepair() then
        local guildMoney = GetGuildBankWithdrawMoney()
        if guildMoney == -1 or guildMoney >= cost then
            RepairAllItems(true)
            repaired = true
            print("|cff00ff00Auto-Repaired (Guild)|r")
        end
    end

    -- No guild funds? The fighter pays out of pocket
    if not repaired and money >= cost then
        RepairAllItems()
        repaired = true
        local gold = math.floor(cost / COPPER_PER_GOLD)
        local silver = math.floor((cost % COPPER_PER_GOLD) / COPPER_PER_SILVER)
        local copper = cost % COPPER_PER_SILVER
        print(string.format("|cff00ff00Auto-Repaired for %dg %ds %dc|r", gold, silver, copper))
    end

    if not repaired then
        print("|cffff0000Not enough money to auto-repair!|r")
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function DurabilityWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Durability", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local _, slots, count = self:GetDurabilityInfo()
    local shownAny = false
    for i = 1, count do
        local info = slots[i]
        local r, g, b = 1, 1, 1
        if info.pct <= DURABILITY_FLASH_PCT then r, g, b = 1, 0, 0
        elseif info.pct <= DURABILITY_CRITICAL_PCT then r, g, b = 1, 0.3, 0
        elseif info.pct <= DURABILITY_WARNING_PCT then r, g, b = 1, 0.65, 0
        elseif info.pct < FULL_PCT then r, g, b = 1, 1, 1 end
        GameTooltip:AddDoubleLine(info.name, string.format("%d%%", info.pct), 1, 1, 1, r, g, b)
        shownAny = true
    end
    if not shownAny then GameTooltip:AddLine("All items at 100%", 0, 1, 0) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Character Info", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Settings", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function DurabilityWidget:GetMenuItems()
    return {
        { text = "Auto-Repair", checked = self.settings.autoRepair, func = function() self.settings.autoRepair = not self.settings.autoRepair end, closeOnClick = false },
        { text = "Use Guild Funds", checked = self.settings.useGuild, func = function() self.settings.useGuild = not self.settings.useGuild end, closeOnClick = false },
    }
end

function DurabilityWidget:OnClick(button)
    if button == "RightButton" then self:ShowContextMenu()
    else ToggleCharacter("PaperDollFrame") end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function DurabilityWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    

    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    self:RegisterEvent("MERCHANT_SHOW", function() self:TryAutoRepair() end)
    

    self:SetCategory("CHARACTER")

    self:Register()
    

    self:Update()
end


local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() DurabilityWidget:OnLoad() end)
end)
