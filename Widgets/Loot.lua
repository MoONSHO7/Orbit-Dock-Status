-- Loot.lua
-- Advanced Loot widget for StatusDock
-- Features: Auto-Loot Toggle, Speed Loot, Last Looted Item

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local LootWidget = addon.BaseWidget:New("Loot")
addon.LootWidget = LootWidget

-- [ CONSTANTS ] --------------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local ITEM_CLEAR_SEC = 10

-- [ SETTINGS ] --------------------------------------------------------------------

LootWidget.settings = {
    autoLoot = true,
    speedLoot = true,
}

-- [ STATE ] -----------------------------------------------------------------------

LootWidget.lastItem = nil
LootWidget.lastItemTime = 0

-- [ SPEED LOOT ] ------------------------------------------------------------------

function LootWidget:HandleLoot()
    if not self.settings.speedLoot then return end

    local numItems = GetNumLootItems()
    if numItems > 0 then
        -- The rogue grabs everything before the party can roll
        for i = numItems, 1, -1 do
            LootSlot(i)
        end
    end
end

-- [ UPDATES ] ---------------------------------------------------------------------

function LootWidget:Update()
    local text = "Loot: "
    if self.settings.autoLoot then
        text = text .. "|cff00ff00Auto|r"
    else
        text = text .. "|cff888888Manual|r"
    end

    if self.lastItem then
        text = text .. " " .. self.lastItem
    end

    self:SetText(text)
end

function LootWidget:OnLootReceived(itemLink, quantity)
    self.lastItem = itemLink
    self.lastItemTime = GetTime()
    self:Update()

    C_Timer.After(ITEM_CLEAR_SEC, function()
        if GetTime() - self.lastItemTime >= ITEM_CLEAR_SEC then
            self.lastItem = nil
            self:Update()
        end
    end)
end

-- [ INTERACTION ] -----------------------------------------------------------------

function LootWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {
        {
            text = "Auto Loot",
            checked = self.settings.autoLoot,
            func = function()
                self.settings.autoLoot = not self.settings.autoLoot
                SetCVar("autoLootDefault", self.settings.autoLoot and "1" or "0")
                self:Update()
            end,
            closeOnClick = false,
        },
        {
            text = "Speed Loot",
            checked = self.settings.speedLoot,
            func = function() self.settings.speedLoot = not self.settings.speedLoot end,
            closeOnClick = false,
        },
    }

    addon.Menu:Open(self.frame, items)
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
    if button == "RightButton" then
        self:OpenMenu()
    end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function LootWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    -- The dungeon master consults the CVar scroll of truth
    self.settings.autoLoot = GetCVar("autoLootDefault") == "1"


    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("LOOT_READY", function() self:HandleLoot() end)

    self:SetCategory("GAMEPLAY")
    self:Register()
    self:Update()
end


local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() LootWidget:OnLoad() end)
end)
