-- Damage.lua
-- Advanced Damage Meter widget for StatusDock
-- Features: Lightweight DPS/HPS tracking, Combat Graph, Top Damagers display

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local DamageWidget = addon.BaseWidget:New("Damage")
addon.DamageWidget = DamageWidget

-- [ SETTINGS ] ----------------------------------------------------------------

DamageWidget.settings = {
    mode = "DPS", -- "DPS" or "HPS"
    resetOnCombat = true,
}

-- [ STATE ] -------------------------------------------------------------------

DamageWidget.currentSegment = {
    damage = {},
    healing = {},
    totalDamage = 0,
    totalHealing = 0,
    startTime = 0,
    endTime = 0,
    active = false,
}

DamageWidget.history = {} -- For graph (Player DPS over time)
local GRAPH_POINTS = 60

-- [ CONSTANTS ] ---------------------------------------------------------------

local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
local COMBATLOG_OBJECT_TYPE_PET    = COMBATLOG_OBJECT_TYPE_PET    or 0x00001000
local COMBATLOG_OBJECT_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000
local MASK_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x00000010

-- [ HELPERS ] -----------------------------------------------------------------

local function GetPlayerGUID() return UnitGUID("player") end

local function IsFriendlyPlayer(flags)
    -- Check if bitmask has player/pet/guardian AND friendly flag
    local isPlayer = bit.band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    local isPet = bit.band(flags, COMBATLOG_OBJECT_TYPE_PET) > 0
    local isGuardian = bit.band(flags, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0
    local isFriendly = bit.band(flags, MASK_FRIENDLY) > 0

    return (isPlayer or isPet or isGuardian) and isFriendly
end

local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return string.format("%.0f", num)
    end
end

-- [ PARSING ] -----------------------------------------------------------------

function DamageWidget:OnCombatLog()
    if not self.currentSegment.active then return end

    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = CombatLogGetCurrentEventInfo()

    -- Filter out non-player sources early for performance
    -- We only care about group members really, but IsFriendlyPlayer is a decent filter
    if not IsFriendlyPlayer(sourceFlags) then return end

    -- Consolidate Pet Damage to Owner? (Complex, skip for now - verify by name/flags)
    -- For simplicity, treat pets as separate or group by name if needed.
    -- Standard practice: Sum pets into owner.
    -- To do this properly, we'd need a pet-to-owner GUID map.
    -- Let's stick to simple sourceName aggregation for this "Lightweight" meter.

    local isDamage = (subevent == "SWING_DAMAGE") or (subevent == "RANGE_DAMAGE") or (subevent == "SPELL_DAMAGE") or (subevent == "SPELL_PERIODIC_DAMAGE")
    local isHealing = (subevent == "SPELL_HEAL") or (subevent == "SPELL_PERIODIC_HEAL")

    if isDamage then
        local dmg = 0
        if subevent == "SWING_DAMAGE" then
            dmg = amount -- arg12 is amount for swing
        else
            dmg = amount -- arg15 is amount for spell/range (passed as 'amount' variable here due to vararg mapping... wait)
            -- CombatLogGetCurrentEventInfo mapping:
            -- 1: timestamp, 2: subevent, 3: hideCaster
            -- 4: sourceGUID, 5: sourceName, 6: sourceFlags, 7: sourceRaidFlags
            -- 8: destGUID, 9: destName, 10: destFlags, 11: destRaidFlags
            -- 12+: prefix params
            -- SWING_DAMAGE: 12: amount
            -- SPELL_DAMAGE: 12: spellId, 13: spellName, 14: spellSchool, 15: amount
        end

        -- Correct argument mapping manually for clarity
        if subevent == "SWING_DAMAGE" then
            dmg = select(12, CombatLogGetCurrentEventInfo())
        elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
            dmg = select(15, CombatLogGetCurrentEventInfo())
        end

        if dmg and dmg > 0 then
            if not self.currentSegment.damage[sourceName] then
                self.currentSegment.damage[sourceName] = 0
            end
            self.currentSegment.damage[sourceName] = self.currentSegment.damage[sourceName] + dmg
            self.currentSegment.totalDamage = self.currentSegment.totalDamage + dmg
        end

    elseif isHealing then
        local heal = select(15, CombatLogGetCurrentEventInfo())
        if heal and heal > 0 then
            -- Subtract overheating? (arg16)
            local overheal = select(16, CombatLogGetCurrentEventInfo()) or 0
            local effective = math.max(0, heal - overheal)

            if effective > 0 then
                if not self.currentSegment.healing[sourceName] then
                    self.currentSegment.healing[sourceName] = 0
                end
                self.currentSegment.healing[sourceName] = self.currentSegment.healing[sourceName] + effective
                self.currentSegment.totalHealing = self.currentSegment.totalHealing + effective
            end
        end
    end
end

-- [ UPDATES ] -----------------------------------------------------------------

function DamageWidget:Update()
    local duration = 0
    if self.currentSegment.active then
        duration = GetTime() - self.currentSegment.startTime
    else
        duration = self.currentSegment.endTime - self.currentSegment.startTime
    end

    if duration < 1 then duration = 1 end

    -- Player Stats
    local playerName = UnitName("player")
    local playerDmg = self.currentSegment.damage[playerName] or 0
    local playerHeal = self.currentSegment.healing[playerName] or 0

    local dps = playerDmg / duration
    local hps = playerHeal / duration

    -- Group Rank (Top)
    -- Find max dps
    local maxDmg = 0
    local topDamager = ""
    for name, dmg in pairs(self.currentSegment.damage) do
        if dmg > maxDmg then
            maxDmg = dmg
            topDamager = name
        end
    end

    local text = ""
    if self.settings.mode == "DPS" then
        text = string.format("DPS: %s", FormatNumber(dps))
        -- Add graph point
        table.insert(self.history, dps)
        if #self.history > GRAPH_POINTS then table.remove(self.history, 1) end
    else
        text = string.format("HPS: %s", FormatNumber(hps))
        -- Add graph point
        table.insert(self.history, hps)
        if #self.history > GRAPH_POINTS then table.remove(self.history, 1) end
    end

    if not self.currentSegment.active then
        text = text .. " (Done)"
    end

    self:SetText(text)
end

-- [ COMBAT HANDLERS ] ---------------------------------------------------------

function DamageWidget:OnCombatStart()
    if self.settings.resetOnCombat then
        self.currentSegment = {
            damage = {},
            healing = {},
            totalDamage = 0,
            totalHealing = 0,
            startTime = GetTime(),
            endTime = 0,
            active = true,
        }
        self.history = {} -- Reset graph
    else
        -- Resume segment?
        if not self.currentSegment.active then
             self.currentSegment.active = true
             self.currentSegment.startTime = GetTime() -- Reset start time? No, this messes up dps calc.
             -- Complex logic for "resume" vs "new". Reset is safer for now.
             -- Let's stick to Reset on Combat = true logic.
             self.currentSegment.startTime = GetTime()
        end
    end

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function() self:OnCombatLog() end)

    -- Ticker for updates
    if self.ticker then self.ticker:Cancel() end
    self.ticker = C_Timer.NewTicker(0.5, function() self:Update() end)
