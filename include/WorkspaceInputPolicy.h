// SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>

#include "WorkspaceMode.h"

namespace workspace_input {

enum class Control : std::uint8_t {
  SwipeUp,
  SwipeRight,
  SwipeDown,
  SwipeLeft,
  Agent,
  Send,
  CenterPowerHold,
  LeftPhysicalButton,
  RightPhysicalButton,
  RedPowerButton,
};

inline bool allowed(workspace_mode::Mode mode, Control control) {
  if (mode == workspace_mode::Mode::Codex) return true;
  switch (control) {
    case Control::SwipeUp:
    case Control::SwipeRight:
    case Control::SwipeDown:
    case Control::SwipeLeft:
    case Control::CenterPowerHold:
    case Control::RedPowerButton:
      return true;
    case Control::Agent:
    case Control::Send:
    case Control::LeftPhysicalButton:
    case Control::RightPhysicalButton:
      return false;
  }
  return false;
}

}  // namespace workspace_input
