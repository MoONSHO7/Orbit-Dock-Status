-- CombatTimer.lua
-- Combat Timer widget for StatusDock
-- Features: encounter timer, deaths counter, average combat duration, contextual visibility

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local CombatTimerWidget = addon.BaseWidget:New("CombatTimer")
addon.CombatTimerWidget = CombatTimerWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local UPDATE_INTERVAL_SEC = 0.5
local IDLE_TIMEOUT_SEC = 5
local SECONDS_PER_MINUTE = 60
local FRAME_WIDTH = 60
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ STATE ] -----------------------------------------------------------------------

CombatTimerWidget.startTime = 0
CombatTimerWidget.inCombat = false
CombatTimerWidget.ticker = nil
CombatTimerWidget.encounterName = nil
CombatTimerWidget.encounterStart = 0
CombatTimerWidget.sessionDeaths = 0
CombatTimerWidget.combatHistory = {}

-- [ HELPERS ] ---------------------------------------------------------------------

local function FormatDuration(seconds)
    return string.format("%02d:%02d", math.floor(seconds / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE))
end

function CombatTimerWidget:GetAverageCombatDuration()
    if #self.combatHistory == 0 then return 0 end
    local sum = 0
    for _, d in ipairs(self.combatHistory) do sum = sum + d end
    return sum / #self.combatHistory
end

-- [ UPDATES ] ---------------------------------------------------------------------

function CombatTimerWidget:Update()
    if not self.inCombat then
        if self.inEditMode then
            self:SetText("|cff888888Idle|r")
            self.frame:Show()
        else
            self.frame:Hide()
        end
        return
    end
    self.frame:Show()
    local duration = GetTime() - self.startTime
    self:SetText("|cffff0000" .. FormatDuration(duration) .. "|r")
end

-- [ EVENTS ] ----------------------------------------------------------------------

function CombatTimerWidget:OnCombatStart()
    self.inCombat = true
    self.startTime = GetTime()
    if self.ticker then self.ticker:Cancel() end
    self.ticker = C_Timer.NewTicker(UPDATE_INTERVAL_SEC, function() self:Update() end)
    self:Update()
end

function CombatTimerWidget:OnCombatEnd()
    self.inCombat = false
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    local duration = GetTime() - self.startTime
    table.insert(self.combatHistory, duration)
    self:SetText("|cff00ff00" .. FormatDuration(duration) .. "|r")
    C_Timer.After(IDLE_TIMEOUT_SEC, function()
        if not self.inCombat then self:SetText("|cff888888Idle|r") end
    end)
end

function CombatTimerWidget:OnEncounterStart(_, encounterID, encounterName)
    self.encounterName = encounterName
    self.encounterStart = GetTime()
end

function CombatTimerWidget:OnEncounterEnd(_, encounterID, encounterName, difficultyID, groupSize, success)
    if self.encounterStart > 0 then
        local duration = GetTime() - self.encounterStart
        local result = success == 1 and "|cff00ff00Kill" or "|cffff0000Wipe"
        print(string.format("%s|r: %s - %s", result, encounterName or self.encounterName or "Boss", FormatDuration(duration)))
        self.encounterName = nil
        self.encounterStart = 0
    end
end

function CombatTimerWidget:OnPlayerDeath()
    self.sessionDeaths = self.sessionDeaths + 1
end

-- [ INTERACTION ] -----------------------------------------------------------------

function CombatTimerWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Combat Timer", 1, 0.82, 0)

    if self.inCombat then
        local duration = GetTime() - self.startTime
        GameTooltip:AddDoubleLine("Duration:", string.format("%.1fs", duration), 1, 1, 1, 1, 1, 1)
        if self.encounterName then
            GameTooltip:AddDoubleLine("Encounter:", self.encounterName, 1, 1, 1, 1, 0.82, 0)
        end
        GameTooltip:AddLine("Status: In Combat", 1, 0, 0)
    else
        GameTooltip:AddLine("Status: Idle", 0.5, 0.5, 0.5)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Session Deaths:", tostring(self.sessionDeaths), 1, 1, 1, 1, 0.3, 0.3)

    local avg = self:GetAverageCombatDuration()
    if avg > 0 then
        GameTooltip:AddDoubleLine("Avg Combat:", FormatDuration(avg), 1, 1, 1, 0.7, 0.7, 0.7)
        GameTooltip:AddDoubleLine("Fights:", tostring(#self.combatHistory), 1, 1, 1, 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Reset Session", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function CombatTimerWidget:OnClick(button)
    self.sessionDeaths = 0
    self.combatHistory = {}
    print("|cff00ff00Combat Timer session data reset.|r")
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function CombatTimerWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Reset Session"
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:OnCombatStart() end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:OnCombatEnd() end)
    self:RegisterEvent("ENCOUNTER_START", function(_, ...) self:OnEncounterStart(_, ...) end)
    self:RegisterEvent("ENCOUNTER_END", function(_, ...) self:OnEncounterEnd(_, ...) end)
    self:RegisterEvent("PLAYER_DEAD", function() self:OnPlayerDeath() end)
    self:SetCategory("SYSTEM")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() CombatTimerWidget:OnLoad() end)
end)
