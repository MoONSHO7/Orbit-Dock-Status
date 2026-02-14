-- Formatting.lua
-- Centralized formatting library for Orbit StatusDock
-- Handles Numbers, Time, Colors

local _, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local Formatting = {}
addon.Formatting = Formatting

-- [ NUMBERS ] ---------------------------------------------------------------------

function Formatting:FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return string.format("%d", num)
    end
end

function Formatting:FormatMoney(copper, full)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100

    if full then
        return string.format("|cffffd700%d|r gold |cffc0c0c0%d|r silver |cffeda55f%d|r copper", gold, silver, cop)
    end

    if gold >= 1000000 then
        return string.format("|cffffd700%.2fm|r", gold / 1000000)
    elseif gold >= 1000 then
        return string.format("|cffffd700%.1fk|r", gold / 1000)
    elseif gold > 0 then
        return string.format("|cffffd700%d|rg |cffc0c0c0%d|rs", gold, silver)
    else
        return string.format("|cffc0c0c0%d|rs |cffeda55f%d|rc", silver, cop)
    end
end

-- [ TIME ] ------------------------------------------------------------------------

function Formatting:FormatTime(seconds)
    if not seconds or seconds == math.huge then return "N/A" end
    if seconds < 60 then return string.format("%ds", seconds) end
    if seconds < 3600 then return string.format("%dm", seconds / 60) end
    return string.format("%dh %dm", seconds / 3600, (seconds % 3600) / 60)
end

function Formatting:FormatTimeShort(seconds)
    if not seconds then return "" end
    if seconds < 60 then return string.format("%d", seconds) end
    if seconds < 3600 then return string.format("%d:%02d", seconds / 60, seconds % 60) end
    return string.format("%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
end

-- [ COLORS ] ----------------------------------------------------------------------

function Formatting:GetColor(value, max, inverse)
    local pct = (value / max) * 100
    if inverse then
        if pct < 50 then return "|cff00ff00" end
        if pct < 80 then return "|cffffa500" end
        return "|cffff0000"
    else
        if pct < 20 then return "|cffff0000" end
        if pct < 50 then return "|cffffa500" end
        return "|cff00ff00"
    end
end

-- [ RING BUFFER ] -----------------------------------------------------------------

local RingBuffer = {}
RingBuffer.__index = RingBuffer

function RingBuffer:New(capacity)
    return setmetatable({ data = {}, capacity = capacity, head = 0, count = 0 }, RingBuffer)
end

function RingBuffer:Push(value)
    self.head = (self.head % self.capacity) + 1
    self.data[self.head] = value
    if self.count < self.capacity then self.count = self.count + 1 end
end

function RingBuffer:Clear()
    self.head = 0
    self.count = 0
end

function RingBuffer:Iterate()
    local i = 0
    local start = (self.head - self.count) % self.capacity
    return function()
        i = i + 1
        if i > self.count then return nil end
        local idx = (start + i - 1) % self.capacity + 1
        return i, self.data[idx]
    end
end

function RingBuffer:Last(offset)
    offset = offset or 0
    if offset >= self.count then return nil end
    local idx = (self.head - 1 - offset) % self.capacity + 1
    return self.data[idx]
end

function RingBuffer:Nth(n)
    if n < 1 or n > self.count then return nil end
    local start = (self.head - self.count) % self.capacity
    local idx = (start + n - 1) % self.capacity + 1
    return self.data[idx]
end

function RingBuffer:Count() return self.count end

Formatting.RingBuffer = RingBuffer

