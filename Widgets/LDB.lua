-- LDB.lua
-- LibDataBroker support for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local LDB = LibStub("LibDataBroker-1.1", true)
if not LDB then return end

local LDBWidget = {}
addon.LDBWidget = LDBWidget

-- Helper to sanitize LDB object name for use as widget ID
local function GetWidgetID(ldbName)
    return "LDB_" .. ldbName:gsub("%s+", "_"):gsub("[^%w_]", "")
end

-- Helper to update widget display based on LDB object attributes
local function UpdateLDBDisplay(widgetFrame, ldbObject)
    if not widgetFrame then return end

    local text = ldbObject.text or ldbObject.label or ldbObject.name or ""
    local icon = ldbObject.icon

    -- Update text
    if widgetFrame.Text then
        widgetFrame.Text:SetText(text)
    end

    -- Update icon if present (optional feature, currently text-focused)
    if icon and widgetFrame.Icon then
        widgetFrame.Icon:Show()
        widgetFrame.Icon:SetTexture(icon)
        if ldbObject.iconCoords then
            widgetFrame.Icon:SetTexCoord(unpack(ldbObject.iconCoords))
        else
            widgetFrame.Icon:SetTexCoord(0, 1, 0, 1)
        end

        if ldbObject.iconR and ldbObject.iconG and ldbObject.iconB then
            widgetFrame.Icon:SetVertexColor(ldbObject.iconR, ldbObject.iconG, ldbObject.iconB)
        else
            widgetFrame.Icon:SetVertexColor(1, 1, 1)
        end

        -- Anchor text to right of icon
        widgetFrame.Text:ClearAllPoints()
        widgetFrame.Text:SetPoint("LEFT", widgetFrame.Icon, "RIGHT", 4, 0)
        widgetFrame.Text:SetPoint("RIGHT", widgetFrame, "RIGHT", -2, 0)
    elseif widgetFrame.Icon then
        -- No icon, hide it and re-anchor text
        widgetFrame.Icon:Hide()
        widgetFrame.Text:ClearAllPoints()
        widgetFrame.Text:SetPoint("LEFT", widgetFrame, "LEFT", 4, 0)
        widgetFrame.Text:SetPoint("RIGHT", widgetFrame, "RIGHT", -2, 0)
    end

    -- Resize frame to fit content
    if widgetFrame.Text then
        local width = widgetFrame.Text:GetStringWidth()
        local iconWidth = (icon and widgetFrame.Icon) and 20 or 0 -- 16 + 4 padding
        local padding = 8
        widgetFrame:SetSize(width + iconWidth + padding, 20)
    end
end

-- Create a widget frame for an LDB object
local function CreateLDBWidgetFrame(name, ldbObject)
    local f = CreateFrame("Button", GetWidgetID(name), UIParent)
    f:SetSize(100, 20)
    f:SetClampedToScreen(true)
    f.editModeName = name

    -- Icon (optional)
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetSize(16, 16)
    f.Icon:SetPoint("LEFT", f, "LEFT", 2, 0)

    -- Text
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("LEFT", f.Icon, "RIGHT", 4, 0)
    f.Text:SetPoint("RIGHT", f, "RIGHT", -2, 0)

    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 12 })
    end

    -- Interaction
    f:EnableMouse(true)
    f:RegisterForClicks("AnyUp")
    f:SetMovable(true)

    -- Click handler
    f:SetScript("OnClick", function(self, button)
        if self.isDragging then return end
        if ldbObject.OnClick then
            ldbObject.OnClick(self, button)
        end
    end)

    -- Tooltip handler
    f:SetScript("OnEnter", function(self)
        if self.isDragging then return end

        local anchor = "ANCHOR_TOP"
        -- Adjust anchor based on screen position if needed

        if ldbObject.OnTooltipShow then
            GameTooltip:SetOwner(self, anchor)
            GameTooltip:ClearLines()
            ldbObject.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        elseif ldbObject.OnEnter then
            ldbObject.OnEnter(self)
        else
            GameTooltip:SetOwner(self, anchor)
            GameTooltip:ClearLines()
            GameTooltip:AddLine(name)
            if ldbObject.text then
                GameTooltip:AddLine(ldbObject.text, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)

    f:SetScript("OnLeave", function(self)
        if ldbObject.OnLeave then
            ldbObject.OnLeave(self)
        else
            GameTooltip:Hide()
        end
    end)

    -- Drag handling (standard widget behavior)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart(GetWidgetID(name)) then
            return
        end
        self.isDragging = true
        self:SetParent(UIParent)
        self:SetFrameStrata("TOOLTIP")
        self:StartMoving()
        if not self.dragTicker then
            self.dragTicker = C_Timer.NewTicker(0.05, function()
                local WM2 = addon.WidgetManager
                if WM2 then WM2:OnWidgetDragUpdate() end
            end)
        end
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false
        if self.dragTicker then
            self.dragTicker:Cancel()
            self.dragTicker = nil
        end
        local WM = addon.WidgetManager
        if WM then WM:OnWidgetDragStop(GetWidgetID(name)) end
    end)

    return f
end

-- Register an LDB object as a widget
local function RegisterLDBWidget(name, ldbObject)
    local widgetID = GetWidgetID(name)
    local WM = addon.WidgetManager

    -- Avoid duplicates or conflicts with existing widgets
    if WM:GetWidget(widgetID) then return end

    -- Skip launcher-type objects (usually minimap buttons) if desired
    -- For now, include everything as the user can just not dock them

    local f = CreateLDBWidgetFrame(name, ldbObject)

    WM:Register(widgetID, {
        name = name,
        frame = f,
        onDock = function(frame, zone)
            frame:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2)
        end,
        onUndock = function(frame)
            UpdateLDBDisplay(frame, ldbObject)
        end,
        onEnable = function(frame)
            UpdateLDBDisplay(frame, ldbObject)
        end,
        onDisable = function(frame)
            -- Nothing specific needed
        end,
    })

    -- Initial update
    UpdateLDBDisplay(f, ldbObject)

    -- By default, LDB widgets go to drawer (handled by WidgetManager logic)
end

-- Initialize LDB support
local function InitLDB()
    -- Register existing objects
    for name, obj in LDB:DataObjectIterator() do
        RegisterLDBWidget(name, obj)
    end

    -- Listen for new objects and updates
    LDB.RegisterCallback(addon, "LibDataBroker_AttributeChanged", function(event, name, key, value, obj)
        local widgetID = GetWidgetID(name)
        local widget = addon.WidgetManager:GetWidget(widgetID)

        if not widget then
            -- New object?
            RegisterLDBWidget(name, obj)
        else
            -- Update existing
            if key == "text" or key == "label" or key == "icon" or key == "value" then
                UpdateLDBDisplay(widget.frame, obj)
            end
        end
    end)
end

-- Start up
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1.0, InitLDB)  -- Delay to ensure other addons loaded their LDB objects
end)
