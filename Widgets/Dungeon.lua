-- Dungeon.lua
-- Advanced Dungeon/Raid widget for StatusDock
-- Features: Saved Instances, M+ Keystone, Great Vault, World Bosses

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local DungeonWidget = addon.BaseWidget:New("Dungeon")
addon.DungeonWidget = DungeonWidget
DungeonWidget.category = "World"

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function DungeonWidget:GetSavedInstances()
    local saved = {}
    local num = GetNumSavedInstances()
    for i = 1, num do
        local name, id, reset, diff, locked, extended, _, isRaid, _, diffName = GetSavedInstanceInfo(i)
        if (locked or extended) and isRaid then
            table.insert(saved, { name = name, diff = diffName, reset = reset })
        end
    end
    return saved
end

function DungeonWidget:GetKeystone()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID and level then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
        return mapName, level
    end
    return nil, nil
end

function DungeonWidget:GetGreatVault()
    local activities = C_WeeklyRewards.GetActivities()
    local raids = 0
    local mythic = 0
    local pvp = 0
    for _, activity in ipairs(activities) do
        if activity.type == Enum.WeeklyRewardChestThresholdType.Raid then
            if activity.progress >= activity.threshold then raids = raids + 1 end
        elseif activity.type == Enum.WeeklyRewardChestThresholdType.MythicPlus then
            if activity.progress >= activity.threshold then mythic = mythic + 1 end
        elseif activity.type == Enum.WeeklyRewardChestThresholdType.RankedPvP then
            if activity.progress >= activity.threshold then pvp = pvp + 1 end
        end
    end
    return raids, mythic, pvp
end

-- [ UPDATES ] -----------------------------------------------------------------

function DungeonWidget:Update()
    local mapName, level = self:GetKeystone()
    if mapName then
        self:SetFormattedText("Key:", string.format("|cff00ff00+%d|r %s", level, mapName))
    else
        self:SetFormattedText("Key:", "None")
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function DungeonWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Open Group Finder", function() PVEFrame_ToggleFrame() end)
    rootDescription:CreateButton("Open Adventure Guide", function() ToggleEncounterJournal() end)
    rootDescription:CreateButton("Open Great Vault", function()
        if WeeklyRewardsFrame then ShowUIPanel(WeeklyRewardsFrame) else LoadAddOn("Blizzard_WeeklyRewards"); ShowUIPanel(WeeklyRewardsFrame) end
    end)
end

function DungeonWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Dungeons & Raids", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    -- Keystone
    local mapName, level = self:GetKeystone()
    if mapName then
        GameTooltip:AddDoubleLine("Keystone:", string.format("+%d %s", level, mapName), 1, 1, 1, 0, 1, 0)
    else
        GameTooltip:AddDoubleLine("Keystone:", "None", 1, 1, 1, 0.5, 0.5, 0.5)
    end

    GameTooltip:AddLine(" ")

    -- Great Vault
    local raids, mythic, pvp = self:GetGreatVault()
    GameTooltip:AddLine("Great Vault", 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("Raids:", string.format("%d/3", raids), 1, 1, 1, raids > 0 and 0 or 1, raids > 0 and 1 or 0, 0)
    GameTooltip:AddDoubleLine("Mythic+:", string.format("%d/3", mythic), 1, 1, 1, mythic > 0 and 0 or 1, mythic > 0 and 1 or 0, 0)
    GameTooltip:AddDoubleLine("PvP:", string.format("%d/3", pvp), 1, 1, 1, pvp > 0 and 0 or 1, pvp > 0 and 1 or 0, 0)

    GameTooltip:AddLine(" ")

    -- Saved Instances
    local saved = self:GetSavedInstances()
    if #saved > 0 then
        GameTooltip:AddLine("Lockouts", 0.7, 0.7, 0.7)
        for _, instance in ipairs(saved) do
            local time = SecondsToTime(instance.reset)
            GameTooltip:AddDoubleLine(instance.name .. " (" .. instance.diff .. ")", time, 1, 1, 1, 0.7, 0.7, 0.7)
        end
    else
        GameTooltip:AddLine("No Lockouts", 0.5, 0.5, 0.5)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Group Finder", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function DungeonWidget:OnClick(button)
    PVEFrame_ToggleFrame()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function DungeonWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("UPDATE_INSTANCE_INFO")
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() DungeonWidget:OnLoad() end)
end)
