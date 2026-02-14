-- PvPProgress.lua
-- PvP progress widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local PvPWidget = addon.BaseWidget:New("PvPProgress")
addon.PvPWidget = PvPWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local BRACKET_2V2 = 1
local BRACKET_3V3 = 2
local BRACKET_RBG = 4

-- [ STATE ] -----------------------------------------------------------------------

PvPWidget.cachedHonor = 0
PvPWidget.useCachedData = false

-- [ UPDATES ] ---------------------------------------------------------------------

function PvPWidget:Update()
    local honor = self.useCachedData and self.cachedHonor or UnitHonor("player")
    if not self.useCachedData then self.cachedHonor = honor end
    local honorLevel = UnitHonorLevel("player")
    self:SetText(string.format("|cffcc9900H%d|r", honorLevel))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function PvPWidget:GetRatingStr(bracket)
    local rating = GetPersonalRatedInfo(bracket)
    return rating and rating > 0 and tostring(rating) or "|cff888888—|r"
end

function PvPWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("PvP Progress", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Honor Level:", tostring(UnitHonorLevel("player")), 1, 1, 1, 1, 0.82, 0)
    local honor = self.useCachedData and self.cachedHonor or UnitHonor("player")
    local honorMax = UnitHonorMax("player")
    if honorMax > 0 then
        GameTooltip:AddDoubleLine("Honor:", string.format("%d / %d", honor, honorMax), 1, 1, 1, 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Arena Ratings:", 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("  2v2:", self:GetRatingStr(BRACKET_2V2), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("  3v3:", self:GetRatingStr(BRACKET_3V3), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("  RBG:", self:GetRatingStr(BRACKET_RBG), 1, 1, 1, 1, 1, 1)

    local conquestInfo = C_CurrencyInfo.GetCurrencyInfo(1602)
    if conquestInfo then
        GameTooltip:AddLine(" ")
        local capStr = conquestInfo.maxQuantity > 0 and string.format("%d / %d", conquestInfo.quantity, conquestInfo.maxQuantity) or tostring(conquestInfo.quantity)
        GameTooltip:AddDoubleLine("Conquest:", capStr, 1, 1, 1, 0.4, 0.8, 1)
    end

    if self.useCachedData then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Using cached data (in combat)|r")
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open PvP Panel", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function PvPWidget:OnClick(button) PVEFrame_ToggleFrame("PVPUIFrame") end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function PvPWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open PvP Panel"
    self:RegisterEvent("HONOR_XP_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self.useCachedData = true end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self.useCachedData = false
        self:Update()
    end)
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() PvPWidget:OnLoad() end)
end)
