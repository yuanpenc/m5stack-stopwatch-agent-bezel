# Stopwatch AgentBezel C152 Brand Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make **Stopwatch AgentBezel C152** the public repository brand without changing any runtime identifier, installed permission boundary, protocol, or device behavior.

**Architecture:** Treat branding as a presentation layer over the existing Codex Micro-compatible implementation. Update only public copy, legal contributor identity, and port-owned copyright comments; protect the BLE, USB Audio, Swift package, bundle, LaunchAgent, GATT, HID, and RPC contracts with explicit assertions before publishing.

**Tech Stack:** Markdown, C++17, Swift Package Manager, PlatformIO, Git, GitHub CLI/API.

## Global Constraints

- Product name is exactly **Stopwatch AgentBezel C152**.
- Repository slug remains `m5stack-stopwatch-agent-bezel`.
- `Codex Micro`, `Codex StopWatch Mic`, `CodexWatchCompanion`, `codex-watch-companion`, and `io.github.codex-micro-stopwatch.companion` remain unchanged runtime identifiers.
- BLE GATT UUIDs, HID reports, RPC methods, device matching constants, USB descriptors, local paths, log names, and installed bundle structure remain unchanged.
- On-device `CODEX` and `SUPER` labels remain unchanged workspace labels.
- Upstream copyright, Space Mono license, trademark disclaimers, and unofficial-project notice remain intact.
- Historical plans and specifications retain their original terminology.
- No firmware flash, Companion replacement, LaunchAgent restart, or macOS permission change is allowed.
- Publish only tracked Git content; never add ignored build caches or local installation artifacts.
- All new commits use the repository's GitHub noreply email.

---

### Task 1: Adopt the public brand in tracked source and documentation

**Files:**
- Modify: `README.md:1-8`
- Modify: `README.zh-CN.md:1-8`
- Modify: `LICENSE:3-4`
- Modify: `NOTICE.md:1-9`
- Modify: `src/main.cpp:1-4`
- Modify: `src/CodexMicroBle.cpp:1-4`
- Modify: `include/CodexMicroBle.h:1-4`

**Interfaces:**
- Consumes: The approved identity and protected identifiers in `docs/superpowers/specs/2026-08-30-stopwatch-agentbezel-c152-brand-migration-design.md`.
- Produces: Public copy and legal attribution that Task 2 can verify without changing runtime behavior.

- [ ] **Step 1: Run the pre-change brand assertions to obtain RED**

Run:

```bash
test "$(sed -n '1p' README.md)" = '# Stopwatch AgentBezel C152'
test "$(sed -n '1p' README.zh-CN.md)" = '# Stopwatch AgentBezel C152'
rg -F 'Stopwatch AgentBezel C152 contributors' LICENSE NOTICE.md
```

Expected: the first assertion fails because both README titles still use the old project name.

- [ ] **Step 2: Update the English public identity**

Use `apply_patch` to make the opening of `README.md` read:

```markdown
# Stopwatch AgentBezel C152

[简体中文](README.zh-CN.md)

**Stopwatch AgentBezel C152** is an independent, open-source AI agent control
surface for the **M5Stack StopWatch Dev Kit C152**. It provides Codex
Micro-compatible controls, a local quota dashboard, a dedicated
super.engineering workspace, and an optional USB microphone.

The public project brand is Stopwatch AgentBezel C152. Compatibility-facing
runtime names such as `Codex Micro`, `Codex StopWatch Mic`, and
`CodexWatchCompanion` intentionally remain unchanged so existing pairing,
audio selection, permissions, and automatic startup continue to work.
```

Keep the existing preview image and every subsequent installation, feature,
privacy, compatibility, and recovery section.

- [ ] **Step 3: Update the Chinese public identity**

Use `apply_patch` to make the opening of `README.zh-CN.md` read:

```markdown
# Stopwatch AgentBezel C152

[English](README.md)

**Stopwatch AgentBezel C152** 是面向 **M5Stack StopWatch Dev Kit C152**
的独立开源 AI Agent 控制界面，支持 Codex Micro 兼容控制、本地额度面板、
super.engineering 专属工作区和可选 USB 麦克风。

项目的公开品牌名是 Stopwatch AgentBezel C152。为保持现有蓝牙配对、音频设备
选择、macOS 权限和自动启动继续有效，`Codex Micro`、`Codex StopWatch Mic`
和 `CodexWatchCompanion` 等兼容性运行时名称有意保持不变。
```

Keep all existing Chinese installation, control, privacy, compatibility, and
recovery content after the opening.

- [ ] **Step 4: Update legal and port-owned contributor identity**

Use `apply_patch` to replace only the port contributor identity:

```text
codex-micro-4-stopwatch contributors
```

with:

```text
Stopwatch AgentBezel C152 contributors
```

in `LICENSE` and `NOTICE.md`. Replace the port-owned copyright comment text
`Codex Micro for StopWatch contributors` with
`Stopwatch AgentBezel C152 contributors` in `src/main.cpp`,
`src/CodexMicroBle.cpp`, and `include/CodexMicroBle.h`.

