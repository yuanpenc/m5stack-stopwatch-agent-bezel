#include <algorithm>
#include <cassert>
#include <string>
#include <vector>

#include "DashboardUi.h"

namespace {
struct Text { std::string value; int x; int y; };
struct RecordingSurface {
  std::vector<Text> texts;
  void loadFont(const std::uint8_t*) {}
  void unloadFont() {}
  void setTextDatum(textdatum_t) {}
  void setTextSize(float) {}
  void setTextColor(int) {}
  void drawString(const char* text, int x, int y) { texts.push_back({text, x, y}); }
  void fillSmoothRoundRect(int, int, int, int, int, int) {}
  void fillTriangle(int, int, int, int, int, int, int) {}
  std::uint16_t color565(int r, int g, int b) {
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
  }
};

bool contains(const RecordingSurface& surface, const char* text) {
  return std::any_of(surface.texts.begin(), surface.texts.end(),
                     [&](const Text& item) { return item.value == text; });
}
void at(const RecordingSurface& surface, const char* text, int x, int y) {
  auto found = std::find_if(surface.texts.begin(), surface.texts.end(),
                           [&](const Text& item) { return item.value == text; });
  assert(found != surface.texts.end());
  assert(found->x == x && found->y == y);
}
RecordingSurface draw(dashboard::State state) {
  RecordingSurface surface;
  dashboard::drawSmallText(surface, state);
  dashboard::drawQuotaValue(surface, state);
  return surface;
}
dashboard::State liveState() {
  dashboard::State state;
  state.linkHealth = dashboard::LinkHealth::CodexLive;
  state.quotaAvailable = true;
  state.remainingPercent = 82;
  state.resetInSeconds = 3600;
  state.batteryPercent = 78;
  return state;
}

void normalStateUsesFourRowsWithoutWeeklyCaption() {
  const auto surface = draw(liveState());
  assert(!contains(surface, "WEEKLY LEFT"));
  at(surface, "CODEX LIVE", 233, 185);
  at(surface, "82%", 233, 228);
  at(surface, "RESET 1H 00M", 233, 270);
  at(surface, "78%", 254, 301);
  // Peripheral labels keep their existing coordinates.
  at(surface, "A1", 233, 69);
  at(surface, "A4", 233, 397);
}
void diagnosticStatesKeepOriginalFiveRows() {
  auto state = liveState();
  state.quotaStale = true;
  auto surface = draw(state);
  at(surface, "CODEX LIVE", 233, 168);
  at(surface, "SYNC STALE", 233, 198);
  at(surface, "82%", 233, 238);
  at(surface, "RESET 1H 00M", 233, 280);
  at(surface, "78%", 254, 307);

  state.quotaStale = false;
  state.linkHealth = dashboard::LinkHealth::Offline;
  state.quotaAvailable = false;
  surface = draw(state);
  at(surface, "WAITING CODEX", 233, 198);
  at(surface, "--", 233, 238);
  at(surface, "NO QUOTA DATA", 233, 280);
  state.quotaStale = true;
  surface = draw(state);
  assert(!contains(surface, "WAITING CODEX"));
  at(surface, "SYNC STALE", 233, 198);
  at(surface, "CHECK COMPANION", 233, 280);
}
void noQuotaKeepsTheCompactNormalLayout() {
  auto state = liveState();
  state.linkHealth = dashboard::LinkHealth::BleOnly;
  state.quotaAvailable = false;
  state.batteryPercent = -1;
  const auto surface = draw(state);
  assert(!contains(surface, "WEEKLY LEFT"));
  at(surface, "--", 233, 228);
  at(surface, "NO QUOTA DATA", 233, 270);
  at(surface, "--%", 254, 301);
}
}  // namespace

int main() {
  normalStateUsesFourRowsWithoutWeeklyCaption();
  diagnosticStatesKeepOriginalFiveRows();
  noQuotaKeepsTheCompactNormalLayout();
}
