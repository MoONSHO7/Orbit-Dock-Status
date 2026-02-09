-- Mounts.lua
-- Advanced Mount widget for StatusDock
-- Features: Collection stats, Mount of the Day (Smart Summon)

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local MountsWidget = addon.BaseWidget:New("Mounts"); addon.MountsWidget.category = "World"
addon.MountsWidget = MountsWidget

-- [ HELPER FUNCTIONS ] --------------------------------------------------------

function MountsWidget:GetCollectionStats()
    local numMounts = C_MountJournal.GetNumMounts()
    local owned = 0
    local usable = 0

    for i = 1, numMounts do
        local name, spellID, icon, isActive, isUsable, source, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i)
        if isCollected and not hideOnChar then
            owned = owned + 1
            if isUsable then usable = usable + 1 end
        end
    end

    return owned, numMounts
end

-- [ UPDATE ] ------------------------------------------------------------------

function MountsWidget:Update()
    local owned, total = self:GetCollectionStats()
    -- "Mounts: 450"
    self:SetText(string.format("Mounts: %d", owned))
end

-- [ SMART SUMMON ] ------------------------------------------------------------

function MountsWidget:SmartSummon()
    if InCombatLockdown() then return end

    -- Logic:
    -- If Swimming -> Aquatic Mount
    -- If Flyable -> Flying Mount (Dragonriding if available)
    -- Else -> Ground Mount

    -- Simplified: Use random favorite
    C_MountJournal.SummonByID(0)
end

-- [ INTERACTION ] -------------------------------------------------------------

function MountsWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Mount Collection", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local owned, total = self:GetCollectionStats()
    GameTooltip:AddDoubleLine("Owned:", string.format("%d", owned), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Total Available:", string.format("%d", total), 1, 1, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Mount Journal", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Random Favorite", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function MountsWidget:OnClick(button)
    if button == "RightButton" then
        self:SmartSummon()
    else
        ToggleCollectionsJournal(1)
    end
end

-- [ LIFECYCLE ] ---------------------------------------------------------------

function MountsWidget:OnLoad()
    self:CreateFrame(100, 20)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:RegisterEvent("NEW_MOUNT_ADDED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() MountsWidget:OnLoad() end)
end)
