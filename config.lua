Config = Config or {}

Config.Keybind = {
    name = 'vehiclekeys:toggle-lock',
    description = 'Lock or unlock the nearest vehicle',
    defaultKey = 'L',
}

Config.RemoteDistance = 25.0
Config.InteractionDistance = 5.0
Config.RequireKeyToStart = true
Config.AccessCacheMs = 1500

-- Virtual keys are held only for the current server session. Garages,
-- dealerships, and job resources can grant them with exports.qbvehiclekeys:giveKeys.
Config.AllowTemporaryKeys = true

-- Jobs listed here can use the configured vehicle models without holding a
-- plate key. Model names are the vehicle spawn names, not display labels.
--
-- Config.JobVehicles = {
--     police = { 'police', 'police2', 'police3' },
--     ambulance = { 'ambulance' },
-- }
Config.JobVehicles = {}

-- Turn this on to require an inventory item whose metadata matches the target
-- vehicle. Metadata values may be literal values, or '{plate}' to use the
-- vehicle's normalised plate. `true` is a shorthand for '{plate}'.
--
-- Example item metadata: { plate = 'QB 123', owner = 'citizen-id-here' }
Config.PhysicalKey = {
    enabled = false,
    item = 'vehiclekey',
    metadata = {
        plate = '{plate}',
    },
}

Config.Lockpick = {
    item = 'lockpick',
    breakChance = { success = 5, failure = 25 },
    difficulty = {
        attempts = 2,
        pinCount = 4,
        tolerance = 0.12,
        speed = 0.85,
        timeLimit = 12000,
    },
}

Config.Hotwire = {
    enabled = true,
    keybind = {
        name = 'vehiclekeys:hotwire',
        description = 'Hotwire the vehicle you are driving',
        defaultKey = 'H',
    },
    -- A successful hotwire grants an in-memory session key. Set false when a
    -- server wants hotwiring to unlock doors only, without allowing ignition.
    grantTemporaryKey = true,
}

Config.RateLimits = {
    toggle = { max = 10, window = 5000 },
    access = { max = 20, window = 10000 },
    hotwire = { max = 4, window = 10000 },
}

if QB and QB.config and QB.config.adopt then
    Config.JobVehicles = QB.config.map({}, QB.config.list({}, QB.config.string('', { minLength = 1 })), {
        label = 'Job vehicles',
        description = 'Defines vehicle model names that each job may operate without possessing a physical key. Use the job name as the outer key and an ordered list of exact vehicle model names as its value.',
    })
    Config = QB.config.adopt(Config)
end
