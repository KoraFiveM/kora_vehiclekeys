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

-- Bikes and bicycles have no doors, so a locked bike is never given the native
-- locked-door status (that blocks lifting a fallen bike). Instead a locked bike
-- stays blocked for players without its key, who get a "This bike is locked."
-- notice; key holders can always pick it up. Set true to let anyone pick up
-- (and mount) a locked bike; the ignition still needs a key when RequireKeyToStart is on.
Config.allowPickupLockedBikes = false

-- Virtual keys are held only for the current server session. Garages,
-- dealerships, and job resources can grant them with exports.kora_vehiclekeys:giveKeys.
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
        -- H is the default headlight key (control 74), so hotwiring defaults to
        -- U. Players can rebind it under Settings > Key Bindings > FiveM. Saved
        -- bindings from an older default are kept by the game.
        defaultKey = 'U',
    },
    -- When true, pressing the hotwire key outside the driver seat (or in a
    -- vehicle that cannot be hotwired) shows an error. Off by default so the
    -- key is silent whenever hotwiring does not apply. Read on every press.
    notifyUnavailable = false,
    -- A successful hotwire grants an in-memory session key. Set false when a
    -- server wants hotwiring to unlock doors only, without allowing ignition.
    grantTemporaryKey = true,
}

-- Feedback after a successful lock/unlock (failed attempts never give feedback).
-- Every key is read each time a vehicle is toggled, so changes apply live.
Config.lockFeedback = {
    sound = true,        -- key-fob chirp for the player who toggled the lock
    soundNearby = false, -- also play the chirp for players within soundRange
    soundRange = 10.0,   -- metres, used by soundNearby
    lights = true,       -- flash indicators and headlights; everyone nearby sees it
    animation = true,    -- key-fob animation when on foot (skipped inside the vehicle)
    notify = true,       -- top-right kora_lib notification
    textUI = false,      -- short bottom-centre "Locked"/"Unlocked" status
}

Config.RateLimits = {
    toggle = { max = 10, window = 5000 },
    access = { max = 20, window = 10000 },
    hotwire = { max = 4, window = 10000 },
}

if Kora and Kora.config and Kora.config.adopt then
    Config.JobVehicles = Kora.config.map({}, Kora.config.list({}, Kora.config.string('', { minLength = 1 })), {
        label = 'Job vehicles',
        description = 'Defines vehicle model names that each job may operate without possessing a physical key. Use the job name as the outer key and an ordered list of exact vehicle model names as its value.',
    })
    Config = Kora.config.adopt(Config)
end
