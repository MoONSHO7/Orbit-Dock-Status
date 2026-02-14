-- QueueStatus.lua
-- Queue status widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local QueueWidget = addon.BaseWidget:New("QueueStatus")
addon.QueueWidget = QueueWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local SECONDS_PER_MINUTE = 60

-- [ HELPERS ] ---------------------------------------------------------------------

local function FormatWait(seconds)
    if not seconds or seconds <= 0 then return "—" end
    local mins = math.floor(seconds / SECONDS_PER_MINUTE)
    local secs = seconds % SECONDS_PER_MINUTE
    if mins > 0 then return string.format("%dm %ds", mins, secs) end
    return string.format("%ds", secs)
end

-- [ UPDATES ] ---------------------------------------------------------------------

function QueueWidget:Update()
    local inQueue = false
    local queueType = ""
    local waitTime = 0

    for i = 1, GetNumWorldPVPAreas and GetNumWorldPVPAreas() or 0 do
        local _, localizedName, isActive, canQueue, _, _, _, _, _, isRegistered = GetWorldPVPAreaInfo(i)
        if isRegistered then inQueue = true; queueType = localizedName; break end
    end

    local mode, submode = GetLFGMode(LE_LFG_CATEGORY_LFD)
    if mode == "queued" then
        inQueue = true
        queueType = "Dungeon"
        local hasData, _, _, _, _, _, _, _, _, _, _, _, _, _, _, estimatedWait = GetLFGQueueStats(LE_LFG_CATEGORY_LFD)
        if hasData then waitTime = estimatedWait or 0 end
    end

    local raidMode = GetLFGMode(LE_LFG_CATEGORY_RF)
    if raidMode == "queued" then
        inQueue = true
        queueType = "Raid Finder"
        local hasData, _, _, _, _, _, _, _, _, _, _, _, _, _, _, estimatedWait = GetLFGQueueStats(LE_LFG_CATEGORY_RF)
        if hasData then waitTime = estimatedWait or 0 end
    end

    local status, _, _, _, _, _, _, _, _, roleType = GetBattlefieldStatus(1)
    if status == "queued" then
        inQueue = true
        queueType = "Battleground"
    elseif status == "confirm" then
        inQueue = true
        queueType = "|cff00ff00BG Ready!|r"
        self:Flash()
    end

    if not inQueue then
        self.frame:Hide()
        self:StopFlash()
        return
    end

    self.frame:Show()
    if waitTime > 0 then
        self:SetText(string.format("%s: %s", queueType, FormatWait(waitTime)))
    else
        self:SetText(queueType)
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function QueueWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Queue Status", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local hasAny = false
    local mode = GetLFGMode(LE_LFG_CATEGORY_LFD)
    if mode == "queued" then
        hasAny = true
        local hasData, _, tankNeeds, healerNeeds, dpsNeeds, _, _, _, _, myWait, _, _, _, _, _, estWait = GetLFGQueueStats(LE_LFG_CATEGORY_LFD)
        GameTooltip:AddLine("Dungeon Queue:", 0.7, 0.7, 0.7)
        if hasData then
            GameTooltip:AddDoubleLine("  Wait:", FormatWait(estWait), 1, 1, 1, 1, 0.8, 0)
            GameTooltip:AddDoubleLine("  Elapsed:", FormatWait(myWait), 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end

    local status, _, _, _, _, queueType = GetBattlefieldStatus(1)
    if status == "queued" or status == "confirm" then
        hasAny = true
        GameTooltip:AddLine("Battleground:", 0.7, 0.7, 0.7)
        GameTooltip:AddDoubleLine("  Status:", status == "confirm" and "|cff00ff00Ready!|r" or "Waiting", 1, 1, 1, 1, 1, 1)
    end

    if not hasAny then GameTooltip:AddLine("Not in queue", 0.5, 0.5, 0.5) end

    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function QueueWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self.leftClickHint = "Queue Info"
    self:RegisterEvent("LFG_UPDATE")
    self:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:SetUpdateTier("NORMAL")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() QueueWidget:OnLoad() end)
end)
