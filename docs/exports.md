---
title: Exports
sidebar_position: 8
---

# Exports

## Server exports of kora_vehiclekeys

| Export | Returns | Description |
| --- | --- | --- |
| `exports.kora_vehiclekeys:giveKeys(source, plate)` | boolean | Grants a session key and tells the client. Returns `false` for an invalid plate or when `Config.AllowTemporaryKeys` is `false`. |
| `exports.kora_vehiclekeys:removeKeys(source, plate)` | boolean | Removes the player's session key. |
| `exports.kora_vehiclekeys:hasKeys(source, plate)` | boolean | `true` for a session key, hotwire key or matching physical key. Job access is not included. |

```lua
exports.kora_vehiclekeys:giveKeys(source, plate)
local hasKeys = exports.kora_vehiclekeys:hasKeys(source, plate)
exports.kora_vehiclekeys:removeKeys(source, plate)
```

Call `giveKeys` after a garage, dealership, rental or job resource has handed a vehicle to the player.

## qb-vehiclekeys exports (compat)

Provided with `Kora.compat.provideExport('qb-vehiclekeys', ...)`.

| Side | Export | Description |
| --- | --- | --- |
| server | `HasKeys(src, plate)` | Same as `hasKeys`; returns `false` for an invalid source. |
| server | `GiveKeys(src, plate)` | Maps to `giveKeys`. Without a plate uses the vehicle the player is in. Swapped arguments are tolerated. The player must be online. |
| server | `RemoveKeys(src, plate)` | Maps to `removeKeys`. |
| client | `HasKeys(plate)` | Read-only callback for the local player's own keys; may yield, returns `false` on invalid input or timeout. |
| client | `addNoLockVehicles(model)` | Name or hash. This client stops starting lock toggles for the model. The server ignores the list. |
| client | `removeNoLockVehicles(model)` | Undo the above. |
