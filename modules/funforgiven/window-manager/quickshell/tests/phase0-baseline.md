# Phase 0 baseline

Captured on 2026-07-10 before enabling the repository-owned shell.

## Resolved implementation choices

- Wallpaper: the existing `~/Pictures/Wallpapers/current.png` is 3840×2160 and
  has SHA-256 `265fad7275448931279d2523dbfb26aab2de028c3059243984a376c9466726e9`.
  It remains outside Git to avoid redistributing personal/copyrighted art and
  is imported through the locked local `wallpaper` input.
- Audio grouping: group playback streams by WirePlumber's persistent identity
  key, while keeping child streams visible and independently routable when a
  client exposes distinct roles or keys.
- Channel gain: all four channel bridges start at 100% and unmuted. After first
  use, WirePlumber owns gain and mute persistence.
- Wake input: the first wake event passes through. The AMOLED overlay never
  claims keyboard focus and disappears immediately when swayidle reports
  activity.
- Neutral output selection: sort eligible physical sinks by descending
  `priority.session`, then ascending stable `node.name` to break ties without a
  hardware-specific preference.

## Pinned versions and pre-cutover observations

- Niri: commit `0777769e719b7c9b7c980d4ea66288bfbb4da5b3`
- Quickshell: 0.3.0
- PipeWire: 1.6.5
- WirePlumber: 0.5.15
- Stylix: commit `14814ef555d8148ab82eba5054e654cd9eae3a1f`

The live PipeWire graph contained six device-backed `Audio/Sink` nodes. Each
had a `device.id`, none declared `node.virtual`, and two shared the highest
observed session priority. This is why priority alone is not a deterministic
first-use policy. No hardware node name is part of the declarative channel
schema or generated QML.

Historical WirePlumber stream state showed real persistence keys for Chromium,
`WEBRTC VoiceEngine`, Telegram Desktop, Steam input, Firefox, PipeWire ALSA
clients, and several games. Most fell back to `application.name`; Discord's
Chromium and WebRTC roles were distinct. No normalization rule is added at this
stage: Phase 2 must observe active properties before declaring one.

## Pre-cutover Niri/DMS snapshot

The effective `~/.config/niri/config.kdl` was a DMS wrapper around `hm.kdl` and
the `alttab`, `binds`, `colors`, `layout`, `windowrules`, and `wpblur`
fragments. The exact pre-cutover wrapper, its complete Home Manager KDL, and
every non-empty included DMS fragment are preserved under
`modules/funforgiven/window-manager/tests/phase0-niri/`. The empty
`windowrules.kdl` had SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The snapshot includes the wrapper's explicit border-fix stanza, so the table
below is a disposition record rather than a substitute for the captured input.

| DMS fragment | Cutover disposition |
| --- | --- |
| `alttab` | Retain the recent-window corner radius declaratively in the focused Niri layout module. |
| `binds` | Retain compositor-native overview, focus, move, workspace, sizing, screenshot, floating, tabbed, fullscreen, and quit actions. Discard every DMS launcher/settings/notification/notepad/wallpaper/lock/process-list action. Reintroduce media or audio keys only through explicit non-DMS actions. |
| `colors` | Replace with the Stylix-derived Niri target. |
| `layout` | Retain the 4-pixel gap, 2-pixel border, 16-pixel geometry radius, clipping, and tiled-state behavior in focused Niri modules. |
| `windowrules` | The captured fragment was empty; retain no generated rule. Existing repository-owned application rules remain. |
| `wpblur` | Discard the DMS-only `dms:blurwallpaper` layer rule. The replacement uses opaque surfaces and swaybg. |

The retained pre-cutover session-path baseline was:

```text
PATH=/run/wrappers/bin:$HOME/.nix-profile/bin:/run/current-system/sw/bin
XDG_DATA_DIRS=$HOME/.nix-profile/share:/run/current-system/sw/share
```

The candidate Quickshell unit adds the user and system Flatpak export paths to
`XDG_DATA_DIRS`, conditions startup on both `WAYLAND_DISPLAY` and `NIRI_SOCKET`,
and passes both variables from Niri's systemd session. The
`desktop-runtime-contract` check evaluates these exact properties.
