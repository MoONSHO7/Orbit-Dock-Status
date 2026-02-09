-- Quest.lua
-- Advanced Quest widget for StatusDock
-- Features: Auto-Accept, Auto-Turn In, Quest Log Summary

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local QuestWidget = addon.BaseWidget:New("Quest"); addon.QuestWidget.category = "World"
addon.QuestWidget = QuestWidget

-- [ SETTINGS ] ----------------------------------------------------------------

QuestWidget.settings = {
    autoAccept = true,
    autoTurnIn = true,
}

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function QuestWidget:GetQuestSummary()
    local num = C_QuestLog.GetNumQuestLogEntries()
    local count = 0
    local zones = {}

    for i = 1, num do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then
            count = count + 1
            local zoneName = "Unknown"
            local zoneInfo = C_QuestLog.GetZoneStoryInfo(info.questID)
            if zoneInfo and zoneInfo.zoneName then zoneName = zoneInfo.zoneName end

            if not zones[zoneName] then zones[zoneName] = 0 end
            zones[zoneName] = zones[zoneName] + 1
        end
    end

    return count, 25, zones
end

-- [ UPDATES ] -----------------------------------------------------------------

function QuestWidget:Update()
    local count, max, _ = self:GetQuestSummary()
    local color = "|cff00ff00"
    if count >= max - 5 then color = "|cffffa500" end
    if count >= max then color = "|cffff0000" end

    self:SetFormattedText("Quests:", string.format("%s%d|r/%d", color, count, max))
end

-- [ AUTOMATION ] --------------------------------------------------------------

function QuestWidget:HandleGossip()
    -- Logic kept same as previous version
    if self.settings.autoAccept then
        local available = C_GossipInfo.GetAvailableQuests()
        if available then
            for _, quest in ipairs(available) do C_GossipInfo.SelectAvailableQuest(quest.questID) end
        end
    end

    if self.settings.autoTurnIn then
        local active = C_GossipInfo.GetActiveQuests()
        if active then
            for _, quest in ipairs(active) do
                if quest.isComplete then C_GossipInfo.SelectActiveQuest(quest.questID) end
            end
        end
    end
end

function QuestWidget:HandleQuestDetail() if self.settings.autoAccept then AcceptQuest() end end
function QuestWidget:HandleQuestProgress() if self.settings.autoTurnIn and IsQuestCompletable() then CompleteQuest() end end
function QuestWidget:HandleQuestComplete() if self.settings.autoTurnIn and GetNumQuestChoices() <= 1 then GetQuestReward(1) end end

-- [ INTERACTION ] -------------------------------------------------------------

function QuestWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateCheckbox("Auto-Accept Quests", function() return self.settings.autoAccept end, function()
        self.settings.autoAccept = not self.settings.autoAccept
    end)
    rootDescription:CreateCheckbox("Auto-Turn In Quests", function() return self.settings.autoTurnIn end, function()
        self.settings.autoTurnIn = not self.settings.autoTurnIn
    end)
end

function QuestWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Quest Log", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local count, max, zones = self:GetQuestSummary()
    GameTooltip:AddDoubleLine("Total:", string.format("%d/%d", count, max), 1, 1, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("By Zone:", 0.7, 0.7, 0.7)

    for zone, num in pairs(zones) do
        GameTooltip:AddDoubleLine(zone, tostring(num), 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Quest Log", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Settings", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function QuestWidget:OnClick(button)
    ToggleQuestLog()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function QuestWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("QUEST_ACCEPTED")
    self:RegisterEvent("QUEST_REMOVED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:RegisterEvent("GOSSIP_SHOW", function() self:HandleGossip() end)
    self:RegisterEvent("QUEST_DETAIL", function() self:HandleQuestDetail() end)
    self:RegisterEvent("QUEST_PROGRESS", function() self:HandleQuestProgress() end)
    self:RegisterEvent("QUEST_COMPLETE", function() self:HandleQuestComplete() end)

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() QuestWidget:OnLoad() end)
end)
