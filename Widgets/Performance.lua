-- Performance.lua
-- System performance widget for StatusDock
-- Features: FPS, Latency, Memory Usage, Graph Visualization

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local PerformanceWidget = addon.BaseWidget:New("Performance")
addon.PerformanceWidget = PerformanceWidget

-- [ CONSTANTS ] ---------------------------------------------------------------

local COLORS = {
    GREEN = "|cff00ff00",
    YELLOW = "|cfffea300",
    RED = "|cffff0000",
}

-- [ HISTORY ] -----------------------------------------------------------------

PerformanceWidget.history = {
    fps = {},
    latency = {},
    memory = {},
}
local HISTORY_SIZE = 60 -- Store last 60 seconds

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function PerformanceWidget:GetColor(value, threshold1, threshold2, reverse)
    if reverse then
        if value >= threshold2 then return COLORS.GREEN
        elseif value >= threshold1 then return COLORS.YELLOW
        else return COLORS.RED
        end
    else
        if value <= threshold1 then return COLORS.GREEN
        elseif value <= threshold2 then return COLORS.YELLOW
        else return COLORS.RED
        end
    end
end

-- [ UPDATES ] -----------------------------------------------------------------

function PerformanceWidget:Update()
    local fps = GetFramerate()
    local _, _, home, world = GetNetStats()
    UpdateAddOnMemoryUsage()
    local mem = collectgarbage("count") / 1024 -- MB
    
    -- Store history
    table.insert(self.history.fps, fps)
    if #self.history.fps > HISTORY_SIZE then table.remove(self.history.fps, 1) end

    table.insert(self.history.latency, world)
    if #self.history.latency > HISTORY_SIZE then table.remove(self.history.latency, 1) end

    table.insert(self.history.memory, mem)
    if #self.history.memory > HISTORY_SIZE then table.remove(self.history.memory, 1) end

    local fpsColor = self:GetColor(fps, 30, 60, true)
    local msColor = self:GetColor(world, 100, 200, false)
    
    self:SetText(string.format("%s%d|rfps %s%d|rms", fpsColor, math.floor(fps), msColor, world))
end

function PerformanceWidget:OnEnable()
    self:Update()
    self.timer = C_Timer.NewTicker(1, function() self:Update() end)
end

function PerformanceWidget:OnDisable()
    if self.timer then
        self.timer:Cancel()
        self.timer = nil
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function PerformanceWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("System Performance", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local fps = GetFramerate()
    local _, _, home, world = GetNetStats()
    local mem = collectgarbage("count") / 1024
    
    GameTooltip:AddDoubleLine("FPS:", string.format("%.1f", fps), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Home Latency:", string.format("%dms", home), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("World Latency:", string.format("%dms", world), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Memory:", string.format("%.2f MB", mem), 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    
    -- Addon CPU/Memory
    GameTooltip:AddLine("Top Addons (Memory):", 0.7, 0.7, 0.7)

    local addons = {}
    for i = 1, GetNumAddOns() do
        local m = GetAddOnMemoryUsage(i)
        local name, title = GetAddOnInfo(i)
        if m > 0 then
            table.insert(addons, { name = title or name, mem = m })
        end
    end
    
    table.sort(addons, function(a, b) return a.mem > b.mem end)

    for i = 1, 5 do
        if addons[i] then
            local memStr
            if addons[i].mem > 1000 then
                memStr = string.format("%.2f MB", addons[i].mem / 1000)
            else
                memStr = string.format("%.0f KB", addons[i].mem)
            end
            GameTooltip:AddDoubleLine(addons[i].name, memStr, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Collect Garbage", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()

    -- Draw Graph (Advanced Feature)
    if not self.graphFrame then
        self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
        self.graphFrame:SetSize(200, 50)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
        self.graph = addon.Graph:New(self.graphFrame, 200, 50)
    end

    self.graphFrame:SetParent(GameTooltip)
    self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
    self.graphFrame:Show()

    -- Which graph to show? FPS for now
    self.graph:Clear()
    self.graph:SetColor(0, 1, 0, 1) -- Green
    for _, val in ipairs(self.history.fps) do
        self.graph:AddData(val)
    end
    self.graph:Draw()
end

function PerformanceWidget:OnClick(button)
    collectgarbage("collect")
    print("|cff00ff00Memory Garbage Collected|r")
    self:Update()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function PerformanceWidget:OnLoad()
    self:CreateFrame(120, 20)
    
    -- Setup handlers
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Register with manager
    self:Register()
    
    -- Start loop
    self:Enable()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() PerformanceWidget:OnLoad() end)
end)
