# Stopwatch AgentBezel C152 Dual-Workspace README Design

**Status:** Implemented and locally verified

**Date:** 2026-08-31

## Objective

Rewrite the English and Simplified Chinese project READMEs so the public
repository presents Stopwatch AgentBezel C152 as a dual-workspace AI agent
control surface. Codex Micro and super.engineering are both first-class
capabilities, while super.engineering remains an optional integration.

The new README must show both physical display designs near the top of the
page: the existing Codex Micro dashboard and the dedicated SUPER workspace.
Installation and technical details remain available, but they no longer obscure
the product's two-workspace model.

## Public positioning

The opening describes Stopwatch AgentBezel C152 as an independent, unofficial,
open-source control surface for the M5Stack StopWatch Dev Kit C152. It states
that Codex Micro compatibility is experimental and undocumented.

The two workspace roles are distinct:

- **Codex Micro workspace:** the default control surface for ChatGPT/Codex,
  quota status, Agent state, voice actions, Send, and configurable directions.
- **super.engineering workspace:** an optional foreground-aware workspace for
  entering or leaving super.engineering, selecting projects, and advancing
  session tabs.

Users who do not enable super.engineering retain the complete Codex Micro
experience. The README must not imply that super.engineering is required for
normal operation.

## First-screen presentation

Immediately after the opening and compatibility notice, both 466 x 466 display
previews appear in a two-column GitHub-compatible layout:

1. **Codex Micro Workspace** uses the existing
   `artifacts/dashboard-preview-v2-round.png` asset.
2. **super.engineering Workspace** uses a new tracked
   `artifacts/super-workspace-preview.png` asset.

Each image has meaningful English or Chinese alternative text. On narrow
renderers, the content may wrap, but Codex Micro remains first and
super.engineering second in reading order.

The SUPER asset is regenerated from the repository's current deterministic
`super` preview scenario. It represents the normal connected state and contains
only fixed interface labels, connection state, and battery state. It contains
no project name, session name, device identifier, path, or user content.

Below the gallery, a compact comparison summarizes the input model:

| Input | Codex Micro workspace | super.engineering workspace |
| --- | --- | --- |
| Left physical button | Push to talk | No action with matching `usb-mic` firmware |
| Right physical button | Toggle Voice Chat | No action with matching `usb-mic` firmware |
| Center tap | Send | No action with matching `usb-mic` firmware |
| Swipe left | User-configurable Codex Micro direction | Enter or leave super.engineering |
| Swipe up | User-configurable Codex Micro direction | Previous project |
| Swipe down | User-configurable Codex Micro direction | Next project |
| Swipe right | User-configurable Codex Micro direction | Next session tab |
| Power controls | Existing desk sleep and Travel Mode | Existing power behavior |

The detailed workspace sections explain why the controls differ instead of
mixing both contexts into one ambiguous control table.

## README information architecture

Both language versions use the same section sequence and equivalent facts:

1. Product identity, compatibility boundary, and dual-workspace gallery.
2. Dual-workspace overview and comparison.
3. Codex Micro workspace.
4. Optional super.engineering workspace.
5. Recommended quick installation.
6. Required macOS permissions and application configuration.
7. Optional USB microphone.
8. Privacy and architecture.
9. Manual build and flash.
10. Troubleshooting.
11. Acknowledgements, license, and trademarks.

The rewrite preserves useful commands, exact-port flash safeguards, factory
recovery guidance, quota Companion details, privacy constraints, and existing
troubleshooting. Repeated explanations are consolidated.

## Codex Micro workspace section

This section explains:

- the dashboard's Agent, quota, connection, reset, and battery states;
- the physical buttons, center Send action, and configurable swipe directions;
- ChatGPT Input Monitoring and Codex Micro settings;
- completion feedback, haptics, desk sleep, and Travel Mode;
- the separation between the compatible HID channel and the project-owned
  quota GATT channel.

It preserves the existing runtime names `Codex Micro`, `Codex StopWatch Mic`,
`CodexWatchCompanion`, `codex-watch-companion`, and
`io.github.codex-micro-stopwatch.companion`.

## Optional super.engineering workspace section

This section gives super.engineering equal product visibility without making it
a default requirement. It explains:

