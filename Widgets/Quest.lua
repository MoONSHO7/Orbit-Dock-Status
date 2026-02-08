-- Quest.lua
-- Advanced Quest widget for StatusDock
-- Features: Auto-Accept, Auto-Turn In, Quest Log Summary

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local QuestWidget = addon.BaseWidget:New("Quest")
addon.QuestWidget = QuestWidget

-- [ SETTINGS ] ----------------------------------------------------------------

QuestWidget.settings = {
    autoAccept = true,
    autoTurnIn = true,
    skipGossip = true, -- For auto-turn in
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
            local zone = C_QuestLog.GetZoneStoryInfo(info.questID) -- returns table with zoneName
            local zoneName = "Unknown"
            if zone and zone.zoneName then zoneName = zone.zoneName end

            if not zones[zoneName] then zones[zoneName] = 0 end
            zones[zoneName] = zones[zoneName] + 1
        end
    end

    return count, 25, zones -- 25 is standard limit, or 35 in DF? C_QuestLog.GetMaxNumQuestsCanAccept()
end

-- [ UPDATES ] -----------------------------------------------------------------

function QuestWidget:Update()
    local count, max, _ = self:GetQuestSummary()
    local color = "|cff00ff00"
    if count >= max - 5 then color = "|cffffa500" end -- Orange near limit
    if count >= max then color = "|cffff0000" end -- Red full

    self:SetText(string.format("%s%d|r/%d Quests", color, count, max))
end

-- [ AUTOMATION ] --------------------------------------------------------------

function QuestWidget:HandleGossip()
    if not self.settings.skipGossip then return end

    local options = C_GossipInfo.GetOptions()
    if options and #options == 1 and options[1].type == "gossip" then
        -- Only skip if it's the only option and it's gossip (e.g. "Let me fly to...")
        -- Risky if not careful. Maybe just for quests?
        -- For now, disable generic gossip skipping to be safe.
        -- Focus on QUEST specific gossip options.
    end

    -- Auto-Select available quests
    local available = C_GossipInfo.GetAvailableQuests()
    if self.settings.autoAccept and available then
        for _, quest in ipairs(available) do
            C_GossipInfo.SelectAvailableQuest(quest.questID)
        end
    end

    -- Auto-Select active quests (for turn in)
    local active = C_GossipInfo.GetActiveQuests()
    if self.settings.autoTurnIn and active then
        for _, quest in ipairs(active) do
            if quest.isComplete then
                C_GossipInfo.SelectActiveQuest(quest.questID)
            end
        end
    end
end

function QuestWidget:HandleQuestDetail()
    if self.settings.autoAccept then
        AcceptQuest()
    end
end

function QuestWidget:HandleQuestProgress()
    if self.settings.autoTurnIn and IsQuestCompletable() then
        CompleteQuest()
    end
end

function QuestWidget:HandleQuestComplete()
    if self.settings.autoTurnIn then
        if GetNumQuestChoices() <= 1 then
            GetQuestReward(1)
        end
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function QuestWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {
        {
            text = "Auto-Accept Quests",
            checked = self.settings.autoAccept,
            func = function() self.settings.autoAccept = not self.settings.autoAccept end,
            closeOnClick = false,
        },
        {
            text = "Auto-Turn In Quests",
            checked = self.settings.autoTurnIn,
            func = function() self.settings.autoTurnIn = not self.settings.autoTurnIn end,
            closeOnClick = false,
        },
    }

    addon.Menu:Open(self.frame, items)
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
    GameTooltip:AddDoubleLine("Right Click", "Automation Settings", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function QuestWidget:OnClick(button)
    if button == "RightButton" then
        self:OpenMenu()
    else
        ToggleQuestLog()
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function QuestWidget:OnLoad()
    self:CreateFrame(100, 20)

    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Register events
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("QUEST_ACCEPTED")
    self:RegisterEvent("QUEST_REMOVED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Automation Events
    self:RegisterEvent("GOSSIP_SHOW", function() self:HandleGossip() end)
    self:RegisterEvent("QUEST_DETAIL", function() self:HandleQuestDetail() end)
    self:RegisterEvent("QUEST_PROGRESS", function() self:HandleQuestProgress() end)
    self:RegisterEvent("QUEST_COMPLETE", function() self:HandleQuestComplete() end)

    -- Register with manager
    self:Register()

    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() QuestWidget:OnLoad() end)
end)
