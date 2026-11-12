---
title: Installation
sidebar_position: 2
---

# Installation

## Dependencies

Declared in `fxmanifest.lua`:

| Resource | Used for |
| --- | --- |
| `kora_lib` | Shared library loaded through `@kora_lib/init.lua`: callbacks, push events, keybinds, notifications, vehicle plate normalisation, network entity validation, lockpick minigame proofs, config schema, text UI, compat exports. |
| `kora_core` | Player data (`getPlayerData`), inventory (`getItemsByName`, `getItemByName`, `removeItem`), usable items (`createUseable`), `hasPermission`, and `getByPlate`. |

Used but not declared:

| Resource | Used for |
| --- | --- |
| `kora_inventory` | Not referenced by this resource's code; the item functions above are called on `kora_core`. Start it before this resource if your server uses it for items. |
| `kora_doorlock` | Optional. When a lockpick is used on foot with no vehicle in reach and `Config.Lockpick.doorFallback` is not `false`, the client calls `exports.kora_doorlock:pickClosestDoor()` if that resource is started. |

## Steps

1. Place the resource folder `kora_vehiclekeys` in your resources directory.
2. Ensure it after `kora_lib` and `kora_core`.
3. Review [Configuration](./configuration.md). For item-based keys, set `Config.PhysicalKey.enabled = true` and register the key item (default name `vehiclekey`) in your item registry.
4. Register the lockpick items `lockpick` and `advancedlockpick` in your item registry (or whatever you put in `Config.Lockpick.items`).
5. From your garage, dealership, rental or job resource call `exports.kora_vehiclekeys:giveKeys(source, plate)` when a vehicle is handed to a player. See [Exports](./exports.md).

The manifest declares `provide 'qb-vehiclekeys'`, so do not run the stock `qb-vehiclekeys` alongside it.

## Tests

`test/run.sh` runs the offline Lua smoke tests in `test/smoke/` (set `LUA` to choose the interpreter). `tests/*.feature` are `kora_qa` Gherkin scenarios, registered with `qa_feature` in the manifest.
