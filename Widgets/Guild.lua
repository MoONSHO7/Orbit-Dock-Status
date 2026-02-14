-- Guild.lua
-- Advanced Guild widget for StatusDock
-- Features: Detailed roster, class coloring, sorting, click-to-invite

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local GuildWidget = addon.BaseWidget:New("Guild")
addon.GuildWidget = GuildWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local COLORS = {
    GREEN = "|cff00ff00",
    YELLOW = "|cfffea300",
    RED = "|cffff0000",
    GREY = "|cff888888",
    WHITE = "|cffffffff",
}

local MAX_TOOLTIP_DISPLAY = 30
local ROSTER_REFRESH_SEC = 30
local FRAME_WIDTH = 80
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ HELPER FUNCTIONS ] ------------------------------------------------------------

function GuildWidget:GetClassColor(classFileName)
    if not classFileName then return COLORS.WHITE end
    local color = C_ClassColor.GetClassColor(classFileName)
    if color then
        return color:GenerateHexColor()
    end
    return COLORS.WHITE
end

function GuildWidget:GetStatusIcon(status)
    if status == 1 then return "|TInterface\\FriendsFrame\\StatusIcon-Away:14|t" end
    if status == 2 then return "|TInterface\\FriendsFrame\\StatusIcon-DnD:14|t" end
    return ""
end

function GuildWidget:FormatName(name, classFileName)
    local color = self:GetClassColor(classFileName)
    return string.format("|c%s%s|r", color, name)
end

function GuildWidget:GetGuildData()
    if not IsInGuild() then return 0, 0, {} end
    
    local total = GetNumGuildMembers()
    local online = 0
    local members = {}

    for i = 1, total do
        local name, rank, rankIndex, level, class, zone, note, officernote, onlineState, status, classFileName = GetGuildRosterInfo(i)
        if onlineState then
            online = online + 1
            table.insert(members, {
                name = name,
                rank = rank,
                rankIndex = rankIndex,
                level = level,
                class = class,
                classFileName = classFileName,
                zone = zone,
                note = note,
                status = status,
            })
        end
    end

    -- Charisma modifier determines who sits at the guild master's table first
    table.sort(members, function(a, b)
        if a.rankIndex == b.rankIndex then
            return a.name < b.name
        end
        return a.rankIndex < b.rankIndex
    end)

    return online, total, members
end

-- [ UPDATES ] ---------------------------------------------------------------------

function GuildWidget:Update()
    if not IsInGuild() then
        self:SetText(COLORS.GREY .. "No Guild|r")
        return
    end
    
    local online, total, _ = self:GetGuildData()
    local color = online > 0 and COLORS.GREEN or COLORS.GREY

    self:SetText(string.format("%s%d|r%s/%d|r Guild", color, online, COLORS.GREY, total))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function GuildWidget:ShowTooltip()
    if not IsInGuild() then
        GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Guild", 1, 0.82, 0)
        GameTooltip:AddLine("Not in a guild", 0.5, 0.5, 0.5)
        GameTooltip:Show()
        return
    end
    
    local online, total, members = self:GetGuildData()
    local guildName, _, _, _ = GetGuildInfo("player")
    local motd = GetGuildRosterMOTD()
    
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine(guildName or "Guild", string.format("%d/%d Online", online, total), 0.4, 0.8, 0.4, 1, 1, 1)

    if motd and motd ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ffffMOTD:|r " .. motd, 1, 1, 1, true)
    end
    
    GameTooltip:AddLine(" ")
    
    -- The guild notice board
    GameTooltip:AddLine(string.format("%-20s %-10s %-10s %-15s", "Name", "Level", "Rank", "Zone"), 0.7, 0.7, 0.7)
    
    -- Even the longest adventurer roster has a scroll limit
    local maxDisplay = MAX_TOOLTIP_DISPLAY
    for i, m in ipairs(members) do
        if i > maxDisplay then
            GameTooltip:AddLine(string.format("... and %d more", online - maxDisplay), 0.5, 0.5, 0.5)
            break
        end

        local nameStr = self:FormatName(m.name, m.classFileName) .. self:GetStatusIcon(m.status)
        local zoneStr = m.zone or "Unknown"
        local rankStr = m.rank or ""

        -- Add line with custom formatting (using DoubleLine for basic layout, but ideally would use columns)
        -- Since GameTooltip doesn't support 4 columns easily, we combine Level/Rank/Zone into right text
        local rightText = string.format("|cffffffff%d|r  |cffcccccc%s|r  |cffffd700%s|r", m.level, rankStr, zoneStr)
        GameTooltip:AddDoubleLine(nameStr, rightText)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Guild", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Sort/Filter (Coming Soon)", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function GuildWidget:OnClick(button)
    if button == "LeftButton" then
        ToggleGuildFrame()
    end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function GuildWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    
    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    -- Register events
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_GUILD_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Initial request
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    
    self:SetUpdateTier("GLACIAL")
    
    -- Register with manager
    self:SetCategory("SOCIAL")

    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() GuildWidget:OnLoad() end)
end)
