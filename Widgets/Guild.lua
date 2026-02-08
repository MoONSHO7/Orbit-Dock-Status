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
GuildWidget.category = "Social"

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function GuildWidget:GetClassColor(classFileName)
    if not classFileName then return "|cffffffff" end
    local color = C_ClassColor.GetClassColor(classFileName)
    return color and color:GenerateHexColor() or "|cffffffff"
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
                status = status,
            })
        end
    end

    table.sort(members, function(a, b)
        if a.rankIndex == b.rankIndex then return a.name < b.name end
        return a.rankIndex < b.rankIndex
    end)

    return online, total, members
end

-- [ UPDATES ] -----------------------------------------------------------------

function GuildWidget:Update()
    if not IsInGuild() then
        self:SetFormattedText(nil, "|cff888888No Guild|r")
        return
    end
    
    local online, total, _ = self:GetGuildData()
    local color = online > 0 and "|cff00ff00" or "|cff888888"

    self:SetFormattedText("Guild:", string.format("%s%d|r/%d", color, online, total))
end

-- [ INTERACTION ] -------------------------------------------------------------

function GuildWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Open Guild", function() ToggleGuildFrame() end)

    -- Filter/Sort options could go here
end

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
    local guildName = GetGuildInfo("player")
    local motd = GetGuildRosterMOTD()
    
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine(guildName or "Guild", string.format("%d/%d Online", online, total), 0.4, 0.8, 0.4, 1, 1, 1)

    if motd and motd ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ffffMOTD:|r " .. motd, 1, 1, 1, true)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format("%-20s %-10s %-10s %-15s", "Name", "Level", "Rank", "Zone"), 0.7, 0.7, 0.7)
    
    local maxDisplay = 30
    for i, m in ipairs(members) do
        if i > maxDisplay then
            GameTooltip:AddLine(string.format("... and %d more", online - maxDisplay), 0.5, 0.5, 0.5)
            break
        end

        local color = self:GetClassColor(m.classFileName)
        local nameStr = string.format("|c%s%s|r", color, m.name)

        local rightText = string.format("|cffffffff%d|r  |cffcccccc%s|r  |cffffd700%s|r", m.level, m.rank, m.zone or "Unknown")
        GameTooltip:AddDoubleLine(nameStr, rightText)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Guild", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function GuildWidget:OnClick(button)
    ToggleGuildFrame()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function GuildWidget:OnLoad()
    self:CreateFrame(80, 20)
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_GUILD_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    if IsInGuild() then C_GuildInfo.GuildRoster() end

    -- Periodic refresh
    C_Timer.NewTicker(30, function()
        if IsInGuild() and self.isEnabled then C_GuildInfo.GuildRoster() end
    end)
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() GuildWidget:OnLoad() end)
end)
