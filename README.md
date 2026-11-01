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
| event `qb-vehiclekeys:server:GiveVehicleKeys(receiver, plate)` | Sender must hold the key; receiver must be online and within `Config.InteractionDistance`. |
| event `qb-vehiclekeys:server:AcquireVehicleKeys(plate)` and client events `qb-vehiclekeys:client:AddKeys`, `vehiclekeys:client:SetOwner` | **Ignored by default** (a client naming a plate would be a self-grant). With `Config.LegacyClientGrants = true`, honoured only for the vehicle the player is driving with a matching plate (this lets a driver skip hotwiring). |
| client event `qb-vehiclekeys:client:RemoveKeys(plate)` | Drops the player's own temporary key. |

Not mapped: server-to-client `TriggerClientEvent('qb-vehiclekeys:client:AddKeys', ...)` from other server scripts cannot grant keys (the server cannot intercept it); use `exports['qb-vehiclekeys']:GiveKeys(src, plate)` or `exports.kora_vehiclekeys:giveKeys`. `ToggleEngine`, `breakLockpick` and client-side exports other than `HasKeys` are not provided. Stock events are throttled to one call per 500 ms per player.

## Lock feedback

After a successful lock or unlock, `Config.lockFeedback` controls the confirmation: `sound` (key-fob chirp for the player), `soundNearby`/`soundRange` (also audible to others in range), `lights` (indicator and headlight flash everyone nearby sees), `animation` (fob animation on foot), `notify` (top-right notification) and `textUI` (bottom-centre Locked/Unlocked for about 1.5 s). Defaults: sound, lights and notify on; soundNearby and textUI off. Failed attempts (no key, out of range) give no feedback. Values are read on each toggle.

Bikes and bicycles are never given the native locked-door status, because it stops a player lifting a fallen bike. A locked bike stays blocked for players without its key (they see "This bike is locked."); key holders can always pick it up. `Config.allowPickupLockedBikes = true` lets anyone pick up a locked bike. Read live.
