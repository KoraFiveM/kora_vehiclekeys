---
title: Troubleshooting
sidebar_position: 11
---

# Troubleshooting

- **"You do not have the keys for this vehicle."** - the player has no session key, hotwire key, matching physical key or job access. Grant with `giveKeys` or `/addkeys`.
- **Keys vanish after relog or restart** - session keys are memory-only. Re-grant them or use physical keys.
- **`giveKeys` returns `false`** - invalid plate, or `Config.AllowTemporaryKeys` is `false`.
- **Physical key not recognised** - `Config.PhysicalKey.enabled` is `false` by default; the item name must equal `Config.PhysicalKey.item` and its `info` must match `metadata` (plate compared after normalisation).
- **Lockpick does nothing** - check that `Config.Hotwire.enabled` is `true`, the item is in `Config.Lockpick.items`, and `registerUsable` is on or another resource registers it. Set `Config.Hotwire.debug = true` for client console details.
- **Job vehicle not accepted** - the model must be the spawn name in `Config.JobVehicles` for the player's current job. The config is read at start; restart the resource after editing.
- **Engine shuts off in own vehicle** - the server says no access. Check the plate on the entity matches the key plate and that the vehicle is networked.
- **"This bike is locked."** - see [Lock feedback and bikes](./feedback.md).
- **Stock script cannot grant keys** - client-triggered AddKeys/SetOwner are decided by `Config.TrustedSetOwner`; see [Compatibility](./compatibility.md).