Do not change the upstream `imliubo` copyright, MIT terms, font license,
trademark section, or protocol disclaimer.

- [ ] **Step 5: Run the brand assertions to obtain GREEN**

Run:

```bash
test "$(sed -n '1p' README.md)" = '# Stopwatch AgentBezel C152'
test "$(sed -n '1p' README.zh-CN.md)" = '# Stopwatch AgentBezel C152'
test "$(rg -l -F 'Stopwatch AgentBezel C152 contributors' LICENSE NOTICE.md src/main.cpp src/CodexMicroBle.cpp include/CodexMicroBle.h | wc -l | tr -d ' ')" = 5
test "$(rg -l -F 'codex-micro-4-stopwatch contributors' LICENSE NOTICE.md | wc -l | tr -d ' ')" = 0
git diff --check
```

Expected: all assertions exit 0 and `git diff --check` prints nothing.

- [ ] **Step 6: Review and commit the brand copy**

Run:

```bash
git diff -- README.md README.zh-CN.md LICENSE NOTICE.md src/main.cpp src/CodexMicroBle.cpp include/CodexMicroBle.h
git status --short
git add README.md README.zh-CN.md LICENSE NOTICE.md src/main.cpp src/CodexMicroBle.cpp include/CodexMicroBle.h
git commit -m "docs: adopt Stopwatch AgentBezel C152 brand"
```

Expected: one focused commit containing only the seven approved files.

---

### Task 2: Prove compatibility and publication readiness

**Files:**
- Modify: `docs/superpowers/specs/2026-08-30-stopwatch-agentbezel-c152-brand-migration-design.md`
- Test: `simulator/completion_banner_test.cpp`
- Test: `simulator/connection_health_test.cpp`
- Test: `simulator/gesture_test.cpp`
- Test: `simulator/host_rpc_request_test.cpp`
- Test: `simulator/power_button_gesture_test.cpp`
- Test: `simulator/quota_payload_test.cpp`
- Test: `simulator/super_workspace_ui_test.cpp`
- Test: `simulator/workspace_input_policy_test.cpp`
- Test: `simulator/workspace_mode_test.cpp`

**Interfaces:**
- Consumes: Task 1 public copy and the unchanged runtime contracts in the approved design.
- Produces: Fresh compatibility, privacy, native-test, preview, and USB-microphone build evidence suitable for publication.

- [ ] **Step 1: Assert the protected runtime identifiers**

Run:

```bash
rg -F 'constexpr char kDeviceName[] = "Codex Micro";' src/CodexMicroBle.cpp
rg -F 'static constexpr char kUsbMicName[] = "Codex StopWatch Mic";' src/UsbMic.cpp
rg -F 'USB.productName("Codex StopWatch Mic");' src/UsbMic.cpp
rg -F 'USB.manufacturerName("Codex Micro StopWatch");' src/UsbMic.cpp
rg -F 'private let legacyDeviceNames = ["Codex Micro StopWatch Mic", "TinyUSB UAC1"]' scripts/usb_mic_capture.swift
rg -F 'name: "CodexWatchCompanion"' companion/Package.swift
rg -F '.executable(name: "codex-watch-companion"' companion/Package.swift
test "$(rg -l -F '<string>io.github.codex-micro-stopwatch.companion</string>' companion/app/Info.plist companion/launchd/io.github.codex-micro-stopwatch.companion.plist.example | wc -l | tr -d ' ')" = 2
git diff -I 'StopWatch port changes copyright' f707bf4 -- src/main.cpp src/CodexMicroBle.cpp include/CodexMicroBle.h
```

Expected: every exact string is present. The final `git diff` contains no
runtime change after ignoring only the approved copyright comment line.

- [ ] **Step 2: Create the temporary native-test M5GFX stub**

Use `apply_patch` to create `/private/tmp/agentbezel-brand-test-stub/M5GFX.h`:

```cpp
#pragma once
enum textdatum_t { middle_center, middle_left, middle_right };
```

Expected: the stub contains only the enum required to parse
`SuperWorkspaceUi.h`; it is outside the repository and is never committed.

- [ ] **Step 3: Compile and run all nine native tests**

Compile each test with C++17, `-Wall -Wextra -Werror`, `-Iinclude`, the existing
temporary M5GFX stub for `super_workspace_ui_test.cpp`, and the ArduinoJson
include directory from the USB-microphone PlatformIO environment. Run:

```bash
for name in completion_banner connection_health gesture host_rpc_request power_button_gesture quota_payload super_workspace_ui workspace_input_policy workspace_mode; do
  clang++ -std=c++17 -Wall -Wextra -Werror \
    -I/private/tmp/agentbezel-brand-test-stub -Iinclude \
    -Iusb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src \
    "simulator/${name}_test.cpp" \
    -o "/private/tmp/agentbezel-brand-${name}-test"
  "/private/tmp/agentbezel-brand-${name}-test"
done
```

Expected: nine compile exits 0 and nine test exits 0.

- [ ] **Step 4: Build the native preview and USB-microphone firmware**

Run:

