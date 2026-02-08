-- CombatTimer.lua
-- Advanced Combat Timer widget for StatusDock
-- Features: Auto-show on combat, DPS estimation (simple), color coding

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local CombatTimerWidget = addon.BaseWidget:New("CombatTimer"); addon.CombatTimerWidget.category = "Combat"
addon.CombatTimerWidget = CombatTimerWidget

-- [ STATE ] -------------------------------------------------------------------

CombatTimerWidget.startTime = 0
CombatTimerWidget.inCombat = false
CombatTimerWidget.ticker = nil
CombatTimerWidget.damageDone = 0

-- [ UPDATES ] -----------------------------------------------------------------

function CombatTimerWidget:Update()
    if not self.inCombat then
        -- Contextual: Hide when not in combat, unless in Edit Mode
        if self.inEditMode then
            self:SetText("|cff888888Idle|r")
            self.frame:Show()
        else
            self.frame:Hide()
        end
        return
    end
    
    self.frame:Show()
    local now = GetTime()
    local duration = now - self.startTime
    
    local color = "|cffff0000" -- Red for combat
    local timeStr = string.format("%02d:%02d", math.floor(duration / 60), math.floor(duration % 60))
    
    self:SetText(color .. timeStr .. "|r")
end

-- [ EVENTS ] ------------------------------------------------------------------

function CombatTimerWidget:OnCombatStart()
    self.inCombat = true
    self.startTime = GetTime()
    self.damageDone = 0
    
    -- Start ticker
    if self.ticker then self.ticker:Cancel() end
    self.ticker = C_Timer.NewTicker(0.1, function() self:Update() end)
    
    self:Update()
end

function CombatTimerWidget:OnCombatEnd()
    self.inCombat = false
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    
    -- Final update
    local duration = GetTime() - self.startTime
    local timeStr = string.format("%02d:%02d", math.floor(duration / 60), math.floor(duration % 60))
    self:SetText("|cff00ff00" .. timeStr .. "|r") -- Green for done
    
    -- Hide after 5 seconds?
    C_Timer.After(5, function()
        if not self.inCombat then
            self:SetText("|cff888888Idle|r")
        end
    end)
end

-- [ INTERACTION ] -------------------------------------------------------------

function CombatTimerWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Combat Timer", 1, 0.82, 0)

    if self.inCombat then
        local duration = GetTime() - self.startTime
        GameTooltip:AddDoubleLine("Duration:", string.format("%.1fs", duration), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine("Status: In Combat", 1, 0, 0)
    else
        GameTooltip:AddLine("Status: Idle", 0.5, 0.5, 0.5)
    end

    GameTooltip:Show()
end

function CombatTimerWidget:OnClick(button)
    -- Reset?
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function CombatTimerWidget:OnLoad()
    self:CreateFrame(60, 20)
    
    -- Setup handlers
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    
    -- Register events
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:OnCombatStart() end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:OnCombatEnd() end)
    
    -- Register with manager
    self:Register()

    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() CombatTimerWidget:OnLoad() end)
end)
