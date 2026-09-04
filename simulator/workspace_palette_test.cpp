#include <algorithm>
#include <cassert>
#include <cstdint>
#include <limits>
#include "WorkspacePalette.h"

int main() {
  workspace_palette::Palette palette;
  std::uint32_t random = 1;
  int calls = 0;
  auto next = [&]() { ++calls; random = random * 1664525u + 1013904223u; return random; };
  auto previous = palette.colors();
  assert(palette.colors() == previous);
  for (std::uint32_t i = 0; i < 10000; ++i) {
    assert(palette.acceptSwipe(i * 800, next));
    auto colors = palette.colors();
    for (std::size_t j = 0; j < 4; ++j) {
      assert(colors[j] != previous[j]);
      assert(std::find(workspace_palette::kColors.begin(), workspace_palette::kColors.end(), colors[j]) != workspace_palette::kColors.end());
      for (std::size_t k = j + 1; k < 4; ++k) assert(colors[j] != colors[k]);
    }
    assert(!palette.acceptSwipe(i * 800 + 799, next));
    assert(palette.colors() == colors);
    previous = colors;
  }
  assert(calls == 40000);
  for (std::size_t j = 0; j < 12; ++j)
    for (std::size_t k = j + 1; k < 12; ++k)
      assert(workspace_palette::kColors[j] != workspace_palette::kColors[k]);
  workspace_palette::Palette wrap;
  const auto start = std::numeric_limits<std::uint32_t>::max() - 399;
  assert(wrap.acceptSwipe(start, next));
  assert(!wrap.acceptSwipe(399, next));
  assert(wrap.acceptSwipe(400, next));
}
