---
title: "Commands"
sidebar_position: 4
---


# Commands

Three chat commands are registered on the server through `Kora.commands.add` and two on the client with `RegisterCommand`. The main controls are keybinds (L lock, G engine, U hotwire), not commands. The keybinds come from Kora Lib's `Kora.keybind.add` and players can rebind them in FiveM key bindings.

## Commands

### `/givekeys [id]`

Hands a copy of your key to someone. The server command only triggers the client event `qb-vehiclekeys:client:GiveKeys` for you; the client then picks the receivers and the server decides.

| Field | Details |
| --- | --- |
| Context | In-game · server command (Kora Core) |
| Arguments | id? — optional server id of the receiver. |
| Access | Everyone. Ignored when run from the server console. The server then requires that you hold the key and that each receiver is online, is not you and is within `Config.InteractionDistance` of you (at most 8 receivers). |

**Example**

```text
/givekeys
/givekeys 12
```

**Result**

Without an id the client uses every other player in your vehicle, otherwise the closest player within 1.5 m. Messages: "You don't have keys to this vehicle.", "There is nobody nearby to hand keys to", or the receivers are told "You get keys to the vehicle!".

### `/addkeys <id> <plate>`

Gives a player a session key for a plate by calling the same `giveKeys` logic as the export. Writes an audit line (console print and `Kora.logging.event` as `vehiclekeys:addkeys`).

| Field | Details |
| --- | --- |
| Context | In-game or console · server command |
| Arguments | id — target server id (must be online). plate — vehicle plate. |
| Access | Requires the `admin` permission, checked with `exports.kora_core:hasPermission(src, 'admin')`. |

**Example**

```text
/addkeys 12 QB123
```

**Result**

On bad arguments: "Fill out the player ID and Plate arguments". If `Config.AllowTemporaryKeys` is `false`: "Temporary keys are disabled." and nothing is logged.

### `/removekeys <id> <plate>`

Removes the session key of a player for a plate (calls `removeKeys`). Writes the audit line `vehiclekeys:removekeys`. It does not remove inventory key items.

| Field | Details |
| --- | --- |
| Context | In-game or console · server command |
| Arguments | id — target server id (must be online). plate — vehicle plate. |
| Access | Requires the `admin` permission. |

**Example**

```text
/removekeys 12 QB123
```

**Result**

The audit entry is written even when the player did not hold that key.

### `/togglelocks`

Same flow as pressing the lock keybind: toggles the lock of the vehicle you are in, or the closest vehicle within `Config.RemoteDistance`.

| Field | Details |
| --- | --- |
| Context | In-game · client command |
| Arguments | None. |
| Access | Everyone, but the server still requires a key, a matching key item or job access. |

**Example**

```text
/togglelocks
```

**Result**

Notification "Vehicle locked." or "Vehicle unlocked." (when `Config.lockFeedback.notify` is not false), or the server reason such as "You do not have the keys for this vehicle.". Registered with `restricted = false`.

### `/engine`

Same flow as the engine keybind. Driver only; the server must confirm keys or job access.

| Field | Details |
| --- | --- |
| Context | In-game · client command |
| Arguments | None. |
| Access | Everyone in the driver seat; silent otherwise. |

**Example**

```text
/engine
```

**Result**

The engine switches on or off when the server confirms access. Nothing is shown when it refuses.

## Keybinds

Registered with `Kora.keybind.add`: `Config.Keybind` (default `L`, toggle lock), `Config.EngineKeybind` (default `G`, toggle engine) and, only when `Config.Hotwire.enabled`, `Config.Hotwire.keybind` (default `U`, hotwire the vehicle you drive).

| Name | Default | Action |
| --- | --- | --- |
| `vehiclekeys:toggle-lock` | `L` | Lock or unlock the nearest vehicle. |
| `vehiclekeys:toggle-engine` | `G` | Toggle the engine of the vehicle you drive, if you have access. |
| `vehiclekeys:hotwire` | `U` | Hotwire the vehicle you drive. Registered only when `Config.Hotwire.enabled`. |

## Command summary

| Command | Access | Description |
| --- | --- | --- |
| `/givekeys [id]` | Everyone | Hand over keys to a player. Without an id: every other player in your vehicle, else the closest player within 1.5 m. Requires that you hold the key. |
| `/addkeys id plate` | `admin` permission | Grant a session key to a player. Fails with a notification if `Config.AllowTemporaryKeys` is `false`. Logged. |
| `/removekeys id plate` | `admin` permission | Remove a player's session key. Logged. |
| `/togglelocks` | Everyone | Same as the lock keybind (client command). |
| `/engine` | Everyone | Same as the engine keybind (client command). |

Both admin commands validate that the target is online and the plate is valid, print to the server console and call `Kora.logging.event` with `vehiclekeys:addkeys` or `vehiclekeys:removekeys`. `/givekeys` from the console does nothing.
