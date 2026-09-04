# Navigation permissions and center UI refinement

Status: Approved implementation; preview and physical acceptance pending.
Date: 2026-09-04. Branch: `feature/hermes-desktop-workspace`.
Source baseline: `9676b6f`.

## Approved scope

- Restore Accessibility authorization for the installed Companion and restart
  the original LaunchAgent. Do not reinstall, re-sign, remap keys, modify the
  plist, or read application configuration. Retain Input Monitoring.
- Verify SUPER previous/next project and next tab; HERMES previous/next tab
  and new tab. Require both no fresh permission rejection and user-observed
  physical success. If still failing, stop navigation acceptance and compare
  physical keyboard input with existing process-targeted delivery.
- Remove `WEEKLY LEFT` from the normal Codex dial. Keep status, quota, reset
  and battery text centers at y=185, 228, 270 and 301. Keep the original
  five-row diagnostic layout and its `SYNC STALE` / `WAITING CODEX` messages.
- Center the SUPER/HERMES battery icon, including its terminal, an 8px gap,
  and the measured percentage label together at x=233, y=276. Preserve
  charging and low-battery rendering, title/status positions, triangle geometry,
  palette behavior, feedback and lease behavior.
- No HID/RPC, public interface, key mapping, audio, quota or Companion source
  changes. No push or merge. Preview approval and fresh exact-port approval
  are separate gates before any USB-mic flash.

## Implementation and verification

The two renderer changes were developed test-first and reviewed serially
against the approved requirements and `AGENTS.md`; no subagents were used.

| Layer | Result | Evidence and boundary |
| --- | --- | --- |
| Codex renderer RED | Observed | New test failed because the old renderer still drew `WEEKLY LEFT` |
| Workspace battery RED | Observed | New test failed the icon-terminal-to-label 8px gap requirement |
| Renderer GREEN | Pass | Normal/diagnostic coordinates and battery-group center error of at most 1px; both profiles, charging on/off, 0%, 9%, 78%, 100%, unknown |
| Native test executables | Pass | All 11 `simulator/*_test.cpp` executables compiled with C++17 and `-Wall -Wextra -Werror`, then exited 0 |
| Native preview | Pass with dependency warning | 37 scenarios rendered at 466x466; native M5GFX emits an existing variable-length-array warning |
| Visual inspection | Pass for inspected previews | Normal Codex/SUPER/HERMES, stale Codex, charging, workspace unknown/100% battery and power overlay inspected; no observed new text collision |
| USB-mic build | Pass | Both PlatformIO environments succeeded; final build log has no warning/error diagnostics |
| Whitespace | Pass | `git diff --check` |
| Swift / XCTest | Not rerun | No Swift changes; the earlier CLT `XCTest` environment limitation is not a passing test result |
| Navigation | Pending user observation | User re-added Accessibility; original service restarted without changing plist/signature. Initial fresh log check found no Input Monitoring, Accessibility or delivery warning; this alone does not prove physical navigation |
| New UI installation | Not performed | Native previews and compilation are not physical C152 acceptance |

Preview fixtures add low, full, unknown and charging batteries. The three public
preview assets are generated from the same shared production renderers, using
synthetic values only. They are not screenshots of user data or hardware.

The pre-change USB-mic artifacts were preserved privately before building.
The baseline firmware SHA-256 remains
`0d4d3c74b12081f6a4a408f108fd8a93db8ea45c6687563c8408d47399bdb1b3`.
The new UI firmware SHA-256 is
`f4a4c3c52a2cac56b8cd1f20ad3926fe51b852e0c751f8bbbd96854e2b6846f8`.
These identify local build artifacts, not reproducible-build or hardware claims.

## Review and acceptance gates

Serial standards review found no blocking issue: runtime identifiers and
privacy boundaries are unchanged, fonts are loaded before measuring text,
and label bounds use the terminal's width. Serial specification review found
no source-level deviation in the scoped UI change. Remaining physical gates
are deliberately not marked complete:

- [ ] User confirms all six navigation actions after reauthorization.
- [ ] User approves the three updated native previews.
- [ ] Reconfirm recovery artifacts and freshly enumerate the download port.
- [ ] Obtain explicit approval of that exact port, then flash USB-mic only.
- [ ] Physically verify three-desktop cycling, six navigation actions, random
  colors, input isolation, USB microphone and quota synchronization.

Do not infer success for any unchecked item from earlier installation history.
