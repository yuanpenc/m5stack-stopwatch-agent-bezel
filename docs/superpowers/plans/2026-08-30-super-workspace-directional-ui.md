# StopWatch SUPER Directional UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task in the current session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the row-based SUPER screen with the approved A-v3 square-and-triangle directional UI, then preview, build, install, and physically verify it on the USB-microphone C152.

**Architecture:** Keep `super_workspace::State` and every input/RPC/Companion boundary unchanged. Replace only the renderer's layout model with fixed integer geometry and palette constants; use native tests for the geometry contract and the existing pixel-identical native preview for visual acceptance before any flash.

**Tech Stack:** C++17, M5GFX, PlatformIO native preview, PlatformIO ESP32-S3 USB-microphone environment, native `assert` tests.

## Global Constraints

- Execute serially in the current session; do not use subagents.
- Create an isolated `feature/super-workspace-directional-ui` worktree from the clean commit containing this plan before editing production code.
- Target only M5Stack StopWatch Dev Kit C152 and the isolated USB-microphone firmware.
- Do not change Companion, RPC, HID, BLE, quota, USB audio, gesture, haptic, power, lease, or privacy behavior.
- Keep the surface at 466 × 466 and use the exact approved A-v3 coordinates and RGB565 palette.
- Center-square and triangle outlines are always five pixels wide.
- Triangle bases exactly reuse the four square edges; the square renders after the triangles and has 90-degree corners.
- Fixed direction labels are `PREV`, `TAB`, `NEXT`, and `BACK`; never add project names, session names, tab titles, or other user content.
- Do not build or flash the default wireless firmware.
- Do not flash until the current download-mode `/dev/cu.*` port is freshly resolved, reported, and explicitly confirmed by the user.
- Keep existing firmware and Companion backups untouched.

---

## Execution Setup

- [ ] From the clean main worktree, invoke `using-git-worktrees` and create:
  - branch: `feature/super-workspace-directional-ui`
  - path: `.worktrees/super-workspace-directional-ui`
  - base: the main commit containing this plan
- [ ] In the new worktree, verify `git status --short` is empty and read `AGENTS.md`, the approved design spec, and this plan.
- [ ] Confirm the installed Companion and C152 are not modified during Tasks 1–3.

---

### Task 1: Replace the row model with the approved directional geometry

**Files:**
- Modify: `include/SuperWorkspaceUi.h`
- Modify: `simulator/super_workspace_ui_test.cpp`

**Interfaces:**
- Consumes: existing `super_workspace::State`, `touch_gesture::Direction`, Space Mono VLW fonts, and the current power-overlay state.
- Produces:
  - `struct Point { int x; int y; }`
  - `struct Rect { int left; int top; int right; int bottom; }`
  - `struct DirectionalControl`
  - `constexpr Rect kCenterSquare`
  - `constexpr int kOutlineWidth`
  - `constexpr std::array<DirectionalControl, 4> kDirectionalControls`
  - unchanged `template <typename Surface> void render(Surface&, const State&)`

- [ ] **Step 1: Add failing geometry and palette assertions**

Replace the row-layout assertions in `simulator/super_workspace_ui_test.cpp` with the approved contract:

