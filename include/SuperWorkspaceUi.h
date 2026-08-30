// SPDX-License-Identifier: MIT
#pragma once

#include <M5GFX.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>

#include "SpaceMonoVlw.h"
#include "TouchGesture.h"

namespace super_workspace {

constexpr int kWidth = 466;
constexpr int kHeight = 466;
constexpr int kCenterX = kWidth / 2;

// SUPER uses a violet signal palette that is intentionally independent from
// the green Codex telemetry dashboard.
constexpr std::uint16_t kBackground = 0x0820;
constexpr std::uint16_t kPanel = 0x18C8;
constexpr std::uint16_t kPanelActive = 0x4A37;
constexpr std::uint16_t kText = 0xF7DF;
constexpr std::uint16_t kMuted = 0x8410;
constexpr std::uint16_t kAccent = 0xA2FF;
constexpr std::uint16_t kConnected = 0x6E9B;
constexpr std::uint16_t kWarning = 0xFDA9;
constexpr std::uint16_t kDanger = 0xFAED;

constexpr const char* kTitle = "SUPER";
constexpr int kRowX = 30;
constexpr int kRowWidth = 406;
constexpr int kRowHeight = 50;
constexpr int kBatteryTop = 401;
constexpr int kBatteryHeight = 31;

enum class PowerOverlay : std::uint8_t {
  None,
  HoldToPowerOff,
  PoweringOff,
};

struct CommandRow {
  touch_gesture::Direction direction;
  const char* directionLabel;
  const char* actionLabel;
  int centerY;
};

static constexpr std::array<CommandRow, 4> kCommandRows = {{
    {touch_gesture::Direction::Left, "LEFT", "BACK", 144},
    {touch_gesture::Direction::Up, "UP", "PREV PROJECT", 206},
    {touch_gesture::Direction::Down, "DOWN", "NEXT PROJECT", 268},
    {touch_gesture::Direction::Right, "RIGHT", "NEXT TAB", 330},
}};

struct State {
  std::int8_t batteryPercent = -1;
  bool charging = false;
  bool connected = false;
  touch_gesture::Direction swipeDirection = touch_gesture::Direction::None;
  PowerOverlay powerOverlay = PowerOverlay::None;
  float powerHoldProgress = 0.0f;
};

template <typename Surface>
void drawText(Surface& surface, const char* text, int x, int y,
              textdatum_t datum, std::uint16_t color) {
  surface.setTextDatum(datum);
  surface.setTextSize(1.0f);
  surface.setTextColor(color);
  surface.drawString(text, x, y);
}

template <typename Surface>
void drawHeading(Surface& surface, const State& state) {
  surface.loadFont(dashboard::font_data::kSpaceMono46Vlw);
  drawText(surface, kTitle, kCenterX, 49, middle_center, kText);
  surface.unloadFont();

  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  const char* status = state.connected ? "CONNECTED" : "OFFLINE";
  const std::uint16_t statusColor = state.connected ? kConnected : kDanger;
  drawText(surface, status, kCenterX, 92, middle_center, statusColor);
  surface.unloadFont();
}

template <typename Surface>
void drawCommands(Surface& surface, const State& state) {
  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  for (const CommandRow& row : kCommandRows) {
    const bool active = state.swipeDirection == row.direction;
    const int top = row.centerY - kRowHeight / 2;
    if (active) {
      surface.fillSmoothRoundRect(kRowX, top, kRowWidth, kRowHeight, 15,
                                  kAccent);
      surface.fillSmoothRoundRect(kRowX + 4, top + 4, kRowWidth - 8,
                                  kRowHeight - 8, 12, kPanelActive);
    } else {
      surface.fillSmoothRoundRect(kRowX, top, kRowWidth, kRowHeight, 15,
                                  kPanel);
    }

    const std::uint16_t directionColor = active ? kText : kAccent;
    const std::uint16_t actionColor = active ? kText : kMuted;
    drawText(surface, row.directionLabel, kRowX + 22, row.centerY + 1,
             middle_left, directionColor);
    drawText(surface, row.actionLabel, kRowX + kRowWidth - 22,
             row.centerY + 1, middle_right, actionColor);
  }
  surface.unloadFont();
}

template <typename Surface>
void drawBattery(Surface& surface, const State& state) {
  constexpr int batteryX = 162;
  constexpr int batteryY = kBatteryTop + 7;
  constexpr int batteryWidth = 31;
  constexpr int batteryHeight = 16;
  const int battery = std::max(
      -1, std::min(100, static_cast<int>(state.batteryPercent)));
  const std::uint16_t color =
      battery < 0 ? kMuted : (battery <= 20 ? kWarning : kText);

  surface.fillSmoothRoundRect(batteryX, batteryY, batteryWidth, batteryHeight,
                              3, color);
  surface.fillSmoothRoundRect(batteryX + 2, batteryY + 2, batteryWidth - 4,
                              batteryHeight - 4, 2, kBackground);
  surface.fillSmoothRoundRect(batteryX + batteryWidth, batteryY + 4, 3,
                              batteryHeight - 8, 1, color);
  if (battery > 0) {
    const int fillWidth = std::max(2, (batteryWidth - 6) * battery / 100);
    surface.fillSmoothRoundRect(batteryX + 3, batteryY + 3, fillWidth,
                                batteryHeight - 6, 1, color);
  }
  if (state.charging) {
    const int boltX = batteryX + batteryWidth / 2;
    surface.fillTriangle(boltX, batteryY + 1, boltX - 5, batteryY + 8,
                         boltX - 1, batteryY + 8, kText);
    surface.fillTriangle(boltX - 1, batteryY + 7, boltX + 4, batteryY + 7,
                         boltX - 3, batteryY + batteryHeight - 1, kText);
  }

  char label[12];
  if (battery < 0) {
    std::snprintf(label, sizeof(label), "--%%");
  } else {
    std::snprintf(label, sizeof(label), "%d%%", battery);
  }
  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  drawText(surface, label, 218, kBatteryTop + kBatteryHeight / 2 + 1,
           middle_left, color);
  surface.unloadFont();
}

template <typename Surface>
void drawPowerOverlay(Surface& surface, const State& state) {
  if (state.powerOverlay == PowerOverlay::None) return;

  const bool confirming = state.powerOverlay == PowerOverlay::HoldToPowerOff;
  const char* heading = confirming ? "KEEP HOLDING" : "POWERING OFF";
  const char* detail = confirming ? "ALERTS PAUSE" : "RED OR USB WAKE";
  const std::uint16_t color = confirming ? kWarning : kDanger;
  constexpr int overlayX = 44;
  constexpr int overlayY = 172;
  constexpr int overlayWidth = 378;
  constexpr int overlayHeight = 128;

  surface.fillSmoothRoundRect(overlayX, overlayY, overlayWidth, overlayHeight,
                              24, kAccent);
  surface.fillSmoothRoundRect(overlayX + 4, overlayY + 4, overlayWidth - 8,
                              overlayHeight - 8, 20, kPanel);
  if (confirming) {
    const float progress = std::max(0.0f, std::min(1.0f,
                                                  state.powerHoldProgress));
    surface.fillSmoothRoundRect(overlayX + 28, overlayY + overlayHeight - 24,
                                overlayWidth - 56, 7, 3, kMuted);
    const int progressWidth =
        static_cast<int>((overlayWidth - 56) * progress);
    if (progressWidth > 0) {
      surface.fillSmoothRoundRect(overlayX + 28,
                                  overlayY + overlayHeight - 24,
                                  progressWidth, 7, 3, color);
    }
  }

  surface.loadFont(dashboard::font_data::kSpaceMono18Vlw);
  drawText(surface, heading, kCenterX, overlayY + 39, middle_center, color);
  drawText(surface, detail, kCenterX, overlayY + 70, middle_center, kText);
  surface.unloadFont();
}

template <typename Surface>
void render(Surface& surface, const State& state) {
  surface.fillScreen(kBackground);
  drawHeading(surface, state);
  drawCommands(surface, state);
  drawBattery(surface, state);
  drawPowerOverlay(surface, state);
}

}  // namespace super_workspace
