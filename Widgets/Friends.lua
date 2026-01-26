-- Friends.lua
-- Friends online widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local FriendsWidget = {}
addon.FriendsWidget = FriendsWidget

local widgetFrame = nil

local function GetFriendsOnline()
    local online = 0
    local numFriends = C_FriendList.GetNumFriends()
    for i = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            online = online + 1
        end
    end
    
    -- Also count BNet friends
    local numBNet = BNGetNumFriends()
    for i = 1, numBNet do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
            online = online + 1
        end
    end
    
    return online
end

local function UpdateFriends()
    if not widgetFrame then return end
    
    local online = GetFriendsOnline()
    local color = online > 0 and "|cff00ff00" or "|cff888888"
    widgetFrame.Text:SetText(string.format("%s%d|r Friends", color, online))
    
    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusFriendsWidget", UIParent)
    f:SetSize(80, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Friends"
    
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
        GameTooltip:AddLine("Friends", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        local numFriends = C_FriendList.GetNumFriends()
        local numBNet = BNGetNumFriends()
        local online = GetFriendsOnline()
        GameTooltip:AddDoubleLine("Online:", tostring(online), 0.7, 0.7, 0.7, 0, 1, 0)
        GameTooltip:AddDoubleLine("WoW Friends:", tostring(numFriends), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("Battle.net:", tostring(numBNet), 0.7, 0.7, 0.7, 0.4, 0.6, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Click", "Open Friends", 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Click to open friends panel
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            ToggleFriendsFrame()
        end
    end)
    
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("Friends") then
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
        if WM then WM:OnWidgetDragStop("Friends") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function FriendsWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Friends", {
            name = "Friends",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateFriends() end,
        })
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("FRIENDLIST_UPDATE")
    eventFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    eventFrame:SetScript("OnEvent", UpdateFriends)
    
    UpdateFriends()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() FriendsWidget:OnLoad() end)
end)
