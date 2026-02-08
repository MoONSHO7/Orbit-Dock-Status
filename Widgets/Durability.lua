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
    local totalRepairCost = 0
    
    for _, info in ipairs(SLOTS) do
        local slotId = GetInventorySlotInfo(info.slot)
        if slotId then
            local current, maximum = GetInventoryItemDurability(slotId)
            if current and maximum and maximum > 0 then
                local pct = (current / maximum) * 100
                table.insert(slotInfo, {
                    name = info.name,
                    pct = pct,
                    current = current,
                    max = maximum
                })
                if pct < lowest then
                    lowest = pct
                end
            end
        end
    end
    
    return lowest, slotInfo
end

function DurabilityWidget:GetColor(pct)
    if pct <= 20 then
        return "|cffff0000" -- Red
    elseif pct <= 50 then
        return "|cffffa500" -- Orange
    elseif pct < 100 then
        return "|cffffffff" -- White
    else
        return "|cff00ff00" -- Green (only for tooltip)
    end
end

-- [ UPDATES ] -----------------------------------------------------------------

function DurabilityWidget:Update()
    local lowest, _ = self:GetDurabilityInfo()
    local color = self:GetColor(lowest)
    
    -- Contextual Visibility: Hide if 100% and not in Edit Mode
    if lowest >= 100 and not self.inEditMode then
        self.frame:Hide()
    else
        self.frame:Show()
        self:SetText(string.format("%s%d%%|r Dur", color, lowest))
    end
end

-- [ AUTO REPAIR ] -------------------------------------------------------------

function DurabilityWidget:TryAutoRepair()
    if not self.settings.autoRepair then return end
    if not CanMerchantRepair() then return end

    local cost = GetRepairAllCost()
    if cost <= 0 then return end

    local money = GetMoney()
    local repaired = false

    -- Try Guild Repair
    if self.settings.useGuild and IsInGuild() and CanGuildBankRepair() then
        local guildMoney = GetGuildBankWithdrawMoney()
        if guildMoney == -1 or guildMoney >= cost then
            RepairAllItems(true)
            repaired = true
            print("|cff00ff00Auto-Repaired (Guild)|r")
        end
    end

    -- Fallback to Personal Repair
    if not repaired and money >= cost then
        RepairAllItems()
        repaired = true
        local gold = math.floor(cost / 10000)
        local silver = math.floor((cost % 10000) / 100)
        local copper = cost % 100
        print(string.format("|cff00ff00Auto-Repaired for %dg %ds %dc|r", gold, silver, copper))
    end

    if not repaired then
        print("|cffff0000Not enough money to auto-repair!|r")
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function DurabilityWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {
        {
            text = "Auto-Repair",
            checked = self.settings.autoRepair,
            func = function() self.settings.autoRepair = not self.settings.autoRepair end,
            closeOnClick = false,
        },
        {
            text = "Use Guild Funds",
            checked = self.settings.useGuild,
            func = function() self.settings.useGuild = not self.settings.useGuild end,
            closeOnClick = false,
        },
    }

    addon.Menu:Open(self.frame, items)
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
            local r, g, b = 1, 1, 1
            if info.pct <= 20 then r, g, b = 1, 0, 0
            elseif info.pct <= 50 then r, g, b = 1, 0.65, 0
            end

            GameTooltip:AddDoubleLine(info.name, string.format("%d%%", info.pct), 1, 1, 1, r, g, b)
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
    if button == "RightButton" then
        self:OpenMenu()
    else
        ToggleCharacter("PaperDollFrame")
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function DurabilityWidget:OnLoad()
    self:CreateFrame(70, 20)
    
    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    -- Register events
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    self:RegisterEvent("MERCHANT_SHOW", function() self:TryAutoRepair() end)
    
    -- Register with manager
    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() DurabilityWidget:OnLoad() end)
end)
