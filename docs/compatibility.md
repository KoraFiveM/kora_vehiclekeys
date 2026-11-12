---
title: Compatibility
sidebar_position: 10
---

# Compatibility

The manifest provides `qb-vehiclekeys`. The surface below is derived from code. Net events are untrusted input: the server re-derives key ownership, driver seat and distance. Stock events are throttled per player to one call per 500 ms (300 ms for `AcquireVehicleKeys`).

## Server events

| Event | Behaviour |
| --- | --- |
| `qb-vehiclekeys:server:setVehLockState(netId, state)` | Needs access to a vehicle within `Config.RemoteDistance`. State 2 or higher locks. |
| `qb-vehiclekeys:server:GiveVehicleKeys(receiver or list, plate)` | Sender must hold the key. At most 8 receivers, each online and within `Config.InteractionDistance`. |
| `qb-vehiclekeys:server:RemoveVehicleKeys(plate)` and `qb-vehiclekeys:server:RemoveOwnKeys(plate)` | Drop only the sender's own session key. |
| `qb-vehiclekeys:server:breakLockpick` | Accepted and ignored; breakage is rolled on the server. |
| `qb-vehiclekeys:server:AcquireVehicleKeys(netId or plate)` | See below. |

## Client events

| Event | Behaviour |
| --- | --- |
| `qb-vehiclekeys:client:GiveKeys(id)` | Gives keys as `/givekeys` does. |
| `qb-vehiclekeys:client:AddKeys(plate)`, `vehiclekeys:client:SetOwner(plate)` | Look up the vehicle by plate (current vehicle, else within 15 m) and ask the server with its network id, retrying every 400 ms up to 8 times until the server reports a key. They never grant keys themselves. |
| `qb-vehiclekeys:client:RemoveKeys(plate)` | Drop the player's own session key. |
| `qb-vehiclekeys:client:ToggleEngine` | Toggle the engine (driver with access only). |
| `lockpicks:UseLockpick` | Start the lockpick flow. |

A server script triggering `qb-vehiclekeys:client:AddKeys` on a client cannot grant keys the way stock does; use the exports in [Server exports](./api/server-exports.md) and [Client exports](./api/client-exports.md). Stock persistent keys (player metadata) are not implemented.

## Key requests and trusted SetOwner

With `Config.LegacyClientGrants = true`, `AcquireVehicleKeys` is honoured only for the vehicle the player is driving (this lets a driver skip hotwiring). Otherwise `Config.TrustedSetOwner` decides, when `enabled`. A key is granted when the player has no access yet and:

- the vehicle is networked, within `maxDistance`, is not owned (no `vehicleid` state and no `getByPlate` row for the raw or normalised plate; unreadable ownership counts as owned), is not locked, has no other holder for the plate, no other live vehicle with the same plate, and no online player with a matching physical key item; and
- either it was script-created within `spawnWindowMs` by the requester, or by the server with the requester in the driver seat, or its model is in `Config.JobVehicles` for the requester's job while `onduty` is `true`.

Grants are limited by `rateLimit` per player and printed to the server console unless `log = false`.
