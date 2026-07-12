# Native polkit validation

The native UI is deliberately gated by `dendritic.polkit.agent = "quickshell"`.
The default remains `"kde"`; do not change it until the interactive matrix below
passes in one generation. The generated `ShellConfig.nativePolkitEnabled` flag
and the KDE unit are derived from that same enum, so desired state is exclusive.
The live transition must still happen at logout/login and must verify that the
old KDE process stopped before the native listener registers.

## Static evidence

- `PolkitOverlay` is a QML singleton and contains one conditionally loaded
  `PolkitAgent`.
- `quickshell-0.3-polkit-conversation.patch` repairs measured defects in the
  pinned backend: concurrent requests now remain FIFO, completion is tied to
  the flow that emitted it, unsupported identities are skipped iteratively,
  identity changes invalidate the old prompt, task completion is idempotent,
  cancellation handlers are disconnected before request destruction, and late
  registration callbacks detach safely. Unix groups are rejected because the
  pinned PolkitAgentSession can authenticate only Unix users. Synchronous
  pre-prompt failures are deferred and bounded; after three, the dialog exposes
  an explicit Retry/Cancel choice instead of recursing or spinning.
- The patch is applied only to the native-agent package. Its regression check
  applies it to the exact pinned source, checks the repaired contracts, and
  builds the resulting Quickshell package. Upstream 0.3 has only a manual
  polkit QML test, so the real daemon/PAM matrix remains mandatory.
- The response editor is cleared and destroyed after submit, user/daemon
  cancellation, failure, completion, flow replacement, and identity changes.
- Copy, cut, undo, and redo shortcuts are consumed. Responses are never sent to
  a signal, property, log, persistence API, or clipboard API.
- The editor is recreated for each prompt so its ordinary undo history cannot
  restore a prior response. This is not a secure-memory-erasure claim: Qt,
  Quickshell, PAM, and temporary `QString`/UTF-8 buffers may retain copies until
  their normal destruction.
- Only an active authentication flow requests exclusive layer-shell keyboard
  focus. A registration warning has no keyboard focus and its click mask is
  limited to the warning card.
- Placement follows the one focused Niri workspace output and falls back to a
  connected screen if IPC/output state is incomplete during hotplug.

## Isolated selector canary

`quickshell-native-polkit-smoke` evaluates the alternate selector through the
standalone Home Manager configuration and the NixOS configuration's nested
Home Manager user. It proves that all three select `quickshell`, disable the KDE
unit, use the native-patched package, generate
`ShellConfig.nativePolkitEnabled = true`, embed `quickshell` in each alternate
runtime validator, and build both the alternate Home Manager activation package
and NixOS toplevel. The normal evaluated host and validator still select KDE.

The check then loads the exact alternate shell for ten seconds under isolated
headless Weston. Both D-Bus addresses point to nonexistent sockets, so it cannot
contact the live session bus or system polkit daemon. Requiring
`Configuration Loaded` and rejecting QML/runtime type errors covers the
eight-second registration-warning path. This proves packaging, selection, and
bounded failure presentation only; it deliberately does not claim PAM or
registration success.

## Required interactive matrix

Run after selecting the native agent, before accepting that generation as the
new default:

1. `pkexec` with a correct password and then an incorrect password.
2. Retry after failure; cancel using both the button and Escape.
3. A PAM conversation with a visible response.
4. A policy request permitting multiple identities; switch identities before
   and during a prompt.
5. Multi-turn PAM, fingerprint, or 2FA when configured, including information
   and error messages.
6. Two concurrent `pkexec` requests; verify one dialog processes them in FIFO
   order without exposing the prior response.
7. Focus each monitor, including over a fullscreen window, and verify the one
   overlay follows Niri's focused output.
8. Reload Quickshell during a request, then kill it during a request and verify
   systemd restarts it and the caller is cancelled or can retry cleanly.
9. Log out/in for the KDE-to-native transition and verify registration succeeds
   once per session. Do not treat an in-place rebuild as proof of exclusivity.
10. Inspect the session bus/processes and confirm only the Quickshell agent is
    registered and `niri-flake-polkit` is disabled.

`funforgiven-runtime-check` verifies the selected unit/native state and rejects
known competing agent processes, but polkit has no public enumeration API for
authentication-agent registrations. It does not replace steps 1–10 or prove
that an arbitrary third-party process is not registered.

## Remaining backend limits

Quickshell 0.3 exposes `isRegistered` but no registration-completed error signal,
error detail, or retry method. The UI can therefore only infer failure when the
property remains false for eight seconds; recovery requires restarting the
supervised shell. A crashed shell cannot render its own failure, so crash
visibility is limited to systemd/journal evidence and the registration warning
after restart.

Queueing remains implemented inside Quickshell and queue depth is not exposed to
QML. Because GLib permits cancellation callbacks from other threads, the patch
uses a shared invalidatable request token and schedules cancellation onto the
default main context before touching Qt-owned flow or queue state. It also fixes
request lifetime, disconnect, idempotence, and task leaks. The cancellation
stress matrix is still required to validate the actual polkit call path used on
this system.

The local patch is intentionally version-pinned and must be re-audited whenever
Quickshell changes. Keep KDE selected until concurrent requests, repeated and
racing cancellation, reload, crash/restart, registration, and exactly-one-agent
tests all pass in the same native generation.
