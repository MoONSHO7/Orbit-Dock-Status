-- Performance.lua
-- System performance widget for StatusDock
-- Features: Color-coded FPS/latency, shift-hover extended stats, memory trend, top addons

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local PerformanceWidget = addon.BaseWidget:New("Performance")
addon.PerformanceWidget = PerformanceWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FPS_THRESHOLD_LOW = 30
local FPS_THRESHOLD_HIGH = 60
local FPS_THRESHOLD_CRITICAL = 15
local LATENCY_THRESHOLD_LOW = 100
local LATENCY_THRESHOLD_HIGH = 200
local KB_TO_MB = 1024
local MEM_DISPLAY_THRESHOLD_KB = 1000
local TOP_ADDON_COUNT = 10
local TOP_ADDON_DEFAULT = 5
local UPDATE_INTERVAL_SEC = 1
local INIT_DELAY_SEC = 0.5
local GRAPH_WIDTH = 200
local GRAPH_HEIGHT = 50
local GRAPH_OFFSET_Y = -5
local HISTORY_SIZE = 60
local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local TREND_WINDOW = 10
local JITTER_THRESHOLD_MS = 50

local COLORS = {
    GREEN  = "|cff00ff00",
    YELLOW = "|cfffea300",
    ORANGE = "|cffff6600",
    RED    = "|cffff0000",
}

-- [ STATE ] -----------------------------------------------------------------------

local RingBuffer = addon.Formatting.RingBuffer
PerformanceWidget.history = {
    fps = RingBuffer:New(HISTORY_SIZE),
    latency = RingBuffer:New(HISTORY_SIZE),
    memory = RingBuffer:New(HISTORY_SIZE),
}

-- [ HELPERS ] ---------------------------------------------------------------------

function PerformanceWidget:GetFPSColor(fps)
    if fps >= FPS_THRESHOLD_HIGH then return COLORS.GREEN
    elseif fps >= FPS_THRESHOLD_LOW then return COLORS.YELLOW
    elseif fps >= FPS_THRESHOLD_CRITICAL then return COLORS.ORANGE
    else return COLORS.RED end
end

function PerformanceWidget:GetLatencyColor(ms)
    if ms <= LATENCY_THRESHOLD_LOW then return COLORS.GREEN
    elseif ms <= LATENCY_THRESHOLD_HIGH then return COLORS.YELLOW
    else return COLORS.RED end
end

function PerformanceWidget:GetMemoryTrend()
    local hist = self.history.memory
    if hist:Count() < TREND_WINDOW then return "" end
    local recent = hist:Last(0)
    local older = hist:Last(TREND_WINDOW - 1)
    if recent > older then return "|cffff0000\226\150\178|r"
    elseif recent < older then return "|cff00ff00\226\150\188|r"
    else return "" end
end

function PerformanceWidget:GetHistoryStats(ring)
    if ring:Count() == 0 then return 0, 0, 0, 0 end
    local first = ring:Nth(1)
    local min, max, sum = first, first, 0
    for _, v in ring:Iterate() do
        if v < min then min = v end
        if v > max then max = v end
        sum = sum + v
    end
    local avg = sum / ring:Count()
    local variance = 0
    for _, v in ring:Iterate() do variance = variance + (v - avg) * (v - avg) end
    local stddev = math.sqrt(variance / ring:Count())
    return min, max, avg, stddev
end

-- [ UPDATES ] ---------------------------------------------------------------------

function PerformanceWidget:Update()
    local fps = GetFramerate()
    local _, _, home, world = GetNetStats()
    local mem = collectgarbage("count") / KB_TO_MB

    self.history.fps:Push(fps)
    self.history.latency:Push(world)
    self.history.memory:Push(mem)

    local fpsColor = self:GetFPSColor(fps)
    local msColor = self:GetLatencyColor(world)
    self:SetText(string.format("%s%d|rfps %s%d|rms", fpsColor, math.floor(fps), msColor, world))
end

-- [ INTERACTION ] -----------------------------------------------------------------


function PerformanceWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("System Performance", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local fps = GetFramerate()
    local _, _, home, world = GetNetStats()
    local mem = collectgarbage("count") / KB_TO_MB
    local trend = self:GetMemoryTrend()

    GameTooltip:AddDoubleLine("FPS:", string.format("%.1f", fps), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Home Latency:", string.format("%dms", home), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("World Latency:", string.format("%dms", world), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Memory:", string.format("%.2f MB %s", mem, trend), 1, 1, 1, 1, 1, 1)

    local shiftHeld = IsShiftKeyDown()
    if shiftHeld then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Extended Stats", 0.7, 0.7, 0.7)
        local fMin, fMax, fAvg = self:GetHistoryStats(self.history.fps)
        GameTooltip:AddDoubleLine("FPS Min/Avg/Max:", string.format("%.0f / %.0f / %.0f", fMin, fAvg, fMax), 1, 1, 1, 0.7, 0.7, 0.7)
        local _, peakMem = self:GetHistoryStats(self.history.memory)
        GameTooltip:AddDoubleLine("Peak Memory:", string.format("%.2f MB", peakMem), 1, 1, 1, 0.7, 0.7, 0.7)
        local _, _, _, jitter = self:GetHistoryStats(self.history.latency)
        local jitterColor = jitter > JITTER_THRESHOLD_MS and "|cffff0000" or "|cff00ff00"
        GameTooltip:AddDoubleLine("Network Jitter:", string.format("%s%.1fms|r stddev", jitterColor, jitter), 1, 1, 1, 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    local addonCount = shiftHeld and TOP_ADDON_COUNT or TOP_ADDON_DEFAULT
    GameTooltip:AddLine(string.format("Top %d Addons (Memory):", addonCount), 0.7, 0.7, 0.7)

    local addons = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local m = GetAddOnMemoryUsage(i)
        local name, title = C_AddOns.GetAddOnInfo(i)
        if m > 0 then table.insert(addons, { name = title or name, mem = m }) end
    end
    table.sort(addons, function(a, b) return a.mem > b.mem end)

    for i = 1, addonCount do
        if addons[i] then
            local memStr = addons[i].mem > MEM_DISPLAY_THRESHOLD_KB and string.format("%.2f MB", addons[i].mem / MEM_DISPLAY_THRESHOLD_KB) or string.format("%.0f KB", addons[i].mem)
            GameTooltip:AddDoubleLine(addons[i].name, memStr, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Collect Garbage", 0.7, 0.7, 0.7, 1, 1, 1)
    if not shiftHeld then GameTooltip:AddDoubleLine("Shift+Hover", "Extended Stats", 0.7, 0.7, 0.7, 1, 1, 1) end
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
    self.graph:SetColor(0, 1, 0, 1)
    for _, val in self.history.fps:Iterate() do self.graph:AddData(val) end
    self.graph:Draw()
end

function PerformanceWidget:OnClick(button)
    collectgarbage("collect")
    print("|cff00ff00Memory Garbage Collected|r")
    self:Update()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function PerformanceWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("NORMAL")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Collect Garbage"
    self:SetCategory("SYSTEM")
    self:Register()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() PerformanceWidget:OnLoad() end)
end)