```cpp
void testDirectionalGeometryAndPalette() {
  using touch_gesture::Direction;

  static_assert(super_workspace::kOutlineWidth == 5);
  static_assert(super_workspace::kCenterSquare.left == 143);
  static_assert(super_workspace::kCenterSquare.top == 143);
  static_assert(super_workspace::kCenterSquare.right == 322);
  static_assert(super_workspace::kCenterSquare.bottom == 322);

  const auto& controls = super_workspace::kDirectionalControls;
  assert(controls.size() == 4);

  assert(controls[0].direction == Direction::Up);
  assert(controls[0].baseStart == super_workspace::Point{143, 143});
  assert(controls[0].baseEnd == super_workspace::Point{322, 143});
  assert(controls[0].tip == super_workspace::Point{233, 26});
  assert(std::strcmp(controls[0].label, "PREV") == 0);
  assert(controls[0].borderColor == 0x26DF);

  assert(controls[1].direction == Direction::Right);
  assert(controls[1].baseStart == super_workspace::Point{322, 143});
  assert(controls[1].baseEnd == super_workspace::Point{322, 322});
  assert(controls[1].tip == super_workspace::Point{440, 233});
  assert(std::strcmp(controls[1].label, "TAB") == 0);
  assert(controls[1].borderColor == 0xFCE6);

  assert(controls[2].direction == Direction::Down);
  assert(controls[2].baseStart == super_workspace::Point{322, 322});
  assert(controls[2].baseEnd == super_workspace::Point{143, 322});
  assert(controls[2].tip == super_workspace::Point{233, 440});
  assert(std::strcmp(controls[2].label, "NEXT") == 0);
  assert(controls[2].borderColor == 0xEA7F);

  assert(controls[3].direction == Direction::Left);
  assert(controls[3].baseStart == super_workspace::Point{143, 322});
  assert(controls[3].baseEnd == super_workspace::Point{143, 143});
  assert(controls[3].tip == super_workspace::Point{26, 233});
  assert(std::strcmp(controls[3].label, "BACK") == 0);
  assert(controls[3].borderColor == 0x53DF);

  assert(super_workspace::kCenterBorder == 0x372F);
  assert(controls[0].borderColor != controls[1].borderColor);
  assert(controls[1].borderColor != controls[2].borderColor);
  assert(controls[2].borderColor != controls[3].borderColor);
  assert(controls[3].borderColor != controls[0].borderColor);
}
```

Keep the existing state/privacy assertions and update `main()` to call this test.

- [ ] **Step 2: Compile RED against the current row renderer**

Use `apply_patch` to create a temporary `/private/tmp/codex-super-ui-red/M5GFX.h` containing only:

```cpp
#pragma once
enum textdatum_t { middle_center, middle_left, middle_right };
```

Run:

```bash
clang++ -std=c++17 -Wall -Wextra -Werror \
  -I/private/tmp/codex-super-ui-red -Iinclude \
  simulator/super_workspace_ui_test.cpp \
  -o /private/tmp/codex-super-ui-red/super_workspace_ui_test
```

Expected: compile failure because `kOutlineWidth`, `kCenterSquare`, and
`kDirectionalControls` do not exist. A typo or missing include is not an
acceptable RED result.

- [ ] **Step 3: Add the exact geometry model**

In `include/SuperWorkspaceUi.h`, replace `CommandRow`, `kCommandRows`, and
row geometry with:

```cpp
struct Point {
  int x;
  int y;
  constexpr bool operator==(const Point& other) const {
    return x == other.x && y == other.y;
  }
};

struct Rect {
  int left;
  int top;
  int right;
  int bottom;
};

struct DirectionalControl {
  touch_gesture::Direction direction;
  const char* label;
  Point baseStart;
  Point baseEnd;
  Point tip;
  Point innerBaseStart;
  Point innerBaseEnd;
  Point innerTip;
  Point labelAnchor;
  std::uint16_t borderColor;
  std::uint16_t fillColor;
  std::uint16_t activeBorderColor;
  std::uint16_t activeFillColor;
};

constexpr int kOutlineWidth = 5;
constexpr Rect kCenterSquare{143, 143, 322, 322};
constexpr std::uint16_t kBackground = 0x0041;
constexpr std::uint16_t kCenterFill = 0x0862;
constexpr std::uint16_t kCenterBorder = 0x372F;

static constexpr std::array<DirectionalControl, 4>
    kDirectionalControls = {{
        {touch_gesture::Direction::Up, "PREV",
         {143, 143}, {322, 143}, {233, 26},
         {149, 138}, {316, 138}, {233, 36}, {233, 91},
         0x26DF, 0x0082, 0x673F, 0x0A09},
        {touch_gesture::Direction::Right, "TAB",
         {322, 143}, {322, 322}, {440, 233},
         {327, 149}, {327, 316}, {430, 233}, {375, 233},
         0xFCE6, 0x1061, 0xFDCE, 0x4961},
        {touch_gesture::Direction::Down, "NEXT",
         {322, 322}, {143, 322}, {233, 440},
         {316, 327}, {149, 327}, {233, 430}, {233, 387},
         0xEA7F, 0x1042, 0xF43F, 0x40C9},
        {touch_gesture::Direction::Left, "BACK",
         {143, 322}, {143, 143}, {26, 233},
         {138, 316}, {138, 149}, {36, 233}, {90, 233},
         0x53DF, 0x0862, 0x8D1F, 0x1929},
    }};
```