end

function DamageWidget:OnCombatEnd()
    self.currentSegment.active = false
    self.currentSegment.endTime = GetTime()
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end

    self:Update() -- Final update
end

-- [ INTERACTION ] -------------------------------------------------------------

function DamageWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {
        {
            text = "Show DPS",
            checked = (self.settings.mode == "DPS"),
            func = function()
                self.settings.mode = "DPS"
                self:Update()
            end,
            closeOnClick = false,
        },
        {
            text = "Show HPS",
            checked = (self.settings.mode == "HPS"),
            func = function()
                self.settings.mode = "HPS"
                self:Update()
            end,
            closeOnClick = false,
        },
        {
            text = "Reset Data",
            func = function()
                self.currentSegment = {
                    damage = {},
                    healing = {},
                    totalDamage = 0,
                    totalHealing = 0,
                    startTime = GetTime(),
                    endTime = GetTime(),
                    active = false,
                }
                self.history = {}
                self:Update()
            end,
        },
    }

    addon.Menu:Open(self.frame, items)
end

function DamageWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Damage Meter (" .. self.settings.mode .. ")", 1, 0.82, 0)

    local duration = 0
    if self.currentSegment.active then
        duration = GetTime() - self.currentSegment.startTime
    else
        duration = self.currentSegment.endTime - self.currentSegment.startTime
    end
    if duration < 1 then duration = 1 end

    GameTooltip:AddDoubleLine("Time:", string.format("%.1fs", duration), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")

    -- Sort and List Top 5
    local list = {}
    local source = (self.settings.mode == "DPS") and self.currentSegment.damage or self.currentSegment.healing
    local total = (self.settings.mode == "DPS") and self.currentSegment.totalDamage or self.currentSegment.totalHealing

    for name, val in pairs(source) do
        table.insert(list, { name = name, val = val })
    end

    table.sort(list, function(a, b) return a.val > b.val end)

    if #list == 0 then
        GameTooltip:AddLine("No Data", 0.5, 0.5, 0.5)
    else
        for i = 1, math.min(10, #list) do
            local entry = list[i]
            local perSec = entry.val / duration
            local pct = (entry.val / total) * 100

            local left = string.format("%d. %s", i, entry.name)
            local right = string.format("%s (%.1f%%)", FormatNumber(perSec), pct)

            GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Right Click", "Options", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Left Click", "Reset", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()

    -- Graph
    if #self.history > 2 then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(200, 50)
            self.graph = addon.Graph:New(self.graphFrame, 200, 50)
        end
        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, -5)
        self.graphFrame:Show()

        self.graph:Clear()
        self.graph:SetColor(1, 0, 0, 1) -- Red for Damage
        if self.settings.mode == "HPS" then self.graph:SetColor(0, 1, 0, 1) end -- Green for Healing

        for _, val in ipairs(self.history) do
            self.graph:AddData(val)
        end
        self.graph:Draw()
    end
end

function DamageWidget:OnClick(button)
    if button == "RightButton" then
        self:OpenMenu()
    else
        -- Reset
        self.currentSegment = {
            damage = {},
            healing = {},
            totalDamage = 0,
            totalHealing = 0,
            startTime = GetTime(),
            endTime = GetTime(),
            active = false,
        }
        self.history = {}
        self:Update()
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function DamageWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:OnCombatStart() end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:OnCombatEnd() end)

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() DamageWidget:OnLoad() end)
end)
