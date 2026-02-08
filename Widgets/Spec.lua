-- Spec.lua
-- Advanced Specialization widget for StatusDock
-- Features: Quick spec switching, Loot spec management

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local SpecWidget = addon.BaseWidget:New("Spec"); addon.SpecWidget.category = "Character"
addon.SpecWidget = SpecWidget

-- [ HELPER ] ------------------------------------------------------------------

function SpecWidget:GetSpecInfo()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, nil, nil end
    local id, name, description, icon, role, class = GetSpecializationInfo(specIndex)
    return name, icon, role
end

function SpecWidget:GetLootSpecInfo()
    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        local specIndex = GetSpecialization()
        if specIndex then
            local _, name = GetSpecializationInfo(specIndex)
            return "Current (" .. (name or "?") .. ")", nil
        end
        return "Current", nil
    end
    local _, name, _, icon = GetSpecializationInfoByID(lootSpecID)
    return name, icon
end

-- [ UPDATE ] ------------------------------------------------------------------

function SpecWidget:Update()
    local name, icon, role = self:GetSpecInfo()
    local lootName, lootIcon = self:GetLootSpecInfo()

    local text = "No Spec"
    if name then
        text = string.format("|T%s:14|t %s", icon, name)
        if lootIcon then
            text = text .. string.format(" |cff888888(|T%s:12|t)|r", lootIcon)
        end
    end

    self:SetFormattedText(nil, text)
end

-- [ INTERACTION ] -------------------------------------------------------------

function SpecWidget:GenerateMenu(owner, rootDescription)
    -- Spec Switch
    rootDescription:CreateTitle("Specialization")
    local numSpecs = GetNumSpecializations()
    for i = 1, numSpecs do
        local id, name, _, icon = GetSpecializationInfo(i)
        rootDescription:CreateRadio(string.format("|T%s:14|t %s", icon, name), function() return GetSpecialization() == i end, function()
            SetSpecialization(i)
        end)
    end
    
    -- Loot Spec
    rootDescription:CreateTitle("Loot Specialization")
    rootDescription:CreateRadio("Current Specialization", function() return GetLootSpecialization() == 0 end, function()
        SetLootSpecialization(0)
    end)

    for i = 1, numSpecs do
        local id, name, _, icon = GetSpecializationInfo(i)
        rootDescription:CreateRadio(string.format("|T%s:14|t %s", icon, name), function() return GetLootSpecialization() == id end, function()
            SetLootSpecialization(id)
        end)
    end
end

function SpecWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Specialization", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local specName, specIcon, role = self:GetSpecInfo()
    local lootName, lootIcon = self:GetLootSpecInfo()

    GameTooltip:AddDoubleLine("Current Spec:", specName or "None", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Role:", role or "None", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Loot Spec:", lootName, 1, 1, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Talents", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Menu", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function SpecWidget:OnClick(button)
    if button == "LeftButton" then
        if PlayerSpellsFrame then
            if not PlayerSpellsFrame:IsShown() then ShowUIPanel(PlayerSpellsFrame) else HideUIPanel(PlayerSpellsFrame) end
        else
            ToggleTalentFrame()
        end
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function SpecWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterMenu(function(owner, root) self:GenerateMenu(owner, root) end)

    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() SpecWidget:OnLoad() end)
end)
