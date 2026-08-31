# Stopwatch AgentBezel C152

[简体中文](README.zh-CN.md)

**Stopwatch AgentBezel C152** is an independent, unofficial, open-source
dual-workspace control surface for the **M5Stack StopWatch Dev Kit C152**.
It gives one physical device a Codex Micro-compatible workspace and an optional
dedicated super.engineering workspace, plus a local quota dashboard and an
optional USB microphone.

Codex Micro compatibility is experimental and undocumented. Compatibility-
facing runtime names intentionally remain unchanged so existing Bluetooth
pairing, audio selection, macOS permissions, and automatic startup keep working.

## Two workspaces

<table>
  <tr>
    <th>Codex Micro workspace</th>
    <th>super.engineering workspace <em>(optional)</em></th>
  </tr>
  <tr>
    <td width="50%"><img src="artifacts/dashboard-preview-v2-round.png" alt="Codex Micro workspace showing six controls, connection status, quota, reset time, and battery"></td>
    <td width="50%"><img src="artifacts/super-workspace-preview.png" alt="super.engineering workspace showing SUPER status, connection, battery, and four directional controls"></td>
  </tr>
</table>

Codex Micro is the default ChatGPT/Codex surface for Agent status, quota,
voice, Send, and configurable directions. super.engineering is an optional,
foreground-aware integration for entering or leaving that app, moving between
projects, and advancing session tabs. Without it, the complete Codex Micro
experience remains available.

| StopWatch input | Codex Micro workspace | super.engineering workspace |
| --- | --- | --- |
| Hold left physical button | Push to talk | No action |
| Press right physical button | Toggle Voice Chat | No action |
| Tap center | Send | No action |
| Swipe left | User-configurable direction | Enter or leave super.engineering |
| Swipe up | User-configurable direction | Previous project |
| Swipe down | User-configurable direction | Next project |
| Swipe right | User-configurable direction | Next session tab |
| Power controls | Desk sleep and Travel Mode | Same power behavior |

## Codex Micro workspace

The default dashboard shows Agent state, weekly Codex allowance, reset
countdown, battery and charging/Dock state, and whether Codex, BLE, and quota
sync are healthy. A completed Agent turns green and plays a soft completion
chime. The left physical button is Push to talk, the right button is Voice
Chat, the center dial is Send, and all four swipe directions remain
user-configurable in ChatGPT Desktop. Physical buttons and touch gestures use
haptics.

The compatible `Codex Micro` BLE HID channel carries controls. The local quota
companion uses a separate, project-owned BLE GATT service, so the watch never
stores an OpenAI token. The installed ChatGPT Desktop version used during
development exposed one Mic key rather than separate `ACT10` and `ACT11`
assignments: the right button intentionally sends configurable `ACT09`
(`Command Key 4`), not `ACT11`.

On battery, the display dims after two minutes and enters desk sleep after five;
Dock Mode extends those intervals to ten and thirty minutes. Desk sleep keeps
BLE alerts alive. Double-click the red power button for firmware-confirmed
Travel Mode shutdown; power button or USB wakes it. A six-second center hold is
a deliberately slower Travel Mode fallback with a missed-alert warning. Physical
power switching soak testing is still pending, so timings and wake behavior are
experimental until that checklist is complete.

## Optional super.engineering workspace

This integration is optional and identifies super.engineering only by the exact
bundle identifier `com.zarifpour.superconductor`. It sends only fixed workspace
mode and targeted shortcut events; it never reads or transmits project names,
session names, windows, Spaces, workspace state, prompts, conversations,
credentials, or configuration content.

### Setup

1. Assign super.engineering to a dedicated normal macOS Space. Create the
   Space, move the app there, then choose **Dock → Options → Assign To → This
   Desktop**. The Companion neither creates nor enumerates Spaces.
2. In super.engineering **Keyboard Shortcuts**, configure **Previous Project**
   = `Control-Option-Up`, **Next Project** = `Control-Option-Down`, and **Next
   Tab** = `Control-Option-Right`.
3. Enable both Input Monitoring and Accessibility for the installed
   `CodexWatchCompanion.app`. Accessibility is required for project and tab
   navigation; the Companion does not change macOS permissions itself.
4. Leave only ChatGPT's Analog stick left direction unbound; retain its
   original up, down, and right mappings.

Swipe left to enter super.engineering, or to return to the exact previously
foreground application when super.engineering is already in front. Swipe up
selects Previous Project, down selects Next Project, and right selects Next
Tab. These Companion-led entry, return, project, and tab controls are available
without the USB-mic image. The automatic physical SUPER screen, its firmware
lease, and device-side input isolation require the separately user-chosen,
matching `usb-mic` image. With that image installed, the watch follows the
foreground app, refreshes SUPER every 5 seconds, and falls back to Codex within
15 seconds without a valid lease. The screen does not wake merely because the
foreground app changes.

With the matching `usb-mic` image installed, SUPER isolates Agent, Send, Voice
Chat, and ChatGPT physical-button actions while preserving the four workspace
swipes and power controls. Disabled inputs emit neither HID actions nor success
haptics; entering releases any held microphone/voice control. Returning to
Codex restores all existing controls. The Companion context-gates up, down, and
right to the exact foreground app, then sends fixed process-targeted keys rather
than global input.

