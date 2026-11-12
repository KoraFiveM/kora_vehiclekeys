---
title: "Configuration"
sidebar_position: 4
---


# Configuration

All options live in the global `Config` table in `config.lua`, loaded in both realms as a shared script. There are no locale files: titles and fallback texts are in `Config.Text`.

Namespace: `Config` · Source: `config.lua`

## Config options (config.lua)

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| Config.Keybind.name / .description / .defaultKey | string | 'vehiclekeys:toggle-lock' / 'Lock or unlock the nearest vehicle' / 'L' | Keybind that toggles the lock. |
| Config.RemoteDistance | number | 25.0 | Metres. Closest-vehicle search radius for the toggle, and the server's maximum distance for `toggleRequested` and stock `setVehLockState`. |
| Config.InteractionDistance | number | 5.0 | Metres for lockpick, hotwire, access checks, handing over keys and the on-foot lockpick target. |
| Config.RequireKeyToStart | boolean | true | When true a client loop turns the engine off for drivers without access. |
| Config.AccessCacheMs | integer | 1500 | Milliseconds the client caches an `accessRequested` answer per network id. |
| Config.allowPickupLockedBikes | boolean | false | true lets anyone mount or lift a locked bike. Read live. |
| Config.AllowTemporaryKeys | boolean | true | Whether ordinary session keys (from `giveKeys`) count. Hotwired keys and keys given with the third argument always count. |
| Config.LegacyClientGrants | boolean | false | true honours stock client key requests only for the vehicle the player drives (lets a driver skip hotwiring). |
| Config.TrustedSetOwner.enabled | boolean | true | Master switch for the trusted stock request path. |
| Config.TrustedSetOwner.spawnWindowMs | integer | 15000 | How long after creation an entity counts as a fresh spawn. |
| Config.TrustedSetOwner.maxDistance | number | 7.5 | Metres between player and vehicle for a stock request. |
| Config.TrustedSetOwner.rateLimit | &#123; max, window &#125; | &#123; max = 5, window = 60000 &#125; | Grants per player per window in ms. |
| Config.TrustedSetOwner.log | boolean | true | Print a server console line for each grant. |
| Config.JobVehicles | table&lt;string, string[]> | &#123;&#125; | Job name to a list of vehicle model names (or hashes) usable without a key. Validated by `assert` at load and given a schema by `Kora.config` when available. |
| Config.PhysicalKey.enabled | boolean | false | Require/accept an inventory key item. |
| Config.PhysicalKey.item | string | 'vehiclekey' | Item name. |
| Config.PhysicalKey.metadata | table | &#123; plate = '&#123;plate&#125;' &#125; | Required `info` fields. Values: literal, `'{plate}'` or `true` for the plate. |
| Config.Lockpick.item | string | 'lockpick' | Fallback pick when `items` is empty. |
| Config.Lockpick.items | string[] | &#123; 'lockpick', 'advancedlockpick' &#125; | Items that start the flow and are accepted as the pick. |
| Config.Lockpick.registerUsable | boolean | true | Register those items as usable through Kora Core. |
| Config.Lockpick.lockpickFailureText | boolean | true | On-foot failures show the 'Lockpicking Failed' wording. |
| Config.Lockpick.doorFallback | boolean | true | When a lockpick item is used on foot with no vehicle in reach, and `kora_doorlock` is started, hand the pick to the closest lockpickable door (`exports.kora_doorlock:pickClosestDoor()`) instead of showing the no-vehicle error. Read live. |
| Config.Lockpick.breakChance | &#123; success, failure &#125; | &#123; success = 5, failure = 25 &#125; | Percent chance (0-100) that the used pick breaks. |
| Config.Lockpick.difficulty | &#123; attempts, pinCount, tolerance, speed, timeLimit &#125; | &#123; 2, 4, 0.12, 0.85, 12000 &#125; | Passed to `Kora.minigames.authorizeProof('lockpick', ...)`. |
| Config.EngineKeybind.name / .description / .defaultKey | string | 'vehiclekeys:toggle-engine' / 'Toggle the engine of your vehicle' / 'G' | Engine toggle keybind. |
| Config.Hotwire.enabled | boolean | true | Master switch. When false hotwiring and on-foot lockpicking are both refused (`Hotwiring is disabled.` / `Lockpicking is disabled.`). |
| Config.Hotwire.keybind.name / .description / .defaultKey | string | 'vehiclekeys:hotwire' / 'Hotwire the vehicle you are driving' / 'U' | Hotwire keybind. |
| Config.Hotwire.notifyUnavailable | boolean | false | Show an error when the hotwire key is pressed where it does not apply. Read on each press. |
| Config.Hotwire.grantTemporaryKey | boolean | true | A successful hotwire grants a session key. False means doors unlock only. |
| Config.Hotwire.debug | boolean | false | Print technical hotwire failures to the client console. |
| Config.Text.titleKeys / titleHotwire / titleHotwireFailed / titleLockpickFailed | string | 'Vehicle Keys' / 'Hotwire' / 'Hotwire Failed' / 'Lockpicking Failed' | Notification titles. |
| Config.Text.lockpickFailed / lockpickNoVehicle / lockpickNotNeeded / hotwireFailed | string | 'You failed to pick the lock.' / 'There is no vehicle close enough to lockpick.' / 'You do not need a lockpick for this vehicle.' / 'Attempt to hotwire vehicle failed.' | Fallback texts. Many other messages are hard-coded in English in the Lua files. |
| Config.lockFeedback.sound | boolean | true | Key-fob chirp for the player who toggled. |
| Config.lockFeedback.soundNearby | boolean | false | Also play the chirp for players within `soundRange`. |
| Config.lockFeedback.soundRange | number | 10.0 | Metres for `soundNearby`. |
| Config.lockFeedback.lights | boolean | true | Flash indicators and headlights for everyone within 100 m. |
| Config.lockFeedback.animation | boolean | true | Key-fob animation on foot. |
| Config.lockFeedback.notify | boolean | true | Top-right Locked/Unlocked notification. |
| Config.lockFeedback.textUI | boolean | false | Bottom-centre Locked/Unlocked text for 1.5 seconds. |
| Config.RateLimits.toggle | &#123; max, window &#125; | &#123; max = 10, window = 5000 &#125; | `toggleRequested` per player. |
| Config.RateLimits.access | &#123; max, window &#125; | &#123; max = 20, window = 10000 &#125; | `accessRequested`, `legacyHasKeys`, `GetVehicleKeys`, `checkPlayerOwned`. |
| Config.RateLimits.hotwire | &#123; max, window &#125; | &#123; max = 4, window = 10000 &#125; | `hotwireStarted`, `lockpickStarted` and the `hotwireFinished` event. The client mirrors it to avoid hitting the limit. |

