# Stopwatch AgentBezel C152 Dual-Workspace README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite both public READMEs around distinct Codex Micro and optional super.engineering workspaces, add the current SUPER display preview beside the Codex dashboard, verify the documentation and asset, and publish the result.

**Architecture:** Treat the README as the product landing page and the existing detailed instructions as supporting documentation. Generate one deterministic tracked SUPER image from the current native renderer, present both workspaces in a local two-column gallery, then organize the English and Chinese documents with equivalent sections and separate control models.

**Tech Stack:** Markdown, HTML supported by GitHub Markdown, C++17 native preview, M5GFX, PlatformIO, macOS `sips`, Git, GitHub CLI/API.

## Global Constraints

- Product name remains exactly **Stopwatch AgentBezel C152**.
- Codex Micro and super.engineering are first-class README sections; super.engineering is explicitly optional.
- The opening remains independent, unofficial, open source, and states that Codex Micro compatibility is experimental and undocumented.
- The tracked Codex preview remains `artifacts/dashboard-preview-v2-round.png` and is not modified.
- The new SUPER preview is `artifacts/super-workspace-preview.png`, generated from the current deterministic `super` scenario in the normal connected state at exactly 466 x 466 pixels.
- `Codex Micro`, `Codex StopWatch Mic`, `CodexWatchCompanion`, `codex-watch-companion`, and `io.github.codex-micro-stopwatch.companion` remain unchanged runtime identifiers.
- BLE GATT UUIDs, HID reports, RPC methods, USB descriptors, device matching constants, local app paths, log names, and permission-bearing bundle structure remain unchanged.
- The README must not claim that super.engineering is required for normal Codex Micro operation.
- The README must not claim physical validation from a build; existing C152 flash, pairing, control, microphone, quota, and recovery layers remain distinct.
- No firmware flash, Companion replacement, LaunchAgent restart, permission change, pairing change, or device configuration occurs in this documentation task.
- No project name, session name, window, Space, workspace state, prompt, conversation, credential, local UUID, username, home path, device identifier, or captured audio enters the tracked tree.
- Every new commit uses the repository's GitHub noreply email.

---

### Task 1: Generate and track the current SUPER workspace preview

**Files:**
- Create: `artifacts/super-workspace-preview.png`
- Read: `simulator/preview_main.cpp`
- Read: `include/SuperWorkspaceUi.h`
- Preserve: `artifacts/dashboard-preview-v2-round.png`

**Interfaces:**
- Consumes: The deterministic `super` preview scenario and current SUPER renderer.
- Produces: A local 466 x 466 PNG at `artifacts/super-workspace-preview.png` for both READMEs.

- [ ] **Step 1: Record the pre-change asset RED condition**

Run:

```bash
test -f artifacts/dashboard-preview-v2-round.png
test -f artifacts/super-workspace-preview.png
```

Expected: the Codex preview assertion exits 0 and the SUPER preview assertion exits 1 because the tracked asset does not exist yet.

- [ ] **Step 2: Build the current native preview**

Run:

```bash
env HOMEBREW_PREFIX=/opt/homebrew \
  PLATFORMIO_SETTING_ENABLE_TELEMETRY=no \
  pio run -e native-preview
```

Expected: `native-preview` reports `SUCCESS`. Existing third-party M5GFX VLA or `ranlib` no-symbol warnings may remain; project-owned source must add no warning.

- [ ] **Step 3: Generate the normal connected SUPER frame outside Git**

Run:

```bash
.pio/build/native-preview/program \
  /private/tmp/agentbezel-super-workspace-preview.ppm super
```

Expected: the command reports a 466 x 466 `super` preview and writes only the temporary PPM.

- [ ] **Step 4: Convert the deterministic frame to the tracked PNG**

Run:

```bash
sips -s format png \
  /private/tmp/agentbezel-super-workspace-preview.ppm \
  --out artifacts/super-workspace-preview.png
```

