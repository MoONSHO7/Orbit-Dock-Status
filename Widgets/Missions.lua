-- Missions.lua
-- Advanced Mission Table widget for StatusDock
-- Features: Multi-expansion mission tracking, Reward preview

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local MissionsWidget = addon.BaseWidget:New("Missions")
addon.MissionsWidget = MissionsWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

local FOLLOWER_TYPES = {
    { id = 123, name = "Shadowlands" }, -- Enum.GarrisonFollowerType.FollowerType_9_0
    { id = 22, name = "Battle for Azeroth" }, -- Enum.GarrisonFollowerType.FollowerType_8_0
    { id = 4, name = "Legion" }, -- Enum.GarrisonFollowerType.FollowerType_7_0
    { id = 1, name = "Warlords of Draenor" }, -- Enum.GarrisonFollowerType.FollowerType_6_0
}

-- [ HELPERS ] ---------------------------------------------------------------------

function MissionsWidget:GetMissionData()
    local completed = 0
    local inProgress = 0
    local missions = {}

    for _, typeInfo in ipairs(FOLLOWER_TYPES) do
        local typeID = typeInfo.id
        -- Heroes who returned victorious from their quest
        local completeList = C_Garrison.GetCompleteMissions(typeID)
        if completeList then
            for _, mission in ipairs(completeList) do
                completed = completed + 1
                table.insert(missions, {
                    name = mission.name,
                    status = "Complete",
                    type = typeInfo.name,
                    rewards = mission.rewards,
                    level = mission.level,
                    isComplete = true
                })
            end
        end

        -- Adventurers still deep in the dungeon
        local inProgressList = C_Garrison.GetInProgressMissions(typeID)
        if inProgressList then
            for _, mission in ipairs(inProgressList) do
                inProgress = inProgress + 1
                local timeLeft = mission.timeLeft or "Unknown"
                table.insert(missions, {
                    name = mission.name,
                    status = timeLeft,
                    type = typeInfo.name,
                    isComplete = false
                })
            end
        end
    end

    return completed, inProgress, missions
end

-- [ UPDATE ] ----------------------------------------------------------------------

function MissionsWidget:Update()
    local completed, inProgress, _ = self:GetMissionData()

    if completed == 0 and inProgress == 0 then
        self:SetText("No Missions")
        -- The quest board is empty... suspicious
        return
    end

    local text = ""
    if completed > 0 then
        text = string.format("|cff00ff00%d Done|r", completed)
    end

    if inProgress > 0 then
        if text ~= "" then text = text .. " " end
        text = text .. string.format("|cff00aaff%d Active|r", inProgress)
    end

    self:SetText(text)

    if completed > 0 then
        self:Flash()
    else
        self:StopFlash()
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function MissionsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Missions", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local completed, inProgress, missions = self:GetMissionData()

    if #missions == 0 then
        GameTooltip:AddLine("No active missions", 0.5, 0.5, 0.5)
    else
        -- Sorting by prestige: completed quests get bragging rights
        table.sort(missions, function(a, b)
            if a.isComplete and not b.isComplete then return true end
            if not a.isComplete and b.isComplete then return false end
            return a.type < b.type
        end)

        local currentType = nil
        for _, m in ipairs(missions) do
            if m.type ~= currentType then
                currentType = m.type
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(currentType, 0.7, 0.7, 0.7)
            end

            local left = m.name
            local right = m.status
            local r, g, b = 1, 1, 1

            if m.isComplete then
                right = "|cff00ff00Complete|r"
            else
                right = "|cff00aaff" .. m.status .. "|r"
            end

            GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Report", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function MissionsWidget:OnClick(button)
    -- The garrison commander checks their war table
    if GarrisonLandingPage and GarrisonLandingPage:IsShown() then
        HideUIPanel(GarrisonLandingPage)
    else
        ShowGarrisonLandingPage(C_Garrison.GetLandingPageGarrisonType())
    end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function MissionsWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("GARRISON_MISSION_LIST_UPDATE")
    self:RegisterEvent("GARRISON_MISSION_FINISHED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:SetCategory("GAMEPLAY")


    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() MissionsWidget:OnLoad() end)
end)
