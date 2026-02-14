-- Notes.lua
-- Advanced Notes widget for StatusDock
-- Features: Persistent scratchpad, quick edit

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

if not addon.BaseWidget then return end

local NotesWidget = addon.BaseWidget:New("Notes")
addon.NotesWidget = NotesWidget

-- [ CONSTANTS ] --------------------------------------------------------------------------

local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local INIT_DELAY_SEC = 1

-- [ SETTINGS ] --------------------------------------------------------------------

NotesWidget.settings = {
    note = "Click to edit note...",
}

-- [ EDIT BOX ] --------------------------------------------------------------------

local function CreateEditFrame()
    local f = CreateFrame("Frame", "OrbitStatusNotesFrame", UIParent, "BackdropTemplate")
    f:SetSize(300, 200)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Title
    f.Title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.Title:SetPoint("TOP", f, "TOP", 0, -15)
    f.Title:SetText("StatusDock Notes")

    -- ScrollFrame
    local sf = CreateFrame("ScrollFrame", "OrbitStatusNotesScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 40)

    -- EditBox
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetSize(240, 120)
    eb:SetMultiLine(true)
    eb:SetFontObject("GameFontHighlight")
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    f.EditBox = eb

    -- Save Button
    local btn = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    btn:SetSize(80, 25)
    btn:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    btn:SetText("Save")
    btn:SetScript("OnClick", function()
        NotesWidget.settings.note = eb:GetText()
        NotesWidget:Update()
        -- Save via Config
        if addon.Config then
            addon.Config:Set("NotesWidget", "note", NotesWidget.settings.note)
        end
        f:Hide()
    end)

    f:Hide()
    return f
end

-- [ UPDATE ] ----------------------------------------------------------------------

function NotesWidget:Update()
    local note = self.settings.note or "Click to edit..."
    -- Truncate to first line or 20 chars
    local firstLine = note:match("([^\n]+)") or note
    if #firstLine > 25 then
        firstLine = string.sub(firstLine, 1, 22) .. "..."
    end

    self:SetText("|cffffd700Note:|r " .. firstLine)
end

-- [ INTERACTION ] -----------------------------------------------------------------

function NotesWidget:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Notes", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local note = self.settings.note or ""
    GameTooltip:AddLine(note, 1, 1, 1, true) -- Wrap text

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Edit Note", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:Show()
end

function NotesWidget:OnClick(button)
    if not self.editFrame then
        self.editFrame = CreateEditFrame()
    end

    self.editFrame.EditBox:SetText(self.settings.note or "")
    self.editFrame:Show()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------

function NotesWidget:OnLoad()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)

    -- Load settings
    if addon.Config then
        local saved = addon.Config:Get("NotesWidget")
        if saved and saved.note then
            self.settings.note = saved.note
        else
            addon.Config:Register("NotesWidget", { note = "Click to edit..." })
        end
    end

    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) self:OnClick(btn) end)

    self:SetCategory("UTILITY")


    self:Register()
    self:Update()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:SetScript("OnEvent", nil)
    C_Timer.After(INIT_DELAY_SEC, function() NotesWidget:OnLoad() end)
end)
