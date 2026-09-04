# Hermes OPEN: installation and physical acceptance

**Status:** Agreed physical acceptance complete, confirmed by the user.
**Date:** 2026-09-04.
**Source revision:** `5e9cc25`, `feature/hermes-desktop-workspace`.
**Target:** M5Stack StopWatch Dev Kit C152, explicitly selected USB-mic firmware.

This is the final acceptance record for the Hermes expansion and subsequent
OPEN/center-layout refinements. It supersedes pending-installation statements
in the earlier stage reports without rewriting their historical test results.
It is one tested local installation, not certification of every desktop-app
version, a published binary release or a guarantee of reproducible builds.

## Installed behavior

- Left cycles Codex / ChatGPT → SUPER → HERMES → Codex / ChatGPT.
- SUPER keeps previous/next Project and next session Tab.
- Hermes keeps native Control-Shift-Tab / Control-Tab browsing. Right confirms
  the highlighted central-picker session with one Control press/release and
  cleared release flags; the watch labels it OPEN. It does not send Return or
  Command-T. Keyboard semantics were checked on Hermes Desktop 0.17.0 and
  physical swipe behavior was separately confirmed after installation.
- Hermes browsing is not project-tree navigation. The proposed source extension
  was canceled; no Hermes plugin, app modification or content access was added.
- Codex's normal center has four balanced rows without WEEKLY LEFT; diagnostic
  messages remain. SUPER/HERMES center the battery icon and percentage together.
  Three synthetic native previews remain in the bilingual READMEs; they are not
  photographs of the tested device.

## Installation evidence

The existing signed Companion and recoverable firmware were backed up privately.
Only the installed Companion executable and its signing metadata were updated;
runtime identity, original LaunchAgent, device binding and stored paths were
preserved. The user renewed Input Monitoring and Accessibility, and navigation
was confirmed with fresh logs plus physical gestures.

Manual download-mode attempts still enumerated the normal USB microphone. After
separate user authorization, the existing maintenance command received an ATT
acknowledgement followed by BLE disconnect. A newly enumerated Espressif download
interface was identified, its exact port was explicitly approved for that
attempt, and PlatformIO uploaded only the USB-mic target. Upload exited 0 and
all written image hashes verified. No historical port authorization was reused.

Installed application firmware SHA-256:
`a6a685cc8ee857b37faa912a58d7dcce1b12a3fdde5d154f2e18227b351a917f`.
The pre-install Companion build fingerprint and layered build evidence are in
the [OPEN implementation record](2026-09-04-hermes-open-selection.md).

## Physical acceptance by layer

| Layer | Result | Evidence and boundary |
| --- | --- | --- |
| OPEN and center UI | User confirmed | HERMES OPEN label, Codex four-row center and centered directional battery display |
| Navigation and palette | User confirmed | Three-workspace cycle, Hermes browse/open, SUPER directions and random four-color feedback |
| Confirmation safety | User confirmed | Repeated right and right without a picker did not create sessions, send drafts or leave Control stuck |
| Input isolation | User confirmed | Agent/Send/side controls inactive in directional modes; Codex controls restored; no ChatGPT background action |
| Sleeping display | User confirmed | Foreground changes did not wake the watch; manual wake showed the correct workspace |
| Lease fallback | User confirmed plus process evidence | Original Companion paused with SIGSTOP; user observed Codex fallback and workspace restoration; same process resumed in 18.03 seconds |
| Travel shutdown/reconnect | User confirmed plus HID logs | Correct workspace and controls returned without duplicate input or stale completion notices; one detach/attach observed |
| USB microphone enumeration | Host verified | USB input, one channel, 48000 Hz after flash and reconnect |
| USB microphone audio | User confirmed | Approximately five-second local recording and playback normal; recording deletion confirmed; assistant did not access or analyze audio |
| Quota and runtime health | Host verified | Final scoped log window contained four successful quota writes, zero workspace Output failures and zero permission warnings; one running Companion instance |
| Configuration and signature | Host verified | Original LaunchAgent byte comparison and installed app signature verification passed; recovery backups retained |

The pause test armed an independent 18-second resume guard and a finally-based
resume. The normal recovery path was observed; guard failure, process death and
forced interruption were not injected. The 15-second lease value is established
by implementation/tests; this physical check was a visual fallback observation,
not a precision measurement of the last heartbeat timestamp.

## Automated results and remaining limits

Before installation, the OPEN revision passed 11 native C++ executables, 53
temporary Swift test bodies, USB-mic build, fixed macOS 15.4 SDK Companion release
with warnings as errors, and synthetic JSON smoke. These are the previously
recorded implementation results, not new executions during documentation closeout.
Native preview retained an existing third-party M5GFX warning. Full `swift test`
remained unavailable with `no such module 'XCTest'`; the harness is not XCTest.

The agreed checklist is complete. Cold-launch/missing-app/no-skip scenarios,
all Space/window arrangements, long-duration power switching, every battery
percentage on physical hardware and a fresh macOS-login startup were not
retested in this final pass. Keep these separate from the confirmed checklist;
native tests/previews and the preserved LaunchAgent do not prove them physically.
Other installations and changed app versions require their own acceptance.

No merge, push or branch cleanup was performed. Private recovery artifacts,
raw installation logs, audio, device identifiers and local configuration are
not included in this public record. Upstream attribution and runtime identifiers
remain unchanged.
