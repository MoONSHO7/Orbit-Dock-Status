-- Weekly.lua
-- Advanced Weekly Checklist widget for StatusDock
-- Features: Tracks Great Vault, World Bosses, Sparks, and Weekly Events

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local WeeklyWidget = addon.BaseWidget:New("Weekly"); addon.WeeklyWidget.category = "World"
addon.WeeklyWidget = WeeklyWidget

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function WeeklyWidget:GetWeeklyStatus()
    local status = {
        vault = 0,
        worldBoss = false,
        weeklyQuest = false,
        profession = 0, -- Knowledge points?
        catalyst = 0,
    }

    -- 1. Great Vault (Unlock count)
    local activities = C_WeeklyRewards.GetActivities()
    for _, activity in ipairs(activities) do
        if activity.progress >= activity.threshold then
            status.vault = status.vault + 1
        end
    end

    -- 2. World Boss (Check generic quest IDs for current expac bosses)
    -- Dragonflight Bosses: 70830 (Strunraan), etc.
    -- Better: Iterate map POIs or Saved Instances?
    -- Simplified: Check "IsQuestFlaggedCompleted" for known IDs.
    -- (Placeholder logic as IDs rotate)
    status.worldBoss = IsQuestFlaggedCompleted(70830)

    -- 3. Weekly Quest (Aiding the Accord)
    -- ID: 70750 (example)
    status.weeklyQuest = C_QuestLog.IsQuestFlaggedCompleted(70750)

    -- 4. Catalyst Charges
    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(2777) -- Renascent Dream
    if currencyInfo then status.catalyst = currencyInfo.quantity end

    return status
end

-- [ UPDATE ] ------------------------------------------------------------------

function WeeklyWidget:Update()
    local status = self:GetWeeklyStatus()

    local completed = 0
    local total = 3 -- Arbitrary "Big 3" goals

    if status.vault >= 1 then completed = completed + 1 end
    if status.weeklyQuest then completed = completed + 1 end
    if status.worldBoss then completed = completed + 1 end

    local color = addon.Formatting:GetColor(completed, total, false)
    self:SetFormattedText("Weekly:", string.format("%s%d/%d Done|r", color, completed, total))
end

-- [ INTERACTION ] -------------------------------------------------------------

function WeeklyWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Open Great Vault", function()
        if WeeklyRewardsFrame then ShowUIPanel(WeeklyRewardsFrame) else LoadAddOn("Blizzard_WeeklyRewards"); ShowUIPanel(WeeklyRewardsFrame) end
    end)
end

function WeeklyWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Weekly Checklist", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local status = self:GetWeeklyStatus()

    local function AddCheck(label, done)
        local icon = done and "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14|t" or "|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14|t"
        local text = done and "|cff00ff00Done|r" or "|cffff0000Pending|r"
        GameTooltip:AddDoubleLine(label, icon .. " " .. text, 1, 1, 1, 1, 1, 1)
    end

    AddCheck("Great Vault (1+ Slot)", status.vault >= 1)
    AddCheck("Weekly Quest", status.weeklyQuest)
    AddCheck("World Boss", status.worldBoss)

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Catalyst Charges:", tostring(status.catalyst), 1, 1, 1, 1, 1, 1)

    GameTooltip:Show()
end

function WeeklyWidget:OnClick(button)
    if WeeklyRewardsFrame then ShowUIPanel(WeeklyRewardsFrame) end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function WeeklyWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() WeeklyWidget:OnLoad() end)
end)
