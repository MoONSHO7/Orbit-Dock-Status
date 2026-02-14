-- Volume.lua
-- Volume control widget for StatusDock
-- Features: Click to mute, Scroll for Master, Menu for individual channels

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local VolumeWidget = addon.BaseWidget:New("Volume")
addon.VolumeWidget = VolumeWidget

-- [ CONSTANTS ] --------------------------------------------------------------------------

local FRAME_WIDTH = 100
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ HELPERS ] ---------------------------------------------------------------------

function VolumeWidget:GetVolumeText(level)
    if level == 0 then return "|cff888888Muted|r" end
    local color = "|cff00ff00"
    if level > 0.8 then color = "|cffff0000"
    elseif level > 0.5 then color = "|cffffa500"
    end
    return string.format("%s%d%%|r", color, level * 100)
end

function VolumeWidget:GetIcon(level)
    if level == 0 then return "|TInterface\\Common\\Indicator-Red:14|t" end
    if level < 0.3 then return "|TInterface\\Common\\Indicator-Yellow:14|t" end
    return "|TInterface\\Common\\Indicator-Green:14|t"
end

-- [ UPDATE ] ----------------------------------------------------------------------

function VolumeWidget:Update()
    local level = tonumber(GetCVar("Sound_MasterVolume"))
    local enabled = GetCVar("Sound_EnableAllSound") == "1"

    if not enabled then
        self:SetText(self:GetIcon(0) .. " Muted")
    else
        self:SetText(self:GetIcon(level) .. " " .. self:GetVolumeText(level))
    end
end

-- [ INTERACTION ] -----------------------------------------------------------------

function VolumeWidget:OnScroll(delta)
    local level = tonumber(GetCVar("Sound_MasterVolume"))
    local step = 0.05

    if delta > 0 then
        level = math.min(1.0, level + step)
    else
        level = math.max(0.0, level - step)
    end

    SetCVar("Sound_MasterVolume", level)
    self:Update()
end

function VolumeWidget:OnClick(button)
    if button == "LeftButton" then
        -- Silence spell cast on the entire realm
        local enabled = GetCVar("Sound_EnableAllSound") == "1"
        if enabled then
            SetCVar("Sound_EnableAllSound", "0")
            print("Sound Muted")
        else
            SetCVar("Sound_EnableAllSound", "1")
            print("Sound Enabled")
        end
        self:Update()

    elseif button == "RightButton" then
        -- The bard opens the tavern's mixing board
        if not addon.Menu then return end

        local channels = {
            { cvar = "Sound_MasterVolume", name = "Master" },
            { cvar = "Sound_MusicVolume", name = "Music" },
            { cvar = "Sound_SFXVolume", name = "SFX" },
            { cvar = "Sound_AmbienceVolume", name = "Ambience" },
            { cvar = "Sound_DialogVolume", name = "Dialog" },
        }

        local items = {}
        for _, ch in ipairs(channels) do
            table.insert(items, {
                type = "slider",
                text = ch.name,
                min = 0,
                max = 1,
                value = tonumber(GetCVar(ch.cvar)),
                func = function(v)
                    SetCVar(ch.cvar, v)
                    self:Update()
                end
            })
        end

        addon.Menu:Open(self.frame, items)
    end
end

function VolumeWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Volume Control", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Scroll", "Adjust Master Volume", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Left Click", "Toggle Mute", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Mixer Menu", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function VolumeWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    -- Even the volume knob answers to the scroll wheel
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta) self:OnScroll(delta) end)

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)


    self:RegisterEvent("CVAR_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:SetCategory("SYSTEM")


    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() VolumeWidget:OnLoad() end)
end)
