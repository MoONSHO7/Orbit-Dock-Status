-- Collections.lua
-- Collections summary widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local CollWidget = addon.BaseWidget:New("Collections")
addon.CollWidget = CollWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ HELPERS ] ---------------------------------------------------------------------

function CollWidget:GetCollectionCounts()
    local mounts = C_MountJournal.GetNumMounts()
    local mountsCollected = 0
    for i = 1, mounts do
        local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(C_MountJournal.GetDisplayedMountID(i) or 0)
        if isCollected then mountsCollected = mountsCollected + 1 end
    end
    local numPets = C_PetJournal.GetNumPets()
    local _, petsCollected = C_PetJournal.GetNumPets()
    local toys = C_ToyBox.GetNumTotalDisplayedToys()
    local toysCollected = C_ToyBox.GetNumLearnedDisplayedToys()
    return {
        mounts = { collected = mountsCollected, total = mounts },
        pets = { collected = petsCollected or 0, total = numPets or 0 },
        toys = { collected = toysCollected or 0, total = toys or 0 },
    }
end

-- [ UPDATES ] ---------------------------------------------------------------------

function CollWidget:Update()
    local c = self:GetCollectionCounts()
    self:SetText(string.format("|cffffd700%d|r|cff888888M|r |cff00ccff%d|r|cff888888P|r |cff00ff00%d|r|cff888888T|r", c.mounts.collected, c.pets.collected, c.toys.collected))
end

-- [ INTERACTION ] -----------------------------------------------------------------

function CollWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Collections", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local c = self:GetCollectionCounts()
    GameTooltip:AddDoubleLine("Mounts:", string.format("%d / %d", c.mounts.collected, c.mounts.total), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Pets:", string.format("%d / %d", c.pets.collected, c.pets.total), 1, 1, 1, 0, 0.8, 1)
    GameTooltip:AddDoubleLine("Toys:", string.format("%d / %d", c.toys.collected, c.toys.total), 1, 1, 1, 0, 1, 0)
    local numHeirlooms = C_Heirloom.GetNumKnownHeirlooms and C_Heirloom.GetNumKnownHeirlooms() or 0
    if numHeirlooms > 0 then
        GameTooltip:AddDoubleLine("Heirlooms:", tostring(numHeirlooms), 1, 1, 1, 0.8, 0.6, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Open Collections", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function CollWidget:OnClick(button) ToggleCollectionsJournal() end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function CollWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Open Collections"
    self:RegisterEvent("NEW_MOUNT_ADDED")
    self:RegisterEvent("NEW_TOY_ADDED")
    self:RegisterEvent("NEW_PET_ADDED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() CollWidget:OnLoad() end)
end)
