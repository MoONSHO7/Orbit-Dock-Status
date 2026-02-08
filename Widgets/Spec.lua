-- Spec.lua
-- Advanced Specialization widget for StatusDock
-- Features: Quick spec switching, Loot spec management

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local SpecWidget = addon.BaseWidget:New("Spec")
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
            return "Current Spec (" .. (name or "Unknown") .. ")", nil
        end
        return "Current Spec", nil
    end
    
    local _, name, _, icon = GetSpecializationInfoByID(lootSpecID)
    return name, icon
end

-- [ UPDATE ] ------------------------------------------------------------------

function SpecWidget:Update()
    local name, icon, role = self:GetSpecInfo()
    if not name then
        self:SetText("No Spec")
        return
    end

    -- Icon + Name
    self:SetText(string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t %s", icon, name))
end

-- [ INTERACTION ] -------------------------------------------------------------

function SpecWidget:OnClick(button)
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            -- Loot Spec Menu
            self:OpenLootSpecMenu()
        else
            -- Toggle Talent Frame
            if PlayerSpellsFrame then
                PlayerSpellsFrame:SetTab(1)
                PlayerSpellsFrame:SetShown(not PlayerSpellsFrame:IsShown())
            elseif ClassTalentFrame then
                ToggleFrame(ClassTalentFrame)
            end
        end
    elseif button == "RightButton" then
        -- Spec Switch Menu
        self:OpenSpecMenu()
    end
end

function SpecWidget:OpenSpecMenu()
    if not addon.Menu then return end

    local items = {}
    local numSpecs = GetNumSpecializations()
    local currentSpec = GetSpecialization()

    for i = 1, numSpecs do
        local id, name, _, icon = GetSpecializationInfo(i)
        table.insert(items, {
            text = string.format("|T%s:14|t %s", icon, name),
            func = function() SetSpecialization(i) end,
            checked = (i == currentSpec)
        })
    end
    
    addon.Menu:Open(self.frame, items)
end

function SpecWidget:OpenLootSpecMenu()
    if not addon.Menu then return end

    local items = {}
    local currentLootSpec = GetLootSpecialization()
    local numSpecs = GetNumSpecializations()

    -- "Current Spec" Option
    table.insert(items, {
        text = "Current Specialization",
        func = function() SetLootSpecialization(0) end,
        checked = (currentLootSpec == 0)
    })

    for i = 1, numSpecs do
        local id, name, _, icon = GetSpecializationInfo(i)
        table.insert(items, {
            text = string.format("|T%s:14|t %s", icon, name),
            func = function() SetLootSpecialization(id) end,
            checked = (currentLootSpec == id)
        })
    end
    
    addon.Menu:Open(self.frame, items)
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
    GameTooltip:AddDoubleLine("Right Click", "Switch Spec", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Shift+Left Click", "Loot Spec", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function SpecWidget:OnLoad()
    self:CreateFrame(100, 20)

    -- Setup handlers
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    -- Register events
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Register with manager
    self:Register()
    
    -- Initial update
    self:Update()
end

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() SpecWidget:OnLoad() end)
end)