Expected: `sips` reports a PNG output in `artifacts/`; the temporary PPM remains outside the repository.

- [ ] **Step 5: Verify dimensions, format, content boundary, and Codex asset preservation**

Run:

```bash
file artifacts/dashboard-preview-v2-round.png artifacts/super-workspace-preview.png
sips -g pixelWidth -g pixelHeight artifacts/super-workspace-preview.png
test "$(sips -g pixelWidth artifacts/super-workspace-preview.png | awk '/pixelWidth/ {print $2}')" = 466
test "$(sips -g pixelHeight artifacts/super-workspace-preview.png | awk '/pixelHeight/ {print $2}')" = 466
git diff --quiet -- artifacts/dashboard-preview-v2-round.png
git diff --check
```

Expected: both assets are PNGs, SUPER is 466 x 466, the existing Codex image is unchanged, and the diff check is clean.

Visually inspect `artifacts/super-workspace-preview.png`. It must show the centered `SUPER`, `CONNECTED`, and battery state; blue `BACK`, cyan `PREV`, magenta `NEXT`, and orange `TAB` directions; and no local or user content.

- [ ] **Step 6: Commit the generated asset**

Run:

```bash
git add artifacts/super-workspace-preview.png
git commit -m "docs: add super workspace preview"
```

Expected: one focused binary-asset commit containing only the new PNG.

---

### Task 2: Rewrite the English and Chinese READMEs as a dual-workspace product page

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Read: `companion/README.md`
- Read: `docs/superpowers/specs/2026-08-29-super-engineering-workspace-controls-design.md`
- Read: `docs/superpowers/specs/2026-08-30-super-engineering-stopwatch-workspace-design.md`
- Read: `docs/superpowers/specs/2026-08-31-dual-workspace-readme-design.md`

**Interfaces:**
- Consumes: Both tracked workspace previews and the approved workspace behavior/privacy specifications.
- Produces: Fact-equivalent English and Simplified Chinese GitHub landing pages with separate workspace sections.

- [ ] **Step 1: Run the new README structure assertions to obtain RED**

Run:

```bash
rg -F '## Two workspaces' README.md
rg -F '## Codex Micro workspace' README.md
rg -F '## Optional super.engineering workspace' README.md
rg -F 'artifacts/super-workspace-preview.png' README.md
rg -F '## 双工作区' README.zh-CN.md
rg -F '## Codex Micro 工作区' README.zh-CN.md
rg -F '## 可选的 super.engineering 工作区' README.zh-CN.md
rg -F 'artifacts/super-workspace-preview.png' README.zh-CN.md
```

Expected: at least the new headings and SUPER image references are absent, so the block is RED.

- [ ] **Step 2: Replace the English first screen with the exact dual-workspace identity and gallery**

Use `apply_patch`. The English opening must contain these exact facts:

```markdown
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
```

Immediately below that heading, add this GitHub-compatible local gallery:

```html
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
```

- [ ] **Step 3: Add the exact English workspace comparison and separate sections**

The workspace comparison must use this control contract:

```markdown
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
```

Use these English top-level headings in this order after `Two workspaces`:

```markdown
## Codex Micro workspace
## Optional super.engineering workspace
## Recommended installation
## macOS permissions and app configuration
## Optional USB microphone
## Privacy and architecture
## Manual build and flash
## Troubleshooting
## Acknowledgements, license, and trademarks
```

The `Codex Micro workspace` section must keep Agent/quota/connection/battery,
left Push to talk, right Voice Chat, center Send, configurable swipes, haptics,
completion feedback, desk sleep, Travel Mode, and the HID-versus-GATT boundary.

The optional super.engineering section must state all of the following:

```markdown
- Assign super.engineering to a dedicated normal macOS Space.
- Configure Previous Project = Control-Option-Up.
- Configure Next Project = Control-Option-Down.
- Configure Next Tab = Control-Option-Right.
- Enable Accessibility for the installed Companion.
- Leave only ChatGPT's Analog stick left direction unbound; retain its original up, down, and right mappings.
- The watch follows the foreground app, refreshes SUPER every 5 seconds, and falls back to Codex within 15 seconds without a valid lease.
- SUPER isolates Agent, Send, Voice Chat, and ChatGPT physical-button actions while preserving the four workspace swipes and power controls.
```

Include a short setup subsection and a concise acceptance checklist for entering,
returning, project navigation, tab navigation, fallback, and restored Codex
controls. State that the integration uses the exact bundle identifier
`com.zarifpour.superconductor`.

- [ ] **Step 4: Preserve and consolidate the English installation and safety details**

Move, do not lose, these existing facts:

- C152-only hardware support, macOS 14+, Swift 5.10+, PlatformIO, Bluetooth, and data USB-C prerequisites.
- Codex-assisted installation as the recommended source-build path.
- Official M5Stack recovery link, build-before-flash, exact `/dev/cu.*` resolution, and explicit confirmation immediately before flashing.
- Default `m5stack-stopwatch` image and the distinct `CODEX_MICRO_STOPWATCH_READY` serial validation.
- Isolated `usb-mic` build, input-only USB Audio, no speaker endpoint, `Codex StopWatch Mic`, and separate audio/BLE verification.
- Pairing and stale HID descriptor recovery.
- Quota Companion setup, local App Server context, device binding, automatic-start option, and local-only paths/UUIDs/logs.
- Existing troubleshooting for serial enumeration, Bluetooth, Input Monitoring, Voice Chat, and stale quota data.
- Existing upstream acknowledgement, Space Mono license, trademark disclaimer, and unofficial-project notice.

The recommended Codex prompt must add optional super.engineering as a separate,
explicitly user-chosen phase. It must not silently enable Accessibility, edit
super.engineering settings, assign a Space, or select the USB microphone image.

- [ ] **Step 5: Rewrite the Simplified Chinese README with exact structural parity**

Use `apply_patch`. The Chinese opening must contain these exact facts:

```markdown
# Stopwatch AgentBezel C152

[English](README.md)

**Stopwatch AgentBezel C152** 是面向 **M5Stack StopWatch Dev Kit C152**
的独立、非官方开源双工作区控制界面。一台设备同时提供 Codex Micro 兼容
工作区和可选的 super.engineering 专属工作区，并支持本地额度面板和可选
USB 麦克风。

Codex Micro 兼容性为实验性且未文档化功能。为保持现有蓝牙配对、音频设备
选择、macOS 权限和自动启动继续有效，兼容性运行时名称有意保持不变。

## 双工作区
```

Use the same HTML gallery paths with Chinese alternative text. Use these
Chinese top-level headings in the same order as English:

```markdown
## 双工作区
## Codex Micro 工作区
## 可选的 super.engineering 工作区
## 推荐安装方式
## macOS 权限与应用配置
## 可选 USB 麦克风
## 隐私与架构
## 手动编译与刷机
## 常见问题
## 致谢、许可证与商标
```

Translate every English workspace behavior, setup requirement, privacy claim,
safety boundary, and troubleshooting fact without adding or removing capability.
The Chinese workspace comparison must preserve the same eight input rows and
the same direction-to-action mapping.

- [ ] **Step 6: Run the dual-language README GREEN assertions**

Run:

