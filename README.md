# Codex Micro for M5Stack StopWatch

[简体中文](README.zh-CN.md)

Turn an **M5Stack StopWatch Dev Kit C152** into an experimental Codex Micro
control surface and a small Codex usage dashboard.

![Native 466 x 466 dashboard preview](artifacts/dashboard-preview-v2-round.png)

## What it does

- Shows Agent status.
- Shows weekly Codex allowance remaining and the reset countdown.
- Shows battery, charging/Dock state, and whether Codex, BLE, and quota sync
  are actually healthy.
- Turns a completed Agent green and plays a soft completion chime.
- Uses the left physical button for push-to-talk.
- Uses the right physical button for Voice Chat.
- Uses the large center dial as Send.
- Maps full-screen up, right, down, and left swipes to the four configurable
  Codex Micro analog-stick directions.
- Provides haptic feedback for the physical buttons and touch gestures.
- Supports BLE-aware desk sleep and a long-hold Travel Mode power-off.
- Optionally exposes the StopWatch microphone to the Mac over USB.

The control surface uses the Codex Micro-compatible BLE HID channel. Quota data
travels separately from a local macOS companion over a project-owned BLE GATT
service. The watch never stores an OpenAI token.

## Requirements

- **M5Stack StopWatch Dev Kit, SKU C152**. Other M5Stack devices are not
  supported by this port.
- A Bluetooth-capable Mac running macOS 14 or newer.
- A data-capable USB-C cable for the first flash. Normal use is wireless; the
  optional microphone build keeps the cable connected while recording.
- Swift 5.10 or newer (Xcode 15.3 Command Line Tools or newer) and PlatformIO
  Core.
  Codex can install a missing tool after explaining the change and obtaining
  approval.
- ChatGPT Desktop with Codex Micro support and an existing signed-in Codex
  session.
- The local Codex app, CLI, or another local coding agent capable of running
  shell commands.

## Recommended installation: let Codex do it

This is the primary installation path. The project intentionally does not
distribute a prebuilt macOS app, DMG, or PKG. Codex builds the firmware and
companion from source on the user's Mac and keeps machine-specific values local.

### 1. Open the repository locally

Download this repository as a ZIP or clone it, then open its folder in the
Codex desktop app. Keep the repository on the Mac that will pair with the
StopWatch.

### 2. Connect the StopWatch

Connect the C152 with a data-capable USB-C cable. Do not guess which serial port
belongs to it if other development boards are connected.

### 3. Paste this into Codex

```text
Install this project on my physical M5Stack StopWatch Dev Kit C152.

Read AGENTS.md and README.md completely before acting. Work through the setup
autonomously, but follow these safety rules:

1. Start with read-only checks. Confirm macOS, the C152 target, available build
   tools, and the exact newly connected serial device.
2. Do not build or enable any microphone, USB Audio, BLE Audio, diagnostics, or
   other deferred experiment. Use only the m5stack-stopwatch firmware target.
3. Explain any missing dependency before installing it. Never ask me for an
   OpenAI API key, login cookie, access token, or other credential.
4. Show me the official M5Stack factory-recovery link and build the firmware
   before attempting an upload.
5. Immediately before flashing, report the exact /dev/cu.* port you resolved
   and ask me to confirm that one destructive device action.
6. After flashing, verify the CODEX_MICRO_STOPWATCH_READY marker with
   `python3 scripts/serial_probe.py <the exact port> --seconds 30 --expect
   CODEX_MICRO_STOPWATCH_READY`, then guide me
   through macOS Bluetooth pairing.
7. Help me grant ChatGPT Input Monitoring and configure ChatGPT Desktop: left
   button = Push to talk, Command Key 4 = Toggle voice chat, center = Send, and
   let me choose the four swipe actions.
8. Build the Swift quota companion from source. Use demo discovery to find this
   Mac's CoreBluetooth UUID, then bind real quota writes to that exact device.
9. If I approve automatic startup, create the local app wrapper and LaunchAgent
   only on this Mac. Keep generated paths, UUIDs, logs, and app files out of Git.
10. Verify buttons, center Send, four swipes, Agent colors, completion chime,
    haptics, and a real quota/reset update separately. Report anything that was
    not physically observed as unverified.
```

The repository's [AGENTS.md](AGENTS.md) gives Codex durable installation and
privacy boundaries, so the prompt can stay readable. Claude Code and other
local coding agents can follow the same instructions, but Codex is the
documented default path.

### Optional: use the StopWatch as a USB microphone (experimental)

The default build uses the Mac's microphone. Users who want the StopWatch's
built-in microphone can instead ask Codex to install the isolated `usb-mic`
build. On macOS it appears as **Codex StopWatch Mic**, with 48 kHz,
16-bit, mono input. It does not expose a USB speaker, and the watch's
local completion chime plays only while the Mac is not streaming microphone
audio. BLE controls and the dashboard remain included.

