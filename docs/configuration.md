---
title: Configuration
sidebar_position: 3
---

# Configuration

All options live in `config.lua` (shared, so clients read them too). When `Kora.config.adopt` is available the config is adopted by `kora_lib`; `Config.JobVehicles` has a schema (job name mapped to a list of non-empty model name strings). Notification text is in `Config.Text`; there are no locale files.

## General

| Option | Default | Meaning |
| --- | --- | --- |
| `Config.Keybind` | `vehiclekeys:toggle-lock`, key `L` | Lock/unlock keybind (`name`, `description`, `defaultKey`). Players can rebind it in FiveM key bindings. |
| `Config.RemoteDistance` | `25.0` | Maximum distance for lock toggles (server check) and the client search radius for the nearest vehicle. |
| `Config.InteractionDistance` | `5.0` | Maximum distance for ignition access checks, lockpicking, and for receivers of `givekeys`. |
| `Config.RequireKeyToStart` | `true` | Client monitors the driver seat and turns the engine off without access. Read once at client start. |
| `Config.AccessCacheMs` | `1500` | How long the client caches the server's access answer per vehicle. Cleared when keys change. |
| `Config.allowPickupLockedBikes` | `false` | Allow anyone to pick up or mount a locked bike. See [Lock feedback and bikes](./feedback.md). |
| `Config.AllowTemporaryKeys` | `true` | Allow session keys from `giveKeys`. When `false` only physical keys (and hotwire keys) work. |
| `Config.LegacyClientGrants` | `false` | Honour stock client key requests for the vehicle the player is driving. See [Compatibility](./compatibility.md). |

## Trusted SetOwner

`Config.TrustedSetOwner`: `enabled` (`true`), `spawnWindowMs` (`15000`), `maxDistance` (`7.5`), `rateLimit` (`max = 5`, `window = 60000`), `log` (`true`). Details in [Compatibility](./compatibility.md).

## Job vehicles

```lua
Config.JobVehicles = {
    police = { 'police', 'police2', 'police3' },
    ambulance = { 'ambulance' },
}
```

Outer keys are `kora_core` job names, values are vehicle spawn names (hashed with `joaat` on the server; numeric hashes are also accepted by the server code). The default is empty. Changes need a resource restart.

## Physical keys

```lua
Config.PhysicalKey = {
    enabled = false,
    item = 'vehiclekey',
    metadata = { plate = '{plate}' },
}
```

`enabled` defaults to `false`. See [Keys and access](./keys.md) for matching rules.

## Lockpick

| Option | Default | Meaning |
| --- | --- | --- |
| `Config.Lockpick.item` | `lockpick` | Fallback pick when `items` is empty. |
| `Config.Lockpick.items` | `lockpick`, `advancedlockpick` | Items that start the lockpick flow and are accepted by the server. |
| `Config.Lockpick.registerUsable` | `true` | Register the items as usable through `kora_core`. Set `false` if another resource does it. |
| `Config.Lockpick.lockpickFailureText` | `true` | Use the "Lockpicking Failed" wording for on-foot failures. |
| `Config.Lockpick.doorFallback` | `true` | With no vehicle in reach, try `kora_doorlock`. |
| `Config.Lockpick.breakChance` | `success = 5`, `failure = 25` | Percent chance that the pick used is removed after an attempt. |
| `Config.Lockpick.difficulty` | `attempts = 2`, `pinCount = 4`, `tolerance = 0.12`, `speed = 0.85`, `timeLimit = 12000` | Parameters for the `kora_lib` lockpick minigame. |

## Engine and hotwire

- `Config.EngineKeybind` - `vehiclekeys:toggle-engine`, default `G`.
- `Config.Hotwire.enabled` (`true`) - enables the hotwire keybind and both server lockpick callbacks. When `false`, on-foot lockpicking is disabled too.
- `Config.Hotwire.keybind` - `vehiclekeys:hotwire`, default `U` (not `H`, which is the headlight key).
- `Config.Hotwire.notifyUnavailable` (`false`) - show errors when the hotwire key is pressed where hotwiring does not apply.
- `Config.Hotwire.grantTemporaryKey` (`true`) - a successful hotwire grants a session key. When `false` it only unlocks.
- `Config.Hotwire.debug` (`false`) - print technical hotwire failures to the client console.

## Text

`Config.Text` holds `titleKeys`, `titleHotwire`, `titleHotwireFailed`, `titleLockpickFailed`, `lockpickFailed`, `lockpickNoVehicle`, `lockpickNotNeeded` and `hotwireFailed`. Most other messages (for example "Vehicle locked.", "You need a lockpick.") are hard-coded in the scripts and not configurable.

## Feedback

`Config.lockFeedback` - see [Lock feedback and bikes](./feedback.md).

## Rate limits

`Config.RateLimits` entries are `max` calls per `window` ms, applied by `kora_lib` per player:

| Key | Default | Applies to |
| --- | --- | --- |
| `toggle` | 10 per 5000 | `toggleRequested` callback |
| `access` | 20 per 10000 | `accessRequested`, `legacyHasKeys`, `GetVehicleKeys`, `checkPlayerOwned` callbacks |
| `hotwire` | 4 per 10000 | `hotwireStarted`, `lockpickStarted` callbacks and `hotwireFinished` event |