- [ ] **Step 4: Implement the normal directional renderer**

Add these focused helpers and remove `drawHeading`, `drawCommands`, and the
bottom-row battery layout:

```cpp
template <typename Surface>
void drawDirectionalControl(Surface& surface,
                            const DirectionalControl& control,
                            bool active);

template <typename Surface>
void drawCenterPanel(Surface& surface, const State& state);

template <typename Surface>
void drawCenterBattery(Surface& surface, const State& state);
```

`drawDirectionalControl` must:

1. fill the outer triangle with `borderColor` or `activeBorderColor`;
2. fill the inner triangle with `fillColor` or `activeFillColor`;
3. draw the fixed label at `labelAnchor` with Space Mono 18;
4. keep identical outer and inner geometry in active and inactive states.

`drawCenterPanel` must render the square after every triangle:

```cpp
surface.fillRect(143, 143, 180, 180, kCenterBorder);
surface.fillRect(148, 148, 170, 170, kCenterFill);
```

It then renders `SUPER`, `CONNECTED` or `OFFLINE`, and the compact battery
row inside the 170 × 170 interior. Reuse the existing battery clamping,
`--%`, charging bolt, low-battery warning, and offline danger semantics.

The final renderer order is:

```cpp
template <typename Surface>
void render(Surface& surface, const State& state) {
  surface.fillScreen(kBackground);
  for (const DirectionalControl& control : kDirectionalControls) {
    drawDirectionalControl(surface, control,
                           state.swipeDirection == control.direction);
  }
  drawCenterPanel(surface, state);
  drawPowerOverlay(surface, state);
}
```

- [ ] **Step 5: Compile and run GREEN**

Run the same `clang++` command from Step 2, then:

```bash
/private/tmp/codex-super-ui-red/super_workspace_ui_test
```

Expected: exit 0 with no compiler warnings.

- [ ] **Step 6: Run the existing input-policy and workspace-mode tests**

Compile and run `workspace_input_policy_test.cpp` and
`workspace_mode_test.cpp` with `-Wall -Wextra -Werror` and the existing
ArduinoJson include path under
`usb-mic/.pio/libdeps/m5stack-stopwatch-usb-mic/ArduinoJson/src`.

Expected: both exit 0, proving the renderer change did not alter SUPER input
isolation or lease behavior.

- [ ] **Step 7: Review and commit Task 1**

Review only the renderer and its native test. Confirm no changes in
`src/main.cpp`, Companion, RPC, HID, BLE, or USB audio files.

```bash
git add include/SuperWorkspaceUi.h simulator/super_workspace_ui_test.cpp
git commit -m "feat: render geometric super workspace controls"
```

---

### Task 2: Expand native preview states and obtain visual acceptance

**Files:**
- Modify: `simulator/preview_main.cpp`
- Test: native preview CLI and generated PPM/PNG files under `/private/tmp`

**Interfaces:**
- Consumes: unchanged `super_workspace::State` and Task 1 renderer.
- Produces: preview scenarios `super`, `super-active-right`,
  `super-offline`, `super-charging`, and `super-power-hold`.

- [ ] **Step 1: Verify preview-scenario RED**

Build the existing preview without changing `preview_main.cpp`:

```bash
env HOMEBREW_PREFIX=/opt/homebrew PLATFORMIO_SETTING_ENABLE_TELEMETRY=no \
  pio run -e native-preview
```

Run:

```bash
.pio/build/native-preview/program \
  /private/tmp/super-active-right-red.ppm super-active-right
```

Expected: exit 2 and `Unknown scenario 'super-active-right'`.

- [ ] **Step 2: Add deterministic SUPER preview states**

Change the helper to `superPreviewState(const char* scenario)` and assign:

