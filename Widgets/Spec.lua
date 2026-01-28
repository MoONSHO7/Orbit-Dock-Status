-- Spec.lua
-- Specialization display widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local SpecWidget = {}
addon.SpecWidget = SpecWidget

local widgetFrame = nil

local function UpdateSpec()
    if not widgetFrame then return end
    
    local specIndex = GetSpecialization()
    if specIndex then
        local _, name, _, icon = GetSpecializationInfo(specIndex)
        if name then
            widgetFrame.Text:SetText(name)
            widgetFrame.Icon:SetTexture(icon)
            widgetFrame.Icon:Show()
        end
    else
        widgetFrame.Text:SetText("No Spec")
        widgetFrame.Icon:Hide()
    end
    
    -- Calculate total content width and center it
    local textWidth = widgetFrame.Text:GetStringWidth()
    local iconWidth = widgetFrame.Icon:IsShown() and 20 or 0  -- 16px icon + 4px gap
    local contentWidth = textWidth + iconWidth
    
    widgetFrame:SetSize(contentWidth + 10, 20)
    
    -- Re-center the icon so icon+text is centered in frame
    widgetFrame.Icon:ClearAllPoints()
    widgetFrame.Icon:SetPoint("LEFT", widgetFrame, "CENTER", -contentWidth/2, 0)
end

local function CreateWidgetFrame()
    local f = CreateFrame("Frame", "OrbitStatusSpecWidget", UIParent)
    f:SetSize(100, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Spec"
    
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetSize(16, 16)
    f.Icon:SetPoint("LEFT", f, "CENTER", -40, 0)  -- Offset left from center
    
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("LEFT", f.Icon, "RIGHT", 4, 0)
    f.Text:SetJustifyH("LEFT")
    
    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 12 })
    end
    
    -- No default position - WidgetManager places in drawer
    f:SetMovable(true)
    f:EnableMouse(true)
    
    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Specialization", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        local specIndex = GetSpecialization()
        if specIndex then
            local _, name, _, _, role = GetSpecializationInfo(specIndex)
            GameTooltip:AddDoubleLine("Current:", name, 0.7, 0.7, 0.7, 1, 1, 1)
            local roleText = role == "TANK" and "Tank" or role == "HEALER" and "Healer" or "DPS"
            GameTooltip:AddDoubleLine("Role:", roleText, 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Click", "Open Talents", 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Click to open talents
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.isDragging then
            if PlayerSpellsFrame then
                PlayerSpellsFrame:SetTab(1)
                PlayerSpellsFrame:SetShown(not PlayerSpellsFrame:IsShown())
            elseif ClassTalentFrame then
                ToggleFrame(ClassTalentFrame)
            end
        end
    end)
    
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("Spec") then
            return  -- Block drag if drawer isn't open
        end
        self.isDragging = true
        self:SetParent(UIParent)
        self:SetFrameStrata("TOOLTIP")
        self:StartMoving()
        if not widgetFrame.dragTicker then
            widgetFrame.dragTicker = C_Timer.NewTicker(0.05, function()
                local WM2 = addon.WidgetManager
                if WM2 then WM2:OnWidgetDragUpdate() end
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
        local WM = addon.WidgetManager
        if WM then WM:OnWidgetDragStop("Spec") end
    end)
    
    f:RegisterForDrag("LeftButton")
    return f
end

function SpecWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame
    
    -- Create event frame for spec changes
    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    
    local WM = addon.WidgetManager
    if WM then
        WM:Register("Spec", {
            name = "Spec",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateSpec() end,
            onEnable = function(f)
                -- Re-register spec event and update display
                eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
                UpdateSpec()
            end,
            onDisable = function(f)
                -- Unregister event to save resources
                eventFrame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
            end,
        })
    end
    
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:SetScript("OnEvent", UpdateSpec)
    
    UpdateSpec()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() SpecWidget:OnLoad() end)
end)
