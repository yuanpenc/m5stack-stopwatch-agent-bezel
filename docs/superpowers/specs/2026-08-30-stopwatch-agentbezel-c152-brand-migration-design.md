# Stopwatch AgentBezel C152 Brand Migration Design

**Status:** Implemented and verified

**Verification scope:** Local implementation, compatibility, build, and privacy
evidence is verified. The GitHub description/topics update and remote `main`
equality publication gate remain pending Task 3.

**Date:** 2026-08-30

## Objective

Adopt **Stopwatch AgentBezel C152** as the public project brand while keeping
every installed device, macOS permission, protocol, and compatibility boundary
stable. The migration changes presentation and repository metadata only. It
does not require a firmware flash or Companion reinstall.

## Public identity

- Product name: **Stopwatch AgentBezel C152**
- Repository slug: `m5stack-stopwatch-agent-bezel`
- English description: `Open-source AI agent control surface for M5Stack
  StopWatch C152 with Codex Micro compatibility, super.engineering workspace
  controls, a quota dashboard, and an optional USB microphone.`
- Chinese description: `面向 M5Stack StopWatch C152 的开源 AI Agent 控制界面，
  支持 Codex Micro 兼容控制、super.engineering 工作区、额度面板和可选 USB
  麦克风。`

The README files lead with the new brand, describe the project as independent
and unofficial, and use Codex Micro, ChatGPT, super.engineering, and M5Stack
only as compatibility or product references.

## Files that change

The implementation updates:

- `README.md` and `README.zh-CN.md`: title, opening description, and a short
  brand-versus-compatibility explanation.
- `LICENSE` and `NOTICE.md`: the port contributor identity becomes
  `Stopwatch AgentBezel C152 contributors`; upstream copyright and all existing
  trademark and compatibility notices remain.
- Port-owned copyright comments in `src/main.cpp`, `src/CodexMicroBle.cpp`, and
  `include/CodexMicroBle.h`.
- The GitHub repository description and topics for
  `jiangew/m5stack-stopwatch-agent-bezel`.

Historical implementation plans and specifications keep their original terms.
They are development records rather than current product branding.

## Compatibility identifiers that do not change

The following strings are runtime or migration contracts, not project branding,
and remain byte-for-byte unchanged:

- BLE device name `Codex Micro` and the Codex Micro-compatible HID descriptor.
- USB Audio product name `Codex StopWatch Mic` and its legacy aliases.
- Swift package, module, executable, and app name `CodexWatchCompanion` and
  `codex-watch-companion`.
- Bundle identifier and LaunchAgent label
  `io.github.codex-micro-stopwatch.companion`.
- Existing Companion log names, local app paths, and permission-bearing bundle
  structure.
- BLE GATT UUIDs, HID report identifiers, RPC method names, USB descriptors
  other than the unchanged product name, and all device matching constants.
- On-device functional labels such as `CODEX` and `SUPER`, which identify the
  active workspace rather than the repository brand.

Keeping these identifiers stable preserves pairing, Input Monitoring,
Accessibility, Bluetooth authorization, audio device selection, automatic
startup, and the already-installed C152 firmware.

## GitHub presentation

The repository description uses the English public description above. Topics
are limited to discoverability terms that describe the implementation:

- `m5stack`
- `esp32-s3`
- `stopwatch`
- `ai-agents`
- `codex`
- `macos`
- `swift`
- `platformio`
- `ble-hid`
- `usb-audio`

No homepage, release, package, or binary distribution is added as part of this
migration.

## Verification

Before publication, verification must prove:

1. Both README titles and opening descriptions use the new brand.
2. The legal contributor name is consistent while upstream attribution remains.
3. Every protected runtime identifier listed above is unchanged.
4. The tracked tree contains no personal paths, device identifiers, credentials,
   or non-noreply commit email metadata.
5. The nine native tests, native preview build, and both USB-microphone firmware
   environments still pass.
6. The GitHub description and topics match this design and remote `main` equals
   the verified local HEAD.

### Verification record — 2026-08-31

The protected-identifier assertions passed, including the unchanged BLE, USB
audio, Companion package/executable, bundle identifier, LaunchAgent, and
runtime-source diff contracts. The native tests `completion_banner`,
`connection_health`, `gesture`, `host_rpc_request`, `power_button_gesture`,
`quota_payload`, `super_workspace_ui`, `workspace_input_policy`, and
`workspace_mode` compiled and passed with `-Wall -Wextra -Werror`.

The native preview build passed using the pinned local M5GFX dependency. Both
USB-microphone environments (`prepare-bluedroid` and
`m5stack-stopwatch-usb-mic`) built successfully. The tracked-file privacy scan
and noreply commit-metadata check passed. No firmware was flashed and no
installed Companion was changed.

## Rollback

The branding commit can be reverted without changing firmware or the installed
Companion. GitHub description and topics can be restored independently. No
rollback step may rename or rewrite a protected runtime identifier.
