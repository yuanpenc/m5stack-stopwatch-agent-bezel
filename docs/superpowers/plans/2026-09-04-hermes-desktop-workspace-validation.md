# Hermes workspace implementation validation

> Historical pre-installation report. Its NEW action and artifact fingerprints
> describe the original implementation stage, not the installed OPEN revision.
> Current installation and user-observed results are recorded in
> [Hermes OPEN physical acceptance](2026-09-04-hermes-open-physical-acceptance.md).

Date: 2026-09-04. Branch: `feature/hermes-desktop-workspace`.
Reviewed source base: `3c955f3`; final runtime revision: `b03c2f0`.

## Result by layer

| Layer | Result | Evidence / limitation |
| --- | --- | --- |
| Native C++ | PASS | All 10 simulator test executables compiled with C++17, `-Wall -Wextra -Werror` and exited 0 |
| Palette | PASS | 10,000 deterministic swipes; four distinct in-pool colors, all positions change; exactly 40,000 RNG calls; 799/800ms and UInt32 wrap boundaries |
| UI model/renderer | PASS | Recorded drawing calls preserve triangle bases and exclude center outline; fixed HERMES/NEW/CYCLE text and private-data-free model |
| Native framebuffer | PASS with dependency warnings | Native target built; 20 SUPER/HERMES scenarios rendered at 466×466; title, corners, random colors, low-battery/offline and power overlay visually inspected |
| USB-mic firmware | PASS | Both prepare-bluedroid and m5stack-stopwatch-usb-mic succeeded in final build; final log contains no warning/error diagnostics |
| Companion release | PASS | Swift 6.3.1, fixed macOS 15.4 SDK, minimum deployment macOS 14, `-warnings-as-errors`; final incremental verification also passed |
| Full XCTest | UNAVAILABLE | Final `swift test` stops at `no such module 'XCTest'` in the installed Command Line Tools; not a passing test suite |
| Temporary Swift harness | PASS, not XCTest | 53 actual test bodies with temporary assertion support; sources retained as XCTest in repository |
| HID RPC tool | PASS | `hid_rpc_probe.swift --self-test`, including fixed Hermes request; no live workspace probe sent |
| USB audio analysis tool | PASS, synthetic only | `usb_mic_validate.py self-test`; no physical capture or audio analysis of user content |
| JSON smoke | PASS | Synthetic `--demo --json-only` and real `--json-only` produced valid JSON objects; values not logged here |
| Mode gates / RunLoop | PASS in harness | Real watch only; demo/json/one-shot/maintenance excluded; RunLoop response and quota-failure-next-cycle assertions |
| Invalid maintenance mode | PASS | Synthetic device ID with bootloader+JSON rejected before device access; no bootloader request issued |
| Source whitespace | PASS | `git diff --check` |
| Installation / physical C152 | NOT RUN | Existing Companion, LaunchAgent and firmware were not replaced; all new hardware behavior remains unverified |

Native framebuffer dependencies emit existing third-party M5GFX variable-length
array warnings and archive-tool empty-object warnings on this host. Do not
describe that entire native build as warning-free. C++ unit compilation,
USB-mic build and Companion release are separate results.

The first relocated isolated-toolchain preparation failed while the USB target
succeeded. Preparation and subsequent complete builds passed after local
initialization; the initial failure's precise cause was not established.
The first real quota smoke was sandbox-blocked during App Server state runtime
initialization. The approved unsandboxed read-only quota retry succeeded.
Neither workaround changed source or installed configuration.

## Review and regression coverage

Serial specification and code-quality review covered the complete source diff
from the base, including uncommitted documentation/assets before this commit:

- Strict three-mode RPC shapes, connection ownership, renewal without dirty,
  owner disconnect, Codex escape and unsigned lease expiry. Existing
  `ControlOnly`/host-activity separation remains unchanged.
- Fixed framing, UInt32 request IDs, stop-on-fragment-failure, exact HID identity
  and existing callback/device-handle invalidation boundaries.
- Neutral decoder directions, release gating, 800ms cooldown, exact app profiles,
  PID/bundle/foreground revalidation and no global key posting.