## How it works

Most values are read when used. Exceptions are read once at load: `Config.JobVehicles` (hashed), the keybind definitions, `Config.RateLimits` (applied when the callbacks register) and the `Config.PhysicalKey` / `Config.Lockpick.registerUsable` item registrations. Restart the resource after changing those. Comments in the file state that `Config.lockFeedback` and `Config.allowPickupLockedBikes` apply live.

## Constants not in Config

These are fixed in the source: the stock-event throttle (500 ms per player and event, 300 ms for `AcquireVehicleKeys`), the maximum of 8 receivers for `GiveVehicleKeys`, the 32 character plate limit, the 100 m light flash range, and the client retry loop of 8 attempts every 400 ms for stock `AddKeys`/`SetOwner`.

## Job vehicles

`Config.JobVehicles` takes job names exactly as Kora Core spells them and model spawn names (strings, hashed with `joaat`) or numeric hashes. An empty list is allowed.

## Limits and related APIs

Notification text for most flows is hard-coded in English. Only the strings in `Config.Text` can be changed without editing the Lua.

## Adoption and schema

When `Kora.config.adopt` is available the config is adopted by `kora_lib`; `Config.JobVehicles` has a schema (job name mapped to a list of non-empty model name strings). Config is shared, so clients read it too.

## Notes on individual options

- `Config.RequireKeyToStart` is read once when the client starts.
- `Config.Hotwire.enabled` also enables both server lockpick callbacks.
- `Config.Hotwire.keybind` defaults to `U`, not `H`, which is the headlight key.
- `Config.TrustedSetOwner` is explained in [Compatibility](../compatibility.md); lock feedback in [Lock feedback and bikes](../feedback.md); physical key matching in [Keys and access](../keys.md).

## Examples

```lua title="config.lua"
Config.JobVehicles = {
    police = { 'police', 'police2', 'police3' },
    ambulance = { 'ambulance' },
}

Config.PhysicalKey = {
    enabled = false,
    item = 'vehiclekey',
    metadata = { plate = '{plate}' },
}
```

Outer keys of `Config.JobVehicles` are `kora_core` job names, values are vehicle spawn names. Changes need a resource restart.

## Related guides

- [Keys and access](../keys.md)
- [Lockpicking and hotwiring](../lockpicking.md)
- [Lock feedback and bikes](../feedback.md)
- [Compatibility](../compatibility.md)
