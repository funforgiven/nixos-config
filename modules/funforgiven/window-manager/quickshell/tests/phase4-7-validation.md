# Phases 4–7 validation record

Captured on 2026-07-10 before the first DMS-removal activation attempt and
updated through the 2026-07-11 deployed interaction-regression audit.

## Proven before deployment

- The fully generated shell loads under the exact patched Quickshell package.
  A repository check starts a nested headless Weston compositor, requires the
  `Configuration Loaded` marker, and rejects QML type/module and invalid
  property failures. This caught and now guards missing `qmldir` exports and a
  read-only `Loader.implicitHeight` assignment that static lint did not reject.
- `qmllint` has zero unsuppressed warnings. The remaining exact inline
  suppressions cover only pinned Quickshell qmltype gaps or deliberately
  dynamic `Loader.item` access.
- The Niri reducer/action protocol fixtures, shell ownership scan, desktop
  runtime contract, desktop-entry probe, patched Quickshell C++ regressions,
  and native-polkit source/package contracts pass.
- `quickshell-theme-contrast` checks every generated semantic text token at
  WCAG 4.5:1 against each surface and rejects decorative accent/error colors as
  direct text colors.
- `quickshell-native-polkit-smoke` evaluates and builds the alternate native
  selector for standalone Home Manager, nested Home Manager, and NixOS without
  changing the default. It also loads that exact generated shell for ten
  seconds under isolated Weston with deliberately nonexistent session/system
  D-Bus sockets, covering the eight-second registration-warning path without
  contacting live polkit.
- An earlier pre-final bounded launch in the old three-output Niri session reached
  `Configuration Loaded`, connected to Niri and PipeWire, and answered
  `amoled isVisible` with `false`; `deactivate` completed without showing a black
  surface. The process was stopped by a ten-second timeout. Later launcher,
  theme, and lifecycle changes are covered by current hermetic checks; this
  historical run is not acceptance evidence for the final deployed candidate.
- With the evaluated qt6ct config, candidate Home Manager/system data paths,
  and explicit `QT_QPA_PLATFORMTHEME=qt6ct`, Papirus resolves the generic shell
  icons without the missing-icon warnings produced by the old DMS-owned live
  qt6ct config.
- Dock launches use the absolute pinned `app2unit` and pass only the selected
  normalized Desktop Entry ID as typed argv. Its service mode reparses the
  entry's `Exec`, `Path`, and `Terminal` metadata, creates a collected
  `Type=exec`/`ExitType=cgroup` unit in `app-graphical.slice`, and attaches
  `After`/`PartOf=graphical-session.target` plus `SourcePath`. The deployed
  runtime validator proves the display, Niri, Qt, XDG, cursor, and path values
  are imported into the user manager, so the service inherits the session
  environment without duplicating it per launch. A seven-second QML guard
  bounds client failure reporting and surfaces nonzero launcher stderr on the
  dock. The repository contract runs `app2unit --test` against a controlled
  entry and rejects the unsupported `JobTimeoutSec` property that previously
  broke every launch. Actual post-activation application lifetime and visible
  nonexistent-executable behavior remain manual tests.
- `funforgiven-runtime-check` is installed in the candidate Home Manager
  profile. It aggregates systemd properties, Niri JSON, PipeWire JSON,
  Quickshell's JSON instance registry, and a read-only shell diagnostics IPC
  snapshot into one JSON result. Every external probe is bounded, the instance
  scan crosses displays, and the shell IPC is addressed to the supervised PID.
  It compares the shell's Niri models with direct Niri snapshots, rejects
  unrouted streams and audio feedback cycles, and checks the selected polkit
  process/native registration plus known competing-agent processes. Against
  the current old generation it failed exactly on the expected cutover gaps
  while still passing unchanged output, workspace, and no-notification
  contracts.

## First activation attempt

The system switch reached Home Manager, which refused to replace the DMS-owned
relative symlink `~/.config/gtk-3.0/gtk.css -> dank-colors.css`. The configured
`hm-bak` policy was active and would safely back up the other regular legacy
GTK/Qt files, but Home Manager deliberately does not back up symlinks.

Stylix is now the authoritative owner of that exact target, so the GUI profile
sets `xdg.configFile."gtk-3.0/gtk.css".force = true`. Both standalone and nested
Home Manager evaluations assert the narrow override, and the generated
collision checker contains only that GTK 3 path in `forcedPaths`. Other legacy
files retain backup protection. The failed switch partially applied system
changes but did not complete the Home Manager generation; it is not cutover
acceptance evidence.

## Successful rebuild and read-only deployed audit

The next user-owned rebuild completed and booted the candidate generation. A
read-only audit inside the new Niri session established the following:

