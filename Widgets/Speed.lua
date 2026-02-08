-- Speed.lua
-- Advanced Movement Speed widget for StatusDock
-- Features: Real-time speed tracking, Dragonriding graph

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local SpeedWidget = addon.BaseWidget:New("Speed")
addon.SpeedWidget = SpeedWidget

-- [ HISTORY ] -----------------------------------------------------------------

SpeedWidget.history = {}
local HISTORY_SIZE = 60 -- Store last 60 ticks (30 seconds at 0.5s rate)

-- [ UPDATE ] ------------------------------------------------------------------

function SpeedWidget:Update()
    local unit = "player"
    local currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed(unit)

    local speed = (currentSpeed / runSpeed) * 100
    -- Dragonriding logic: Check for aura or speed > 400%
    if IsFlying() then
        speed = (currentSpeed / 7) * 100 -- approx
    end

    -- Format: "Speed: 100%"
    self:SetText(string.format("Speed: %.0f%%", speed))

    -- Store history
    table.insert(self.history, speed)
    if #self.history > HISTORY_SIZE then table.remove(self.history, 1) end
end

-- [ INTERACTION ] -------------------------------------------------------------

function SpeedWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Movement Speed", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
    local pct = (currentSpeed / 7) * 100

    GameTooltip:AddDoubleLine("Current:", string.format("%.0f%%", pct), 1, 1, 1, 1, 1, 1)

    GameTooltip:Show()

    -- Draw Graph
    if not self.graphFrame then
        self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
        self.graphFrame:SetSize(200, 50)
        self.graph = addon.Graph:New(self.graphFrame, 200, 50)
    end

    self.graphFrame:SetParent(GameTooltip)
    self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
    self.graphFrame:Show()

    self.graph:Clear()
    self.graph:SetColor(0, 0.7, 1, 1) -- Blue for speed
    for _, val in ipairs(self.history) do
        self.graph:AddData(val)
    end
    self.graph:Draw()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function SpeedWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetTooltipFunc(function() self:ShowTooltip() end)

    -- High frequency update for speed
    C_Timer.NewTicker(0.2, function() self:Update() end)

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() SpeedWidget:OnLoad() end)
end)
