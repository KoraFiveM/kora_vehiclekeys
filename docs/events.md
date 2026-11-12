---
title: Events and callbacks
sidebar_position: 9
---

# Events and callbacks

Kora events and callbacks go through `kora_lib` (`Kora.events`, `Kora.callback`). Rate limits are in [Configuration](./api/configuration.md).

## Server callbacks

| Name | Arguments | Result |
| --- | --- | --- |
| `kora_vehiclekeys:server:accessRequested` | network id | `true` when the player is the driver within `Config.InteractionDistance` and has access. |
| `kora_vehiclekeys:server:toggleRequested` | network id | New locked state, or `nil` plus an error message. Vehicle must be within `Config.RemoteDistance`. |
| `kora_vehiclekeys:server:hotwireStarted` | network id | Minigame authorisation or `nil` plus a message. |
| `kora_vehiclekeys:server:lockpickStarted` | network id | Minigame authorisation or `nil` plus a message. |
| `kora_vehiclekeys:server:legacyHasKeys` | plate | Whether the caller holds the key. Read-only. |
| `qb-vehiclekeys:server:GetVehicleKeys` | none | Table of the caller's plates set to `true`. |
| `qb-vehiclekeys:server:checkPlayerOwned` | plate | `true` when the caller has the key or the plate is a player-owned vehicle (also `true` if ownership cannot be read). |

## Server events (client to server)

| Name | Description |
| --- | --- |
| `kora_vehiclekeys:server:hotwireFinished` (authorisation, proof) | Ends a lockpick/hotwire session; the server validates and consumes the proof. |

Stock events are listed in [Compatibility](./compatibility.md).

## Push events (server to client)

| Name | Arguments | Effect |
| --- | --- | --- |
| `kora_vehiclekeys:client:lockStateChanged` | network id, locked | Applies the lock status to the vehicle. Sent to everyone. |
| `kora_vehiclekeys:client:lockFeedback` | network id, locked, source | Lights and nearby sound. Sent only when `lights` or `soundNearby` is on. |
| `kora_vehiclekeys:client:keysChanged` | plate, granted | Clears the client access cache. |
| `kora_vehiclekeys:client:lockpickUsed` | none | Starts the lockpick flow after a pick item is used. |
| `kora_vehiclekeys:client:physicalKeyUsed` | item info | Toggles the nearest vehicle after the key item is used. |

## State bag

`kora_vehiclekeys:locked` on the vehicle entity (replicated). Clients react to changes and apply the door lock status.