- `/run/current-system`, `/run/booted-system`, and the system profile resolve to
  the same generation. The previous session stopped Quickshell, swayidle, and
  swaybg cleanly; the reboot started exactly one of each plus the selected KDE
  polkit agent.
- The repository-owned shell, Niri model, and direct compositor snapshot agree
  on the three outputs, output-local workspaces, and windows. The deployed
  outputs are 4K 240 Hz on `DP-1`, 4K 160.001 Hz on `HDMI-A-2`, and portrait 4K
  160.001 Hz on `HDMI-A-1`, all at scale 1.5.
- PipeWire exposes exactly four logical sinks and four bridges plus six eligible
  physical sinks. All four saved bridge targets returned after reboot, every
  target is physical and cycle-safe, and the idle graph reported zero errors.
- The KDE agent is active at the exact selected unit `MainPID`; its journal
  reports a live listener and successful registration. The deployed validator
  passed 19 of 20 checks. Its sole failure was a scanner false negative because
  the same-UID process could read `/proc/<pid>/cmdline` but not
  `/proc/<pid>/exe`. The validator now has a hermetic regression and falls back
  only to the NUL-delimited `argv[0]`, while retaining exact `MainPID` matching.
- `xdg-document-portal.service` exposed a real separate defect: it failed to
  mount `/run/user/1000/doc` because the generation lacked the privileged
  `fusermount3` wrapper. The focused portal feature now owns
  `programs.fuse.enable = true`, asserts the wrapper, and the validator rejects
  a failed document portal.
- swayidle's ignored pre-start hide raced Quickshell IPC readiness, and upstream
  swayidle 1.9 queried `BlockInhibited` without opening its optional logind bus
  in this timeout-only configuration. The pre-start call is removed, the useful
  fail-open post-stop deactivate remains, and the package is built without the unused
  logind backend. No lock, sleep, suspend, DPMS, idle-hint, or monitor-power
  behavior was added.
- With the mixer and AMOLED overlay closed, a five-second sample measured
  Quickshell at roughly 5.38% of one CPU core and 164–165 MiB resident memory.
  This is a baseline, not the required mixer-open/fullscreen/game result.

No playback streams were active during the audit. Discord, Chromium, and Steam
client metadata alone is insufficient to prove playback identity, grouping,
route persistence, loaded latency, or xruns, so those items remain explicitly
unaccepted. Tray menu/scroll, dock and launcher interaction, drag cancellation,
hotplug/fullscreen/VRR behavior, rollback boot, and the native-polkit PAM matrix
also remain manual deployed tests after the next user-owned activation.

The combined workspace/task strip additionally requires a real-session pointer
pass: every output must show icon-only workspace capsules, a capsule must grow
and shrink with its authoritative Niri window count, empty workspaces must
remain reachable, and clicking an app icon must focus that exact window. With a
tray popup already open, one right-click on a different tray icon must
replace it immediately; selecting an entry, clicking the current icon, Escape,
and application-owned menu destruction must still close the menu normally.
The tray must not instantiate `QsMenuAnchor` or call the native
`PlatformMenuEntry` path. Pinned Quickshell 0.3 emits `QsMenuAnchor.closed`
re-entrantly from `PlatformMenuEntry::onAboutToHide`, then defers destruction;
even dismissal-only menu-handle cleanup can invalidate that live native stack.
The repository-owned `PopupWindow + QsMenuOpener` renderer instead owns outside
dismissal, actions, separators, icons, check/radio state, scrolling, and submenu
drill-down. Exercise rapid A→B→C switching, every outside-click direction,
Escape/back navigation, and removal of A while open; there must remain exactly
one tray popup and one shell process. Short and long menus must follow their
rendered labels within the configured width bounds; hover tiles and keyboard
focus outlines must keep a visible gutter on both sides instead of touching or
clipping against the popup edge.

The launcher and mixer polish also retain a visual acceptance boundary. Check
the launcher on the 240 Hz primary while focus and pointer move across every
output, with an empty query, no-match query, pending start, and failed start;
it must remain on the configured primary, immediately receive keyboard input
when invoked from every other output without moving the pointer, keyboard and
pointer selection must stay aligned, and the nine-dot dock control must remain
visually inert.
While the mixer is open, begin/cancel group and child drags, complete moves in
both directions, and switch hardware outputs. Only the source/hovered target and
drop destination may react: no overlay rail may intersect the cards, the four
cards must not flash, jump, or rebuild together, no transient Unrouted shelf may
appear for an already-pending move, and no visible Move button or expanding
routing grid may return. Tab to a drag grip and confirm Left/Right uses the same
graph-confirmed routing path. Open every hardware-output picker: its width must
follow the longest live label within the 280–680 bound, every row state layer
must retain its inset, and the intrinsic Auto-select action must not become a
full-width hover strip.

