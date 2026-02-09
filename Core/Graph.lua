-- Graph.lua
-- Lightweight Line Graph rendering library for StatusDock tooltips
-- Enhanced for robustness, class colors, and visual polish

local addonName, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local Graph = {}
addon.Graph = Graph

-- [ DRAWING ] -----------------------------------------------------------------

--- Create a graph on a parent frame
---@param parent frame Frame to draw on
---@param width number Width of graph
---@param height number Height of graph
---@return table Graph object { frame, AddData, Clear, SetColor }
function Graph:New(parent, width, height)
    local graph = {}

    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    graph.frame = f

    -- Backdrop (Grid-like background)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Border line at bottom
    f.border = f:CreateLine()
    f.border:SetStartPoint("BOTTOMLEFT", 0, 0)
    f.border:SetEndPoint("BOTTOMRIGHT", 0, 0)
    f.border:SetColorTexture(0.5, 0.5, 0.5, 1)
    f.border:SetThickness(1)

    graph.points = {}
    graph.lines = {}
    graph.color = { r = 0, g = 1, b = 0, a = 1 }
    graph.minY = 0
    graph.maxY = 0

    function graph:SetColor(r, g, b, a)
        -- Support direct RGB or table (Class Colors)
        if type(r) == "table" then
            self.color = { r = r.r, g = r.g, b = r.b, a = r.a or 1 }
        else
            self.color = { r = r, g = g, b = b, a = a or 1 }
        end
    end

    function graph:Clear()
        for _, line in ipairs(self.lines) do
            line:Hide()
        end
        self.points = {}
    end

    function graph:AddData(value)
        if not value then return end
        table.insert(self.points, value)
        if #self.points > width then -- limit points to width
            table.remove(self.points, 1)
        end
        self:Draw()
    end

    function graph:Draw()
        if #self.points < 2 then return end

        -- Find Min/Max for scaling
        local min, max = self.points[1], self.points[1]
        for _, v in ipairs(self.points) do
            if v < min then min = v end
            if v > max then max = v end
        end

        -- Enforce a minimum range to avoid flatline division by zero
        local range = max - min
        if range == 0 then range = 1 end -- Default range if flat

        -- Padding to prevent hitting exact top/bottom
        local padding = height * 0.1
        local drawHeight = height - (padding * 2)

        local stepX = width / (#self.points - 1)

        -- Create or reuse lines
        for i = 1, #self.points - 1 do
            if not self.lines[i] then
                self.lines[i] = f:CreateLine()
                self.lines[i]:SetThickness(1.5) -- Thicker for visibility
                -- Use PixelUtil if available for sharpness (not standard global, skipping)
            end

            local line = self.lines[i]
            line:SetColorTexture(self.color.r, self.color.g, self.color.b, self.color.a)

            -- Calculate coordinates
            -- Y = ((Value - Min) / Range) * DrawHeight + Padding

            local x1 = (i - 1) * stepX
            local val1 = self.points[i]
            local y1 = ((val1 - min) / range) * drawHeight + padding

            local x2 = i * stepX
            local val2 = self.points[i+1]
            local y2 = ((val2 - min) / range) * drawHeight + padding

            line:SetStartPoint("BOTTOMLEFT", x1, y1)
            line:SetEndPoint("BOTTOMLEFT", x2, y2)
            line:Show()
        end

        -- Hide unused lines
        for i = #self.points, #self.lines do
            self.lines[i]:Hide()
        end
    end

    return graph
end
