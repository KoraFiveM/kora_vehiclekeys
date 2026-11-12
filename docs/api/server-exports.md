---
title: "Server exports"
sidebar_position: 2
---


# Server exports

Three exports register under the resource's own name (`giveKeys`, `removeKeys`, `hasKeys`). Three more, `HasKeys`, `GiveKeys` and `RemoveKeys`, are bridged to the stock name `qb-vehiclekeys` with `Kora.compat.provideExport`. They are the only exports that other server resources should call.

Namespace: `exports.kora_vehiclekeys · exports['qb-vehiclekeys']` · Source: `server/main.lua`

## How it works

Session keys are stored in a local table `temporaryKeys[src][plate]`. A value of `true` is an ordinary key (valid only while `Config.AllowTemporaryKeys` is `true`) and `'hotwired'` is a key that always counts. The table is cleared for a player on `playerDropped`. Keys are never written to disk, so use physical key items for keys that must survive a restart.

## Give and check a key

1. **Create the vehicle** — Spawn or hand over the vehicle in your resource and read its plate with `GetVehicleNumberPlateText`.
2. **Call giveKeys** — Pass the player's server id and the plate. Check the boolean: `false` means an invalid plate or disabled temporary keys.
3. **Check when needed** — Use `hasKeys` for plate or item keys. Do not use it to test job vehicle access.
4. **Remove when done** — Call `removeKeys` when a rental or loan ends. Item keys are not removed by it.

## Terms used on this page

| Term | Meaning |
| --- | --- |
| Session key | A key held in server memory for one player and one normalised plate until the player disconnects or the resource restarts. |
| Physical key | An inventory item named `Config.PhysicalKey.item` whose `info` matches `Config.PhysicalKey.metadata`. |
| Normalised plate | The plate trimmed, uppercased, with internal whitespace collapsed to single spaces, at most 32 characters, any characters. |

## Functions

Server exports are trusted-caller APIs: they do not receive a player claim, they take the source from your script. Never forward a client's value as `src` or `plate` without your own checks.

### `exports.kora_vehiclekeys:giveKeys(src, plate, allowWhenDisabled?) -> boolean`

Gives a player a session key for a plate. Registered with `exports('giveKeys', giveKeys)` in `server/main.lua`. The key lives in server memory until the player drops, the plate is removed with `removeKeys`, or the resource restarts. The client is told with the push `kora_vehiclekeys:client:keysChanged` so its access cache is cleared.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer | Required. Player server id. The function does not check that the player is online: a `nil` source raises a Lua error (it is used as a table index), and a number for an offline player stores a key that nobody can ever use. |
| `plate` | string | Required. Any plate text. It is normalised with `Kora.vehicle.normalizePlate` (trim, uppercase, collapse spaces, maximum 32 characters, any characters allowed). An empty, non-string or longer value fails. |
| `allowWhenDisabled?` | boolean | Optional, defaults to nil. Not in the README but present in the code and used by `kora_truckerjob`. When truthy the key is stored as a `'hotwired'` key, which works even when `Config.AllowTemporaryKeys` is `false`. Without it the key is stored as `true` and works only while `Config.AllowTemporaryKeys` is `true`. |

**Returns**

- **true** — the key was stored.
- **false** — the plate could not be normalised, or `Config.AllowTemporaryKeys` is `false` and `allowWhenDisabled` was not passed.

**Example**

```lua
-- server: a rental script hands out a car
local vehicle = CreateVehicle(joaat('panto'), coords.x, coords.y, coords.z, heading, true, true)
local plate = GetVehicleNumberPlateText(vehicle)

if not exports.kora_vehiclekeys:giveKeys(src, plate) then
    print(('rental: keys for %s were not granted'):format(plate))
end

-- item-only server: force a session key anyway
exports.kora_vehiclekeys:giveKeys(src, plate, true)
```

**Representative console output**

```text
-- true: hasKeys(src, plate) is now true
-- false: invalid plate or Config.AllowTemporaryKeys = false
```

### `exports.kora_vehiclekeys:removeKeys(src, plate) -> boolean`

Removes the player's session key for a plate (either kind). Does not touch inventory key items, so a `Config.PhysicalKey` item still grants access afterwards. Pushes `kora_vehiclekeys:client:keysChanged` to the player.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer | Required. Player server id. A `nil` source raises an error because the table lookup uses it as a key. |
| `plate` | string | Required. Normalised the same way as in `giveKeys`. |

**Returns**

- **true** — the player has a key table; the entry for the plate is cleared (this also happens when the player held no such key).
- **false** — the plate could not be normalised, or the player has never received any session key (no table exists for them yet).

**Example**

