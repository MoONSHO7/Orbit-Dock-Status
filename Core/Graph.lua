-- Graph.lua
-- Lightweight Line Graph rendering library for StatusDock tooltips

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

    -- Backdrop
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.5)

    graph.points = {}
    graph.lines = {}
    graph.color = { r = 0, g = 1, b = 0, a = 1 }

    function graph:SetColor(r, g, b, a)
        self.color = { r = r, g = g, b = b, a = a or 1 }
    end

    function graph:Clear()
        for _, line in ipairs(self.lines) do
            line:Hide()
        end
        self.points = {}
    end

    function graph:AddData(value)
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

        local range = max - min
        if range == 0 then range = 1 end

        local stepX = width / (#self.points - 1)

        -- Create or reuse lines
        for i = 1, #self.points - 1 do
            if not self.lines[i] then
                self.lines[i] = f:CreateLine()
                self.lines[i]:SetThickness(1)
            end

            local line = self.lines[i]
            line:SetColorTexture(self.color.r, self.color.g, self.color.b, self.color.a)

            -- Calculate coordinates
            -- X: straightforward step
            -- Y: normalize value between 0 and height
            local x1 = (i - 1) * stepX
            local y1 = ((self.points[i] - min) / range) * height
            local x2 = i * stepX
            local y2 = ((self.points[i+1] - min) / range) * height

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