Paste this after opening the repository in Codex:

```text
Install the optional USB microphone build on my physical M5Stack StopWatch C152.
Read AGENTS.md and README.md first. Build the isolated usb-mic PlatformIO
project with `pio run -d usb-mic`; do not add a USB speaker/output endpoint.
The existing local-only idle completion chime may remain enabled. Follow
the documented factory-recovery and exact-port confirmation rules before
flashing. This target has a large isolated toolchain, so explain the first-build
download, time, and disk cost before starting. Afterward, do not look for the
default serial READY marker: verify that macOS lists "Codex StopWatch Mic" as
an input device, verify BLE/HID separately, and help me make a short local
recording test. Do not commit the recording, device identifiers, or local paths.
```

After installation, select **Codex StopWatch Mic** in **System Settings >
Sound > Input**. ChatGPT Desktop still receives Push to talk and Voice Chat
actions over Bluetooth, while voice samples travel through USB.

Both images use Bluedroid for the Codex Micro BLE transport. If macOS keeps an
older HID descriptor after switching images, forget only the StopWatch's
**Codex Micro** entry and pair it again. This port supports one active Micro at
a time: keep a real Codex Micro's pairing record, but disconnect or power it
off while installing, validating, or using the StopWatch.

### 4. Finish the visible permission steps

Codex will handle the terminal work, but macOS may still require the user to:

1. Approve installation of a missing build tool.
2. Confirm the exact device immediately before flashing.
3. Pair **Codex Micro** in **System Settings > Bluetooth**.
4. Allow **ChatGPT** in **System Settings > Privacy & Security > Input
   Monitoring**, then quit and reopen ChatGPT.
5. Approve Bluetooth access for the locally built companion.
6. Configure the actions in **ChatGPT Desktop > Settings > Codex Micro**.

## Controls

| StopWatch input | Reported control | Recommended Codex action |
| --- | --- | --- |
| Hold left physical button | Mic key `ACT10` | Push to talk |
| Press right physical button | Command Key 4 `ACT09` | Toggle voice chat |
| Tap the center quota dial | Send key `ACT12` | Send composer message |
| Swipe up | Analog stick up | User configurable |
| Swipe right | Analog stick right | User configurable |
| Swipe down | Analog stick down | User configurable |
| Swipe left | Analog stick left | User configurable |
| Click the red power button | Desk sleep / wake | BLE alerts remain active |
| Double-click the red power button | Travel Mode power-off | Power button or USB wakes it |
| Hold the center dial for 6 seconds | Warned Travel Mode fallback | Power button or USB wakes it |

The installed ChatGPT Desktop version used during development exposed one Mic
key rather than separate `ACT10` and `ACT11` assignments. The right button is
therefore intentionally a configurable command key, not the second Mic switch.

On battery, the display dims after two minutes and enters desk sleep after five
minutes. Dock Mode is detected from USB input power and extends those intervals
to ten and thirty minutes. The default wireless image turns off the shared
AMOLED/audio/motor rail during desk sleep while keeping BLE alive; the optional
USB-mic image keeps its audio rail on and uses brightness-only desk sleep.
Travel Mode is a real PM1 shutdown, so Agent alerts are missed until the power
button or USB power starts the device again. The red-button double-click uses a
firmware-confirmed clean shutdown instead of PM1's immediate hardware cut; a
long red-button hold remains the hardware recovery/download gesture. The
six-second center hold is a deliberately slower fallback with an on-screen
missed-alert warning.

The native renderer and both firmware targets pass their current build-time
checks. Those checks cannot validate physical power switching: C152 sleep/wake
and shutdown soak testing is still pending, so treat the timings and wake
behavior as experimental until that checklist is completed.

## Quota companion and privacy

The Codex Micro HID interface does not include account rate limits. The Swift
companion starts a local Codex App Server using the user's existing signed-in
context, reads `account/rateLimits/read`, and sends this small snapshot to the
explicitly bound watch:

- remaining percentage;
- reset countdown;

In a real `--watch` run, the optional super.engineering integration also sends
only a fixed `codex` or `super` display-mode enum over vendor HID Report ID 6.
It never sends project, session, window, Space, workspace, prompt, or
conversation content.

It does not send an API key, access token, account identifier, prompt, task text,
or audio to the watch. Device MAC addresses, CoreBluetooth UUIDs, usernames,
home-directory paths, and logs are local installation data and must never be
committed. See [the companion documentation](companion/README.md) and the
[GATT contract](docs/COMPANION_PROTOCOL.md).

