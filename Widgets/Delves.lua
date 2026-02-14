-- Delves.lua
-- Delve progress widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local DelvesWidget = addon.BaseWidget:New("Delves")
addon.DelvesWidget = DelvesWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local BRANN_COMPANION_ID = 2601

-- [ UPDATES ] ---------------------------------------------------------------------

function DelvesWidget:Update()
    local brannLevel = self:GetBrannLevel()
    if brannLevel > 0 then
        self:SetText(string.format("|cffcc9900Brann %d|r", brannLevel))
    else
        self:SetText("|cff888888Delves|r")
    end
end

function DelvesWidget:GetBrannLevel()
    if not C_DelvesUI then return 0 end
    local level = C_DelvesUI.GetCurrentDelvesSeasonNumber and C_DelvesUI.GetCurrentDelvesSeasonNumber() or 0
    return level
end

-- [ INTERACTION ] -----------------------------------------------------------------

function DelvesWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Delves", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local brannLevel = self:GetBrannLevel()
    GameTooltip:AddDoubleLine("Brann Level:", brannLevel > 0 and tostring(brannLevel) or "Unknown", 1, 1, 1, 1, 0.82, 0)

    if C_WeeklyRewards then
        local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
        if activities and #activities > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Vault Progress:", 0.7, 0.7, 0.7)
            for _, activity in ipairs(activities) do
                local progress = math.min(activity.progress, activity.threshold)
                local done = activity.progress >= activity.threshold
                local r, g, b = done and 0 or 1, done and 1 or 0.8, done and 0 or 0
                GameTooltip:AddDoubleLine(
                    string.format("  %d/%d", progress, activity.threshold),
                    done and "|cff00ff00\226\156\147|r" or "",
                    r, g, b, 1, 1, 1
                )
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Group Finder", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function DelvesWidget:OnClick(button) PVEFrame_ToggleFrame() end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function DelvesWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Group Finder"
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() DelvesWidget:OnLoad() end)
end)
