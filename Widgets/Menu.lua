local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local Menu = {}
addon.Menu = Menu

-- [ CONSTANTS ] -------------------------------------------------------------------

local MENU_TAG = "ORBIT_STATUS_CONTEXT"

-- [ API ] -------------------------------------------------------------------------

function Menu:Open(ownerFrame, items, widgetName)
    MenuUtil.CreateContextMenu(ownerFrame, function(_, rootDescription)
        rootDescription:SetTag(MENU_TAG .. (widgetName or ""))
        for _, data in ipairs(items) do
            if data.isSeparator then
                rootDescription:CreateDivider()
            elseif data.checked ~= nil then
                rootDescription:CreateCheckbox(
                    data.text,
                    function() return data.checked end,
                    function()
                        data.checked = not data.checked
                        if data.func then data.func() end
                    end
                )
            else
                local btn = rootDescription:CreateButton(data.text, function()
                    if data.func then data.func() end
                end)
                if data.disabled then btn:SetEnabled(false) end
            end
        end
    end)
end

function Menu:Close()
    local blizzManager = _G.Menu and _G.Menu.GetManager and _G.Menu.GetManager()
    if blizzManager then blizzManager:CloseMenu() end
end
