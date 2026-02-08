-- Group.lua
-- Advanced Group widget for StatusDock
-- Features: Role count, Ready Check status, Group Tools

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local GroupWidget = addon.BaseWidget:New("Group")
addon.GroupWidget = GroupWidget

-- [ HELPER ] ------------------------------------------------------------------

function GroupWidget:GetGroupInfo()
    if not IsInGroup() then return 0, 0, 0, 0 end

    local tanks = 0
    local healers = 0
    local dps = 0
    local total = GetNumGroupMembers()

    local prefix = IsInRaid() and "raid" or "party"

    -- Iterate members
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
        self:SetText("Solo")
    else
        -- Format: T/H/D
        self:SetText(string.format("|cff00aaff%d|r/|cff00ff00%d|r/|cffff0000%d|r (%d)", t, h, d, total))
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function GroupWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {}

    if IsInGroup() then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            table.insert(items, {
                text = "Ready Check",
                func = function() DoReadyCheck() end,
            })
            table.insert(items, {
                text = "Role Check",
                func = function() InitiateRolePoll() end,
            })

            local difficulty = GetDungeonDifficultyID()
            -- Add difficulty toggle?
        end

        table.insert(items, {
            text = "Leave Group",
            func = function() LeaveParty() end,
        })

        if not IsInRaid() and UnitIsGroupLeader("player") then
             table.insert(items, {
                text = "Convert to Raid",
                func = function() ConvertToRaid() end,
            })
        end
    end

    addon.Menu:Open(self.frame, items)
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
    if button == "RightButton" then
        self:OpenMenu()
    else
        PVEFrame_ToggleFrame()
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function GroupWidget:OnLoad()
    self:CreateFrame(100, 20)

    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Register events
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("READY_CHECK")

    -- Register with manager
    self:Register()

    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() GroupWidget:OnLoad() end)
end)
