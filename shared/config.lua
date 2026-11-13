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

-- Stock qb-vehiclekeys let a client ask for keys to a plate it names. That is
-- unsafe by default, so those requests (qb-vehiclekeys:server:AcquireVehicleKeys,
-- and the client AddKeys / SetOwner events that forward to it) are ignored.
-- Set true to honour them ONLY for the vehicle the player is currently driving
-- with a matching plate (note: this lets a driver skip hotwiring). Server
-- scripts should use exports.kora_vehiclekeys:giveKeys instead.
Config.LegacyClientGrants = false

-- Safe handling of stock `vehiclekeys:client:SetOwner` / AddKeys /
-- `qb-vehiclekeys:server:AcquireVehicleKeys` (stock qb-core /car and qb-policejob
-- job vehicles). Works while LegacyClientGrants is false. A request is granted a
-- temporary key only when the vehicle is a networked entity within maxDistance of
-- the player and is NOT a player_vehicles row, NOT locked, and held by nobody
-- else, and either:
--   * the entity appeared within spawnWindowMs and was created by the requester
--     (client spawn, as stock /car does) or by the server with the requester in
--     the driver seat (QBCore SpawnVehicle with warp), or
--   * its model is in Config.JobVehicles for the requester's on-duty job.
Config.TrustedSetOwner = {
    enabled = true,
    spawnWindowMs = 15000,
    maxDistance = 7.5,
    -- At most `max` grants per player per `window` ms.
    rateLimit = { max = 5, window = 60000 },
    log = true,
}

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
    -- Items that start the lockpick flow when used from the inventory (and that
    -- the server accepts as the pick for it). Falls back to { item } when empty.
    items = { 'lockpick', 'advancedlockpick' },
    -- Register the items above as usable (via kora_core, so kora_inventory and
    -- other inventory providers route "Use" to the lockpick flow). Set false if
    -- another resource already registers them.
    registerUsable = true,
    -- Failures of the on-foot lockpick (not the driver-seat hotwire) show the
    -- "Lockpicking Failed" wording from Config.Text instead of the hotwire text.
    lockpickFailureText = true,
    -- With no vehicle in reach, a lockpick next to a lockpickable door
    -- (kora_doorlock) picks the door instead of showing the vehicle error.
    doorFallback = true,
    breakChance = { success = 5, failure = 25 },
    difficulty = {
        attempts = 2,
        pinCount = 4,
        tolerance = 0.12,
        speed = 0.85,
        timeLimit = 12000,
    },
}

-- Stock qb-vehiclekeys engine key (`engine` command, G). Only works for the
-- driver of a vehicle the server says they hold keys (or job access) for.
Config.EngineKeybind = {
    name = 'vehiclekeys:toggle-engine',
    description = 'Toggle the engine of your vehicle',
    defaultKey = 'G',
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
    -- Print technical hotwire failures (e.g. no response from the server) to
    -- the client console. Players only ever see Config.Text.hotwireFailed.
    debug = false,
}

-- Notification titles and configurable fallback text. Fixed messages use locales/en.lua.
-- Hotwire notifications use the hotwire titles, key/lock notifications use keys.
Config.Text = {
    titleKeys = 'Vehicle Keys',
    titleHotwire = 'Hotwire',
    titleHotwireFailed = 'Hotwire Failed',
    -- Shown instead of the hotwire failure texts when an on-foot lockpick fails
    -- (see Config.Lockpick.lockpickFailureText).
    titleLockpickFailed = 'Lockpicking Failed',
    lockpickFailed = 'You failed to pick the lock.',
    -- Using a lockpick item with no vehicle in reach / when no pick is needed.
    lockpickNoVehicle = 'There is no vehicle close enough to lockpick.',
    lockpickNotNeeded = 'You do not need a lockpick for this vehicle.',
    -- Shown when hotwiring fails and the server gives no specific reason
    -- (callback rate limit, timeout or a server-side error).
    hotwireFailed = 'Attempt to hotwire vehicle failed.',
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
