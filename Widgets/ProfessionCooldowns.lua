-- ProfessionCooldowns.lua
-- Profession cooldown tracker widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local ProfCDWidget = addon.BaseWidget:New("ProfessionCooldowns")
addon.ProfCDWidget = ProfCDWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_DAY = 86400

-- [ HELPERS ] ---------------------------------------------------------------------

local function FormatRemaining(seconds)
    if seconds <= 0 then return "|cff00ff00Ready|r" end
    local days = math.floor(seconds / SECONDS_PER_DAY)
    local hours = math.floor((seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)
    local mins = math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
    if days > 0 then return string.format("%dd %dh", days, hours) end
    if hours > 0 then return string.format("%dh %dm", hours, mins) end
    return string.format("%dm", mins)
end

-- [ UPDATES ] ---------------------------------------------------------------------

function ProfCDWidget:GetCooldowns()
    local cooldowns = {}
    local professions = { GetProfessions() }
    for _, idx in pairs(professions) do
        if idx then
            local name = GetProfessionInfo(idx)
            local cdSpells = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
            if cdSpells then
                for _, spellID in ipairs(cdSpells) do
                    local cd = C_Spell.GetSpellCooldown(spellID)
                    if cd and cd.startTime > 0 and cd.duration > SECONDS_PER_HOUR then
                        local remaining = math.max(0, (cd.startTime + cd.duration) - GetTime())
                        if remaining > 0 then
                            local spellName = C_Spell.GetSpellName(spellID)
                            table.insert(cooldowns, { name = spellName or "Unknown", remaining = remaining, profession = name })
                        end
                    end
                end
            end
        end
    end
    table.sort(cooldowns, function(a, b) return a.remaining < b.remaining end)
    return cooldowns
end

function ProfCDWidget:Update()
    local cds = self:GetCooldowns()
    if #cds > 0 then
        self:SetText(string.format("|cffff8000%d CD|r", #cds))
    else
        self:SetText("|cff00ff00No CDs|r")
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function ProfCDWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Profession Cooldowns", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local cds = self:GetCooldowns()
    if #cds == 0 then
        GameTooltip:AddLine("No active cooldowns", 0, 1, 0)
    else
        for _, cd in ipairs(cds) do
            GameTooltip:AddDoubleLine(cd.name, FormatRemaining(cd.remaining), 1, 1, 1, 1, 0.8, 0)
            GameTooltip:AddLine("  " .. cd.profession, 0.5, 0.5, 0.5)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Professions", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function ProfCDWidget:OnClick(button)
    if ProfessionsFrame then
        if ProfessionsFrame:IsShown() then HideUIPanel(ProfessionsFrame) else ShowUIPanel(ProfessionsFrame) end
    end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function ProfCDWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Professions"
    self:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("CHARACTER")
    self:Register()
    self:SetUpdateTier("GLACIAL")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() ProfCDWidget:OnLoad() end)
end)