BLE pairing uses the platform's Just Works flow without passkey authentication.
Use the project only in a trusted environment and remove stale pairings when a
Mac or watch changes owner.

## Manual build and flash

The Codex-assisted flow is recommended. Maintainers can also build manually
with [PlatformIO Core](https://docs.platformio.org/en/latest/core/index.html):

```sh
pio run -e m5stack-stopwatch
pio device list
```

Identify the exact serial device that appeared for the connected C152. Build
first, read M5Stack's
[official StopWatch factory-recovery guide](https://docs.m5stack.com/en/guide/restore_factory/stopwatch),
and only then flash the resolved port:

```sh
pio run -e m5stack-stopwatch --target upload --upload-port /dev/cu.YOUR_C152_PORT
```

Never copy a port from another user's documentation. A successful boot prints:

```text
CODEX_MICRO_STOPWATCH_READY
```

Verify that marker against the same resolved port:

```sh
python3 scripts/serial_probe.py /dev/cu.YOUR_C152_PORT --seconds 30 \
  --expect CODEX_MICRO_STOPWATCH_READY
```

Pair **Codex Micro** in macOS, open ChatGPT Desktop, and configure the controls
from the table above. If macOS cached an older HID descriptor, forget the device
on the Mac, restart the watch, and pair it again.

For the optional input-only USB microphone image, use the same exact-port and
recovery checks, but build and upload the isolated project instead:

```sh
pio run -d usb-mic
pio run -d usb-mic -e m5stack-stopwatch-usb-mic --target upload \
  --upload-port /dev/cu.YOUR_C152_PORT
```

Once it boots, the normal USB serial port is replaced by the audio interface.
The first clean USB-mic build downloads and builds a separate ESP32 toolchain;
it can take several minutes and use substantial temporary disk space. The
absence of `CODEX_MICRO_STOPWATCH_READY` over USB is expected for this image.
For later updates, Codex can use the companion's encrypted
`--enter-bootloader` command and then verify the newly enumerated serial port.
M5Stack's manual recovery gesture remains the fallback.

### Run the quota companion manually

```sh
cd companion
swift build -c release

# Demo data only; prints the UUID seen by this Mac.
.build/release/codex-watch-companion --demo --verbose

# Replace the placeholder locally. Never commit the resulting UUID.
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --watch --interval 60
```

Ask Codex to create the optional local app wrapper and per-user LaunchAgent for
automatic startup. The repository contains generic templates, never a generated
user configuration or prebuilt companion app.

## Troubleshooting

### The C152 does not appear as a serial device

- Try a known data-capable USB-C cable and another port.
- Disconnect other development boards, list ports again, and reconnect only the
  C152.
- If the installed firmware cannot boot, follow M5Stack's official download-mode
  and factory-recovery instructions.

### Codex Micro does not appear in Bluetooth settings

- Restart the watch and scan again.
- Forget any old **Codex Micro** pairing before retrying.
- For the default image, confirm the firmware reached
  `CODEX_MICRO_STOPWATCH_READY` over serial. For the USB-mic image, verify its
  audio interface and BLE/HID independently because it has no normal USB serial
  console.

### ChatGPT sees the Micro but the controls do nothing

- Allow ChatGPT under **System Settings > Privacy & Security > Input
  Monitoring**, then quit and reopen it.
- Disconnect any other active Codex Micro; this port supports one active Micro
  at a time.
- Temporarily quit keyboard remappers or security tools that may claim or block
  the HID device, then reconnect it.

### The right button changes UI but does not open Voice Chat

Assign **Command Key 4** to **Toggle voice chat** in ChatGPT Desktop. The right
button sends `ACT09`; it is not `ACT11` in this port.

### The screen says `SYNCING MAC` or quota is stale

- Confirm the companion is running on the paired Mac.
- Re-run demo discovery and bind the exact UUID printed on that Mac.
- Do not use a UUID copied from another computer; CoreBluetooth identifiers are
  local to the host.

## Acknowledgements, license, and trademarks

This project adapts portions of the BLE compatibility layer from
[`imliubo/codex-micro-4-core2`](https://github.com/imliubo/codex-micro-4-core2)
under the MIT License. We thank its author and preserve the applicable
attribution in [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). The StopWatch UI,
power behavior, quota companion, and optional USB microphone are this port's
own additions. Space Mono remains under the SIL Open Font License 1.1 in
`assets/fonts/OFL.txt`.

OpenAI's documentation for the original device is available at
[Codex Micro](https://learn.chatgpt.com/docs/features/codex-micro), and the local
client interface used by the companion is documented under
[Codex App Server](https://learn.chatgpt.com/docs/app-server).

Names and marks are used only to identify compatibility. See
[NOTICE.md](NOTICE.md) for attribution, protocol, security, warranty, and
trademark notices.
