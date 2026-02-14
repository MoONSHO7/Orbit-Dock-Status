-- Keystroke.lua
-- Keybind display widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local KeyWidget = addon.BaseWidget:New("Keystroke")
addon.KeyWidget = KeyWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local MAX_RECENT = 5
local FADE_DURATION_SEC = 3

-- [ STATE ] -----------------------------------------------------------------------

local RingBuffer = addon.Formatting.RingBuffer
KeyWidget.recentKeys = RingBuffer:New(MAX_RECENT)

-- [ UPDATES ] ---------------------------------------------------------------------

function KeyWidget:Update()
    if self.recentKeys:Count() > 0 then
        local latest = self.recentKeys:Last(0)
        local age = GetTime() - latest.time
        if age > FADE_DURATION_SEC then
            self:SetText("|cff888888\226\128\148|r")
        else
            self:SetText("|cff00ccff" .. latest.key .. "|r")
        end
    else
        self:SetText("|cff888888\226\128\148|r")
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function KeyWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Recent Keybinds", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    if self.recentKeys:Count() == 0 then
        GameTooltip:AddLine("No recent keystrokes", 0.5, 0.5, 0.5)
    else
        for _, entry in self.recentKeys:Iterate() do
            local age = GetTime() - entry.time
            GameTooltip:AddDoubleLine(entry.key, string.format("%.1fs ago", age), 1, 1, 1, 0.5, 0.5, 0.5)
        end
    end
    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function KeyWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)

    local keyFrame = CreateFrame("Frame", nil, UIParent)
    keyFrame:SetPropagateKeyboardInput(true)
    keyFrame:SetScript("OnKeyDown", function(_, key)
        self.recentKeys:Push({ key = key, time = GetTime() })
        self:Update()
    end)

    self:SetCategory("UTILITY")
    self:Register()
    self:SetUpdateTier("FAST")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() KeyWidget:OnLoad() end)
end)
