-- GreatVault.lua
-- Great Vault progress widget for StatusDock
-- Features: vault progress rows, reward iLvl previews, claimable status

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local VaultWidget = addon.BaseWidget:New("GreatVault")
addon.VaultWidget = VaultWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local VAULT_TYPES = { Enum.WeeklyRewardChestThresholdType.Activities, Enum.WeeklyRewardChestThresholdType.RankedPvP, Enum.WeeklyRewardChestThresholdType.World }
local VAULT_LABELS = { "M+", "PvP", "World" }
local SLOTS_PER_ROW = 3

-- [ UPDATES ] ---------------------------------------------------------------------

function VaultWidget:Update()
    local hasRewards = C_WeeklyRewards.HasAvailableRewards()
    if hasRewards then
        self:SetText("|cff00ff00Vault Ready!|r")
        self:Flash()
        return
    end
    self:StopFlash()
    local totalUnlocked = 0
    for _, vaultType in ipairs(VAULT_TYPES) do
        local activities = C_WeeklyRewards.GetActivities(vaultType)
        for _, activity in ipairs(activities) do
            if activity.progress >= activity.threshold then totalUnlocked = totalUnlocked + 1 end
        end
    end
    if totalUnlocked > 0 then
        self:SetText(string.format("|cffffd700%d|r/9 Vault", totalUnlocked))
    else
        self:SetText("|cff888888Vault|r")
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function VaultWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Great Vault", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local hasRewards = C_WeeklyRewards.HasAvailableRewards()
    if hasRewards then
        GameTooltip:AddLine("|cff00ff00Rewards Available! Visit the Vault.|r")
        GameTooltip:AddLine(" ")
    end

    for i, vaultType in ipairs(VAULT_TYPES) do
        local activities = C_WeeklyRewards.GetActivities(vaultType)
        if activities and #activities > 0 then
            GameTooltip:AddLine(VAULT_LABELS[i] .. ":", 0.7, 0.7, 0.7)
            for _, activity in ipairs(activities) do
                local progress = math.min(activity.progress, activity.threshold)
                local completed = activity.progress >= activity.threshold
                local r, g, b = 1, 1, 1
                if completed then r, g, b = 0, 1, 0
                elseif activity.progress > 0 then r, g, b = 1, 0.8, 0 end
                local rewardStr = ""
                if activity.rewards and #activity.rewards > 0 then
                    for _, reward in ipairs(activity.rewards) do
                        if reward.type == Enum.CachedRewardType.Item and reward.itemDBID then
                            local itemLevel = C_WeeklyRewards.GetItemHyperlink(reward.itemDBID)
                            if itemLevel then rewardStr = " " .. itemLevel end
                        end
                    end
                end
                GameTooltip:AddDoubleLine(
                    string.format("  %d/%d%s", progress, activity.threshold, rewardStr),
                    completed and "|cff00ff00\226\156\147|r" or "",
                    r, g, b, 1, 1, 1
                )
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Vault", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function VaultWidget:OnClick(button)
    WeeklyRewards_ShowUI()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function VaultWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Vault"
    self:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() VaultWidget:OnLoad() end)
end)
