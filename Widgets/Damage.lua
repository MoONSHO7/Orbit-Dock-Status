-- Damage.lua
-- Damage Meter widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local DamageWidget = {}
addon.DamageWidget = DamageWidget

local widgetFrame = nil
local totalDamage = 0
local combatStartTime = nil
local inCombat = false
local displayMode = "DPS" -- or "TOTAL"

-- Format helper
local function FormatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fk", n / 1000)
    else
        return string.format("%d", n)
    end
end

local function UpdateDisplay()
    if not widgetFrame then return end

    local text = ""
    if displayMode == "DPS" then
        local dps = 0
        if combatStartTime then
            local duration = GetTime() - combatStartTime
            if duration > 0 then
                dps = totalDamage / duration
            end
        end
        text = FormatNumber(dps) .. " DPS"
    else
        text = FormatNumber(totalDamage)
    end

    widgetFrame.Text:SetText(text)

    -- Check if docked
    local isDocked = false
    if addon.WidgetManager then
        local widget = addon.WidgetManager:GetWidget("Damage")
        if widget then isDocked = widget.isDocked end
    end

    if not isDocked then
        -- Auto-resize to fit text
        local width = widgetFrame.Text:GetStringWidth()
        widgetFrame:SetSize(width + 10, 20)
    end
end

local function OnCombatLogEvent()
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if sourceGUID == UnitGUID("player") then
        local amount = 0

        if subevent == "SWING_DAMAGE" then
            amount = select(12, CombatLogGetCurrentEventInfo())
        elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
            amount = select(15, CombatLogGetCurrentEventInfo())
        elseif subevent == "SPELL_PERIODIC_DAMAGE" then
            amount = select(15, CombatLogGetCurrentEventInfo())
        end

        if amount and amount > 0 then
            totalDamage = totalDamage + amount
            UpdateDisplay()
        end
    end
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusDamageWidget", UIParent)
    f:SetSize(100, 20)
    f:SetClampedToScreen(true)
    f.systemIndex = "StatusDock_Damage"
    f.editModeName = "Damage Meter"

    -- Text display
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    f.Text:SetText("0 DPS")

    -- Apply global font
    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        if Orbit.Skin and Orbit.Skin.SkinText then
             Orbit.Skin:SkinText(f.Text, {
                font = Orbit.db.GlobalSettings.Font,
                textSize = 12,
            })
        end
    end

    -- Orbit Anchoring options
    f.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
    }

    -- Make draggable in Edit Mode
    f:SetMovable(true)
    f:EnableMouse(true)

    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Damage Meter", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total Damage:", FormatNumber(totalDamage), 1, 1, 1, 1, 1, 1)

        local dps = 0
        if combatStartTime then
            local duration = GetTime() - combatStartTime
            if duration > 0 then dps = totalDamage / duration end
        end
        GameTooltip:AddDoubleLine("DPS:", FormatNumber(dps), 1, 1, 1, 1, 1, 1)

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Click:", "Toggle Mode", 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Toggle Mode on Click
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            if displayMode == "DPS" then
                displayMode = "TOTAL"
            else
                displayMode = "DPS"
            end
            UpdateDisplay()
            -- Refresh tooltip if visible
            if GameTooltip:IsOwned(self) then
                self:GetScript("OnEnter")(self)
            end
        end
    end)

    -- Dragging Logic
    f:SetScript("OnDragStart", function(self)
        local WidgetManager = addon.WidgetManager
        if not WidgetManager or not WidgetManager:OnWidgetDragStart("Damage") then
            return
        end
        self.isDragging = true
        self:SetParent(UIParent)
        self:SetFrameStrata("TOOLTIP")
        self:StartMoving()

        if not widgetFrame.dragTicker then
            widgetFrame.dragTicker = C_Timer.NewTicker(0.05, function()
                local WM = addon.WidgetManager
                if WM then WM:OnWidgetDragUpdate() end
            end)
        end
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false

        if widgetFrame.dragTicker then
            widgetFrame.dragTicker:Cancel()
            widgetFrame.dragTicker = nil
        end

        local WidgetManager = addon.WidgetManager
        if WidgetManager then
            WidgetManager:OnWidgetDragStop("Damage")
        end
    end)

    f:RegisterForDrag("LeftButton")

    return f
end

function DamageWidget:PLAYER_REGEN_DISABLED()
    combatStartTime = GetTime()
    totalDamage = 0
    inCombat = true
    UpdateDisplay()
end

function DamageWidget:PLAYER_REGEN_ENABLED()
    inCombat = false
    -- Keep last values displayed until next combat
end

function DamageWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame

    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame

    -- Register with WidgetManager
    local WidgetManager = addon.WidgetManager
    if WidgetManager then
        WidgetManager:Register("Damage", {
            name = "Damage",
            frame = widgetFrame,
            onDock = function(f, zone)
                f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2)
            end,
            onUndock = function(f)
                UpdateDisplay()
            end,
            onEnable = function(f)
                eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
                eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
                eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                UpdateDisplay()
            end,
            onDisable = function(f)
                eventFrame:UnregisterAllEvents()
            end,
        })
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        elseif event == "PLAYER_REGEN_DISABLED" then
            DamageWidget:PLAYER_REGEN_DISABLED()
        elseif event == "PLAYER_REGEN_ENABLED" then
            DamageWidget:PLAYER_REGEN_ENABLED()
        end
    end)

    -- Start listening immediately (or rely on WidgetManager enable)
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        DamageWidget:OnLoad()
    end)
end)
