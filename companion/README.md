# macOS quota companion

The Swift companion reads the current Codex rate-limit window from a local
Codex App Server and writes a small quota snapshot to one explicitly bound
StopWatch over the project's private BLE service.

It uses the user's existing local Codex/ChatGPT sign-in context. It does not
scrape the UI, use a cloud relay, read credentials directly, require an OpenAI
API key, or put an account token on the watch.

## Build from source

Requirements:

- macOS 14 or newer;
- Swift 5.10 or newer (Xcode 15.3 Command Line Tools or newer);
- a locally available Codex executable or an explicit `--codex-path`.

```sh
swift build -c release
```

No prebuilt companion binary is distributed by this project.

## Bind a StopWatch safely

First run demo discovery. It writes synthetic data only and prints the
CoreBluetooth UUID assigned by this Mac:

```sh
.build/release/codex-watch-companion --demo --verbose
```

Use the exact UUID printed on this Mac for every real write:

```sh
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --verbose
```

For continuous refreshes while the terminal remains open:

```sh
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --watch --interval 60
```

Keep this `--watch` process running whenever automatic startup is not installed;
otherwise the dashboard will correctly mark quota sync stale.

Pass `--codex-path /absolute/path/to/codex` when automatic executable discovery
does not select the intended local Codex installation.

## Optional super.engineering dedicated workspace controls and screen

A real `--watch` process also listens for the four radial reports from the C152
StopWatch:

| Gesture | Behavior |
| --- | --- |
| Left | Activate or launch super.engineering; when it is already in front, return to the exact previously foreground application |
| Up | Select Previous Project while super.engineering is in front |
| Down | Select Next Project while super.engineering is in front |
| Right | Select Next Tab while super.engineering is in front |

With the matching USB-mic firmware installed, the same real `--watch` process
also follows the foreground application on the StopWatch display. When
super.engineering is in front, the watch shows a fixed `SUPER` screen with the
four actions above. The companion sends `super` immediately and renews it every
5 seconds; the firmware lease lasts 15 seconds. Leaving super.engineering sends
`codex` once and cancels the renewal timer. A device attached or reattached to
the running companion is synchronized immediately. If the companion stops, a
write fails continuously, or the owning HID connection disappears, the watch
returns to the Codex dashboard no later than lease expiry.

Changing the foreground application while the display is asleep does not wake
it. The firmware records the new mode and renders the correct screen the next
time the user wakes the display. In `SUPER` mode, only the four radial swipes,
the red power button, and the existing long-hold Travel Mode path are active.
Agent touch, center Send, and the left/right ChatGPT physical buttons emit no
HID action or success haptic. Any held microphone/voice control is released on
entry. Returning to the Codex dashboard restores the existing controls. The
USB microphone endpoint itself remains available to macOS throughout.

The target is identified only by bundle identifier
`com.zarifpour.superconductor`. If the remembered return application has
exited, the companion leaves super.engineering in front instead of guessing a
replacement. Repeated launch gestures are ignored while launch is in progress,
and radial presses use a release gate plus an 800-millisecond cooldown.

Prepare the dedicated workspace before using these controls:

1. Create a normal macOS Space, move super.engineering there, then use the
   application's Dock menu and choose **Options → Assign To → This Desktop**.
   The companion does not create or enumerate Spaces. Without this assignment,
   left still activates and returns, but macOS provides no dedicated-desktop
   guarantee.
2. In super.engineering's **Keyboard Shortcuts** settings, configure **Previous
   Project** as `Control-Option-Up`, **Next Project** as
   `Control-Option-Down`, and **Next Tab** as `Control-Option-Right`.
3. In ChatGPT's StopWatch controller settings, leave only **Analog stick left**
   unassigned. Keep the existing up, down, and right bindings.
4. Add the locally installed `CodexWatchCompanion.app` under **System Settings →
   Privacy & Security → Input Monitoring** and **Accessibility**, and enable it
   in both places.
5. Restart the existing companion LaunchAgent after changing permissions.

Up, down, and right are companion no-ops unless super.engineering is the exact
foreground application, so ChatGPT retains its mappings after the user returns
to it. Physical acceptance must also confirm that ChatGPT performs no visible
background action while super.engineering is in front; the companion does not
rewrite ChatGPT preferences if that compatibility check fails.

If Input Monitoring is missing, the companion warns once and keeps quota sync
running, but cannot receive any StopWatch radial gesture. If Accessibility is
missing, it warns once and disables only project/tab navigation; left-swipe
activation and return, quota sync, and USB microphone input remain available.
The HID listener starts only in a real `--watch` run, not in one-shot, `--demo`,
`--json-only`, or `--enter-bootloader` modes. It matches only the exact C152
descriptor and report used by this project.