```cpp
super_workspace::State state;
state.batteryPercent = 78;
state.connected = true;

if (std::strcmp(scenario, "super-active-right") == 0) {
  state.swipeDirection = touch_gesture::Direction::Right;
} else if (std::strcmp(scenario, "super-offline") == 0) {
  state.connected = false;
  state.batteryPercent = 18;
} else if (std::strcmp(scenario, "super-charging") == 0) {
  state.charging = true;
} else if (std::strcmp(scenario, "super-power-hold") == 0) {
  state.powerOverlay = super_workspace::PowerOverlay::HoldToPowerOff;
  state.powerHoldProgress = 0.56f;
}
return state;
```

Add all five names to `validScenario`, the usage error, and the SUPER render
branch. The plain `super` scenario has no active swipe.

- [ ] **Step 3: Build preview GREEN and generate all states**

Run the native-preview build again, then generate:

```bash
.pio/build/native-preview/program /private/tmp/super-a-v3-normal.ppm super
.pio/build/native-preview/program /private/tmp/super-a-v3-active-right.ppm super-active-right
.pio/build/native-preview/program /private/tmp/super-a-v3-offline.ppm super-offline
.pio/build/native-preview/program /private/tmp/super-a-v3-charging.ppm super-charging
.pio/build/native-preview/program /private/tmp/super-a-v3-power-hold.ppm super-power-hold
```

Convert each PPM explicitly:

```bash
sips -s format png /private/tmp/super-a-v3-normal.ppm --out /private/tmp/super-a-v3-normal.png
sips -s format png /private/tmp/super-a-v3-active-right.ppm --out /private/tmp/super-a-v3-active-right.png
sips -s format png /private/tmp/super-a-v3-offline.ppm --out /private/tmp/super-a-v3-offline.png
sips -s format png /private/tmp/super-a-v3-charging.ppm --out /private/tmp/super-a-v3-charging.png
sips -s format png /private/tmp/super-a-v3-power-hold.ppm --out /private/tmp/super-a-v3-power-hold.png
```

Do not overwrite or commit existing `artifacts/` images.

Expected: all five previews are 466 × 466 and remain under `/private/tmp`.

- [ ] **Step 4: Perform visual geometry checks**

Inspect the five PNGs and confirm:

- all square and triangle core outlines are visually five pixels;
- every triangle base reaches exactly to both square corners;
- no green corner protrudes outside an attached triangle;
- all tips and labels remain inside the circular visible area;
- center content does not cross the green border;
- active-right changes only the right triangle;
- offline, charging, and power overlay remain legible.

Show the normal and active-right PNGs to the user and pause for explicit visual
approval before continuing to a device build.

- [ ] **Step 5: Commit Task 2 after preview approval**

```bash
git add simulator/preview_main.cpp
git commit -m "test: expand super workspace preview states"
```

---

### Task 3: Full verification and branch review

**Files:**
- Modify after verification: `docs/superpowers/specs/2026-08-30-super-workspace-directional-ui-design.md`
- Verify: all files changed on `feature/super-workspace-directional-ui`

**Interfaces:**
- Consumes: Task 1 renderer and Task 2 preview scenarios.
- Produces: reviewed USB-microphone firmware artifact and an implementation
  record ready for physical installation.

- [ ] **Step 1: Run every native unit test**

Freshly compile and run these nine tests with C++17,
`-Wall -Wextra -Werror`, `-Iinclude`, the temporary M5GFX stub for the SUPER
UI test, and the ArduinoJson path for JSON-dependent tests:

1. `completion_banner_test.cpp`
2. `connection_health_test.cpp`
3. `gesture_test.cpp`
4. `host_rpc_request_test.cpp`
5. `power_button_gesture_test.cpp`
6. `quota_payload_test.cpp`
7. `super_workspace_ui_test.cpp`
8. `workspace_input_policy_test.cpp`
9. `workspace_mode_test.cpp`

Expected: nine compile exits 0 and nine run exits 0.

- [ ] **Step 2: Rebuild the native preview and USB-microphone firmware**

```bash
env HOMEBREW_PREFIX=/opt/homebrew PLATFORMIO_SETTING_ENABLE_TELEMETRY=no \
  pio run -e native-preview
env PLATFORMIO_SETTING_ENABLE_TELEMETRY=no pio run -d usb-mic
```

