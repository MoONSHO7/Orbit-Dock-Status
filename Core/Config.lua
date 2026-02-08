-- Config.lua
-- Centralized configuration system for Orbit Status Dock
-- Manages default settings, profiles, and persistence

local addonName, addon = ...

---@type Orbit
local Orbit = Orbit
if not Orbit then return end

local Config = {}
addon.Config = Config

-- [ VARIABLES ] ---------------------------------------------------------------

local DB = nil
local DEFAULTS = {}
local CALLBACKS = {}

-- [ HELPERS ] -----------------------------------------------------------------

local function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function MergeTables(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dest[k]) == "table" then
            MergeTables(dest[k], v)
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
    return dest
end

-- [ API ] ---------------------------------------------------------------------

--- Initialize the configuration system
function Config:Init()
    -- Ensure saved variable exists
    if not Orbit_StatusDB then Orbit_StatusDB = {} end
    DB = Orbit_StatusDB

    -- Initialize profiles if not present
    if not DB.profiles then DB.profiles = {} end
    if not DB.global then DB.global = {} end

    -- Set current profile (default to character specific if not set)
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    if not DB.currentProfile then DB.currentProfile = charKey end

    -- Ensure current profile exists
    if not DB.profiles[DB.currentProfile] then
        DB.profiles[DB.currentProfile] = {}
    end

    -- Apply defaults
    MergeTables(DB.profiles[DB.currentProfile], DEFAULTS)

    -- Trigger callbacks
    for key, callbacks in pairs(CALLBACKS) do
        for _, func in ipairs(callbacks) do
            func(self:Get(key))
        end
    end
end

--- Register default settings for a module
---@param key string Unique module key (e.g., "GoldWidget")
---@param defaults table Default settings table
function Config:Register(key, defaults)
    DEFAULTS[key] = defaults

    -- Apply immediately if DB is loaded
    if DB and DB.profiles and DB.profiles[DB.currentProfile] then
        if not DB.profiles[DB.currentProfile][key] then
            DB.profiles[DB.currentProfile][key] = DeepCopy(defaults)
        else
            MergeTables(DB.profiles[DB.currentProfile][key], defaults)
        end
    end
end

--- Get settings for a module
---@param key string Module key
---@return table Settings table (reference)
function Config:Get(key)
    if not DB or not DB.profiles or not DB.profiles[DB.currentProfile] then
        return DEFAULTS[key] or {}
    end

    local settings = DB.profiles[DB.currentProfile][key]
    if not settings then
        -- Initialize if missing but registered
        if DEFAULTS[key] then
            DB.profiles[DB.currentProfile][key] = DeepCopy(DEFAULTS[key])
            settings = DB.profiles[DB.currentProfile][key]
        else
            return {}
        end
    end

    return settings
end

--- Set a setting value
---@param key string Module key
---@param setting string Setting name
---@param value any Value to set
function Config:Set(key, setting, value)
    local settings = self:Get(key)
    if settings then
        settings[setting] = value

        -- Trigger update callback if registered
        if CALLBACKS[key] then
            for _, func in ipairs(CALLBACKS[key]) do
                func(settings)
            end
        end
    end
end

--- Register a callback for when settings change
---@param key string Module key
---@param func function Callback function(settings)
function Config:OnUpdate(key, func)
    if not CALLBACKS[key] then CALLBACKS[key] = {} end
    table.insert(CALLBACKS[key], func)
end

-- Initialize on load
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, name)
    if name == addonName then
        Config:Init()
        f:UnregisterEvent("ADDON_LOADED")
    end
end)
