-- Performance.lua
-- System performance widget for StatusDock
-- Features: FPS, Latency, Memory Usage, Garbage Collection

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
    
    local fpsColor = self:GetColor(fps, 30, 60, true) -- higher is better
    local msColor = self:GetColor(world, 100, 200, false) -- lower is better
    
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
    
    GameTooltip:AddDoubleLine("FPS:", string.format("%.1f", fps), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Home Latency:", string.format("%dms", home), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("World Latency:", string.format("%dms", world), 1, 1, 1, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Addon Memory Usage:", 0.7, 0.7, 0.7)
    
    UpdateAddOnMemoryUsage()
    local addons = {}
    for i = 1, GetNumAddOns() do
        local mem = GetAddOnMemoryUsage(i)
        local name, title = GetAddOnInfo(i)
        if mem > 0 then
            table.insert(addons, { name = title or name, mem = mem })
        end
    end
    
    table.sort(addons, function(a, b) return a.mem > b.mem end)

    local count = 0
    for _, addon in ipairs(addons) do
        if count >= 5 then break end
        
        local memStr
        if addon.mem > 1000 then
            memStr = string.format("%.2f MB", addon.mem / 1000)
        else
            memStr = string.format("%.0f KB", addon.mem)
        end
        GameTooltip:AddDoubleLine(addon.name, memStr, 1, 1, 1, 1, 1, 1)
        count = count + 1
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Collect Garbage", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function PerformanceWidget:OnClick(button)
    collectgarbage("collect")
    print("|cff00ff00Memory Garbage Collected|r")
    self:Update()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function PerformanceWidget:OnLoad()
    self:CreateFrame(100, 20)
    
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