Expected: `native-preview`, `prepare-bluedroid`, and
`m5stack-stopwatch-usb-mic` all report SUCCESS, with no compiler warning from
project code.

- [ ] **Step 3: Run diff and boundary review**

Run:

```bash
git diff --check main...HEAD
git diff --stat main...HEAD
git status --short
```

Review `main...HEAD` for:

- exact A-v3 geometry, five-pixel equality, and color values;
- triangle-base/square-edge equality at all four corners;
- unchanged `super_workspace::State` privacy boundary;
- unchanged input mapping, 800 ms debounce, haptics, power flow, lease, RPC,
  Companion, and USB audio;
- generated previews and binaries absent from Git.

Any finding must be reproduced by a failing native assertion, fixed in a focused
commit, and followed by the affected verification again.

- [ ] **Step 4: Record implementation verification**

Change the design document status from `Approved for implementation` to
`Implemented; native preview approved`. Add one short verification note naming
the nine native tests, native preview, and USB-microphone build without claiming
a physical result.

```bash
git add docs/superpowers/specs/2026-08-30-super-workspace-directional-ui-design.md
git commit -m "docs: record super workspace ui verification"
```

- [ ] **Step 5: Confirm readiness without changing the installed system**

Confirm the feature worktree is clean. Perform read-only checks that the existing
signed Companion, LaunchAgent, HID connection, UAC input, and latest quota cycle
are still healthy. Do not replace the Companion executable or restart its
LaunchAgent for this renderer-only change.

---

### Task 4: Flash and physically verify the approved UI

**Files:**
- Build artifact only:
  `usb-mic/.pio/build/m5stack-stopwatch-usb-mic/firmware.bin`
- No tracked file changes

**Interfaces:**
- Consumes: reviewed Task 3 USB-microphone firmware.
- Produces: physically verified A-v3 SUPER screen on the user's C152.

- [ ] **Step 1: Build and hash the exact install artifact**

Run the final USB-microphone build and:

```bash
shasum -a 256 \
  usb-mic/.pio/build/m5stack-stopwatch-usb-mic/firmware.bin
```

Record the SHA-256 without modifying or deleting any prior backup.

- [ ] **Step 2: Freshly resolve the download port**

List current `/dev/cu.*` entries before download mode. Ask the user to put the
C152 into download mode, then list `/dev/cu.*` again.

Require exactly one newly enumerated serial port. Report that exact path and ask
the user to repeat `确认刷写` followed by that exact path. Do not reuse any
historical port name, even if it is identical.

- [ ] **Step 3: Upload only after exact confirmation**

After confirmation, assign the verbatim confirmed path to `resolved_port` and
run:

```bash
pio run -d usb-mic -e m5stack-stopwatch-usb-mic \
  --target upload --upload-port "$resolved_port"
```

Expected: upload exits 0 and every written image hash verifies.

- [ ] **Step 4: Perform layered physical acceptance**

After normal re-enumeration, verify separately:

1. USB Audio exposes one control and one streaming interface.
2. `Codex StopWatch Mic` input responds without recording or analyzing user
   content.
3. BLE/HID reconnect automatically.
4. Entering super.engineering displays the A-v3 SUPER screen.
5. The four triangle colors, equal outlines, aligned corners, labels, center
   status, and battery match the approved preview.
6. Up/down/left/right gestures still perform their existing actions.
7. Held-swipe visual feedback affects only the matching triangle.
8. 800 ms debounce, input isolation, power overlay, sleep behavior, and 15-second
   lease fallback remain correct.
9. Leaving super.engineering restores the Codex panel.
10. Latest quota sync and original LaunchAgent automatic startup remain healthy.

Mark every item not observed on the physical C152 as `未验证`.

- [ ] **Step 5: Finish the branch**

After physical acceptance and a final clean status, use
`finishing-a-development-branch`. The expected integration choice is a local
fast-forward merge to `main`; do not pull or push unless the user explicitly
changes that choice. Remove only the owned
`.worktrees/super-workspace-directional-ui` worktree after the merged-result
verification is green.
