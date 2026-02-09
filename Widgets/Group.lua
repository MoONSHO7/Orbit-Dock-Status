-- Group.lua
-- Advanced Group widget for StatusDock
-- Features: Role count, Ready Check status, Group Tools

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local GroupWidget = addon.BaseWidget:New("Group"); addon.GroupWidget.category = "Social"
addon.GroupWidget = GroupWidget

-- [ HELPER ] ------------------------------------------------------------------

function GroupWidget:GetGroupInfo()
    if not IsInGroup() then return 0, 0, 0, 0 end

    local tanks = 0
    local healers = 0
    local dps = 0
    local total = GetNumGroupMembers()

    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, total do
        local unit = prefix .. i
        if prefix == "party" and i == total then unit = "player" end
        local role = UnitGroupRolesAssigned(unit)
        if role == "TANK" then tanks = tanks + 1
        elseif role == "HEALER" then healers = healers + 1
        elseif role == "DAMAGER" then dps = dps + 1
        end
    end

    return total, tanks, healers, dps
end

-- [ UPDATES ] -----------------------------------------------------------------

function GroupWidget:Update()
    local total, t, h, d = self:GetGroupInfo()

    if total == 0 then
        self:SetFormattedText(nil, "Solo")
    else
        self:SetFormattedText(nil, string.format("|cff00aaff%d|r/|cff00ff00%d|r/|cffff0000%d|r (%d)", t, h, d, total))
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function GroupWidget:GenerateMenu(owner, rootDescription)
    if not IsInGroup() then
        rootDescription:CreateTitle("Not in Group")
        rootDescription:CreateButton("Open Group Finder", function() PVEFrame_ToggleFrame() end)
        return
    end

    if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
        rootDescription:CreateTitle("Management")
        rootDescription:CreateButton("Ready Check", function() DoReadyCheck() end)
        rootDescription:CreateButton("Role Check", function() InitiateRolePoll() end)

        -- Difficulty Submenu (Simplified)
        -- local diff = rootDescription:CreateButton("Difficulty")
        -- diff:CreateRadio("Normal", ...)
    end

    rootDescription:CreateButton("Leave Group", function() LeaveParty() end)

    if not IsInRaid() and UnitIsGroupLeader("player") then
        rootDescription:CreateButton("Convert to Raid", function() ConvertToRaid() end)
    end
end

function GroupWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Group", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local total, t, h, d = self:GetGroupInfo()

    if total > 0 then
        GameTooltip:AddDoubleLine("Tanks:", t, 1, 1, 1, 0, 0.7, 1)
        GameTooltip:AddDoubleLine("Healers:", h, 1, 1, 1, 0, 1, 0)
        GameTooltip:AddDoubleLine("DPS:", d, 1, 1, 1, 1, 0, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total:", total, 1, 1, 1, 1, 1, 1)
    else
        GameTooltip:AddLine("Not in a group", 0.5, 0.5, 0.5)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Group Finder", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Tools", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function GroupWidget:OnClick(button)
    PVEFrame_ToggleFrame()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function GroupWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("READY_CHECK")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() GroupWidget:OnLoad() end)
end)
