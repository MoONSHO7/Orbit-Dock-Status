-- Mail.lua
-- Mailbox status widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local MailWidget = addon.BaseWidget:New("Mail")
addon.MailWidget = MailWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 80
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local EXPIRY_WARNING_DAYS = 3
local SECONDS_PER_DAY = 86400

-- [ UPDATES ] ---------------------------------------------------------------------

function MailWidget:Update()
    local hasNewMail = HasNewMail()
    local _, totalCount = GetInboxNumItems()
    if hasNewMail then
        self:SetText("|cff00ff00New Mail!|r")
        self:Flash()
    elseif totalCount and totalCount > 0 then
        self:SetText(string.format("|cffffd700%d|r Mail", totalCount))
        self:StopFlash()
    else
        self:SetText("|cff888888No Mail|r")
        self:StopFlash()
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function MailWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Mail", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local numItems, totalCount = GetInboxNumItems()
    GameTooltip:AddDoubleLine("Messages:", tostring(totalCount or 0), 1, 1, 1, 1, 1, 1)
    if numItems > 0 then
        local expiringSoon = 0
        for i = 1, numItems do
            local _, _, _, _, _, _, daysLeft = GetInboxHeaderInfo(i)
            if daysLeft and daysLeft <= EXPIRY_WARNING_DAYS then expiringSoon = expiringSoon + 1 end
        end
        if expiringSoon > 0 then
            GameTooltip:AddDoubleLine("Expiring Soon:", string.format("|cffff0000%d|r", expiringSoon), 1, 1, 1, 1, 1, 1)
        end
    end
    if HasNewMail() then GameTooltip:AddLine("|cff00ff00You have new mail!|r") end
    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function MailWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:RegisterEvent("UPDATE_PENDING_MAIL")
    self:RegisterEvent("MAIL_INBOX_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("UTILITY")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() MailWidget:OnLoad() end)
end)