```bash
env HOMEBREW_PREFIX=/opt/homebrew PLATFORMIO_SETTING_ENABLE_TELEMETRY=no \
  pio run -e native-preview
env PLATFORMIO_CORE_DIR="$PWD/usb-mic/.pio-core" \
  PLATFORMIO_SETTING_ENABLE_TELEMETRY=no \
  pio run -d usb-mic
```

Expected: `native-preview`, `prepare-bluedroid`, and
`m5stack-stopwatch-usb-mic` report `SUCCESS`. Existing third-party M5GFX
warnings may remain; project-owned source must add no warning.

- [ ] **Step 5: Run the privacy and commit-metadata gate**

Run:

```bash
if git ls-files -z | xargs -0 rg -l -I --pcre2 \
  '(AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|/Users/[A-Za-z0-9._-]+)'; then
  exit 1
fi
test "$(git log public/main..HEAD --format='%aE%n%cE' | sort -u | awk 'tolower($0) !~ /@users\.noreply\.github\.com$/ {count++} END {print count+0}')" = 0
test -z "$(git status --porcelain)"
```

Expected: no tracked secret or personal-path match, no non-noreply email in new
commits, and a clean worktree.

- [ ] **Step 6: Record verification in the design**

Use `apply_patch` to change the design status to:

```markdown
**Status:** Implemented and verified
```

Append a verification note naming the nine native tests, native preview build,
both USB-microphone environments, protected-identifier assertions, privacy
scan, and noreply metadata check. Do not claim a firmware flash or installed
Companion change.

- [ ] **Step 7: Commit the verification record**

Run:

```bash
git diff --check
git add docs/superpowers/specs/2026-08-30-stopwatch-agentbezel-c152-brand-migration-design.md
git commit -m "docs: record AgentBezel brand verification"
git status --short --branch
```

Expected: one documentation-only verification commit and a clean branch ahead
of `public/main`.

---

### Task 3: Publish the brand and GitHub metadata

**Files:**
- External metadata: `https://github.com/jiangew/m5stack-stopwatch-agent-bezel`
- Remote branch: `public/main`

**Interfaces:**
- Consumes: Task 2 verified local HEAD and the exact description/topics in the approved design.
- Produces: A public GitHub repository whose main branch and presentation match the verified local state.

- [ ] **Step 1: Recheck the final local publication gate**

Run:

```bash
test -z "$(git status --porcelain)"
test "$(git remote get-url public)" = 'https://github.com/jiangew/m5stack-stopwatch-agent-bezel.git'
test "$(git log public/main..HEAD --format='%aE%n%cE' | sort -u | awk 'tolower($0) !~ /@users\.noreply\.github\.com$/ {count++} END {print count+0}')" = 0
git diff --check public/main..HEAD
```

Expected: all assertions exit 0.

- [ ] **Step 2: Push only main**

Run:

```bash
git push public main
```

Expected: a fast-forward update of `public/main`. Do not use `--force`,
`--mirror`, or `--all`.

- [ ] **Step 3: Update GitHub description and topics**

Run:

```bash
gh api --method PATCH repos/jiangew/m5stack-stopwatch-agent-bezel \
  -f description='Open-source AI agent control surface for M5Stack StopWatch C152 with Codex Micro compatibility, super.engineering workspace controls, a quota dashboard, and an optional USB microphone.'

gh api --method PUT repos/jiangew/m5stack-stopwatch-agent-bezel/topics \
  -f 'names[]=m5stack' \
  -f 'names[]=esp32-s3' \
  -f 'names[]=stopwatch' \
  -f 'names[]=ai-agents' \
  -f 'names[]=codex' \
  -f 'names[]=macos' \
  -f 'names[]=swift' \
  -f 'names[]=platformio' \
  -f 'names[]=ble-hid' \
  -f 'names[]=usb-audio'
```

Expected: both API calls succeed without changing visibility, default branch,
or repository name.

- [ ] **Step 4: Verify the public repository**

Run:

```bash
local_head=$(git rev-parse HEAD)
remote_head=$(gh api repos/jiangew/m5stack-stopwatch-agent-bezel/git/ref/heads/main --jq '.object.sha')
test "$local_head" = "$remote_head"
test "$(gh api repos/jiangew/m5stack-stopwatch-agent-bezel --jq '.visibility')" = public
test "$(gh api repos/jiangew/m5stack-stopwatch-agent-bezel --jq '.default_branch')" = main
test "$(gh api repos/jiangew/m5stack-stopwatch-agent-bezel --jq '.description')" = 'Open-source AI agent control surface for M5Stack StopWatch C152 with Codex Micro compatibility, super.engineering workspace controls, a quota dashboard, and an optional USB microphone.'
gh api repos/jiangew/m5stack-stopwatch-agent-bezel --jq '.topics | sort | join("\n")'
gh run list --repo jiangew/m5stack-stopwatch-agent-bezel --limit 5
git status --short --branch
```

Expected: local and remote HEAD match, the repository remains public on `main`,
the description matches exactly, all ten topics are present, and the local
branch is clean and synchronized. Report GitHub Actions honestly as queued,
running, passed, or failed; do not call a running workflow passed.