### Acceptance checklist

- Left enters the assigned super.engineering Space and returns to the exact
  preceding app and Space.
- Up and down visibly select Previous Project and Next Project; right advances
  Next Tab using the application's own wraparound behavior.
- With the separately chosen matching `usb-mic` image, the SUPER screen appears
  while super.engineering is foreground; stopping the Companion or losing its
  lease restores Codex within 15 seconds.
- With that matching `usb-mic` image, SUPER blocks Agent, Send, Voice Chat, and
  ChatGPT physical-button actions; after return, Codex controls and ChatGPT's
  up/down/right mappings work again.

## Recommended installation

This is a source-build project: no prebuilt macOS app, DMG, or PKG is
distributed. The recommended path is to open this repository locally in Codex
on the Bluetooth-capable Mac that will pair with the C152. It requires macOS
14+, Swift 5.10+ (Xcode 15.3 Command Line Tools+), PlatformIO Core, a
data-capable USB-C cable for the first flash, and a signed-in ChatGPT Desktop
with Codex Micro support. This port supports **M5Stack StopWatch Dev Kit, SKU
C152** only; other M5Stack devices are unsupported.

Connect the C152, do not guess its serial port, and paste this into Codex:

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
   CODEX_MICRO_STOPWATCH_READY`, then guide me through macOS Bluetooth pairing.
7. Help me grant ChatGPT Input Monitoring and configure ChatGPT Desktop: left
   button = Push to talk, Command Key 4 = Toggle voice chat, center = Send, and
   let me choose the four swipe actions.
8. Build the Swift quota companion from source. Use demo discovery to find this
   Mac's CoreBluetooth UUID, then bind real quota writes to that exact device.
9. If I approve automatic startup, create the local app wrapper and LaunchAgent
   only on this Mac. Keep generated paths, UUIDs, logs, and app files out of Git.
10. Verify buttons, center Send, four swipes, Agent colors, completion chime,
    haptics, and a real quota/reset update separately. Report anything not
    physically observed as unverified.
11. Only if I explicitly choose the optional super.engineering phase, guide me
    through its Space, shortcuts, and acceptance checks. Do not silently enable
    Accessibility, edit super.engineering settings, or assign a Space.
12. Do not select or flash the optional USB microphone image unless I explicitly
    choose that separate phase.
```

The repository's [AGENTS.md](AGENTS.md) provides durable installation and
privacy boundaries. Claude Code and other local coding agents can follow the
same instructions, but Codex is the documented default.

## macOS permissions and app configuration

Codex handles terminal work; the user still approves missing tools and the
exact flash, pairs **Codex Micro** in **System Settings > Bluetooth**, and
allows **ChatGPT** in **System Settings > Privacy & Security > Input
Monitoring** before quitting and reopening ChatGPT. Configure the actions in
**ChatGPT Desktop > Settings > Codex Micro**. The base installation needs
Bluetooth access for the locally built companion; the optional
super.engineering phase additionally needs Input Monitoring and Accessibility
for `CodexWatchCompanion.app`.

Build the quota companion from source, run demo discovery, and bind real writes
only to the CoreBluetooth UUID printed by that Mac. Keep the `--watch` process
running unless automatic startup is installed. With approval, a locally built
wrapper and per-user LaunchAgent can provide automatic startup; generated app
files, paths, UUIDs, and logs remain local. The LaunchAgent template identity is
`io.github.codex-micro-stopwatch.companion` and the executable remains
`codex-watch-companion`.

If macOS caches an older HID descriptor after changing images, forget only the
StopWatch's **Codex Micro** pairing and pair it again. Keep a real Codex
Micro's pairing record, but disconnect or power it off while validating this
port: one active Micro is supported at a time.

## Optional USB microphone

The default `m5stack-stopwatch` image uses the Mac microphone. Users who
explicitly choose the isolated `usb-mic` build can expose the StopWatch as
**Codex StopWatch Mic**: 48 kHz, 16-bit, mono, input-only USB Audio. It has no
USB speaker/output endpoint. BLE controls and the dashboard remain included;
the local completion chime plays only while the Mac is not streaming microphone
audio. Keep USB connected while recording, select **Codex StopWatch Mic** in
**System Settings > Sound > Input**, and keep Push to talk and Voice Chat
actions on Bluetooth while audio samples travel over USB.

Build this separate target with `pio run -d usb-mic`; explain its first-build
toolchain download, time, and disk cost before starting. Follow the same
factory-recovery and exact-port confirmation rules. Afterward, do not expect
the default serial READY marker: verify the selected **Codex StopWatch Mic**
input, verify BLE/HID separately, and make a short local recording test. Do
not commit recordings, device identifiers, or local paths.

## Privacy and architecture

The Swift `CodexWatchCompanion` starts a local Codex App Server with the
user's existing signed-in context and reads `account/rateLimits/read`. It sends
only remaining percentage and reset countdown over the project-owned quota
GATT service to the explicitly bound watch. The compatible HID interface does
not include account rate limits.

