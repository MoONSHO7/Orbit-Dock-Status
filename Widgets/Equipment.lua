-- Equipment.lua
-- Advanced Equipment Set Manager for StatusDock
-- Features: Quick set switching, iLvl display

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local EquipmentWidget = addon.BaseWidget:New("Equipment")
addon.EquipmentWidget = EquipmentWidget

-- [ HELPER ] ------------------------------------------------------------------

function EquipmentWidget:GetCurrentSet()
    local setID = C_EquipmentSet.GetEquipmentSetAssignedToPlayer()
    if setID then
        local name, icon, setID, isEquipped, numItems, numEquipped, numInInventory, numLost, numIgnored = C_EquipmentSet.GetEquipmentSetInfo(setID)
        return name, icon, numEquipped, numItems
    end
    return "No Set", nil, 0, 0
end

-- [ UPDATE ] ------------------------------------------------------------------

function EquipmentWidget:Update()
    local name, icon, equipped, total = self:GetCurrentSet()
    if icon then
        self:SetText(string.format("|T%s:14|t %s", icon, name))
    else
        self:SetText(name)
    end
end

-- [ INTERACTION ] -------------------------------------------------------------

function EquipmentWidget:OpenMenu()
    if not addon.Menu then return end

    local items = {}
    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    local currentSetID = C_EquipmentSet.GetEquipmentSetAssignedToPlayer()

    for _, id in ipairs(setIDs) do
        local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
        table.insert(items, {
            text = string.format("|T%s:14|t %s", icon, name),
            checked = (id == currentSetID),
            func = function()
                if not InCombatLockdown() then
                    C_EquipmentSet.UseEquipmentSet(id)
                else
                    print("|cffff0000Cannot change equipment in combat|r")
                end
            end
        })
    end

    if #items == 0 then
        table.insert(items, { text = "No Equipment Sets Found", func = nil })
    end

    addon.Menu:Open(self.frame, items)
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
    GameTooltip:AddDoubleLine("Left Click", "Switch Set", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Shift+Click", "Character Info", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function EquipmentWidget:OnClick(button)
    if IsShiftKeyDown() then
        ToggleCharacter("PaperDollFrame")
    else
        self:OpenMenu()
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function EquipmentWidget:OnLoad()
    self:CreateFrame(120, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

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
