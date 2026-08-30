# StopWatch SUPER Directional UI Redesign

**Status:** Implemented; native preview approved
**Date:** 2026-08-30
**Target:** M5Stack StopWatch Dev Kit C152, USB-microphone firmware only

## Summary

Replace the current row-based SUPER workspace screen with the approved A-v3
directional cross:

- a centered square containing only the SUPER mark, connection state, battery,
  and charging state;
- four outward-pointing triangles attached to the square;
- a green five-pixel square border;
- four five-pixel triangle borders in distinct direction colors;
- triangle bases aligned exactly with the square sides, so no green corner
  protrudes beyond an attached triangle.

This is a renderer-only change. Workspace-mode RPC, lease ownership, HID input,
gesture mapping, haptics, power behavior, Companion behavior, privacy boundaries,
and USB audio remain unchanged.

## Geometry

The render surface remains 466 × 466 pixels. Geometry uses inclusive pixel
coordinates.

| Element | Coordinates |
| --- | --- |
| Center square | left 143, top 143, right 322, bottom 322 |
| Up triangle | base (143,143)–(322,143), tip (233,26) |
| Right triangle | base (322,143)–(322,322), tip (440,233) |
| Down triangle | base (322,322)–(143,322), tip (233,440) |
| Left triangle | base (143,322)–(143,143), tip (26,233) |
| Shared outline width | 5 pixels |

Each triangle base reuses one complete square edge. Triangles render first and
the square renders afterward, ensuring the green square border is continuous at
all four junctions. The square uses true 90-degree corners; it has no corner
radius.

The normal-state label anchors are:

| Direction | Label | Anchor |
| --- | --- | --- |
| Up | PREV | (233,91) |
| Right | TAB | (375,233) |
| Down | NEXT | (233,387) |
| Left | BACK | (90,233) |

All four labels use the existing Space Mono 18 VLW font and are centered within
their triangles. They are fixed action labels and never include project names,
session names, tab titles, or other user content.

## Color and Content

Colors are fixed RGB565 values derived from the approved mockup:

| Role | RGB | RGB565 |
| --- | --- | --- |
| Background | #06090D | 0x0041 |
| Center fill | #090D10 | 0x0862 |
| Center border / connected | #36E47D | 0x372F |
| Up border | #26D9FF | 0x26DF |
| Right border | #FF9C32 | 0xFCE6 |
| Down border | #EE4FFF | 0xEA7F |
| Left border | #5278FF | 0x53DF |
| Up fill | #071116 | 0x0082 |
| Right fill | #120D08 | 0x1061 |
| Down fill | #120914 | 0x1042 |
| Left fill | #090D16 | 0x0862 |

The center square contains, from top to bottom:

1. **SUPER** in the existing Space Mono 46 VLW font.
2. **CONNECTED** or **OFFLINE**, retaining green and danger-state semantics.
3. The existing compact battery icon, numeric percentage, and charging bolt.

Unknown battery state remains `--%`. Low battery and offline states retain the
existing warning/danger colors. No quota, Agent, project, session, window,
workspace, prompt, credential, or user-content field is introduced.

## Rendering and Interaction Feedback

The renderer replaces command rows with a small geometry model containing one
square and four directional triangles. A shared outline helper renders both the
square and triangle borders at exactly five pixels.

Rendering order is fixed:

1. background;
2. four colored triangle outlines and dark fills;
3. direction labels;
4. green square outline and center fill;
5. SUPER, connection, and battery content;
6. the existing power-confirmation overlay, when active.

While a swipe is held, only its matching triangle changes state. Its geometry
and five-pixel outline width remain unchanged; its existing direction color is
brightened, its dark fill becomes more luminous, and its label becomes the
primary text color. Release restores the normal state. Haptic timing, gesture
threshold, HID press/release behavior, and the global 800 ms debounce do not
change.

The existing hold-to-power-off and powering-off overlays remain functionally
unchanged and render above the redesigned surface.

## Code Boundaries

Only the SUPER renderer, its native test, and the native preview scenario need
production changes:

- `include/SuperWorkspaceUi.h`
- `simulator/super_workspace_ui_test.cpp`
- `simulator/preview_main.cpp` only if an additional active/offline preview
  state is needed

`src/main.cpp` continues to provide the same `super_workspace::State` and
does not gain new application data. No Companion, RPC, HID, BLE, quota, USB
audio, or input-policy code changes are required.

## Verification

Implementation follows test-first development:

1. Extend the native test with new geometry and palette expectations and verify
   RED against the row-based renderer.
2. Assert that every triangle base exactly equals one square edge, the shared
   outline width is five pixels, all four border colors are distinct, and no
   geometry leaves the 466 × 466 surface.
3. Preserve tests for fixed action mapping, battery/connection inputs, power
   overlay state, and the absence of project/session/quota fields.
4. Implement the minimum renderer change and verify GREEN.
5. Generate normal, active-right, offline, charging, and power-overlay previews
   under `/private/tmp`; visually compare them with the approved A-v3 mockup.
6. Run all native tests, `git diff --check`, and a
   `pio run -d usb-mic` build with no compiler warnings from project code.

The default wireless firmware is not built or flashed for this change.
Companion tests and installation are unaffected, but a final read-only runtime
check will confirm the existing Companion and quota loop remain healthy.

Implementation verification completed with all nine native tests, the five
466 × 466 native preview states, and both USB-microphone PlatformIO build
environments. The generated preview was approved by the user. These checks do
not claim that the redesigned screen has been observed on physical C152
hardware.

## Installation Boundary

No physical device is flashed as part of renderer implementation or preview
review. After the generated native preview is approved, installation requires:

1. a fresh USB-microphone firmware build and SHA-256;
2. putting the C152 into download mode;
3. resolving the newly enumerated exact `/dev/cu.*` port;
4. obtaining explicit confirmation for that exact port before upload;
5. separately verifying the SUPER screen, four gestures, lease fallback, USB
   microphone, HID, BLE, quota sync, and automatic startup.

Existing Companion and firmware backups remain untouched.
