-- Equipment.lua
-- Advanced Equipment Set Manager for StatusDock
-- Features: Quick set switching, iLvl display

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local EquipmentWidget = addon.BaseWidget:New("Equipment"); addon.EquipmentWidget.category = "Character"
addon.EquipmentWidget = EquipmentWidget

-- [ HELPER ] ------------------------------------------------------------------

function EquipmentWidget:GetCurrentSet()
    local setID = C_EquipmentSet.GetEquipmentSetAssignedToPlayer()
    if setID then
        local name, icon, setID, isEquipped, numItems, numEquipped = C_EquipmentSet.GetEquipmentSetInfo(setID)
        return name, icon, numEquipped, numItems, setID
    end
    return "No Set", nil, 0, 0, nil
end

-- [ UPDATE ] ------------------------------------------------------------------

function EquipmentWidget:Update()
    local name, icon, equipped, total = self:GetCurrentSet()
    local text = name
    if icon then text = string.format("|T%s:14|t %s", icon, name) end

    self:SetFormattedText(nil, text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function EquipmentWidget:GenerateMenu(owner, rootDescription)
    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    local currentSetID = C_EquipmentSet.GetEquipmentSetAssignedToPlayer()

    if #setIDs == 0 then
        rootDescription:CreateTitle("No Equipment Sets")
    else
        for _, id in ipairs(setIDs) do
            local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
            rootDescription:CreateRadio(string.format("|T%s:14|t %s", icon, name), function() return id == currentSetID end, function()
                if not InCombatLockdown() then C_EquipmentSet.UseEquipmentSet(id) end
            end)
        end
    end

    rootDescription:CreateButton("Open Manager", function() ToggleCharacter("PaperDollFrame") end)
end

function EquipmentWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Equipment Manager", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local name, icon, equipped, total = self:GetCurrentSet()
    GameTooltip:AddDoubleLine("Current Set:", name, 1, 1, 1, 1, 1, 1)
    if total > 0 then
        GameTooltip:AddDoubleLine("Items Equipped:", string.format("%d/%d", equipped, total), 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Manager", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Switch Set", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function EquipmentWidget:OnClick(button)
    ToggleCharacter("PaperDollFrame")
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function EquipmentWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() EquipmentWidget:OnLoad() end)
end)
