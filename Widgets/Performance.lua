-- Performance.lua
-- System performance widget for StatusDock
-- Features: FPS, Latency, Memory Usage, Graph Visualization

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local PerformanceWidget = addon.BaseWidget:New("Performance"); addon.PerformanceWidget.category = "System"
addon.PerformanceWidget = PerformanceWidget

-- [ CONSTANTS ] ---------------------------------------------------------------

local COLORS = {
    GREEN = { r = 0, g = 1, b = 0, a = 1 },
    YELLOW = { r = 1, g = 0.8, b = 0, a = 1 },
    RED = { r = 1, g = 0, b = 0, a = 1 },
}

-- [ HISTORY ] -----------------------------------------------------------------

PerformanceWidget.history = {
    fps = {},
    latency = {},
    memory = {},
}
local HISTORY_SIZE = 60

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function PerformanceWidget:GetColorHex(value, threshold1, threshold2, reverse)
    if reverse then
        if value >= threshold2 then return "|cff00ff00" -- Green
        elseif value >= threshold1 then return "|cfffea300" -- Yellow
        else return "|cffff0000" -- Red
        end
    else
        if value <= threshold1 then return "|cff00ff00"
        elseif value <= threshold2 then return "|cfffea300"
        else return "|cffff0000"
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
    
    local fpsColor = self:GetColorHex(fps, 30, 60, true)
    local msColor = self:GetColorHex(world, 100, 200, false)

    self:SetFormattedText(nil, string.format("%s%d|rfps %s%d|rms", fpsColor, math.floor(fps), msColor, world))
end

function PerformanceWidget:OnEnable()
    self:Update()
    self.timer = C_Timer.NewTicker(1, function() self:Update() end)
end

function PerformanceWidget:OnDisable()
    if self.timer then self.timer:Cancel(); self.timer = nil end
end

-- [ INTERACTION ] -------------------------------------------------------------

function PerformanceWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Collect Garbage", function()
        collectgarbage("collect")
        print("|cff00ff00Memory Garbage Collected|r")
        self:Update()
    end)
end

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

    -- Draw Graph (FPS)
    if #self.history.fps > 2 then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(220, 60)
            self.graph = addon.Graph:New(self.graphFrame, 220, 60)
        end

        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
        self.graphFrame:Show()

        self.graph:Clear()
        self.graph:SetColor(COLORS.GREEN)
        for _, val in ipairs(self.history.fps) do
            self.graph:AddData(val)
        end
        self.graph:Draw()
    end
end

function PerformanceWidget:OnClick(button)
    collectgarbage("collect")
    print("|cff00ff00Memory Garbage Collected|r")
    self:Update()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function PerformanceWidget:OnLoad()
    self:CreateFrame(120, 20)
    
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:Register()
    self:Enable()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() PerformanceWidget:OnLoad() end)
end)
