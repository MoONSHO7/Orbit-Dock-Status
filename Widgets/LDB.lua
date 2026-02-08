-- LDB.lua
-- LibDataBroker-1.1 integration for StatusDock
-- Automatically wraps LDB data objects as Orbit Status widgets

local addonName, addon = ...
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
if not LDB then return end

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local LDBHandler = {}
addon.LDBHandler = LDBHandler
LDBHandler.wrappers = {}

-- [ WRAPPER CREATION ] --------------------------------------------------------

local function CreateLDBWrapper(name, dataObj)
    -- Create a new widget extending BaseWidget
    -- We prefix with "LDB_" to avoid collisions
    local widgetName = "LDB_" .. name
    local widget = addon.BaseWidget:New(widgetName)

    -- Store reference
    LDBHandler.wrappers[name] = widget

    -- [ DISPLAY LOGIC ]

    function widget:UpdateDisplay()
        local text = dataObj.text or dataObj.label or name
        local icon = dataObj.icon

        -- Format: Icon + Text
        -- Use standard formatting
        if icon then
            self:SetText(string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t %s", icon, text))
        else
            self:SetText(text)
        end
    end

    -- [ INTERACTION LOGIC ]

    function widget:ShowTooltip()
        if dataObj.OnTooltipShow then
            GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            dataObj.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        elseif dataObj.OnEnter then
            dataObj.OnEnter(self.frame)
        else
            GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(name, 1, 0.82, 0)
            if dataObj.label then
                GameTooltip:AddLine(dataObj.label, 1, 1, 1)
            end
            GameTooltip:Show()
        end
    end

    function widget:OnClick(button)
        if dataObj.OnClick then
            dataObj.OnClick(self.frame, button)
        end
    end

    -- [ LIFECYCLE ]

    function widget:OnLoad()
        self:CreateFrame()

        -- Setup handlers
        self:SetUpdateFunc(function() self:UpdateDisplay() end)
        self:SetTooltipFunc(function() self:ShowTooltip() end)
        self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

        -- Setup LDB callback
        LDB.RegisterCallback(self, "LibDataBroker_AttributeChanged_" .. name, function(_, _, key, value)
            if key == "text" or key == "icon" or key == "label" then
                self:UpdateDisplay()
            end
        end)

        -- Register with manager
        self:Register()

        -- Initial update
        self:UpdateDisplay()
    end

    -- Initialize
    if IsLoggedIn() then
        widget:OnLoad()
    else
        local initFrame = CreateFrame("Frame")
        initFrame:RegisterEvent("PLAYER_LOGIN")
        initFrame:SetScript("OnEvent", function()
            widget:OnLoad()
        end)
    end

    return widget
end

-- [ INITIALIZATION ] ----------------------------------------------------------

function LDBHandler:Init()
    -- Process existing data objects
    for name, dataObj in LDB:DataObjectIterator() do
        CreateLDBWrapper(name, dataObj)
    end

    -- Watch for new data objects
    LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated", function(_, name, dataObj)
        CreateLDBWrapper(name, dataObj)
    end)
end

-- Start automatically
LDBHandler:Init()
