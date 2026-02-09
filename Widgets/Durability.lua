-- Durability.lua
-- Armor durability widget for StatusDock
-- Features: Auto-repair, smart hiding, gradient coloring

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local DurabilityWidget = addon.BaseWidget:New("Durability"); addon.DurabilityWidget.category = "Character"
addon.DurabilityWidget = DurabilityWidget

-- [ SETTINGS ] ----------------------------------------------------------------

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

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function DurabilityWidget:GetDurabilityInfo()
    local lowest = 100
    local slotInfo = {}
    
    for _, info in ipairs(SLOTS) do
        local slotId = GetInventorySlotInfo(info.slot)
        if slotId then
            local current, maximum = GetInventoryItemDurability(slotId)
            if current and maximum and maximum > 0 then
                local pct = (current / maximum) * 100
                table.insert(slotInfo, {
                    name = info.name,
                    pct = pct
                })
                if pct < lowest then lowest = pct end
            end
        end
    end
    return lowest, slotInfo
end

function DurabilityWidget:GetColor(pct)
    return addon.Formatting:GetColor(pct, 100, false)
end

-- [ UPDATES ] -----------------------------------------------------------------

function DurabilityWidget:Update()
    local lowest, _ = self:GetDurabilityInfo()
    local color = self:GetColor(lowest)

    if lowest >= 100 and not self.inEditMode then
        self.frame:Hide()
    else
        self.frame:Show()
        self:SetFormattedText("Durability:", string.format("%s%d%%|r", color, lowest))
    end
end

-- [ AUTO REPAIR ] -------------------------------------------------------------

function DurabilityWidget:TryAutoRepair()
    if not self.settings.autoRepair or not CanMerchantRepair() then return end

    local cost = GetRepairAllCost()
    if cost <= 0 then return end

    local money = GetMoney()
    local repaired = false

    if self.settings.useGuild and IsInGuild() and CanGuildBankRepair() then
        local guildMoney = GetGuildBankWithdrawMoney()
        if guildMoney == -1 or guildMoney >= cost then
            RepairAllItems(true)
            repaired = true
            print("|cff00ff00Auto-Repaired (Guild)|r")
        end
    end

    if not repaired and money >= cost then
        RepairAllItems()
        repaired = true
        print(string.format("|cff00ff00Auto-Repaired for %s|r", addon.Formatting:FormatMoney(cost, false)))
    end

    if not repaired then
        print("|cffff0000Not enough money to auto-repair!|r")
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function DurabilityWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateCheckbox("Auto-Repair", function() return self.settings.autoRepair end, function()
        self.settings.autoRepair = not self.settings.autoRepair
    end)

    rootDescription:CreateCheckbox("Use Guild Funds", function() return self.settings.useGuild end, function()
        self.settings.useGuild = not self.settings.useGuild
    end)
end

function DurabilityWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Durability", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local lowest, slotInfo = self:GetDurabilityInfo()
    local shownAny = false

    for _, info in ipairs(slotInfo) do
        if info.pct < 100 then
            local color = self:GetColor(info.pct)
            GameTooltip:AddDoubleLine(info.name, color .. string.format("%d%%", info.pct) .. "|r", 1, 1, 1)
            shownAny = true
        end
    end

    if not shownAny then
        GameTooltip:AddLine("All items at 100%", 0, 1, 0)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Character Info", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Settings", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function DurabilityWidget:OnClick(button)
    ToggleCharacter("PaperDollFrame")
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function DurabilityWidget:OnLoad()
    self:CreateFrame(70, 20)
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    self:RegisterEvent("MERCHANT_SHOW", function() self:TryAutoRepair() end)
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() DurabilityWidget:OnLoad() end)
end)
