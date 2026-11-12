# kora_vehiclekeys

Server-authoritative vehicle locks, ignition checks, physical vehicle keys, and hotwiring. It uses kora_lib keybinds, notifications, secure callbacks/events, and the proof-backed kora_lib lockpick minigame. Item access is checked on the server through kora_core's inventory exports.

## Setup

Start `kora_vehiclekeys` after `kora_core` and `kora_inventory`. The included server configuration does this already. In normal mode, the resource keeps granted keys only for a player's current session:

```lua
exports.kora_vehiclekeys:giveKeys(source, plate)
exports.kora_vehiclekeys:removeKeys(source, plate)
local hasKeys = exports.kora_vehiclekeys:hasKeys(source, plate)
```

Use `giveKeys` from a garage, dealership, rental, or job vehicle creator after it has handed a vehicle to the player. Plates are trimmed, uppercased, and internal whitespace is collapsed before lookup.

## Job vehicle access

Jobs can be allowed to use selected vehicle models without holding a plate key:

```lua
Config.JobVehicles = {
    police = { 'police', 'police2', 'police3' },
    ambulance = { 'ambulance' },
}
```

The outer keys are kora_core job names and each list contains vehicle spawn names. The server checks the player's current job and the actual networked vehicle model before allowing ignition or lock controls. This access does not make `exports.kora_vehiclekeys:hasKeys` return true because that export reports plate-key ownership only.

## Physical metadata keys

Set `Config.PhysicalKey.enabled = true`, add the named item to the shared item registry, and make each key item's `info` match `Config.PhysicalKey.metadata`. The default is:

```lua
Config.PhysicalKey = {
    enabled = true,
    item = 'vehiclekey',
    metadata = { plate = '{plate}' },
}
```

For a vehicle plate `QB 123`, its key needs `info = { plate = 'QB 123' }`. Additional static fields are supported, for example `metadata = { plate = '{plate}', keyType = 'standard' }`. A value of `true` is also shorthand for matching the normalised vehicle plate. The server always rechecks the actual inventory item; clients cannot select arbitrary metadata.

Keep `Config.AllowTemporaryKeys = true` if vehicle sources use the exports above. Set it to `false` for an item-only setup. Hotwiring can separately grant an in-memory key through `Config.Hotwire.grantTemporaryKey`.

Legacy `qb-vehiclekeys:HasKeys(source, plate)` on the server reads the existing physical/temporary key policy. The client `HasKeys(plate)` performs a rate-limited, read-only server callback for the requesting player and may yield; a timeout returns false. This alias does not grant keys, bypass metadata validation, or include job-vehicle access that is unrelated to physical keys. 

### Wider qb-vehiclekeys alias

`provide 'qb-vehiclekeys'` also covers (server authority is kept; clients never choose who gets keys):

| Stock surface | Behaviour |
|---|---|
| server export `GiveKeys(src, plate)` / `RemoveKeys(src, plate)` | Trusted server callers; map to `giveKeys` / `removeKeys` (so `Config.AllowTemporaryKeys` applies). Swapped `(plate, src)` is tolerated. |
| event `qb-vehiclekeys:server:setVehLockState(netId, state)` | Requires the sender to have access (key/job) to the validated, in-range vehicle; `state >= 2` locks. |
| server export `GiveKeys(src)` | Without a plate the vehicle the player is in is used (stock). |
| event `qb-vehiclekeys:server:GiveVehicleKeys(receiver \| {receivers}, plate)` | Sender must hold the key; each receiver (at most 8) must be online and within `Config.InteractionDistance`. |
| event `qb-vehiclekeys:server:RemoveVehicleKeys(plate)` | Drops the sender's own temporary key only; nobody else's keys can be removed. |
| callbacks `qb-vehiclekeys:server:GetVehicleKeys`, `qb-vehiclekeys:server:checkPlayerOwned(plate)` | `{ [plate] = true }` for the caller's own session keys (plus matching key items); `checkPlayerOwned` is true when the caller holds the key or the plate is a `player_vehicles` row. Other players' keys are never revealed. |
| commands `givekeys [id]`, `addkeys <id> <plate>` (admin), `removekeys <id> <plate>` (admin), `togglelocks`, `engine` | Stock names and help. `givekeys` runs the client event below; the admin ones use kora_core permissions, validate the target, and are logged through `Kora.logging` (`vehiclekeys:addkeys` / `vehiclekeys:removekeys`). `togglelocks`/`engine` run the same flows as the `L`/`G` keybinds (no extra key mapping, so keys are not bound twice). |
| client event `qb-vehiclekeys:client:GiveKeys(id)` | Stock flow: the id, else every other player in your vehicle, else the closest player within 1.5 m. Sent to the server, which checks that you hold the key and that each receiver is in range. |
| client event `lockpicks:UseLockpick(isAdvanced)` and the `lockpick` / `advancedlockpick` items | See "Lockpick items" below. |
| client exports `addNoLockVehicles(model)` / `removeNoLockVehicles(model)` | Client-local and advisory: this client stops starting lock toggles for those models. The server never reads the list, so it cannot unlock or exempt any vehicle (stock also exempted `ignoreLocks` state bags and NPC lock logic; those are not mapped). |
| event `qb-vehiclekeys:server:breakLockpick(item)` | Accepted and ignored. Kora rolls lockpick breakage on the server (`breakChance`), so a client can never ask for an item to be removed. |
| event `qb-vehiclekeys:server:AcquireVehicleKeys(netId \| plate)` and client events `qb-vehiclekeys:client:AddKeys`, `vehiclekeys:client:SetOwner` | Stock sends a vehicle network id; a plate is also accepted (resolved only against the vehicle the player is inside). The client events look the plate up locally (current vehicle first, then within 15 m) and send the network id. With `Config.LegacyClientGrants = false` (default) the request is decided by `Config.TrustedSetOwner`, below. With `Config.LegacyClientGrants = true` it is honoured only for the vehicle the player is driving (this lets a driver skip hotwiring). |
| client event `qb-vehiclekeys:client:ToggleEngine` and the engine key (`Config.EngineKeybind`, default `G`) | Driver only; the engine toggles only if the server confirms keys or job access (same check as ignition). |
| client event `qb-vehiclekeys:client:RemoveKeys(plate)` | Drops the player's own temporary key. |