```lua
-- server: rental ended
local done = exports.kora_vehiclekeys:removeKeys(src, rental.plate)
if exports.kora_vehiclekeys:hasKeys(src, rental.plate) then
    -- still true: the player holds a key item or the job rule applies elsewhere
    print('player still has access through a physical key')
end
```

**Representative console output**

```text
-- done == true after a previous giveKeys
-- done == false if the player never had any session key
```

### `exports.kora_vehiclekeys:hasKeys(src, plate) -> boolean`

Tells whether a player holds a key for a plate: a session key (subject to `Config.AllowTemporaryKeys`) or, with `Config.PhysicalKey.enabled`, a matching key item looked up through `exports.kora_core:getItemsByName`. Job vehicle access is NOT included because it depends on the vehicle model.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer | Required. Player server id. A `nil` source raises an error. |
| `plate` | string | Required. Normalised as in `giveKeys`. |

**Returns**

- **true** — a session key or a matching key item was found.
- **false** — the plate could not be normalised or no key was found.

**Example**

```lua
-- server: only let key holders refuel through a custom station
local function canUseStation(src, vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    return exports.kora_vehiclekeys:hasKeys(src, plate)
end
```

**Representative console output**

```text
-- true when the player has the key, false otherwise
```

### `exports['qb-vehiclekeys']:HasKeys(src, plate) -> boolean`

Stock-compatible alias registered with `Kora.compat.provideExport('qb-vehiclekeys', 'HasKeys', ...)`. Reads the same policy as `hasKeys`. Not available as `exports.kora_vehiclekeys:HasKeys`.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer | Required. Must be a number with an integer value of at least 1, otherwise the alias returns `false` (no error). |
| `plate` | string | Required. Normalised as in `giveKeys`. |

**Returns**

boolean — same result as `hasKeys`; `false` for an invalid `src`.

**Example**

```lua
local ok = exports['qb-vehiclekeys']:HasKeys(src, plate)
```

**Representative console output**

```text
-- ok == true when the player holds a key
```

### `exports['qb-vehiclekeys']:GiveKeys(src, plate?) -> boolean`

Stock-compatible alias of `giveKeys` for server scripts. Maps straight to `giveKeys`, so `Config.AllowTemporaryKeys` still applies. The arguments `(plate, src)` are tolerated in swapped order when the first is a string and the second a number.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer | Required. Must be an online player (an integer of at least 1 whose ped exists); otherwise `false`. |
| `plate?` | string | Optional. When omitted (nil) the plate of the vehicle the player currently sits in is used. If the player is on foot, the result is `false`. |

**Returns**

boolean — result of `giveKeys`; `false` when the player is offline.

**Example**

```lua
-- server: give keys for the vehicle the player is sitting in
exports['qb-vehiclekeys']:GiveKeys(src)

-- explicit plate
exports['qb-vehiclekeys']:GiveKeys(src, 'QB 123')
```

**Representative console output**

```text
-- true when a key was stored
```

### `exports['qb-vehiclekeys']:RemoveKeys(src, plate) -> boolean`

Stock-compatible alias of `removeKeys`, with the same swapped-argument tolerance and an online check.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer | Required. Must be an online player; otherwise `false`. |
| `plate` | string | Required. Normalised as in `giveKeys`. |

**Returns**

boolean — result of `removeKeys`; `false` when the player is offline.

**Example**

```lua
exports['qb-vehiclekeys']:RemoveKeys(src, 'QB 123')
```

**Representative console output**

```text
-- true when the player's key table existed
```

## Limits and related APIs

Only the three own-name exports and the three `qb-vehiclekeys` aliases exist. `exports['qb-vehiclekeys']:giveKeys` (lowercase) or any other stock name is not bridged. `provide` in the manifest only satisfies dependency resolution. The exports do not check that `src` is an online player, apart from the three stock aliases.

## Related guides

- [Client exports](./client-exports.md)
- [Configuration](./configuration.md)

## Quick reference

Summary of the own-name exports (the full signatures above are authoritative):

| Export | Returns | Description |
| --- | --- | --- |
| `exports.kora_vehiclekeys:giveKeys(source, plate)` | boolean | Grants a session key and tells the client. Returns `false` for an invalid plate or when `Config.AllowTemporaryKeys` is `false` (unless the third argument is passed). |
| `exports.kora_vehiclekeys:removeKeys(source, plate)` | boolean | Removes the player's session key. |
| `exports.kora_vehiclekeys:hasKeys(source, plate)` | boolean | `true` for a session key, hotwire key or matching physical key. Job access is not included. |

Call `giveKeys` after a garage, dealership, rental or job resource has handed a vehicle to the player. The stock aliases are provided with `Kora.compat.provideExport('qb-vehiclekeys', ...)`; the events and callbacks of the compatibility layer are in [Compatibility](../compatibility.md) and [Events and callbacks](../events.md).
