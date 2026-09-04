#include <cassert>
#include <cstring>
#include <type_traits>
#include <utility>
#include <array>
#include <string>
#include <vector>

#include "SuperWorkspaceUi.h"

namespace {

struct RecordingSurface {
  std::vector<std::array<int, 5>> rectangles;
  std::vector<int> triangleColors;
  std::vector<std::string> texts;
  void fillScreen(int) {}
  void fillRect(int x, int y, int w, int h, int c) { rectangles.push_back({x,y,w,h,c}); }
  void fillTriangle(int, int, int, int, int, int, int c) { triangleColors.push_back(c); }
  void fillSmoothRoundRect(int, int, int, int, int, int) {}
  void loadFont(const std::uint8_t*) {}
  void unloadFont() {}
  void setTextDatum(textdatum_t) {}
  void setTextSize(float) {}
  void setTextColor(int) {}
  void drawString(const char* text, int, int) { texts.emplace_back(text); }
};

void testSharedRendererDoesNotCoverTriangleBases() {
  super_workspace::State state;
  state.profile = super_workspace::Profile::Hermes;
  state.borderColors = {0xFFFF, 0xFFE0, 0x07FF, 0xF81F};
  state.swipeDirection = touch_gesture::Direction::Right;
  RecordingSurface surface;
  super_workspace::render(surface, state);
  assert(surface.rectangles.size() == 1);
  const auto rect = surface.rectangles[0];
  assert(rect[0] > 143 && rect[1] > 143);
  assert(rect[0] + rect[2] <= 322 && rect[1] + rect[3] <= 322);
  for (std::size_t i=0; i<4; ++i) assert(surface.triangleColors[i*2] == state.borderColors[i]);
  auto contains = [&](const char* text) {
    return std::find(surface.texts.begin(), surface.texts.end(), text) != surface.texts.end();
  };
  assert(contains("HERMES") && contains("NEW") && contains("CYCLE"));
  assert(contains("OFFLINE") && contains("--%"));
  assert(!contains("BACK") && !contains("TAB"));
}

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

void assertPoint(super_workspace::Point actual, int expectedX,
                 int expectedY) {
  assert(actual.x == expectedX);
  assert(actual.y == expectedY);
}

void testDirectionalGeometryAndPalette() {
  using touch_gesture::Direction;

  assert(std::strcmp(super_workspace::kTitle, "SUPER") == 0);
  static_assert(super_workspace::kWidth == 466);
  static_assert(super_workspace::kHeight == 466);
  static_assert(super_workspace::kOutlineWidth == 5);
  static_assert(super_workspace::kCenterSquare.left == 143);
  static_assert(super_workspace::kCenterSquare.top == 143);
  static_assert(super_workspace::kCenterSquare.right == 322);
  static_assert(super_workspace::kCenterSquare.bottom == 322);
  static_assert(super_workspace::kBackground == 0x0041);
  static_assert(super_workspace::kCenterBorder == 0x372F);

  const auto& controls = super_workspace::kDirectionalControls;
  assert(controls.size() == 4);

  assert(controls[0].direction == Direction::Up);
  assertPoint(controls[0].baseStart, 143, 143);
  assertPoint(controls[0].baseEnd, 322, 143);
  assertPoint(controls[0].tip, 233, 26);
  assertPoint(controls[0].labelAnchor, 233, 91);
  assert(std::strcmp(controls[0].label, "PREV") == 0);
  assert(controls[0].borderColor == 0x26DF);

  assert(controls[1].direction == Direction::Right);
  assertPoint(controls[1].baseStart, 322, 143);
  assertPoint(controls[1].baseEnd, 322, 322);
  assertPoint(controls[1].tip, 440, 233);
  assertPoint(controls[1].labelAnchor, 375, 233);
  assert(std::strcmp(controls[1].label, "TAB") == 0);
  assert(controls[1].borderColor == 0xFCE6);

  assert(controls[2].direction == Direction::Down);
  assertPoint(controls[2].baseStart, 322, 322);
  assertPoint(controls[2].baseEnd, 143, 322);
  assertPoint(controls[2].tip, 233, 440);
  assertPoint(controls[2].labelAnchor, 233, 387);
  assert(std::strcmp(controls[2].label, "NEXT") == 0);
  assert(controls[2].borderColor == 0xEA7F);

  assert(controls[3].direction == Direction::Left);
  assertPoint(controls[3].baseStart, 143, 322);
  assertPoint(controls[3].baseEnd, 143, 143);
  assertPoint(controls[3].tip, 26, 233);
  assertPoint(controls[3].labelAnchor, 90, 233);
  assert(std::strcmp(controls[3].label, "CYCLE") == 0);
  assert(controls[3].borderColor == 0x53DF);

  for (const auto& control : controls) {
    assert(control.tip.x >= 0 && control.tip.x < super_workspace::kWidth);
    assert(control.tip.y >= 0 && control.tip.y < super_workspace::kHeight);
  }
  assert(controls[0].baseStart.x == super_workspace::kCenterSquare.left);
  assert(controls[0].baseEnd.x == super_workspace::kCenterSquare.right);
  assert(controls[1].baseStart.y == super_workspace::kCenterSquare.top);
  assert(controls[1].baseEnd.y == super_workspace::kCenterSquare.bottom);
  assert(controls[2].baseStart.x == super_workspace::kCenterSquare.right);
  assert(controls[2].baseEnd.x == super_workspace::kCenterSquare.left);
  assert(controls[3].baseStart.y == super_workspace::kCenterSquare.bottom);
  assert(controls[3].baseEnd.y == super_workspace::kCenterSquare.top);

  assert(controls[0].borderColor != controls[1].borderColor);
  assert(controls[0].borderColor != controls[2].borderColor);
  assert(controls[0].borderColor != controls[3].borderColor);
  assert(controls[1].borderColor != controls[2].borderColor);
  assert(controls[1].borderColor != controls[3].borderColor);
  assert(controls[2].borderColor != controls[3].borderColor);
}

void testDedicatedVisualState() {
  using super_workspace::State;
  using touch_gesture::Direction;

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
  testSharedRendererDoesNotCoverTriangleBases();
  testDirectionalGeometryAndPalette();
  testDedicatedVisualState();
  testNoUserContentOrCodexTelemetryFields();
}
