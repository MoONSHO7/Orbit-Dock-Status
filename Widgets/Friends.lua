-- Friends.lua
-- Advanced Friends widget for StatusDock
-- Features: Battle.net & WoW Friends, Game grouping, App ID icons

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local FriendsWidget = addon.BaseWidget:New("Friends")
addon.FriendsWidget = FriendsWidget
FriendsWidget.category = "Social"

-- [ HELPERS ] -----------------------------------------------------------------

function FriendsWidget:GetFriendInfo()
    local bnetFriends = BNGetNumFriends()
    local wowFriends = C_FriendList.GetNumFriends()
    local onlineBNet = 0
    local onlineWoW = 0
    local friendList = {}

    -- BNet
    for i = 1, bnetFriends do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
            onlineBNet = onlineBNet + 1
            local ga = accountInfo.gameAccountInfo
            table.insert(friendList, {
                type = "BNET",
                name = accountInfo.accountName,
                client = ga.clientProgram,
                charName = ga.characterName,
                level = ga.characterLevel,
                zone = ga.areaName,
                status = ga.richPresence
            })
        end
    end
    
    -- WoW
    for i = 1, wowFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            onlineWoW = onlineWoW + 1
            table.insert(friendList, {
                type = "WOW",
                name = info.name,
                client = "WoW",
                charName = info.name,
                level = info.level,
                zone = info.area,
                status = info.status
            })
        end
    end
    
    table.sort(friendList, function(a, b)
        if a.client == "WoW" and b.client ~= "WoW" then return true end
        if a.client ~= "WoW" and b.client == "WoW" then return false end
        return a.name < b.name
    end)

    return onlineBNet, onlineWoW, friendList
end

-- [ UPDATES ] -----------------------------------------------------------------

function FriendsWidget:Update()
    local bnet, wow, _ = self:GetFriendInfo()
    local total = bnet + wow
    local color = total > 0 and "|cff00ff00" or "|cff888888"
    
    self:SetFormattedText("Friends:", string.format("%s%d|r", color, total))
end

-- [ INTERACTION ] -------------------------------------------------------------

function FriendsWidget:GenerateMenu(owner, rootDescription)
    rootDescription:CreateButton("Open Friends List", function() ToggleFriendsFrame(1) end)
end

function FriendsWidget:ShowTooltip()
    local bnet, wow, friends = self:GetFriendInfo()
    local total = bnet + wow

    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Friends List", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Total Online:", total, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")

    if total == 0 then
        GameTooltip:AddLine("No friends online.", 0.5, 0.5, 0.5)
    else
        local currentClient = nil
        local maxDisplay = 20
        for i, f in ipairs(friends) do
            if i > maxDisplay then
                GameTooltip:AddLine(string.format("... and %d more", total - maxDisplay), 0.5, 0.5, 0.5)
                break
            end

            if f.client ~= currentClient then
                currentClient = f.client
                local header = f.client
                if header == "WoW" then header = "World of Warcraft" end
                if header == "App" then header = "Battle.net App" end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(header, 0.4, 0.8, 1)
            end

            local left = f.name
            if f.charName and f.charName ~= "" then left = string.format("%s (%s)", f.name, f.charName) end

            local right = f.zone or f.status or ""
            if f.level and f.level ~= "" and f.level ~= 0 then
                right = string.format("Lvl %s %s", f.level, right)
            end

            GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Friends", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function FriendsWidget:OnClick(button)
    ToggleFriendsFrame(1)
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function FriendsWidget:OnLoad()
    self:CreateFrame(80, 20)
    
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    
    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    self:RegisterEvent("FRIENDLIST_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() FriendsWidget:OnLoad() end)
end)
