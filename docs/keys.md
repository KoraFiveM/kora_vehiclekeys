---
title: Keys and access
sidebar_position: 6
---

# Keys and access

A player has access to a vehicle when any of these is true. The server evaluates them for every lock, ignition and lockpick request.

1. **Session key** - granted by `giveKeys`, `/addkeys`, `/givekeys`, or the trusted SetOwner flow. Stored in server memory per player and keyed by normalised plate. Counts only while `Config.AllowTemporaryKeys` is `true`.
2. **Hotwire key** - granted by a successful hotwire when `Config.Hotwire.grantTemporaryKey` is `true`. It counts even if `Config.AllowTemporaryKeys` is `false`.
3. **Physical key item** - when `Config.PhysicalKey.enabled` is `true`, an inventory item named `Config.PhysicalKey.item` whose `info` matches `Config.PhysicalKey.metadata`.
4. **Job vehicle** - the player's current `kora_core` job is listed in `Config.JobVehicles` with the actual networked vehicle model. Job access applies to locks and ignition but does not make the `hasKeys` export return `true`.

Session keys are dropped on `playerDropped` and on resource restart. Use physical keys for keys that must persist.

## Plates

Plates are normalised with `Kora.vehicle.normalizePlate` (maximum length 32, any characters): trimmed, upper-cased, internal whitespace collapsed. Keys are matched against the plate read from the actual vehicle entity on the server.

## Physical key metadata

Each metadata field is compared with the item's `info`:

- `'{plate}'` or `true` means the field must equal the normalised vehicle plate (the item value is normalised before comparing).
- Any other value must equal the item's field exactly.

For plate `QB 123`, an item with `info = { plate = 'QB 123' }` matches the default config. Extra static fields such as `keyType = 'standard'` can be added to `metadata`. Using the key item (via `kora_core` usable items) toggles the nearest vehicle; the server rechecks access.

## Defaults for new vehicles

The resource only stores a lock state after a toggle, hotwire or lockpick. A vehicle that was never toggled has no `kora_vehiclekeys:locked` state and keeps whatever lock status the game gave it.