- One activation request, rejection/no-skip, 3-second timeout, real foreground
  confirmation and stale callbacks after lifecycle restart.
- Shared latest-mode heartbeat; per-device immediate attach, independent detach,
  two bounded Codex retries, canceled obsolete timers, 60-second failure logging.
- Poll/state/transition/input ordering, held-input release and Agent baselining;
  USB-only renderer/input changes leave USB audio callbacks/endpoints and default
  wireless runtime paths unchanged.
- Palette remains local, bounded and persistent across redraws/mode switches;
  no randomization in rendering or heartbeat.
- No new application-content/config/credential reads, arbitrary display payloads,
  device identifiers in logs, global macros or private Space operations.

Two review issues were reproduced and fixed:

1. A stale cycle observer could affect a restarted activation request. A harness
   regression failed before separate lifecycle-generation equality was added.
2. Generic touch-down activity woke directional screens for disabled short taps.
   The input-policy regression failed before restricting touch-down wake to
   Codex; firmware now defers directional activity until a real swipe/power hold.
   A wake swipe is consumed without navigation. This last path still requires
   physical sleep/touch acceptance.

Historical filenames containing `SuperEngineering` remain for compatible source
layout; active router/profile/cycle behavior is no longer SUPER-only. Source
review cannot prove macOS app shortcuts or background ChatGPT behavior.

## Reproducing the automated checks

Use private temporary build, module and cache directories. Native tests require
ArduinoJson from the installed PlatformIO dependencies. The lightweight UI
unit test uses only a minimal M5GFX text-datum header; actual M5GFX rendering is
verified separately by the native-preview target.

```sh
# In a prepared checkout; replace placeholders with private temporary paths.
clang++ -std=c++17 -Wall -Wextra -Werror \
  -I<TEXT_DATUM_SHIM> -Iinclude -I<ARDUINOJSON_SRC> \
  simulator/workspace_mode_test.cpp -o <SCRATCH>/workspace-mode
# Repeat for all simulator/*_test.cpp and execute each output.

pio run -e native-preview
pio run -d usb-mic
swift scripts/hid_rpc_probe.swift --self-test
python3 scripts/usb_mic_validate.py self-test

# Use SDKROOT and module/cache paths matching the selected SDK.
swift build --package-path companion -c release --sdk <MACOS_15_4_SDK> \
  --scratch-path <SCRATCH>/release --cache-path <SCRATCH>/cache \
  --config-path <SCRATCH>/config --security-path <SCRATCH>/security \
  --disable-sandbox -Xswiftc -warnings-as-errors
swift test --package-path companion --sdk <MACOS_15_4_SDK> \
  --scratch-path <SCRATCH>/tests --disable-sandbox
```

The temporary Swift harness substitutes a small assertion adapter for XCTest,
retains test bodies and compiles production sources without the CLI entry call.
It validates those behaviors, not XCTest discovery, runners or framework
integration. Harness files and build logs remain local, outside Git.

## Artifact fingerprints

- USB-mic `firmware.bin` SHA-256:
  `0d4d3c74b12081f6a4a408f108fd8a93db8ea45c6687563c8408d47399bdb1b3`
- Companion release executable SHA-256:
  `4e377bff7d6102ff5098c08f6edf08807247b8db1e42987f14d6928643cb8376`

These identify local verified artifacts, not published binaries or a claim of
reproducible builds. Signing/installing would change the executable fingerprint.

## Pending physical acceptance

Install only in a separately authorized step, with signed Companion and firmware
recovery backups. Freshly enumerate and confirm the exact download port before
flashing. Preserve the existing LaunchAgent, binding and paths.

Verify three-app cycle/cold launch/no-skip, actual Hermes keys, SUPER and ChatGPT
compatibility, Space assignment, four-direction colors/debounce, sleeping-screen
behavior, disabled inputs and power hold, no background actions, lease expiry,
reconnect, UAC microphone input, quota and single-instance startup.

The main checkout remains at the source base. The feature branch/worktree and
recovery artifacts are preserved. No push, merge or branch removal was performed.
