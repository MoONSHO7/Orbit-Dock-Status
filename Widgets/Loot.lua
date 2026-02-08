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

-- [ SETTINGS ] ----------------------------------------------------------------

LootWidget.settings = {
    autoLoot = true,
    speedLoot = true,
}

-- [ STATE ] -------------------------------------------------------------------

LootWidget.lastItem = nil
LootWidget.lastItemTime = 0

-- [ SPEED LOOT ] --------------------------------------------------------------

function LootWidget:HandleLoot()
    if not self.settings.speedLoot then return end

    local numItems = GetNumLootItems()
    if numItems > 0 then
        -- Loot everything instantly
        for i = numItems, 1, -1 do
            LootSlot(i)
        end
    end
end

-- [ UPDATES ] -----------------------------------------------------------------

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

    -- Clear after 10s
    C_Timer.After(10, function()
        if GetTime() - self.lastItemTime >= 10 then
            self.lastItem = nil
            self:Update()
        end
    end)
end

-- [ INTERACTION ] -------------------------------------------------------------

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

-- [ LIFECYCLE ] ---------------------------------------------------------------

function LootWidget:OnLoad()
    self:CreateFrame(120, 20)

    -- Sync CVar
    self.settings.autoLoot = GetCVar("autoLootDefault") == "1"

    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Register events
    self:RegisterEvent("LOOT_READY", function() self:HandleLoot() end)
    self:RegisterEvent("CHAT_MSG_LOOT", function(_, msg)
        -- Parse link? Simplify: Just listen for item
        -- Or rely on LOOT_OPENED? No, LOOT_OPENED is for window.
        -- Use pattern matching on msg
    end)

    -- Register with manager
    self:Register()

    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() LootWidget:OnLoad() end)
end)
