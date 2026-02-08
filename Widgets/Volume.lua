-- Volume.lua
-- Volume control widget for StatusDock

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local VolumeWidget = {}
addon.VolumeWidget = VolumeWidget

local widgetFrame = nil

local function GetVolumeText()
    local volume = GetCVar("Sound_MasterVolume")
    local percent = math.floor(tonumber(volume) * 100)

    local enabled = GetCVar("Sound_EnableAllSound") == "1"

    if not enabled then
        return "|cffaaaaaaMuted|r"
    else
        return string.format("%d%%", percent)
    end
end

local function UpdateVolume()
    if not widgetFrame then return end
    widgetFrame.Text:SetText(GetVolumeText())

    local width = widgetFrame.Text:GetStringWidth()
    widgetFrame:SetSize(width + 10, 20)
end

local function SetVolume(delta)
    local volume = tonumber(GetCVar("Sound_MasterVolume"))
    local newVolume = volume + (delta * 0.05) -- 5% step

    if newVolume > 1 then newVolume = 1 end
    if newVolume < 0 then newVolume = 0 end

    SetCVar("Sound_MasterVolume", newVolume)

    -- Ensure sound is enabled if volume is increased
    if delta > 0 and GetCVar("Sound_EnableAllSound") == "0" then
        SetCVar("Sound_EnableAllSound", "1")
    end

    UpdateVolume()
end

local function ToggleMute()
    local enabled = GetCVar("Sound_EnableAllSound") == "1"
    if enabled then
        SetCVar("Sound_EnableAllSound", "0")
    else
        SetCVar("Sound_EnableAllSound", "1")
    end
    UpdateVolume()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Volume", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local volume = math.floor(tonumber(GetCVar("Sound_MasterVolume")) * 100)
    GameTooltip:AddDoubleLine("Master Volume:", volume .. "%", 1, 1, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Scroll", "Adjust Volume", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Click", "Mute / Unmute", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateWidgetFrame()
    local f = CreateFrame("Button", "OrbitStatusVolumeWidget", UIParent)
    f:SetSize(60, 20)
    f:SetClampedToScreen(true)
    f.editModeName = "Volume"

    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")

    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 12 })
    end

    -- Interaction
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:RegisterForClicks("AnyUp")
    f:SetMovable(true)

    f:SetScript("OnEnter", ShowTooltip)
    f:SetScript("OnLeave", HideTooltip)

    f:SetScript("OnMouseWheel", function(self, delta)
        SetVolume(delta)
        ShowTooltip(self) -- Update tooltip
    end)

    f:SetScript("OnClick", function(self, button)
        if self.isDragging then return end

        if button == "LeftButton" then
            ToggleMute()
            ShowTooltip(self)
        end
    end)

    -- Drag handling
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        local WM = addon.WidgetManager
        if not WM or not WM:OnWidgetDragStart("Volume") then
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
        if WM then WM:OnWidgetDragStop("Volume") end
    end)

    return f
end

function VolumeWidget:OnLoad()
    widgetFrame = CreateWidgetFrame()
    self.frame = widgetFrame

    local WM = addon.WidgetManager
    if WM then
        WM:Register("Volume", {
            name = "Volume",
            frame = widgetFrame,
            onDock = function(f, zone) f:SetSize(zone:GetWidth() - 4, zone:GetHeight() - 2) end,
            onUndock = function(f) UpdateVolume() end,
            onEnable = function(f)
                UpdateVolume()
                -- Register CVAR_UPDATE if we want to react to external changes
                f:RegisterEvent("CVAR_UPDATE")
            end,
            onDisable = function(f)
                f:UnregisterEvent("CVAR_UPDATE")
            end,
        })
    end

    widgetFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "CVAR_UPDATE" then
            if arg1 == "Sound_MasterVolume" or arg1 == "Sound_EnableAllSound" then
                UpdateVolume()
            end
        end
    end)

    UpdateVolume()
    widgetFrame:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() VolumeWidget:OnLoad() end)
end)
