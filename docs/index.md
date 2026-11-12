---
title: kora_vehiclekeys
sidebar_position: 1
---

# kora_vehiclekeys

`kora_vehiclekeys` provides server-authoritative vehicle locks, ignition checks, session keys, optional physical key items, lockpicking and hotwiring for Kora servers. It also `provide`s `qb-vehiclekeys`, so scripts written for the stock resource keep working. Every decision (who holds a key, whether a vehicle is in range, whether a lockpick succeeded) is made on the server.

Current version: see `version` in `fxmanifest.lua`.

## Features

- **Lock and unlock** - the `L` keybind (or `/togglelocks`) toggles the nearest vehicle within `Config.RemoteDistance`. The lock state is stored in the entity state bag `kora_vehiclekeys:locked` and applied to the doors on clients.
- **Ignition check** - with `Config.RequireKeyToStart` the engine is forced off for a driver who has no key and no job access. `G` or `/engine` toggles the engine for a driver with access.
- **Keys** - session-only virtual keys granted by exports or admin commands, and optional physical key items matched by metadata. See [Keys and access](./keys.md).
- **Job vehicles** - jobs can use listed models without a key. See [Configuration](./api/configuration.md).
- **Hotwiring and lockpicking** - server-authorised lockpick minigame from the driver seat (hotwire) or on foot next to a locked vehicle. See [Lockpicking and hotwiring](./lockpicking.md).
- **Key sharing** - `/givekeys` hands your key to nearby players.
- **Lock feedback and bikes** - sound, lights, animation, notification and text UI after a toggle, and a guard for locked bikes. See [Lock feedback and bikes](./feedback.md).
- **qb-vehiclekeys compatibility** - stock exports, events, callbacks and commands. See [Compatibility](./compatibility.md).

## Documentation map

- [Installation](./installation.md) - dependencies, manifest, start order and tests.
- [How to use](./how-to-use.md) - giving keys from your resource, how access is decided, job vehicles, physical keys and the lock, ignition, hotwire and lockpick flows.
- [Commands and keybinds](./commands.md) - `/givekeys`, `/addkeys`, `/removekeys`, `/togglelocks`, `/engine` and the keybinds.
- [API reference](./api/index.md) - overview of the exports and config.
  - [Server exports](./api/server-exports.md) - `giveKeys`, `removeKeys`, `hasKeys` and the stock aliases.
  - [Client exports](./api/client-exports.md) - `HasKeys`, `addNoLockVehicles`, `removeNoLockVehicles`.
  - [Configuration](./api/configuration.md) - every `Config` option with defaults, rate limits and constants.
- [Keys and access](./keys.md) - how access is decided, plates and physical key metadata.
- [Lockpicking and hotwiring](./lockpicking.md) - lockpick flows, items and break chances.
- [Lock feedback and bikes](./feedback.md) - feedback options and the locked bike guard.
- [Events and callbacks](./events.md) - callbacks, net events, push events and the state bag.
- [Compatibility](./compatibility.md) - qb-vehiclekeys surface and trusted SetOwner.
- [Troubleshooting](./troubleshooting.md) - common problems.

## Storage

The resource has no database tables, SQL files, NUI pages or locale files. Keys live in server memory and are lost on logout, disconnect and resource restart. The only database read is a plate ownership lookup through `kora_core`'s `getByPlate` (see [Compatibility](./compatibility.md)).