Keys are session-only here. Stock persists them in player metadata (`Config.PersistentKeys`, default true), so that part is not at parity; use physical key items for keys that must survive a restart.

Not mapped: server-to-client `TriggerClientEvent('qb-vehiclekeys:client:AddKeys', ...)` from other server scripts cannot grant keys (the server cannot intercept it); use `exports['qb-vehiclekeys']:GiveKeys(src, plate)` or `exports.kora_vehiclekeys:giveKeys`. Stock events are throttled to one call per 500 ms per player.

### Lockpick items

With `Config.Lockpick.registerUsable` (default), every item in `Config.Lockpick.items` (`lockpick`, `advancedlockpick`) is registered as useable through kora_core; using one pushes `kora_vehiclekeys:client:lockpickUsed`, and the stock client event `lockpicks:UseLockpick` runs the same client flow. Set `registerUsable = false` if another resource registers the items. From the driver seat the flow is hotwiring (`hotwireStarted`): success unlocks and grants a session key per `Config.Hotwire.grantTemporaryKey`. On foot next to a locked vehicle (within `Config.InteractionDistance`) it calls `lockpickStarted`: the server checks the vehicle, that it is locked, that you have no access and that you hold a configured pick, then authorises the minigame (`Config.Lockpick.difficulty`) and on success unlocks the doors only, with no key. `Config.Lockpick.breakChance` breaks the pick that was used. Stock's police alert and stress gain on failure are not part of this resource.

### Client AddKeys / SetOwner

Client `qb-vehiclekeys:client:AddKeys` and `vehiclekeys:client:SetOwner` only ask the server (see Trusted SetOwner); a client can never grant itself a key.

### Trusted SetOwner (stock `/car` and job vehicles)

Stock qb-core `/car` and qb-policejob vehicle spawns call `vehiclekeys:client:SetOwner(plate)`. `Config.TrustedSetOwner` (`enabled`, `spawnWindowMs`, `maxDistance`, `rateLimit`, `log`) lets the server grant a temporary key for such a request, never trusting the client's claim. The vehicle must be a networked vehicle within `maxDistance` (7.5 m) of the player, must not be a `player_vehicles` row (or `vehicleid`-tagged entity; the check fails closed if ownership cannot be read), must not be locked, and no other player may hold a key for the plate. In addition either:

- the entity was created within `spawnWindowMs` by the requester (client spawn such as `/car`), or by the server (QBCore `SpawnVehicle`/`CreateVehicle`) with the requester in the driver seat; or
- its model is listed in `Config.JobVehicles` for the requester's **on-duty** job (list your police models there).

Only script-created (mission, population type 7) entities count as spawns; ambient traffic never does. A request is also refused when another live vehicle shares the plate, when any online player holds a physical key item for the plate, or when `player_vehicles` has the plate in either its raw (trimmed, upper-case) or normalised form.

The stock client events retry the request about every 400 ms for roughly 3 s (until the server confirms a key), because a fresh entity may not be known to the server on the first try. The server therefore allows this event at one call per 300 ms per player instead of 500 ms.

Grants are limited per player by `rateLimit` and logged to the server console (player id, plate, basis) unless `log = false`. Set `enabled = false` to ignore these requests entirely. `Config.LegacyClientGrants` is unchanged and stays `false` by default.

## Lock feedback

After a successful lock or unlock, `Config.lockFeedback` controls the confirmation: `sound` (key-fob chirp for the player), `soundNearby`/`soundRange` (also audible to others in range), `lights` (indicator and headlight flash everyone nearby sees), `animation` (fob animation on foot), `notify` (top-right notification) and `textUI` (bottom-centre Locked/Unlocked for about 1.5 s). Defaults: sound, lights and notify on; soundNearby and textUI off. Failed attempts (no key, out of range) give no feedback. Values are read on each toggle.

Bikes and bicycles are never given the native locked-door status, because it stops a player lifting a fallen bike. A locked bike stays blocked for players without its key (they see "This bike is locked."); key holders can always pick it up. `Config.allowPickupLockedBikes = true` lets anyone pick up a locked bike. Read live (the bike guard re-checks it every 150 ms, or every second while it is true).

Full documentation: see [docs/](docs/index.md).
