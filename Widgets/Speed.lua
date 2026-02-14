-- Speed.lua
-- Movement Speed widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local SpeedWidget = addon.BaseWidget:New("Speed")
addon.SpeedWidget = SpeedWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local BASE_RUN_SPEED = 7
local PERCENT_MULTIPLIER = 100
local UPDATE_INTERVAL_SEC = 0.2
local HISTORY_SIZE = 60
local GRAPH_WIDTH = 200
local GRAPH_HEIGHT = 50
local GRAPH_OFFSET_Y = -5
local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ HISTORY ] ---------------------------------------------------------------------

local RingBuffer = addon.Formatting.RingBuffer
SpeedWidget.history = RingBuffer:New(HISTORY_SIZE)

-- [ UPDATE ] ----------------------------------------------------------------------

function SpeedWidget:Update()
    local currentSpeed, runSpeed = GetUnitSpeed("player")

    local speed = (currentSpeed / runSpeed) * PERCENT_MULTIPLIER
    if IsFlying() then speed = (currentSpeed / BASE_RUN_SPEED) * PERCENT_MULTIPLIER end

    self:SetText(string.format("Speed: %.0f%%", speed))

    self.history:Push(speed)
end

-- [ INTERACTION ] -----------------------------------------------------------------

function SpeedWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Movement Speed", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local currentSpeed = GetUnitSpeed("player")
    local pct = (currentSpeed / BASE_RUN_SPEED) * PERCENT_MULTIPLIER

    GameTooltip:AddDoubleLine("Current:", string.format("%.0f%%", pct), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()

    if not self.graphFrame then
        self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
        self.graphFrame:SetSize(GRAPH_WIDTH, GRAPH_HEIGHT)
        self.graph = addon.Graph:New(self.graphFrame, GRAPH_WIDTH, GRAPH_HEIGHT)
    end

    self.graphFrame:SetParent(GameTooltip)
    self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, GRAPH_OFFSET_Y)
    self.graphFrame:Show()

    self.graph:Clear()
    self.graph:SetColor(0, 0.7, 1, 1)
    for _, val in self.history:Iterate() do self.graph:AddData(val) end
    self.graph:Draw()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function SpeedWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetCategory("SYSTEM")
    self:Register()
    self:SetUpdateTier("NORMAL")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() SpeedWidget:OnLoad() end)
end)
