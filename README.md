# qbvehiclekeys

Server-authoritative vehicle locks, ignition checks, physical vehicle keys, and hotwiring. It uses qblib keybinds, notifications, secure callbacks/events, and the proof-backed qblib lockpick minigame. Item access is checked on the server through qbcore's inventory exports.

## Setup

Start `qbvehiclekeys` after `qbcore` and `qbinventory`. The included server configuration does this already. In normal mode, the resource keeps granted keys only for a player's current session:

```lua
exports.qbvehiclekeys:giveKeys(source, plate)
exports.qbvehiclekeys:removeKeys(source, plate)
local hasKeys = exports.qbvehiclekeys:hasKeys(source, plate)
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

The outer keys are qbcore job names and each list contains vehicle spawn names. The server checks the player's current job and the actual networked vehicle model before allowing ignition or lock controls. This access does not make `exports.qbvehiclekeys:hasKeys` return true because that export reports plate-key ownership only.

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
