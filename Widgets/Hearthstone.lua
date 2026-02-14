local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end
if not addon.BaseWidget then return end

local HearthWidget = addon.BaseWidget:New("Hearthstone")
addon.HearthWidget = HearthWidget

-- [ CONSTANTS ] -------------------------------------------------------------------

local HEARTHSTONE_ID = 6948
local FRAME_WIDTH = 110
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1
local SECONDS_PER_MINUTE = 60

local TELEPORT_ITEMS = {
    { id = 6948, name = "Hearthstone" },
    { id = 110560, name = "Garrison Hearth" },
    { id = 140192, name = "Dalaran Hearth" },
    { id = 180817, name = "Cypher Hearth" },
    { id = 190237, name = "Broker Hearth" },
    { id = 200630, name = "Ohn'ahran Hearth" },
    { id = 208704, name = "Deepdweller's Hearth" },
}

-- [ HELPERS ] ---------------------------------------------------------------------

function HearthWidget:GetHearthCooldown()
    local start, duration = C_Container.GetItemCooldown(HEARTHSTONE_ID)
    if start == 0 or duration == 0 then return 0 end
    local remaining = (start + duration) - GetTime()
    return math.max(0, remaining)
end

function HearthWidget:FormatCooldown(seconds)
    if seconds <= 0 then return "|cff00ff00Ready|r" end
    local mins = math.ceil(seconds / SECONDS_PER_MINUTE)
    return string.format("|cffff8000%dm|r", mins)
end

-- [ UPDATES ] ---------------------------------------------------------------------

function HearthWidget:Update()
    local bindLoc = GetBindLocation() or "Unknown"
    local cd = self:GetHearthCooldown()
    if cd > 0 then
        self:SetText(string.format("%s (%s)", bindLoc, self:FormatCooldown(cd)))
    else
        self:SetText(string.format("|cff00ff00%s|r", bindLoc))
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function HearthWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Hearthstone", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Bound to:", GetBindLocation() or "Unknown", 1, 1, 1, 0, 1, 0)
    local cd = self:GetHearthCooldown()
    GameTooltip:AddDoubleLine("Cooldown:", self:FormatCooldown(cd), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Teleport Items:", 0.7, 0.7, 0.7)
    for _, item in ipairs(TELEPORT_ITEMS) do
        local count = C_Item.GetItemCount(item.id)
        if count > 0 then
            local start, duration = C_Container.GetItemCooldown(item.id)
            local remaining = (start > 0 and duration > 0) and math.max(0, (start + duration) - GetTime()) or 0
            local cdStr = remaining > 0 and string.format("|cffff8000%s|r", self:FormatCooldown(remaining)) or "|cff00ff00Ready|r"
            GameTooltip:AddDoubleLine("  " .. item.name, cdStr, 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Use Hearthstone", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Teleport Menu", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function HearthWidget:GetMenuItems()
    local items = {}
    for _, item in ipairs(TELEPORT_ITEMS) do
        local count = C_Item.GetItemCount(item.id)
        if count > 0 then
            table.insert(items, {
                text = item.name,
                func = function()
                    if InCombatLockdown() then return end
                    self.secureBtn:SetAttribute("item", item.name)
                end,
            })
        end
    end
    return items
end

function HearthWidget:OnClick(button)
    if button == "RightButton" then self:ShowContextMenu() end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function HearthWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    local secBtn = CreateFrame("Button", "OrbitHearthSecure", self.frame, "SecureActionButtonTemplate")
    secBtn:SetAllPoints(self.frame)
    secBtn:SetAttribute("type", "item")
    secBtn:SetAttribute("item", "Hearthstone")
    secBtn:RegisterForClicks("LeftButtonUp")
    secBtn:SetScript("OnEnter", function() self:OnEnter() end)
    secBtn:SetScript("OnLeave", function() self:OnLeave() end)
    self.secureBtn = secBtn

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)
    self.leftClickHint = "Use Hearthstone"
    self.rightClickHint = "Teleport Menu"
    self:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:SetUpdateTier("NORMAL")
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() HearthWidget:OnLoad() end)
end)
