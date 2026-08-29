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

## Optional super.engineering left-swipe shortcut

A real `--watch` process also listens for the C152 StopWatch left-swipe HID
report. One left swipe activates or launches the app whose bundle identifier is
`com.zarifpour.superconductor`; the next left swipe returns to the application
that was previously in front. If that application has exited, the companion
leaves super.engineering in front and records the failure without choosing a
different application. Repeated launch gestures are ignored while a launch is
already in progress.

Before using the shortcut:

1. In ChatGPT's StopWatch controller settings, leave **Analog stick left**
   unassigned. The up, right, and down bindings do not need to change.
2. Add the locally installed `CodexWatchCompanion.app` under **System Settings →
   Privacy & Security → Input Monitoring** and enable it.
3. Restart the companion LaunchAgent after changing either setting.

If Input Monitoring is missing, the companion warns once and keeps quota sync
running; only the shortcut is unavailable. The HID listener starts only in a
real `--watch` run, not in one-shot, `--demo`, `--json-only`, or
`--enter-bootloader` modes. It matches only the C152 descriptor and shortcut
report used by this project, and recognizes only the left radial gesture.

This feature does not run `sc`, shell commands, or AppleScript; it does not read
super.engineering sessions, workspaces, settings, credentials, or keyboard
text. It also does not change or reflash the StopWatch firmware. To roll back,
install the previously backed-up companion app and restart the existing
LaunchAgent; no device-side rollback is required.

Useful diagnostics:

```sh
# Verify App Server parsing without using Bluetooth.
.build/release/codex-watch-companion --json-only

# Verify BLE discovery and writes using a synthetic snapshot.
.build/release/codex-watch-companion --demo --verbose
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

The companion sends only the percentage and reset fields documented in
[`docs/COMPANION_PROTOCOL.md`](../docs/COMPANION_PROTOCOL.md). Agent status,
button events, voice actions, and the other analog directions stay on the Codex
Micro HID channel. In a real `--watch` run, the companion recognizes only the
left radial event described above; it does not capture keyboard text. Audio is
outside this companion's scope.
