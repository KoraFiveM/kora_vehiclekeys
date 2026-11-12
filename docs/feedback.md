---
title: Lock feedback and bikes
sidebar_position: 6
---

# Lock feedback and bikes

## Lock feedback

After a successful lock or unlock, `Config.lockFeedback` controls the confirmation. Values are read on every toggle.

| Option | Default | Effect |
| --- | --- | --- |
| `sound` | `true` | Key-fob chirp for the player who toggled. |
| `soundNearby` | `false` | Also play the chirp for other players within `soundRange`. |
| `soundRange` | `10.0` | Metres for `soundNearby`. |
| `lights` | `true` | Flash indicators and headlights, visible to players within 100 m. |
| `animation` | `true` | Key-fob animation when on foot. |
| `notify` | `true` | "Vehicle locked." / "Vehicle unlocked." notification. |
| `textUI` | `false` | Bottom-centre "Locked" or "Unlocked" for about 1.5 seconds. |

Failed attempts give no feedback beyond the error notification.

## Bikes

Bikes and bicycles never receive the native locked-door status, because it blocks lifting a fallen bike. Instead a client-side guard runs while a bike entry is attempted. Without access, the player is cancelled or ejected and sees "This bike is locked.". Key holders can enter normally. `Config.allowPickupLockedBikes = true` disables the guard. The ignition check still applies when `Config.RequireKeyToStart` is on.