Navigation uses fixed, process-targeted CoreGraphics key-down/key-up pairs. It
revalidates both the foreground identity and the PID/bundle pair before every
delivery. It never posts those keys globally and does not inspect menus,
Accessibility labels, screen coordinates, project names, session titles,
application preferences, conversation content, keyboard text, or credentials.
The display channel sends only the fixed `codex` or `super` mode enum, a fixed
15-second TTL, and a local request number. It does not send project, session,
window, Space, workspace, or user-content metadata. It does not run `sc`, shell
commands, AppleScript, UI scraping, or private Space APIs.

For a companion-only rollback, stop the existing LaunchAgent, restore the
previously backed-up signed companion app, verify its signature, and restart
that same LaunchAgent. The upgraded firmware falls back to the Codex dashboard
within 15 seconds when the old companion sends no renewal. For a complete
two-component rollback, additionally restore the saved pre-change USB-mic
firmware, but only after rediscovering the current `/dev/cu.*` bootloader port
and obtaining explicit confirmation for that exact port. Never reuse a port
from an earlier flash. Optionally set the Dock assignment back to **None** and
reset the three super.engineering shortcuts.

Useful diagnostics:

```sh
# Verify App Server parsing without using Bluetooth.
.build/release/codex-watch-companion --json-only

# Verify BLE discovery and writes using a synthetic snapshot.
.build/release/codex-watch-companion --demo --verbose

# Direct firmware diagnostic. SUPER automatically expires after 15 seconds.
swift ../scripts/hid_rpc_probe.swift --workspace-super
swift ../scripts/hid_rpc_probe.swift --workspace-codex
```

## Optional USB-mic bootloader request

The USB-mic firmware can be asked to restart into the ESP32-S3 serial
bootloader over the same encrypted private GATT characteristic:

```sh
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --enter-bootloader
```

This explicit maintenance mode cannot be combined with `--demo`, `--watch`, or
`--json-only`. The USB-mic firmware requires an encrypted, with-response write
from the same BLE peer that completed a valid Codex HID RPC in the current
connection epoch. Its main loop checks VBUS, waits 400 ms, checks VBUS again,
and only then restarts. The stable non-microphone firmware never acts on this
command.

An ATT acknowledgement proves only that the encrypted command reached the
device, so the companion exits successfully only after BLE disconnects. Before
uploading, resolve the newly enumerated `/dev/cu.*` bootloader port and verify
that it belongs to this StopWatch; never reuse or guess a stale port.

## Optional local background installation

For unattended CoreBluetooth access, Codex can wrap the locally built binary in
a small background `.app` using [`app/Info.plist`](app/Info.plist), ad-hoc sign
that local wrapper, and create a per-user LaunchAgent from
[`launchd/io.github.codex-micro-stopwatch.companion.plist.example`](launchd/io.github.codex-micro-stopwatch.companion.plist.example).

This is a local installation step, not a distributed package. The generated app
belongs under `companion/.local/` or another local application directory. The
generated LaunchAgent belongs under the user's `~/Library/LaunchAgents/`.

Before loading the LaunchAgent, replace every placeholder with an absolute local
value:

- `__EXECUTABLE_PATH__`: executable inside the locally built app wrapper;
- `__CODEX_PATH__`: intended local Codex executable;
- `__DEVICE_UUID__`: UUID printed by demo discovery on this Mac;
- `__LOG_DIRECTORY__`: a private local log directory.

Codex should lint the generated plist, verify the ad-hoc-signed app with
`codesign --verify --deep --strict`, load it only after user approval, and use
`launchctl print gui/$UID/io.github.codex-micro-stopwatch.companion` plus one
real quota/reset update as the health check. To uninstall, boot out that exact
per-user LaunchAgent before removing only the generated local app, plist, and
logs; never delete or edit the tracked templates.

Do not edit the tracked example in place. Never commit the generated plist,
app, UUID, usernames, home paths, or logs. The root README contains the
recommended prompt for asking Codex to perform and verify this installation.

The first Bluetooth access may trigger a macOS permission prompt. Discovery
filters on the private quota service UUID rather than the advertised
`Codex Micro` name. Real writes additionally require the exact bound
CoreBluetooth UUID, so another same-name peripheral is ignored.

## Data boundary

The companion sends the percentage and reset fields documented in
[`docs/COMPANION_PROTOCOL.md`](../docs/COMPANION_PROTOCOL.md) over the private
quota GATT service. In a real `--watch` run it additionally sends only the fixed
`codex`/`super` display mode RPC over Report ID 6. Agent status, button events,
and voice actions otherwise stay on the Codex Micro HID channel. The companion
recognizes only the four fixed radial events described above and emits only the
three fixed, process-targeted navigation key pairs; it does not capture
keyboard text. It does not read or transmit project names, session titles,
windows, Spaces, workspace state, credentials, prompts, conversation content,
or audio. Audio is outside this companion's scope.
