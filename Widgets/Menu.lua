-- Menu.lua
-- Lightweight dropdown menu system for StatusDock
-- Supports custom frames, checkboxes, sliders, and buttons
-- Enhanced with scrolling support for long lists

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local Menu = {}
addon.Menu = Menu

local menuFrame = nil
local BUTTON_HEIGHT = 20
local PADDING = 10
local WIDTH = 200
local MAX_HEIGHT = 300 -- Max height before scrolling

-- [ CREATION ] ----------------------------------------------------------------

local function CreateMenuFrame()
    local f = CreateFrame("Frame", "OrbitStatusMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetSize(WIDTH, 100)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:Hide()

    -- Close when clicking outside
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetAllPoints(UIParent)
    closeBtn:SetFrameStrata("FULLSCREEN_DIALOG")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function() end) -- block mouse
    closeBtn:SetScript("OnLeave", function() end)
    f.closeBtn = closeBtn

    -- ScrollFrame
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -5)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 5) -- Leave space for scrollbar

    -- Content Frame
    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(WIDTH - 25, 100) -- Initial height
    f.scrollFrame:SetScrollChild(f.content)

    f.items = {}
    f.sliders = {}

    return f
end

local function GetMenuItem(index)
    if not menuFrame then menuFrame = CreateMenuFrame() end

    if not menuFrame.items[index] then
        local btn = CreateFrame("Button", nil, menuFrame.content)
        btn:SetSize(WIDTH - 25 - PADDING*2, BUTTON_HEIGHT)
        btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.Text:SetPoint("LEFT", btn, "LEFT", 5, 0)
        btn.Text:SetJustifyH("LEFT")

        btn:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(1, 1, 1, 0.1)
        end)
        btn:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0, 0, 0, 0)
        end)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()

        -- Checkbox
        btn.Check = btn:CreateTexture(nil, "ARTWORK")
        btn.Check:SetSize(14, 14)
        btn.Check:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
        btn.Check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

        menuFrame.items[index] = btn
    end

    return menuFrame.items[index]
end

local function GetSliderItem(index)
    if not menuFrame then menuFrame = CreateMenuFrame() end

    if not menuFrame.sliders[index] then
        local slider = CreateFrame("Slider", nil, menuFrame.content, "OptionsSliderTemplate")
        slider:SetWidth(WIDTH - 25 - PADDING*3)
        slider:SetHeight(16)

        -- Add value label
        slider.Value = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slider.Value:SetPoint("TOP", slider, "BOTTOM", 0, -2)

        menuFrame.sliders[index] = slider
    end

    return menuFrame.sliders[index]
end

-- [ API ] ---------------------------------------------------------------------

function Menu:Open(anchorFrame, items)
    if not menuFrame then menuFrame = CreateMenuFrame() end

    -- Hide all existing items
    for _, item in pairs(menuFrame.items) do item:Hide() end
    for _, slider in pairs(menuFrame.sliders) do slider:Hide() end

    local yOffset = -PADDING
    local buttonCount = 0
    local sliderCount = 0

    for i, data in ipairs(items) do
        if data.type == "slider" then
            sliderCount = sliderCount + 1
            local slider = GetSliderItem(sliderCount)

            slider:ClearAllPoints()
            slider:SetPoint("TOPLEFT", menuFrame.content, "TOPLEFT", PADDING + 5, yOffset - 15)
            slider:SetMinMaxValues(data.min, data.max)
            slider:SetValue(data.value)
            slider:SetScript("OnValueChanged", function(self, value)
                if data.func then data.func(value) end
                if self.Value then self.Value:SetText(string.format("%.2f", value)) end
            end)

            -- Label
            if not slider.Label then
                slider.Label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                slider.Label:SetPoint("BOTTOM", slider, "TOP", 0, 0)
            end
            slider.Label:SetText(data.text)

            slider:Show()
            yOffset = yOffset - 45
        else
            -- Standard Button / Checkbox
            buttonCount = buttonCount + 1
            local btn = GetMenuItem(buttonCount)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", menuFrame.content, "TOPLEFT", PADDING, yOffset)
            btn.Text:SetText(data.text)

            if data.checked ~= nil then
                btn.Check:SetShown(data.checked)
            else
                btn.Check:Hide()
            end

            btn:SetScript("OnClick", function()
                if data.func then data.func() end
                if data.closeOnClick ~= false then
                    menuFrame:Hide()
                else
                    -- Refresh check state visually if toggled
                    if data.checked ~= nil then
                        data.checked = not data.checked
                        btn.Check:SetShown(data.checked)
                    end
                end
            end)

            btn:Show()
            yOffset = yOffset - BUTTON_HEIGHT - 2
        end
    end

    -- Calculate required height
    local contentHeight = math.abs(yOffset) + PADDING
    menuFrame.content:SetHeight(contentHeight)

    -- Set frame height (limit to MAX_HEIGHT)
    local frameHeight = math.min(contentHeight + 10, MAX_HEIGHT)
    menuFrame:SetHeight(frameHeight)

    -- Reset scroll
    menuFrame.scrollFrame:SetVerticalScroll(0)

    -- Position
    menuFrame:ClearAllPoints()
    menuFrame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 5)

    -- Ensure on screen
    menuFrame:SetClampedToScreen(true)

    menuFrame:Show()
end

function Menu:Close()
    if menuFrame then menuFrame:Hide() end
end
