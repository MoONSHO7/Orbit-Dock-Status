-- Achievements.lua
-- Achievement tracking widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local AchWidget = addon.BaseWidget:New("Achievements")
addon.AchWidget = AchWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local MAX_TRACKED = 5

-- [ UPDATES ] ---------------------------------------------------------------------

function AchWidget:Update()
    local totalPts = GetTotalAchievementPoints()
    self:SetText(string.format("|cffffd700%s|r pts", addon.Formatting and addon.Formatting.FormatNumber(totalPts) or tostring(totalPts)))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function AchWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Achievements", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total Points:", tostring(GetTotalAchievementPoints()), 1, 1, 1, 1, 0.82, 0)

    local trackedAchievements = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
    if trackedAchievements and #trackedAchievements > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Tracked:", 0.7, 0.7, 0.7)
        for i = 1, math.min(MAX_TRACKED, #trackedAchievements) do
            local achID = trackedAchievements[i]
            local _, name, _, completed, _, _, _, description, _, _, _, _, wasEarnedByMe = GetAchievementInfo(achID)
            if name then
                local status = completed and "|cff00ff00Complete|r" or "|cffff8000In Progress|r"
                GameTooltip:AddDoubleLine("  " .. name, status, 1, 1, 1, 0.7, 0.7, 0.7)
                local numCriteria = GetAchievementNumCriteria(achID)
                local done = 0
                for j = 1, numCriteria do
                    local _, _, criteriaCompleted = GetAchievementCriteriaInfo(achID, j)
                    if criteriaCompleted then done = done + 1 end
                end
                if numCriteria > 0 and not completed then
                    GameTooltip:AddLine(string.format("    Progress: %d/%d", done, numCriteria), 0.5, 0.5, 0.5)
                end
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Achievements", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function AchWidget:OnClick(button) ToggleAchievementFrame() end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function AchWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Achievements"
    self:RegisterEvent("ACHIEVEMENT_EARNED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() AchWidget:OnLoad() end)
end)
