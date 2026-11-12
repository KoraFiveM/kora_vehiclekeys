---
title: "How to use"
sidebar_position: 3
---


# How to use

Players press L to lock or unlock the nearest vehicle, G to toggle the engine and U to hotwire. Developers mostly use three server exports to hand out and check keys, and a few config tables to choose how access is proven.

## Give keys from your own resource

Use `giveKeys` after your script has handed a vehicle to a player (garage, dealership, rental, job vehicle). Plates are trimmed, uppercased and have internal whitespace collapsed before storage, so `'qb 123 '` and `'QB 123'` are the same key.

```lua title="server.lua"
-- server script of a garage / rental / job resource, after the vehicle exists
local ok = exports.kora_vehiclekeys:giveKeys(src, GetVehicleNumberPlateText(vehicle))
if not ok then
    print('could not give keys (invalid plate or Config.AllowTemporaryKeys = false)')
end

-- later, when the rental ends
exports.kora_vehiclekeys:removeKeys(src, plate)

-- check a plate (keys only, job vehicle access is NOT included)
if exports.kora_vehiclekeys:hasKeys(src, plate) then
    print('player holds a key for', plate)
end
```

## How access is decided

The server function `hasVehicleAccess` allows an action when ANY of these is true (all checked against the real networked vehicle, never against a client claim):

- The player has a session key for the plate: a key from `giveKeys` while `Config.AllowTemporaryKeys` is `true`, or a key made by hotwiring or by a `giveKeys` call that passes the third argument (see `giveKeys`).
- `Config.PhysicalKey.enabled` is `true` and the player owns an item named `Config.PhysicalKey.item` whose `info` matches `Config.PhysicalKey.metadata` for the plate.
- The player's job (read with `exports.kora_core:getPlayerData(src, { 'job' })`) is a key of `Config.JobVehicles` and the vehicle model is in that job's list. This path ignores on-duty status. The separate trusted-grant path for stock `/car` requires on-duty.

> **Note:** `exports.kora_vehiclekeys:hasKeys` reports only the first two (plate keys and item keys). A police officer driving a listed model has access but `hasKeys` still returns `false`.

## Job vehicles without keys

List the exact spawn names (or numeric model hashes) per job. The server compares the model of the actual vehicle, so renaming a label does nothing.

```lua title="config.lua"
-- config.lua
Config.JobVehicles = {
    police = { 'police', 'police2', 'police3' },
    ambulance = { 'ambulance' },
}
```

## Physical keys

Turn on `Config.PhysicalKey.enabled` to require an inventory item. Metadata values may be literals, the string `'{plate}'` (the vehicle's normalised plate) or `true` (shorthand for the plate). The plate comparison normalises both sides, so `info.plate = 'qb 123'` matches `QB 123`. Keep `Config.AllowTemporaryKeys = true` if other resources still use `giveKeys`, or set it to `false` for an item-only server.

```lua title="config.lua"
-- config.lua
Config.PhysicalKey = {
    enabled = true,
    item = 'vehiclekey',
    metadata = { plate = '{plate}' },  -- or { plate = '{plate}', keyType = 'standard' }
}

-- Item metadata (Kora Core item "info") for plate "QB 123":
-- { plate = 'QB 123' }
```

## Lock, ignition, hotwire and lockpick flow

- Lock toggle (L, the `togglelocks` command, or using the key item): the client sends the vehicle network id to the callback `kora_vehiclekeys:server:toggleRequested`. The server validates the vehicle (networked, same routing bucket, within `Config.RemoteDistance`), checks access, flips the replicated state bag `kora_vehiclekeys:locked` and pushes the new state to every client, which applies `SetVehicleDoorsLocked`.
- Ignition: when `Config.RequireKeyToStart` is `true`, a client loop checks the vehicle you drive and switches the engine off whenever the server callback `accessRequested` says you have no access. The answer is cached for `Config.AccessCacheMs`.
- Hotwire (U, or a lockpick item used from the driver seat): the server checks that you have no access and hold a pick, then authorises a Kora Lib lockpick minigame. On success it unlocks the doors and, if `Config.Hotwire.grantTemporaryKey` is `true`, gives a session key.
- Lockpick on foot (a lockpick item used next to a locked vehicle): same flow, but the vehicle must be locked, and success only unlocks the doors and gives no key.
- On foot with no vehicle in reach: if `Config.Lockpick.doorFallback` is not `false` and `kora_doorlock` is running (`GetResourceState('kora_doorlock') == 'started'`), the pick is handed to `exports.kora_doorlock:pickClosestDoor()` instead of showing the vehicle error. This is a soft integration — not declared in `fxmanifest.lua` and never required.
- Pick breakage is rolled on the server with `Config.Lockpick.breakChance`; the client cannot ask for an item to be removed.

## Where the other Kora resources use it

- `kora_dealership` calls `exports.kora_vehiclekeys:giveKeys(target, plate)` after a purchase.
- `kora_core` (qb-vehicles compatibility) calls `giveKeys(src, plate)` for vehicles spawned through its server callbacks when `grantKeys` is on and this resource is started.
- `kora_truckerjob` calls `exports[Config.KeysResource or 'kora_vehiclekeys']:giveKeys(source, plate, true)`, using the optional third argument.
- `kora_inventory` reads the `kora_vehiclekeys:locked` state bag to refuse trunk access to a locked vehicle (a setting in its own config).
