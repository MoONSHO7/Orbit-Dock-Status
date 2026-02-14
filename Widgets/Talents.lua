-- Talents.lua
-- Active talent loadout widget for StatusDock
-- Features: loadout name display, right-click to switch loadouts

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local TalentsWidget = addon.BaseWidget:New("Talents")
addon.TalentsWidget = TalentsWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ UPDATES ] ---------------------------------------------------------------------

function TalentsWidget:Update()
    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(GetSpecializationInfo(GetSpecialization()))
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    if not activeConfigID then self:SetText("|cff888888No Loadout|r"); return end
    local info = C_Traits.GetConfigInfo(activeConfigID)
    local name = info and info.name or "Loadout"
    self:SetText("|cff00ccff" .. name .. "|r")
end

-- [ INTERACTION ] -----------------------------------------------------------------

function TalentsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Talent Loadout", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local specIndex = GetSpecialization()
    if not specIndex then GameTooltip:AddLine("No specialization", 0.5, 0.5, 0.5); GameTooltip:Show(); return end

    local specID, specName = GetSpecializationInfo(specIndex)
    GameTooltip:AddDoubleLine("Spec:", specName or "Unknown", 1, 1, 1, 1, 1, 1)

    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)

    if configIDs then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Loadouts:", 0.7, 0.7, 0.7)
        for _, configID in ipairs(configIDs) do
            local info = C_Traits.GetConfigInfo(configID)
            if info then
                local active = (configID == activeConfigID)
                local prefix = active and "|cff00ff00> " or "  "
                local suffix = active and " (Active)|r" or ""
                GameTooltip:AddLine(prefix .. info.name .. suffix, 1, 1, 1)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Talents", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Switch Loadout", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function TalentsWidget:GetMenuItems()
    local items = {}
    local specIndex = GetSpecialization()
    if not specIndex then return items end
    local specID = GetSpecializationInfo(specIndex)
    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    if configIDs then
        for _, configID in ipairs(configIDs) do
            local info = C_Traits.GetConfigInfo(configID)
            if info then
                local isActive = (configID == activeConfigID)
                table.insert(items, {
                    text = info.name .. (isActive and " |cff00ff00(Active)|r" or ""),
                    func = function()
                        if not isActive and not InCombatLockdown() then
                            C_ClassTalents.LoadConfig(configID, true)
                        end
                    end,
                })
            end
        end
    end
    return items
end

function TalentsWidget:OnClick(button)
    if button == "RightButton" then self:ShowContextMenu()
    else TogglePlayerSpellsFrame() end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function TalentsWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Talents"
    self.rightClickHint = "Switch Loadout"
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() TalentsWidget:OnLoad() end)
end)
