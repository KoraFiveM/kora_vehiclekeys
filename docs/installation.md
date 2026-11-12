---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Vehiclekeys decides who may lock, unlock, start and enter a vehicle. The server owns every decision: keys are a session-only list kept in server memory, optionally backed by an inventory item whose metadata matches the plate. It also adds lockpicking and hotwiring and a qb-vehiclekeys compatibility layer.

## Install Kora Vehiclekeys

1. **Add the folder** — Place `kora_vehiclekeys` in your resources directory (on the Kora recipe it is `resources/[kora]/kora_vehiclekeys`). Keep the folder name: other resources call `exports.kora_vehiclekeys` and `kora_core` checks `GetResourceState('kora_vehiclekeys')`.

2. **Dependencies** — The manifest declares two dependencies: `kora_lib` and `kora_core`. At runtime the server code also calls `exports.kora_core` for item lookups, usable items, permissions and plate ownership, and the lockpick flow uses Kora Lib's minigame, notify, keybind, callback and events modules. The README says to start it after `kora_inventory` as well, because the keys are items looked up through Kora Core's inventory gateway. This is not enforced by the manifest. `kora_doorlock` is an optional soft integration (not a dependency): if it is running, an on-foot lockpick with no vehicle in reach is handed to it instead of failing (see `Config.Lockpick.doorFallback`).

3. **Start it after its dependencies** — Nothing in the manifest orders the start beyond the `dependencies` block, so keep this order in your config.

   ```bash title="server.cfg"
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure kora_inventory
   ensure kora_vehiclekeys
   ```

4. **Check the manifest** — Config and the Kora Lib loader are shared scripts, so both realms see `Config` and `Kora`. The client files load in the order feedback, main, compat, stock because later files use globals defined by earlier ones. The manifest `provide`s `qb-vehiclekeys` so resources that depend on the stock name resolve. Only the listed stock exports are actually bridged (see the Exports modules).

   ```lua title="fxmanifest.lua"
   fx_version 'cerulean'
   game 'gta5'
   provide 'qb-vehiclekeys'
   lua54 'yes'

   name 'kora_vehiclekeys'
   author 'qbcore2'
   version '0.2.0'
   description 'Server-authoritative vehicle keys, locks, and hotwiring for kora_lib/kora_core'

   dependencies {
       'kora_lib',
       'kora_core',
   }

   shared_scripts {
       '@kora_lib/init.lua',
       'config.lua',
   }

   client_scripts { 'client/feedback.lua', 'client/main.lua', 'client/compat.lua', 'client/stock.lua' }
   server_script 'server/main.lua'

   -- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
   qa_feature 'tests/*.feature'
   ```

## Dependency details

What each resource is used for in the code (derived from `fxmanifest.lua` and the server and client scripts):

| Resource | Declared | Used for |
| --- | --- | --- |
| `kora_lib` | yes | Shared library loaded through `@kora_lib/init.lua`: callbacks, push events, keybinds, notifications, vehicle plate normalisation, network entity validation, lockpick minigame proofs, config schema, text UI, compat exports. |
| `kora_core` | yes | Player data (`getPlayerData`), inventory (`getItemsByName`, `getItemByName`, `removeItem`), usable items (`createUseable`), `hasPermission`, and `getByPlate`. |
| `kora_inventory` | no | Not referenced by this resource's code; the item functions above are called on `kora_core`. Start it before this resource if your server uses it for items. |
| `kora_doorlock` | no | Optional. When a lockpick is used on foot with no vehicle in reach and `Config.Lockpick.doorFallback` is not `false`, the client calls `exports.kora_doorlock:pickClosestDoor()` if that resource is started. |

## Setup checklist

1. Place the resource folder `kora_vehiclekeys` in your resources directory.
2. Ensure it after `kora_lib` and `kora_core`.
3. Review [Configuration](./api/configuration.md). For item-based keys, set `Config.PhysicalKey.enabled = true` and register the key item (default name `vehiclekey`) in your item registry.
4. Register the lockpick items `lockpick` and `advancedlockpick` in your item registry (or whatever you put in `Config.Lockpick.items`).
5. From your garage, dealership, rental or job resource call `exports.kora_vehiclekeys:giveKeys(source, plate)` when a vehicle is handed to a player. See [Server exports](./api/server-exports.md).

The manifest declares `provide 'qb-vehiclekeys'`, so do not run the stock `qb-vehiclekeys` alongside it.

## Tests

`test/run.sh` runs the offline Lua smoke tests in `test/smoke/` (set `LUA` to choose the interpreter). `tests/*.feature` are `kora_qa` Gherkin scenarios, registered with `qa_feature` in the manifest.
