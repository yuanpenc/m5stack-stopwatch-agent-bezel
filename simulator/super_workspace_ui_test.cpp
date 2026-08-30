#include <cassert>
#include <cstring>
#include <type_traits>
#include <utility>

#include "SuperWorkspaceUi.h"

namespace {

template <typename T, typename = void>
struct HasProjectName : std::false_type {};
template <typename T>
struct HasProjectName<
    T, std::void_t<decltype(std::declval<T>().projectName)>>
    : std::true_type {};

template <typename T, typename = void>
struct HasSessionName : std::false_type {};
template <typename T>
struct HasSessionName<
    T, std::void_t<decltype(std::declval<T>().sessionName)>>
    : std::true_type {};

template <typename T, typename = void>
struct HasQuotaAvailable : std::false_type {};
template <typename T>
struct HasQuotaAvailable<
    T, std::void_t<decltype(std::declval<T>().quotaAvailable)>>
    : std::true_type {};

template <typename T, typename = void>
struct HasRemainingPercent : std::false_type {};
template <typename T>
struct HasRemainingPercent<
    T, std::void_t<decltype(std::declval<T>().remainingPercent)>>
    : std::true_type {};

void testFixedCopyAndOrder() {
  using touch_gesture::Direction;

  assert(std::strcmp(super_workspace::kTitle, "SUPER") == 0);
  assert(super_workspace::kCommandRows.size() == 4);

  assert(super_workspace::kCommandRows[0].direction == Direction::Left);
  assert(std::strcmp(super_workspace::kCommandRows[0].directionLabel,
                     "LEFT") == 0);
  assert(std::strcmp(super_workspace::kCommandRows[0].actionLabel,
                     "BACK") == 0);

  assert(super_workspace::kCommandRows[1].direction == Direction::Up);
  assert(std::strcmp(super_workspace::kCommandRows[1].directionLabel,
                     "UP") == 0);
  assert(std::strcmp(super_workspace::kCommandRows[1].actionLabel,
                     "PREV PROJECT") == 0);

  assert(super_workspace::kCommandRows[2].direction == Direction::Down);
  assert(std::strcmp(super_workspace::kCommandRows[2].directionLabel,
                     "DOWN") == 0);
  assert(std::strcmp(super_workspace::kCommandRows[2].actionLabel,
                     "NEXT PROJECT") == 0);

  assert(super_workspace::kCommandRows[3].direction == Direction::Right);
  assert(std::strcmp(super_workspace::kCommandRows[3].directionLabel,
                     "RIGHT") == 0);
  assert(std::strcmp(super_workspace::kCommandRows[3].actionLabel,
                     "NEXT TAB") == 0);
}

void testDedicatedVisualStateAndGeometry() {
  using super_workspace::State;
  using touch_gesture::Direction;

  static_assert(super_workspace::kWidth == 466);
  static_assert(super_workspace::kHeight == 466);
  static_assert(super_workspace::kBackground == 0x0820);
  static_assert(super_workspace::kAccent == 0xA2FF);
  static_assert(super_workspace::kPanelActive == 0x4A37);
  static_assert(super_workspace::kAccent != 0x16B6);

  for (const auto& row : super_workspace::kCommandRows) {
    assert(super_workspace::kRowX >= 0);
    assert(super_workspace::kRowX + super_workspace::kRowWidth <=
           super_workspace::kWidth);
    assert(row.centerY - super_workspace::kRowHeight / 2 >= 0);
    assert(row.centerY + super_workspace::kRowHeight / 2 <
           super_workspace::kBatteryTop);
  }
  assert(super_workspace::kBatteryTop + super_workspace::kBatteryHeight <=
         super_workspace::kHeight);

  State state;
  state.batteryPercent = 63;
  state.charging = true;
  state.connected = true;
  state.swipeDirection = Direction::Right;
  state.powerOverlay = super_workspace::PowerOverlay::HoldToPowerOff;
  state.powerHoldProgress = 0.5f;
  assert(state.batteryPercent == 63);
  assert(state.charging);
  assert(state.connected);
  assert(state.swipeDirection == Direction::Right);
}

void testNoUserContentOrCodexTelemetryFields() {
  using State = super_workspace::State;
  static_assert(!HasProjectName<State>::value);
  static_assert(!HasSessionName<State>::value);
  static_assert(!HasQuotaAvailable<State>::value);
  static_assert(!HasRemainingPercent<State>::value);
}

}  // namespace

int main() {
  testFixedCopyAndOrder();
  testDedicatedVisualStateAndGeometry();
  testNoUserContentOrCodexTelemetryFields();
}