```bash
test "$(sed -n '1p' README.md)" = '# Stopwatch AgentBezel C152'
test "$(sed -n '1p' README.zh-CN.md)" = '# Stopwatch AgentBezel C152'
test "$(rg -c -F 'artifacts/dashboard-preview-v2-round.png' README.md README.zh-CN.md | awk -F: '{sum += $2} END {print sum}')" = 2
test "$(rg -c -F 'artifacts/super-workspace-preview.png' README.md README.zh-CN.md | awk -F: '{sum += $2} END {print sum}')" = 2
rg -F '## Two workspaces' README.md
rg -F '## Codex Micro workspace' README.md
rg -F '## Optional super.engineering workspace' README.md
rg -F '5 seconds' README.md
rg -F '15 seconds' README.md
rg -F '## 双工作区' README.zh-CN.md
rg -F '## Codex Micro 工作区' README.zh-CN.md
rg -F '## 可选的 super.engineering 工作区' README.zh-CN.md
rg -F '5 秒' README.zh-CN.md
rg -F '15 秒' README.zh-CN.md
test -f artifacts/dashboard-preview-v2-round.png
test -f artifacts/super-workspace-preview.png
git diff --check
```

Expected: every assertion exits 0.

- [ ] **Step 7: Review structural and factual parity**

Run:

```bash
rg -n '^## ' README.md README.zh-CN.md
rg -n 'Control-Option|Analog stick left|Accessibility|Input Monitoring|5 seconds|15 seconds|com\.zarifpour\.superconductor' README.md
rg -n 'Control-Option|Analog stick left|辅助功能|输入监控|5 秒|15 秒|com\.zarifpour\.superconductor' README.zh-CN.md
rg -n 'Codex Micro|Codex StopWatch Mic|CodexWatchCompanion|codex-watch-companion|io\.github\.codex-micro-stopwatch\.companion' README.md README.zh-CN.md
```

Expected: the heading sequences correspond one-to-one, every optional SUPER
requirement exists in both languages, and all compatibility names remain exact.

- [ ] **Step 8: Commit the bilingual README rewrite**

Run:

```bash
git add README.md README.zh-CN.md
git commit -m "docs: explain both AgentBezel workspaces"
```

Expected: one focused commit containing exactly the two README files.

---

### Task 3: Verify, record, review, and publish the README rewrite

**Files:**
- Modify: `docs/superpowers/specs/2026-08-31-dual-workspace-readme-design.md`
- Verify: `README.md`
- Verify: `README.zh-CN.md`
- Verify: `artifacts/dashboard-preview-v2-round.png`
- Verify: `artifacts/super-workspace-preview.png`
- External: `https://github.com/jiangew/m5stack-stopwatch-agent-bezel`

**Interfaces:**
- Consumes: The tracked preview asset and both rewritten READMEs.
- Produces: Recorded local evidence and a public `main` whose README renders both workspaces correctly.

- [ ] **Step 1: Assert protected runtime identifiers and the documentation-only source boundary**

Run:

```bash
rg -F 'constexpr char kDeviceName[] = "Codex Micro";' src/CodexMicroBle.cpp
rg -F 'static constexpr char kUsbMicName[] = "Codex StopWatch Mic";' src/UsbMic.cpp
rg -F 'USB.productName("Codex StopWatch Mic");' src/UsbMic.cpp
rg -F 'name: "CodexWatchCompanion"' companion/Package.swift
rg -F '.executable(name: "codex-watch-companion"' companion/Package.swift
test "$(rg -l -F '<string>io.github.codex-micro-stopwatch.companion</string>' companion/app/Info.plist companion/launchd/io.github.codex-micro-stopwatch.companion.plist.example | wc -l | tr -d ' ')" = 2
test -z "$(git diff a859509 -- src include companion scripts usb-mic platformio.ini)"
```

Expected: every exact identifier is present and no runtime/configuration source changed after the approved README design baseline.

- [ ] **Step 2: Run the local link, image, structure, privacy, and metadata gate**

Run:

