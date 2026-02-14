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

-- [ CONSTANTS ] -------------------------------------------------------------------

local MAX_TOOLTIP_DISPLAY = 20
local FRAME_WIDTH = 80
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

local COLORS = {
    BNET = "|cff82c5ff", -- Battle.net Blue
    WOW = "|cffffd200", -- WoW Gold
    D3 = "|cffc41f3b", -- Diablo Red
    SC2 = "|cff4286f4", -- Starcraft Blue
    OW = "|cffff9c00", -- Overwatch Orange
    Hearthstone = "|cff5cacee", -- Hearthstone Blue
    HOTs = "|cffb400ff", -- Heroes Purple
    App = "|cff82c5ff", -- Battle.net App
    Mobile = "|cff82c5ff", -- Mobile App
}

local ICONS = {
    -- The rogue identifies allies by their poorly drawn icons
    WoW = "Interface\\Icons\\Inv_Misc_QuestionMark",
    D3 = "Interface\\Icons\\Inv_Misc_QuestionMark",
    SC2 = "Interface\\Icons\\Inv_Misc_QuestionMark",
    OW = "Interface\\Icons\\Inv_Misc_QuestionMark",
    Hearthstone = "Interface\\Icons\\Inv_Misc_QuestionMark",
    HOTs = "Interface\\Icons\\Inv_Misc_QuestionMark",
    App = "Interface\\Icons\\Inv_Misc_QuestionMark",
    Mobile = "Interface\\Icons\\Inv_Misc_QuestionMark",
}

-- [ HELPER FUNCTIONS ] ------------------------------------------------------------

function FriendsWidget:GetFriendInfo()
    local bnetFriends = BNGetNumFriends()
    local wowFriends = C_FriendList.GetNumFriends()
    local onlineBNet = 0
    local onlineWoW = 0

    local friendList = {}

    -- Rolling initiative on the Battle.net party list
    for i = 1, bnetFriends do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
            onlineBNet = onlineBNet + 1
            local gameAccount = accountInfo.gameAccountInfo
            local client = gameAccount.clientProgram
            local name = accountInfo.accountName
            local note = accountInfo.note
            local charName = gameAccount.characterName
            local realmName = gameAccount.realmName
            local factionName = gameAccount.factionName
            local gameText = gameAccount.richPresence or ""
            local class = gameAccount.className or ""
            local level = gameAccount.characterLevel or ""
            local zone = gameAccount.areaName or ""

            table.insert(friendList, {
                type = "BNET",
                name = name,
                note = note,
                client = client,
                charName = charName,
                realmName = realmName,
                faction = factionName,
                status = gameText,
                class = class,
                level = level,
                zone = zone,
            })
        end
    end
    
    -- The local tavern regulars sign the guest book
    for i = 1, wowFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            onlineWoW = onlineWoW + 1
            table.insert(friendList, {
                type = "WOW",
                name = info.name,
                note = info.notes,
                client = "WoW",
                charName = info.name,
                class = info.className,
                level = info.level,
                zone = info.area,
                status = info.status,
            })
        end
    end
    
    -- Charisma check: WoW players sit at the head of the table
    table.sort(friendList, function(a, b)
        if a.client == "WoW" and b.client ~= "WoW" then return true end
        if a.client ~= "WoW" and b.client == "WoW" then return false end
        return a.name < b.name
    end)

    return onlineBNet, onlineWoW, friendList
end

-- [ UPDATES ] ---------------------------------------------------------------------

function FriendsWidget:Update()
    local bnet, wow, _ = self:GetFriendInfo()
    local total = bnet + wow
    local color = total > 0 and "|cff00ff00" or "|cff888888"
    
    -- The herald announces the party size
    self:SetText(string.format("%s%d|r Friends", color, total))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function FriendsWidget:ShowTooltip()
    local bnet, wow, friends = self:GetFriendInfo()
    local total = bnet + wow

    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine("Friends List", string.format("%d Online", total), 0.4, 0.8, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")

    if total == 0 then
        GameTooltip:AddLine("No friends online.", 0.5, 0.5, 0.5)
    else
        local currentClient = nil

        -- The scroll of friends can only display so many names
        local maxDisplay = MAX_TOOLTIP_DISPLAY
        for i, f in ipairs(friends) do
            if i > maxDisplay then
                GameTooltip:AddLine(string.format("... and %d more", total - maxDisplay), 0.5, 0.5, 0.5)
                break
            end

            -- The guild registrar sorts adventurers by realm
            if f.client ~= currentClient then
                currentClient = f.client
                local header = f.client
                if header == "WoW" then header = "World of Warcraft" end
                if header == "App" then header = "Battle.net App" end
                if header == "BSAp" then header = "Battle.net Mobile" end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(COLORS.BNET .. header .. "|r")
            end

            -- The bard composes each friend's title card
            local leftText = f.name
            if f.charName and f.charName ~= "" then
                leftText = string.format("%s (%s)", f.name, f.charName)
            end

            local rightText = ""
            if f.zone and f.zone ~= "" then
                rightText = f.zone
            elseif f.status and f.status ~= "" then
                rightText = f.status
            end

            if f.level and f.level ~= "" and f.level ~= 0 then
                rightText = string.format("Lvl %s %s", f.level, rightText)
            end

            GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Friends", 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:Show()
end

function FriendsWidget:OnClick(button)
    ToggleFriendsFrame(1)
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function FriendsWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    
    -- The quest giver hands out event subscriptions
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    


    self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    self:RegisterEvent("BN_INFO_CHANGED")
    self:RegisterEvent("FRIENDLIST_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    

    self:SetCategory("SOCIAL")

    self:Register()
    

    self:Update()
end


local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() FriendsWidget:OnLoad() end)
end)
