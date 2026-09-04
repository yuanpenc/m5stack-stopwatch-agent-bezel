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

## Optional three-workspace controls and screens

Only a real `--watch` process enables foreground observation, radial HID input
and workspace HID output. One-shot, `--demo`, `--json-only` and bootloader
modes do not create these controllers.

| Foreground app | Left | Up | Down | Right |
| --- | --- | --- | --- | --- |
| Codex / ChatGPT (`com.openai.codex`) | SUPER | Existing ChatGPT binding | Existing ChatGPT binding | Existing ChatGPT binding |
| SUPER (`com.zarifpour.superconductor`) | HERMES | Previous Project | Next Project | Next Tab |
| HERMES (`com.nousresearch.hermes`) | Codex | Previous Tab | Next Tab | New Tab |

From any other foreground app, left activates Codex first. This is a fixed
cycle, not a remembered-return toggle. The companion activates a running app
or launches the exact bundle ID. A pending activation suppresses additional
left requests until foreground confirmation, failure, an external app switch,
or a 3-second timeout. It never skips a missing app or optimistically switches
the watch screen before the real foreground changes.

Prepare the applications and permissions:

1. Optionally place each app in its own normal macOS Space and use its Dock
   menu, **Options → Assign To → This Desktop**. The companion does not create,
   enumerate or control Spaces with private APIs.
2. Configure SUPER **Previous Project**, **Next Project**, **Next Tab** as
   `Control-Option-Up`, `Control-Option-Down`, `Control-Option-Right`.
3. Keep Hermes Desktop's default `Control-Shift-Tab`, `Control-Tab`,
   `Command-T` bindings for previous, next and new session Tab.
4. Leave only ChatGPT **Analog stick left** unassigned; retain up/down/right.
5. Enable the installed `CodexWatchCompanion.app` under **System Settings →
   Privacy & Security → Input Monitoring** and **Accessibility**. Restart the
   existing LaunchAgent after permissions change; do not start a second watch
   process.

Missing Input Monitoring warns once without stopping quota sync. Missing
Accessibility warns once and disables only SUPER/HERMES navigation; left
activation, display synchronization, quota and USB microphone remain separate.
Up/down/right are companion no-ops in Codex and all other applications.
Navigation uses fixed process-targeted CoreGraphics down/up pairs, revalidating
the foreground identity and PID/bundle pair before delivery. It never posts
these keys globally or retries navigation commands. Physical acceptance must
still confirm ChatGPT performs no background action in SUPER/HERMES.

With matching USB-mic firmware, the watch follows the real foreground:
SUPER and HERMES receive an immediate mode write and a heartbeat every
5 seconds. All other foreground apps select Codex. Each directional lease is
15 seconds and each newly attached device is synchronized immediately. A
failed Codex exit write is retried at most twice, 5 seconds apart, only for
failed devices. A new mode, detach or stop cancels obsolete retries. Failures
are logged at most once per 60 seconds, without payload or device identifiers.
Orderly shutdown attempts Codex before stopping the listener. Owner disconnect
or lease expiry also restores Codex.

Both directional screens share four outward triangles, without an independent
center square border. The title, connection and battery stay in the center.
Each accepted local four-direction swipe chooses four distinct colors from a
12-color pool; every direction changes from its previous color. Text colors
stay fixed, redraws and heartbeats do not reshuffle colors, and the 800ms local
visual cooldown does not replace the host decoder's release gate/cooldown.

Foreground changes while asleep do not wake the display. Disabled short taps,
Agent/Send and the left/right ChatGPT physical buttons do not wake or send HID
actions in SUPER/HERMES. A swipe used to wake the sleeping screen is consumed
as a wake gesture, not sent to the app. Four swipes, the red power button and
the existing long-hold Travel Mode remain available. Held microphone/voice
controls are released on entry and stale Agent transitions are silently
baselined. Returning to Codex restores existing controls. The USB microphone
endpoint is unchanged.

The workspace channel sends only fixed `codex`, `super` or `hermes`, a fixed
TTL for directional modes and a local request number. It does not inspect or
transmit projects, sessions, windows, Spaces, app preferences, credentials or
user content. Workspace control does not run CLI, shell, AppleScript, UI
scraping or private Space APIs; the existing Codex App Server quota subprocess
is unchanged.

For rollback, stop the original LaunchAgent, restore the backed-up signed
Companion app, verify its signature and restart that same agent, preserving its
configuration. Without renewals the new firmware returns to Codex within
15 seconds. Older companions may still select SUPER, but do not support the
new cycle/Hermes behavior. Full rollback additionally restores the saved
USB-mic firmware, only after freshly enumerating the download port and obtaining
explicit confirmation for that exact port. Never reuse a historical port.
Space assignments and app shortcuts can be restored manually.

Diagnostics (direct workspace probes briefly change the physical screen):

```sh
.build/release/codex-watch-companion --json-only
swift ../scripts/hid_rpc_probe.swift --self-test
swift ../scripts/hid_rpc_probe.swift --workspace-super
swift ../scripts/hid_rpc_probe.swift --workspace-hermes
swift ../scripts/hid_rpc_probe.swift --workspace-codex
```

The current three-workspace implementation has automated build/harness
verification; installation, gesture compatibility, Space switching, sleep,
lease timeout, reconnect and USB microphone regression still require physical
acceptance. Build results alone do not establish those outcomes.

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