In a real `--watch` run, the optional workspace integration additionally sends
only the fixed `codex` or `super` display-mode enum over vendor HID Report ID
6. It does not send API keys, tokens, account identifiers, prompts, task text,
audio, project/session/window/Space metadata, or user content. It does not
scrape UI, use a cloud relay, inspect keyboard text, invoke shell commands or
AppleScript, use private Space APIs, or inspect super.engineering settings.

Device MAC addresses, CoreBluetooth UUIDs, usernames, home-directory paths,
and logs are local installation data and must never be committed. BLE pairing
uses the platform's Just Works flow without passkey authentication: use the
project in a trusted environment and remove stale pairings when a Mac or watch
changes owner. See [the companion documentation](companion/README.md) and the
[GATT contract](docs/COMPANION_PROTOCOL.md).

## Manual build and flash

The Codex-assisted flow is recommended. Maintainers can use
[PlatformIO Core](https://docs.platformio.org/en/latest/core/index.html):

```sh
pio run -e m5stack-stopwatch
pio device list
```

Identify the exact serial device that appeared for the connected C152. Build
first, read M5Stack's [official StopWatch factory-recovery guide](https://docs.m5stack.com/en/guide/restore_factory/stopwatch),
and only then flash the resolved port after explicit confirmation:

```sh
pio run -e m5stack-stopwatch --target upload --upload-port /dev/cu.YOUR_C152_PORT
```

Never copy a port from another user's documentation. A successful default boot
prints `CODEX_MICRO_STOPWATCH_READY`; verify it against that same port:

```sh
python3 scripts/serial_probe.py /dev/cu.YOUR_C152_PORT --seconds 30 \
  --expect CODEX_MICRO_STOPWATCH_READY
```

For the optional USB-mic image, use the same recovery and exact-port safeguards:

```sh
pio run -d usb-mic
pio run -d usb-mic -e m5stack-stopwatch-usb-mic --target upload \
  --upload-port /dev/cu.YOUR_C152_PORT
```

The USB-mic image replaces normal USB serial with audio, so no
`CODEX_MICRO_STOPWATCH_READY` is expected. Later updates can use the
companion's encrypted `--enter-bootloader` command, then must rediscover and
confirm the newly enumerated port; M5Stack's manual recovery gesture remains
the fallback.

To run the quota companion manually:

```sh
cd companion
swift build -c release

# Demo data only; prints the UUID seen by this Mac.
.build/release/codex-watch-companion --demo --verbose

# Replace the placeholder locally. Never commit the resulting UUID.
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --watch --interval 60
```

## Troubleshooting

### The C152 does not appear as a serial device

- Try a known data-capable USB-C cable and another port.
- Disconnect other development boards, list ports again, and reconnect only the
  C152.
- If installed firmware cannot boot, follow M5Stack's official download-mode
  and factory-recovery instructions.

### Codex Micro does not appear in Bluetooth settings

- Restart the watch and scan again.
- Forget an old **Codex Micro** pairing before retrying.
- For the default image, confirm `CODEX_MICRO_STOPWATCH_READY` over serial. For
  USB-mic, verify its audio interface and BLE/HID independently.

### ChatGPT sees the Micro but controls do nothing

- Allow ChatGPT in Input Monitoring, then quit and reopen it.
- Disconnect any other active Codex Micro.
- Temporarily quit keyboard remappers or security tools that may claim or block
  HID, then reconnect.

### The right button does not open Voice Chat

Assign **Command Key 4** to **Toggle voice chat** in ChatGPT Desktop. The
button sends `ACT09`, not `ACT11`.

### The screen says `SYNCING MAC` or quota is stale

- Confirm the companion runs on the paired Mac.
- Re-run demo discovery and bind the exact UUID printed on that Mac.
- Do not copy a UUID from another computer: CoreBluetooth identifiers are local
  to the host.

### Optional workspace navigation does not work

- Confirm the foreground bundle is `com.zarifpour.superconductor`, the three
  fixed shortcuts work from the physical keyboard, and Accessibility is enabled
  for `CodexWatchCompanion.app`.
- Input Monitoring is required to receive radial gestures. If Accessibility is
  missing, only project/tab navigation is disabled; left entry/return, quota,
  and USB microphone input remain available.

## Acknowledgements, license, and trademarks

This project adapts portions of the BLE compatibility layer from
[`imliubo/codex-micro-4-core2`](https://github.com/imliubo/codex-micro-4-core2)
under the MIT License. We thank its author and preserve applicable attribution
in [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). The StopWatch UI, power
behavior, quota companion, and optional USB microphone are this port's own
additions. Space Mono remains under the SIL Open Font License 1.1 in
`assets/fonts/OFL.txt`.

OpenAI documentation for the original device is available at
[Codex Micro](https://learn.chatgpt.com/docs/features/codex-micro), and the
local client interface used by the companion is documented under
[Codex App Server](https://learn.chatgpt.com/docs/app-server).

Names and marks are used only to identify compatibility. See [NOTICE.md](NOTICE.md)
for attribution, protocol, security, warranty, and trademark notices.
