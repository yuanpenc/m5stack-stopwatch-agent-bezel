// Native, headless, pixel-identical dashboard renderer.
#include <M5GFX.h>

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

#include "DashboardUi.h"

namespace {

dashboard::State previewState() {
  dashboard::State state;
  state.connected = true;
  state.quotaAvailable = true;
  state.remainingPercent = 82.0f;
  state.resetInSeconds = 4 * 86400 + 3 * 3600;
  state.threads = {{
      {0xE9EEF5, 0.90f, false},  // idle
      {0x3794FF, 1.00f, true},   // thinking
      {0x2DDD72, 1.00f, false},  // complete
      {0xFFB020, 1.00f, false},  // requires input
      {0xFF4D5E, 1.00f, false},  // error
      {0x000000, 0.00f, false},  // unassigned
  }};
  return state;
}

bool writePpm(lgfx::LGFX_Sprite& sprite, const char* path) {
  std::FILE* output = std::fopen(path, "wb");
  if (output == nullptr) return false;
  std::fprintf(output, "P6\n%d %d\n255\n", dashboard::kWidth,
               dashboard::kHeight);
  std::vector<lgfx::bgr888_t> pixels(dashboard::kWidth * dashboard::kHeight);
  sprite.readRectRGB(0, 0, dashboard::kWidth, dashboard::kHeight, pixels.data());
  for (const auto& pixel : pixels) {
    const std::uint8_t rgb[3] = {pixel.R8(), pixel.G8(), pixel.B8()};
    std::fwrite(rgb, 1, sizeof(rgb), output);
  }
  return std::fclose(output) == 0;
}

}  // namespace

int main(int argc, char** argv) {
  const char* outputPath = argc > 1 ? argv[1] : "dashboard-preview.ppm";
  lgfx::LGFX_Sprite framebuffer;
  framebuffer.setColorDepth(16);
  if (framebuffer.createSprite(dashboard::kWidth, dashboard::kHeight) == nullptr) {
    std::fprintf(stderr, "Could not allocate preview framebuffer\n");
    return 1;
  }
  framebuffer.setTextWrap(false);
  dashboard::render(framebuffer, previewState(), 375);
  if (!writePpm(framebuffer, outputPath)) {
    std::fprintf(stderr, "Could not write %s\n", outputPath);
    return 1;
  }
  std::printf("Rendered %s (%d x %d, RGB565)\n", outputPath,
              dashboard::kWidth, dashboard::kHeight);
  return 0;
}
