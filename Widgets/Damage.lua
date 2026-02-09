-- Damage.lua
-- Advanced Damage Meter widget for StatusDock
-- Features: Lightweight DPS/HPS tracking, Combat Graph, Top Damagers display, Scroll Modes

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local DamageWidget = addon.BaseWidget:New("Damage")
addon.DamageWidget = DamageWidget
DamageWidget.category = "Combat"

-- [ SETTINGS ] ----------------------------------------------------------------

DamageWidget.settings = {
    mode = "DPS", -- "DPS" or "HPS"
    resetOnCombat = true,
}

DamageWidget.currentSegment = {
    damage = {}, healing = {}, totalDamage = 0, totalHealing = 0,
    startTime = 0, endTime = 0, active = false,
}
DamageWidget.history = {}
local GRAPH_POINTS = 60

-- [ HELPERS ] -----------------------------------------------------------------

local function FormatNumber(num)
    return addon.Formatting:FormatNumber(num)
end

-- [ PARSING ] -----------------------------------------------------------------

function DamageWidget:OnCombatLog()
    if not self.currentSegment.active then return end

    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, arg12, arg13, arg14, arg15 = CombatLogGetCurrentEventInfo()

    if bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then return end

    local amount = 0
    local isHealing = (subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL")

    if subevent == "SWING_DAMAGE" then amount = arg12
    elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then amount = arg15
    elseif isHealing then amount = arg15 end

    if amount and amount > 0 then
        if isHealing then
            local overheal = select(16, CombatLogGetCurrentEventInfo()) or 0
            amount = math.max(0, amount - overheal)
            self.currentSegment.healing[sourceName] = (self.currentSegment.healing[sourceName] or 0) + amount
            self.currentSegment.totalHealing = self.currentSegment.totalHealing + amount
        else
            self.currentSegment.damage[sourceName] = (self.currentSegment.damage[sourceName] or 0) + amount
            self.currentSegment.totalDamage = self.currentSegment.totalDamage + amount
        end
    end
end

-- [ UPDATE ] ------------------------------------------------------------------

function DamageWidget:Update()
    local duration = 0
    if self.currentSegment.active then duration = GetTime() - self.currentSegment.startTime
    else duration = self.currentSegment.endTime - self.currentSegment.startTime end
    if duration < 1 then duration = 1 end

    local playerName = UnitName("player")
    local val = 0
    if self.settings.mode == "DPS" then
        val = (self.currentSegment.damage[playerName] or 0) / duration
    else
        val = (self.currentSegment.healing[playerName] or 0) / duration
    end

    table.insert(self.history, val)
    if #self.history > GRAPH_POINTS then table.remove(self.history, 1) end

    self:SetFormattedText(self.settings.mode .. ":", FormatNumber(val))
end

-- [ INTERACTION ] -------------------------------------------------------------

function DamageWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateTitle("Display Mode")
    rootDescription:CreateRadio("DPS", function() return self.settings.mode == "DPS" end, function()
        self.settings.mode = "DPS"
        self:Update()
    end)
    rootDescription:CreateRadio("HPS", function() return self.settings.mode == "HPS" end, function()
        self.settings.mode = "HPS"
        self:Update()
    end)

    -- Group Breakdown
    rootDescription:CreateTitle("Group " .. self.settings.mode)
    local list = {}
    local source = (self.settings.mode == "DPS") and self.currentSegment.damage or self.currentSegment.healing
    local duration = math.max(1, self.currentSegment.active and (GetTime() - self.currentSegment.startTime) or (self.currentSegment.endTime - self.currentSegment.startTime))

    for name, val in pairs(source) do table.insert(list, { name = name, val = val }) end
    table.sort(list, function(a, b) return a.val > b.val end)

    for i = 1, math.min(10, #list) do
        local entry = list[i]
        local perSec = entry.val / duration
        rootDescription:CreateButton(string.format("%d. %s: %s", i, entry.name, FormatNumber(perSec)), function() end)
    end

    rootDescription:CreateButton("Report to Group", function()
        local channel = IsInRaid() and "RAID" or IsInGroup() and "PARTY" or "SAY"
        SendChatMessage("Orbit Status: Top " .. self.settings.mode, channel)
        for i = 1, math.min(5, #list) do
            local entry = list[i]
            local perSec = entry.val / duration
            SendChatMessage(string.format("%d. %s: %s", i, entry.name, FormatNumber(perSec)), channel)
        end
    end)

    rootDescription:CreateTitle("Options")
    rootDescription:CreateCheckbox("Reset on Combat", function() return self.settings.resetOnCombat end, function()
        self.settings.resetOnCombat = not self.settings.resetOnCombat
    end)

    rootDescription:CreateButton("Reset Data", function()
        self.currentSegment = { damage = {}, healing = {}, totalDamage = 0, totalHealing = 0, startTime = GetTime(), endTime = GetTime(), active = false }
        self.history = {}
        self:Update()
    end)
end

function DamageWidget:OnScroll(delta)
    if delta > 0 then
        self.settings.mode = "DPS"
    else
        self.settings.mode = "HPS"
    end
    self:Update()
end

function DamageWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Damage Meter (" .. self.settings.mode .. ")", 1, 0.82, 0)

    local duration = math.max(1, self.currentSegment.active and (GetTime() - self.currentSegment.startTime) or (self.currentSegment.endTime - self.currentSegment.startTime))
    GameTooltip:AddDoubleLine("Time:", string.format("%.1fs", duration), 1, 1, 1, 1, 1, 1)

    local list = {}
    local source = (self.settings.mode == "DPS") and self.currentSegment.damage or self.currentSegment.healing
    local total = (self.settings.mode == "DPS") and self.currentSegment.totalDamage or self.currentSegment.totalHealing
    if total == 0 then total = 1 end

    for name, val in pairs(source) do table.insert(list, { name = name, val = val }) end
    table.sort(list, function(a, b) return a.val > b.val end)

    for i = 1, math.min(10, #list) do
        local entry = list[i]
        local pct = (entry.val / total) * 100
        GameTooltip:AddDoubleLine(string.format("%d. %s", i, entry.name), string.format("%s (%.1f%%)", FormatNumber(entry.val/duration), pct), 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Scroll", "Cycle DPS/HPS", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Menu / Report", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()

    -- Graph
    if #self.history > 2 then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(220, 60)
            self.graph = addon.Graph:New(self.graphFrame, 220, 60)
        end
        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
        self.graphFrame:Show()

        self.graph:Clear()
        local _, class = UnitClass("player")
        local color = C_ClassColor.GetClassColor(class)
        self.graph:SetColor(color.r, color.g, color.b, 1)

        for _, val in ipairs(self.history) do self.graph:AddData(val) end
        self.graph:Draw()
    end
end

function DamageWidget:OnClick(button)
    -- Left click?
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function DamageWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self:SetScrollFunc(function(_, delta) self:OnScroll(delta) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if self.settings.resetOnCombat then
            self.currentSegment = { damage = {}, healing = {}, totalDamage = 0, totalHealing = 0, startTime = GetTime(), endTime = 0, active = true }
            self.history = {}
        end
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function() self:OnCombatLog() end)
        self.ticker = C_Timer.NewTicker(0.5, function() self:Update() end)
    end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self.currentSegment.active = false
        self.currentSegment.endTime = GetTime()
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        if self.ticker then self.ticker:Cancel() end
        self:Update()
    end)

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() DamageWidget:OnLoad() end)
end)
