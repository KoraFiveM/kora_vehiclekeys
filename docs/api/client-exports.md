---
title: "Client exports"
sidebar_position: 3
---


# Client exports

Three client exports, all bridged to the stock resource name `qb-vehiclekeys` with `Kora.compat.provideExport`. There is no client export under `kora_vehiclekeys`.

Namespace: `exports['qb-vehiclekeys']` · Source: `client/compat.lua, client/stock.lua`

## How it works

`HasKeys` is a thin read-only wrapper over a rate-limited server callback. The two model-list functions only change a client-local table `VehicleKeys.noLockModels` that is consulted by `toggleNearestVehicle`.

## Functions

Call them from client scripts only. The no-lock list is not shared with the server or other players and is lost on restart.

### `exports['qb-vehiclekeys']:HasKeys(plate) -> boolean`

Asks the server whether the local player holds a key for the plate. Registered in `client/compat.lua` and implemented with the callback `kora_vehiclekeys:server:legacyHasKeys`, so it yields. Read-only: it never grants keys. It is not available as `exports.kora_vehiclekeys:HasKeys`.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `plate` | string | Required. A non-empty string of at most 32 characters; anything else returns `false` without calling the server. |

**Returns**

- **true** — the server says the local player holds a session key or a matching key item.
- **false** — invalid plate, or the server says no.

**Example**

```lua
-- client script
local plate = GetVehicleNumberPlateText(vehicle)
local ok, has = pcall(function() return exports['qb-vehiclekeys']:HasKeys(plate) end)
if ok and has then
    print('I hold the key for', plate)
end
```

**Representative console output**

```text
-- has == true when the player holds a key
-- the callback is limited by Config.RateLimits.access (20 per 10 seconds by default)
```

### `exports['qb-vehiclekeys']:addNoLockVehicles(model)`

Stock-compatible. Marks a vehicle model as one this client will not start lock toggles for. Advisory and client-local: the server never reads the list, so it cannot unlock or exempt any vehicle.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `model` | string \| integer | Required. Model name (hashed with `joaat`) or a numeric model hash. An empty string or another type is ignored silently. |

**Returns**

No value.

**Example**

```lua
exports['qb-vehiclekeys']:addNoLockVehicles('faggio')
```

**Representative console output**

```text
-- pressing L next to a faggio no longer sends a toggle request from this client
```

### `exports['qb-vehiclekeys']:removeNoLockVehicles(model)`

Removes a model added with `addNoLockVehicles`.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `model` | string \| integer | Required. Model name or hash. Invalid values are ignored silently. |

**Returns**

No value.

**Example**

```lua
exports['qb-vehiclekeys']:removeNoLockVehicles('faggio')
```

**Representative console output**

```text
-- the model can be toggled again
```

## Limits and related APIs

`HasKeys` calls `Kora.callback.trigger` without a `pcall`. The README says a timeout returns `false`; the code comments elsewhere in the client say Kora Lib raises on a timeout or rate limit, so wrap the call in `pcall` if the result must never raise. This was not confirmed against kora_lib.

## Related guides

- [Server exports](./server-exports.md)

## Compatibility notes

`addNoLockVehicles` and `removeNoLockVehicles` accept a name or a hash; the server ignores the list. A server script cannot grant keys through the client events `qb-vehiclekeys:client:AddKeys` or `vehiclekeys:client:SetOwner`; use the exports in [Server exports](./server-exports.md). See [Compatibility](../compatibility.md).
