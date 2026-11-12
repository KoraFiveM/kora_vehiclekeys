---
title: Lockpicking and hotwiring
sidebar_position: 7
---

# Lockpicking and hotwiring

Both flows use the `kora_lib` lockpick minigame with a server-issued authorisation and a proof that the server consumes. Both require `Config.Hotwire.enabled`.

## Hotwire (driver seat)

Triggered by the hotwire keybind (`U` by default) or by using a lockpick item while in the driver seat. Nothing happens if the engine is running or the player already has access (the item flow shows "You do not need a lockpick for this vehicle."). The server (`hotwireStarted`) checks the vehicle is in range and the player is driver, that the player has no access, and that they carry one of `Config.Lockpick.items`. On success the vehicle is unlocked and, if `Config.Hotwire.grantTemporaryKey` is `true`, a session key is granted.

## Lockpick (on foot)

Using a lockpick item next to a vehicle within `Config.InteractionDistance` calls `lockpickStarted`. The server requires the vehicle to be locked (by the state bag or by a native lock status above 1), the player to have no access, and a configured pick. Success unlocks the doors only and grants no key.

If no vehicle is in reach and `Config.Lockpick.doorFallback` is not `false`, the client tries `exports.kora_doorlock:pickClosestDoor()` when `kora_doorlock` is started.

## Items

With `Config.Lockpick.registerUsable` the items in `Config.Lockpick.items` are registered through `kora_core` `createUseable`; using one pushes `kora_vehiclekeys:client:lockpickUsed`. The stock client event `lockpicks:UseLockpick` runs the same flow. The items must exist in your item registry.

## Breakage

After each attempt, `Config.Lockpick.breakChance.success` or `.failure` percent chance removes one of the used pick through `kora_core` `removeItem`, with reason `vehicle-lockpick-broke`, and sends a "Your lockpick broke." notification. Clients cannot request removal (see `qb-vehiclekeys:server:breakLockpick` in [Compatibility](./compatibility.md)).

## Limits

The client throttles requests with the `hotwire` rate limit, and the server enforces it. A session is single-use: `hotwireFinished` with a wrong authorisation, a moved vehicle or a changed plate is ignored. Stock police alerts and stress are not implemented.
