---
title: Commands and keybinds
sidebar_position: 7
---

# Commands and keybinds

## Commands

| Command | Access | Description |
| --- | --- | --- |
| `/givekeys [id]` | Everyone | Hand over keys to a player. Without an id: every other player in your vehicle, else the closest player within 1.5 m. Requires that you hold the key. |
| `/addkeys id plate` | `admin` permission | Grant a session key to a player. Fails with a notification if `Config.AllowTemporaryKeys` is `false`. Logged. |
| `/removekeys id plate` | `admin` permission | Remove a player's session key. Logged. |
| `/togglelocks` | Everyone | Same as the lock keybind (client command). |
| `/engine` | Everyone | Same as the engine keybind (client command). |

Admin permission is checked with `exports.kora_core:hasPermission(src, 'admin')`. Both admin commands validate that the target is online and the plate is valid, print to the server console and call `Kora.logging.event` with `vehiclekeys:addkeys` or `vehiclekeys:removekeys`. These commands are server-side `Kora.commands`; `/givekeys` from the console does nothing.

## Keybinds

Registered through `Kora.keybind`; players can rebind them in the FiveM key bindings settings.

| Name | Default | Action |
| --- | --- | --- |
| `vehiclekeys:toggle-lock` | `L` | Lock or unlock the nearest vehicle. |
| `vehiclekeys:toggle-engine` | `G` | Toggle the engine of the vehicle you drive, if you have access. |
| `vehiclekeys:hotwire` | `U` | Hotwire the vehicle you drive. Registered only when `Config.Hotwire.enabled`. |