- assigning super.engineering to a dedicated normal macOS Space;
- left swipe to enter or return;
- up for Previous Project, down for Next Project, and right for Next Tab;
- configuring `Control-Option-Up`, `Control-Option-Down`, and
  `Control-Option-Right` in super.engineering;
- enabling Accessibility for the Companion;
- leaving only ChatGPT's Analog stick left direction unbound while retaining
  its original up, down, and right mappings;
- the automatic physical SUPER display, five-second heartbeat, and fifteen-
  second lease fallback;
- input isolation while SUPER is active and full Codex restoration afterward.

The privacy statement is explicit: the integration sends only fixed workspace
mode and targeted shortcut events. It does not read or transmit project names,
session names, windows, Spaces, workspace state, prompts, conversations,
credentials, or configuration content.

## Installation model

Installation is presented in three layers:

1. **Base Codex Micro installation:** build and flash the selected C152 image,
   pair BLE, configure ChatGPT controls, and install the local quota Companion.
2. **Optional super.engineering enablement:** configure the dedicated Space,
   three application shortcuts, Accessibility, and the left-direction
   compatibility rule.
3. **Optional USB microphone:** choose the isolated `usb-mic` image, retain its
   input-only USB Audio boundary, and verify macOS audio separately from BLE.

The Codex-assisted installation remains the recommended path. The prompt must
not claim physical success from a build alone and must retain exact serial-port
confirmation before any flash.

## Files and assets

Implementation changes only:

- `README.md`;
- `README.zh-CN.md`;
- `artifacts/super-workspace-preview.png`;
- this design and its implementation plan.

The existing Codex preview remains unchanged. No runtime source, firmware,
Companion, protocol, permission, LaunchAgent, or installed component changes as
part of the README rewrite.

## Verification

Implementation verification must prove:

1. The English and Chinese READMEs have equivalent section order and factual
   claims.
2. Both workspace previews appear near the top and every referenced local path
   exists.
3. The new SUPER image is freshly generated from the current `super` scenario,
   is a 466 x 466 PNG, and matches the connected normal state.
4. Each workspace has a distinct description, control mapping, prerequisites,
   and privacy boundary.
5. super.engineering is first-class but explicitly optional.
6. The unofficial and experimental/undocumented compatibility notices remain.
7. Protected runtime identifiers remain byte-for-byte unchanged.
8. The tracked tree passes privacy scanning and `git diff --check`.
9. GitHub renders both images and the two-column layout correctly after
   publication.
10. GitHub Actions is reported as queued, running, passed, or failed according
    to its actual state.

The native preview build is rerun to generate the SUPER asset. A firmware flash,
installed Companion replacement, LaunchAgent restart, or macOS permission
change is outside this documentation task.

## Verification record — 2026-08-31

Local verification passed for the dual-workspace README rewrite. The tracked
`artifacts/super-workspace-preview.png` is the freshly generated 466 x 466
connected SUPER preview from the deterministic `super` scenario. Both README
workspace galleries are present, and their exact `##` section parity is 10
headings in English and 10 in Simplified Chinese.

Protected identifier assertions passed for `Codex Micro`, `Codex StopWatch
Mic`, `CodexWatchCompanion`, `codex-watch-companion`, and
`io.github.codex-micro-stopwatch.companion`; the approved design baseline has
no runtime or configuration source changes under `src`, `include`,
`companion`, `scripts`, `usb-mic`, or `platformio.ini`. Local asset, dimension,
and README structure checks passed. The tracked-tree privacy scan found no
credential pattern or personal absolute macOS home path; commit metadata is
limited to GitHub noreply addresses; and `git diff --check` passed. The final
review correction also verifies that both README control tables condition
device-side input isolation on the matching `usb-mic` firmware and preserve
the default firmware's Codex Micro controls.

The local README image-path check passed: both `README.md` and
`README.zh-CN.md` reference `artifacts/dashboard-preview-v2-round.png` and
`artifacts/super-workspace-preview.png`, and both paths resolve to tracked
assets.

This verification made no firmware flash, installed Companion change,
LaunchAgent action, macOS permission change, or device configuration change.

## Rollback

The README rewrite and added image can be reverted as one documentation change.
Rollback does not rename compatibility identifiers or alter the installed C152,
Companion, LaunchAgent, pairing, permissions, or local configuration.