## Deployed interaction-regression audit

The user then exercised the deployed shell with real pointer and playback
activity. The original validator still reported 20/20, but direct structured
evidence exposed three regressions that its first contract did not cover:

- Every launcher and dock start failed because the hand-built `systemd-run`
  request set `JobTimeoutSec=5s`. systemd 260 translated that into an
  unsupported `JobTimeoutUSec` transient-unit property. The candidate now uses
  pinned `app2unit` service mode and a controlled dry-run contract instead of
  assembling the transient unit in QML.
- `pw-dump` contained a running `Stream/Output/Audio` node named
  `alsa_playback.hayase`, serial 1025, linked to the System sink. Quickshell
  exported no playback streams because `PwNode.type` is a QFlags value and the
  model compared it with one scalar enum. The model now carries Quickshell's
  stable `isStream`/`isSink` booleans, and the validator settles and compares
  exact non-bridge playback `id + object.serial` sets.
- The current supervised Quickshell PID had emitted 51,152 matching QML
  errors. Most were a `DockApp.qml` teardown-time null-parent dereference from
  anchoring children managed by a `Row`; the launcher also had an
  `implicitHeight` binding loop. Stable structural keys now prevent mutable
  focus, title, urgency, volume, and mute updates from recreating delegates;
  unsafe dock anchors and layout-affecting hover motion are gone. The validator
  now fails on matching QML errors from the current service PID instead of
  accepting a noisy process.
- The nine-dot launcher affordance no longer mirrors application launch state,
  and the brief app2unit client lifetime no longer changes dock-tile surfaces,
  borders, icon opacity, running marks, or badges. Exact-ID dock activation now
  uses a narrow pinned-Niri patch matching its foreign-toplevel taskbar path:
  the window is revealed/focused without moving the pointer across outputs.
  The patch now preserves the pre-action pointer coordinates explicitly and
  emits no synthetic motion through the target client.
- Niri now keeps one fixed Turkish physical XKB layout. Home Manager supervises
  Fcitx5 with one exact `Turkish or Japanese` group containing only
  `keyboard-tr`/`mozc`, Hiragana initial mode, and native Niri
  Wayland-input-method integration. Active Mozc uses Fcitx's
  internal US raw-key translation for reliable romaji without changing Niri's
  Turkish layout. Fcitx is the only Turkish-direct/Japanese-Mozc language
  owner.

The repair generation has only been built and checked in isolation. These
observations describe the still-deployed older generation and are not evidence
that the interaction repairs are deployed. A new user-owned activation and the
real pointer/launch/routing stress matrix remain required.

## Required after activating the refreshed KDE-polkit candidate

1. Log out and back in. A rebuild cannot replace the Niri compositor serving
   the current session, so this logout/login is required before testing the
   pointer patch. Verify exactly one evaluated Niri executable, Quickshell,
   Fcitx5, swayidle, swaybg, tray watcher, and KDE polkit agent; verify no DMS
   process, unit, window, startup entry, or environment variable.
2. Verify all three output-local bars, workspace/window ID actions, dock
   launch/focus/stable cycling and urgency, and
   Steam/Discord/Telegram/1Password tray interactions. Include a
   harmless `app-niri-*.service` launch and one deliberately nonexistent executable;
   verify the service is in `app-graphical.slice`, receives the expected
   display/Niri/Qt/XDG environment, survives a Quickshell restart, and reports
   the failed exec visibly on the originating dock item. Launch and focus apps
   on every output; the pointer must remain on the dock, the nine-dot control
   must not react, and successful app launches must not flash tile chrome.
   In Firefox, a Qt text field, and the terminal, verify both `Ctrl+Space` and
   left-clicking the Fcitx tray item alternate only between inactive
   `keyboard-tr` Turkish input and active `mozc` Japanese input. Right-click the
   tray item and select each language directly. Verify romanized Japanese input
   produces Hiragana preedit, `F6` converts the current composition to
   Hiragana, and `F7` converts it to full Katakana without changing language.
3. Stress mixer open/outside-dismiss/reopen, rapid stream churn, drag cancel,
   partial grouped moves, PipeWire/WirePlumber restart, visible stale-action
   errors, and both routing persistence paths.
4. Exercise the exact-black overlay on all outputs, fullscreen, hotplug,
   pointer/key/touch wake, Quickshell restart while idle, VRR/mode stability,
   and idle/open-mixer CPU cost. Confirm the physical top and bottom edges stay
   black through the bar and dock reserved strips, with no shell surface visible
   above the overlay.
5. Log out/in again, reboot, and test the prior NixOS generation as rollback
   before deleting any old DMS state.

Only after these checks stabilize should a separate generation select the
native Quickshell polkit agent and run its dedicated PAM/security matrix.