```bash
test -f artifacts/dashboard-preview-v2-round.png
test -f artifacts/super-workspace-preview.png
test "$(sips -g pixelWidth artifacts/super-workspace-preview.png | awk '/pixelWidth/ {print $2}')" = 466
test "$(sips -g pixelHeight artifacts/super-workspace-preview.png | awk '/pixelHeight/ {print $2}')" = 466
test "$(rg -c '^## ' README.md)" = "$(rg -c '^## ' README.zh-CN.md)"
if git ls-files -z | xargs -0 rg -l -I --pcre2 '(AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|/Users/[A-Za-z0-9._-]+)'; then exit 1; fi
test "$(git log public/main..HEAD --format='%aE%n%cE' | sort -u | awk 'tolower($0) !~ /@users\.noreply\.github\.com$/ {count++} END {print count+0}')" = 0
git diff --check public/main..HEAD
test -z "$(git status --porcelain)"
```

Expected: both images exist, dimensions and heading counts match, no tracked
secret/personal path or non-noreply email is found, the diff is clean, and the
worktree is clean.

- [ ] **Step 3: Record implementation verification in the approved design**

Use `apply_patch` to change:

```markdown
**Status:** Approved for implementation
```

to:

```markdown
**Status:** Implemented and locally verified
```

Append a dated verification record naming:

- the freshly generated 466 x 466 connected SUPER preview;
- both README workspace galleries and exact section parity;
- protected identifier/source-boundary assertions;
- local link/image checks;
- privacy scan, noreply metadata, and `git diff --check`;
- no firmware flash, installed Companion change, LaunchAgent action, permission change, or device configuration.

- [ ] **Step 4: Commit the verification record**

Run:

```bash
git diff --check
git add docs/superpowers/specs/2026-08-31-dual-workspace-readme-design.md
git commit -m "docs: record dual-workspace readme verification"
git status --short --branch
```

Expected: one design-only verification commit and a clean branch.

- [ ] **Step 5: Complete task-scoped reviews and one whole-branch review**

Review each task against this plan, then review the complete range from
`a859509` through HEAD. The whole-branch gate must inspect:

- English/Chinese factual parity;
- workspace separation and optional-super positioning;
- gallery accessibility and local paths;
- legal and unofficial/experimental notices;
- exact shortcut directions, five/fifteen-second behavior, and privacy claims;
- protected runtime/configuration boundary;
- generated-asset provenance and absence of private content.

Fix every Critical or Important finding with a reproducing assertion and a
separate focused commit, then repeat the affected review.

- [ ] **Step 6: Publish the reviewed branch without rewriting history**

From an isolated named-branch worktree, run:

```bash
git push public HEAD:main
```

From local `main` itself, run:

```bash
git push public main
```

Choose exactly the command matching the checkout. Do not use `--force`,
`--mirror`, `--all`, `pull`, or reset.

- [ ] **Step 7: Verify the live public README and CI**

Run:

```bash
local_head=$(git rev-parse HEAD)
remote_head=$(gh api repos/jiangew/m5stack-stopwatch-agent-bezel/git/ref/heads/main --jq '.object.sha')
test "$local_head" = "$remote_head"
test "$(gh api repos/jiangew/m5stack-stopwatch-agent-bezel --jq '.visibility')" = public
test "$(gh api repos/jiangew/m5stack-stopwatch-agent-bezel --jq '.default_branch')" = main
gh api repos/jiangew/m5stack-stopwatch-agent-bezel/readme --jq '.html_url'
gh run list --repo jiangew/m5stack-stopwatch-agent-bezel --limit 5
```

Open the public README and confirm:

- both images load from the repository;
- the desktop view is two-column;
- narrow rendering keeps Codex before SUPER;
- both workspace headings, comparison table, and optional label are visible;
- English and Chinese cross-links work.

Report Actions as queued, in progress, passed, or failed according to the
actual result. Do not call a running workflow passed.

- [ ] **Step 8: Complete local integration and cleanup only after green publication**

If implementation used a feature worktree, fast-forward local `main` to the
reviewed HEAD, rerun the local structure/privacy/diff gate on `main`, then
remove only that owned `.worktrees/` checkout and delete only its fully merged
local feature branch. If implementation ran directly on `main`, verify that
`main`, `public/main`, and the live remote SHA are equal and leave other
worktrees and branches untouched.
