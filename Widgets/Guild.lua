-- Guild.lua
-- Guild online widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local GuildWidget = {}
addon.GuildWidget = GuildWidget

local widgetFrame = nil

local function GetGuildOnline()
    if not IsInGuild() then return 0 end
    
    local online = 0
    local numTotal = GetNumGuildMembers()
    for i = 1, numTotal do
        local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            online = online + 1
        end
    end
    return online
end

local function UpdateGuild()
    if not widgetFrame then return end
    
    if not IsInGuild() then
        widgetFrame.Text:SetText("|cff888888No Guild|r")
    else
        local online = GetGuildOnline()
        local color = online > 0 and "|cff40c040" or "|cff888888"
        widgetFrame.Text:SetText(string.format("%s%d|r Guild", color, online))
    end
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusGuildWidget", UIParent)
    f:SetSize(80, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Guild"
    
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    
    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 12 })
    end
    
    -- No default position - WidgetManager places in drawer
    f:SetMovable(true)
    f:EnableMouse(true)
    
    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Guild", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        if IsInGuild() then
            local guildName = GetGuildInfo("player")
            local online = GetGuildOnline()
            local total = GetNumGuildMembers()
            GameTooltip:AddDoubleLine("Guild:", guildName or "Unknown", 0.7, 0.7, 0.7, 0.4, 0.8, 0.4)
            GameTooltip:AddDoubleLine("Online:", tostring(online), 0.7, 0.7, 0.7, 0, 1, 0)
            GameTooltip:AddDoubleLine("Total:", tostring(total), 0.7, 0.7, 0.7, 1, 1, 1)
        else
            GameTooltip:AddLine("Not in a guild", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Click", "Open Guild", 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Click to open guild panel
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            ToggleGuildFrame()
        end
    end)
    
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("Guild") then
            return  -- Block drag if drawer isn't open
        end
        self.isDragging = true
        self:SetParent(UIParent)
        self:SetFrameStrata("TOOLTIP")
        self:StartMoving()
        if not widgetFrame.dragTicker then
            widgetFrame.dragTicker = C_Timer.NewTicker(0.05, function()
                local WM2 = addon.WidgetManager
                if WM2 then WM2:OnWidgetDragUpdate() end
            end)
        end
    end)
    
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false
        if widgetFrame.dragTicker then
            widgetFrame.dragTicker:Cancel()
            widgetFrame.dragTicker = nil
        end
        local WM = addon.WidgetManager
        if WM then WM:OnWidgetDragStop("Guild") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function GuildWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Guild", {
            name = "Guild",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateGuild() end,
        })
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:SetScript("OnEvent", UpdateGuild)
    
    -- Request guild roster on load
    C_GuildInfo.GuildRoster()
    
    UpdateGuild()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() GuildWidget:OnLoad() end)
end)
