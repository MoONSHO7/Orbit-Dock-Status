-- Loot.lua
-- Advanced Loot widget for StatusDock
-- Features: Auto-Loot Toggle, Speed Loot, Last Looted Item

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local LootWidget = addon.BaseWidget:New("Loot"); addon.LootWidget.category = "System"
addon.LootWidget = LootWidget

-- [ SETTINGS ] ----------------------------------------------------------------

LootWidget.settings = {
    autoLoot = true,
    speedLoot = true,
}

LootWidget.lastItem = nil
LootWidget.lastItemTime = 0

-- [ SPEED LOOT ] --------------------------------------------------------------

function LootWidget:HandleLoot()
    if not self.settings.speedLoot then return end
    local numItems = GetNumLootItems()
    if numItems > 0 then
        for i = numItems, 1, -1 do LootSlot(i) end
    end
end

-- [ UPDATES ] -----------------------------------------------------------------

function LootWidget:Update()
    local text = self.settings.autoLoot and "|cff00ff00Auto|r" or "|cff888888Manual|r"
    if self.lastItem then
        text = text .. " " .. self.lastItem
    end
    self:SetFormattedText("Loot:", text)
end

function LootWidget:OnLootReceived(itemLink)
    self.lastItem = itemLink
    self.lastItemTime = GetTime()
    self:Update()

    C_Timer.After(10, function()
        if GetTime() - self.lastItemTime >= 10 then
            self.lastItem = nil
            self:Update()
        end
    end)
end

-- [ INTERACTION ] -------------------------------------------------------------

function LootWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateCheckbox("Auto Loot", function() return self.settings.autoLoot end, function()
        self.settings.autoLoot = not self.settings.autoLoot
        SetCVar("autoLootDefault", self.settings.autoLoot and "1" or "0")
        self:Update()
    end)

    rootDescription:CreateCheckbox("Speed Loot", function() return self.settings.speedLoot end, function()
        self.settings.speedLoot = not self.settings.speedLoot
    end)
end

function LootWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Loot Manager", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    GameTooltip:AddDoubleLine("Auto Loot:", self.settings.autoLoot and "|cff00ff00On|r" or "|cffff0000Off|r", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Speed Loot:", self.settings.speedLoot and "|cff00ff00On|r" or "|cffff0000Off|r", 1, 1, 1, 1, 1, 1)

    if self.lastItem then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Last Looted:", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(self.lastItem)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Right Click", "Settings", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function LootWidget:OnClick(button)
    -- Left click?
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function LootWidget:OnLoad()
    self:CreateFrame(120, 20)
    self.settings.autoLoot = GetCVar("autoLootDefault") == "1"

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("LOOT_READY", function() self:HandleLoot() end)
    self:RegisterEvent("CHAT_MSG_LOOT", function(_, msg)
        -- Placeholder item parsing
    end)

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() LootWidget:OnLoad() end)
end)
