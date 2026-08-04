// SPDX-License-Identifier: MIT
// Copyright (c) 2026 imliubo
// StopWatch port changes copyright (c) 2026 Codex Micro for StopWatch contributors

#include <Arduino.h>
#include <M5Unified.h>

#include <array>
#include <cmath>

#include "CodexMicroBle.h"
#include "DashboardUi.h"
#include "TouchGesture.h"

namespace {

constexpr uint32_t kQuotaStaleAfterMs = 180000;
constexpr uint32_t kCompletionBannerMs = 5000;
constexpr uint32_t kVoiceTapBannerMs = 900;
constexpr uint32_t kVoiceClickPulseMs = 70;
constexpr uint32_t kTouchKeyPulseMs = 55;
constexpr int kSwipeThresholdPx = 52;
constexpr uint8_t kButtonHapticIntensity = 176;
// 144 (56% PWM duty) sat at the motor's start threshold and spun up only
// sometimes; 176 matches the physical buttons, which never felt flaky.
constexpr uint8_t kTouchHapticIntensity = 176;
constexpr uint8_t kSwipeHapticIntensity = 168;
constexpr uint32_t kWakeHapticDurationMs = 20;
constexpr uint32_t kButtonHapticDurationMs = 42;
constexpr uint32_t kTouchHapticDurationMs = 32;
constexpr uint32_t kSwipeHapticDurationMs = 40;
constexpr uint32_t kDimAfterMs = 300000;
constexpr uint32_t kScreenOffAfterMs = 600000;
constexpr uint8_t kActiveBrightness = 120;
constexpr uint8_t kDimBrightness = 24;
constexpr uint32_t kCompletionChimeSampleRate = 12000;
constexpr uint32_t kCompletionChimeDurationMs = 270;
constexpr size_t kCompletionChimeSamples =
    kCompletionChimeSampleRate * kCompletionChimeDurationMs / 1000;
constexpr float kPi = 3.14159265358979323846f;

constexpr char kLeftMicSwitch[] = "ACT10";
// ChatGPT 26.727 exposes one combined Mic key but no independent ACT10/ACT11
// switch setting. Use the fourth configurable Command Key for Voice Chat.
constexpr char kVoiceChatCommandKey[] = "ACT09";
constexpr char kSendKey[] = "ACT12";
const char* kAgentKeys[] = {"AG00", "AG01", "AG02", "AG03", "AG04", "AG05"};

CodexMicroBle codex;
CodexMicroState state;
M5Canvas canvas(&M5.Display);
uint32_t lastDrawMs = 0;
uint32_t lastBatteryMs = 0;
bool leftPressed = false;
bool rightPressed = false;
bool touchAgentPressed = false;
bool touchSendPressed = false;
bool touchTracking = false;
bool voiceTapBannerVisible = false;
bool voiceClickReleasePending = false;
int8_t activeTouchAgent = -1;
int16_t touchStartX = 0;
int16_t touchStartY = 0;
touch_gesture::Direction activeSwipe = touch_gesture::Direction::None;
uint32_t voiceTapBannerUntilMs = 0;
uint32_t voiceClickReleaseAtMs = 0;
uint32_t rightPressedAtMs = 0;
std::array<dashboard::AgentStatus, 6> previousAgentStatuses = {};
std::array<bool, 6> agentStatusObserved = {};
int8_t completedAgent = -1;
uint32_t completionBannerUntilMs = 0;
std::array<int16_t, kCompletionChimeSamples> completionChimePcm = {};
bool hapticActive = false;
uint32_t hapticUntilMs = 0;
uint32_t lastActivityMs = 0;
uint8_t appliedBrightness = kActiveBrightness;

void drawScreen();

float softNoteEnvelope(float noteTime, float noteDuration) {
  constexpr float kAttackSeconds = 0.022f;
  constexpr float kReleaseSeconds = 0.075f;
  if (noteTime < 0.0f || noteTime >= noteDuration) return 0.0f;

  float envelope = 1.0f;
  if (noteTime < kAttackSeconds) {
    const float phase = noteTime / kAttackSeconds;
    const float fade = sinf(phase * kPi * 0.5f);
    envelope *= fade * fade;
  }
  const float releaseStart = noteDuration - kReleaseSeconds;
  if (noteTime > releaseStart) {
    const float phase = (noteTime - releaseStart) / kReleaseSeconds;
    const float fade = cosf(phase * kPi * 0.5f);
    envelope *= fade * fade;
  }
  return envelope;
}

void buildCompletionChime() {
  // A quiet C5 -> E5 major third with rounded attacks and long releases.
  // Keeping this as one PCM buffer avoids the hard edge between two tone() calls.
  constexpr float kFirstFrequency = 523.25f;
  constexpr float kSecondFrequency = 659.25f;
  constexpr float kFirstStart = 0.0f;
  constexpr float kFirstDuration = 0.120f;
  constexpr float kSecondStart = 0.115f;
  constexpr float kSecondDuration = 0.155f;
  constexpr float kPeakAmplitude = 0.145f * 32767.0f;

  for (size_t sample = 0; sample < completionChimePcm.size(); ++sample) {
    const float time = static_cast<float>(sample) / kCompletionChimeSampleRate;
    const float firstTime = time - kFirstStart;
    const float secondTime = time - kSecondStart;
    const float first =
        sinf(2.0f * kPi * kFirstFrequency * firstTime) *
        softNoteEnvelope(firstTime, kFirstDuration);
    const float second =
        sinf(2.0f * kPi * kSecondFrequency * secondTime) *
        softNoteEnvelope(secondTime, kSecondDuration);
    completionChimePcm[sample] =
        static_cast<int16_t>(kPeakAmplitude * (first + second));
  }
}

void startHaptic(uint8_t intensity, uint32_t durationMs) {
  M5.Power.setVibration(intensity);
  hapticActive = true;
  hapticUntilMs = millis() + durationMs;
}

void stopHaptic() {
  M5.Power.setVibration(0);
  hapticActive = false;
}

void updateHaptic() {
  if (!hapticActive || static_cast<int32_t>(millis() - hapticUntilMs) < 0) return;
  stopHaptic();
}

// Returns false when the screen was fully off, so the waking tap can be
// swallowed instead of acting on a control the user could not see.
bool noteActivity() {
  lastActivityMs = millis();
  if (appliedBrightness == kActiveBrightness) return true;
  const bool wasOff = appliedBrightness == 0;
  appliedBrightness = kActiveBrightness;
  M5.Display.setBrightness(kActiveBrightness);
  if (wasOff) drawScreen();  // redraws were paused while the panel was dark
  return !wasOff;
}

void updateIdleDimming() {
  // A held mic button or an ongoing touch counts as continuous use.
  if (leftPressed || rightPressed || touchTracking) lastActivityMs = millis();
  const uint32_t idleMs = millis() - lastActivityMs;
  // ponytail: two fixed steps via setBrightness; move to Display.sleep() if
  // measured battery drain still matters with the panel at zero.
  const uint8_t target = idleMs >= kScreenOffAfterMs ? 0
                         : idleMs >= kDimAfterMs     ? kDimBrightness
                                                     : kActiveBrightness;
  if (target != appliedBrightness) {
    appliedBrightness = target;
    M5.Display.setBrightness(target);
  }
}

void updateVoiceTapBanner() {
  if (!voiceTapBannerVisible ||
      static_cast<int32_t>(millis() - voiceTapBannerUntilMs) < 0) {
    return;
  }
  voiceTapBannerVisible = false;
  drawScreen();
}

void beginVoiceChatClick() {
  if (voiceClickReleasePending) {
    codex.sendKey(kVoiceChatCommandKey, 0);
  }
  codex.sendKey(kVoiceChatCommandKey, 1);
  voiceClickReleasePending = true;
  voiceClickReleaseAtMs = millis() + kVoiceClickPulseMs;
}

void updateVoiceChatClick() {
  if (!voiceClickReleasePending ||
      static_cast<int32_t>(millis() - voiceClickReleaseAtMs) < 0) {
    return;
  }
  codex.sendKey(kVoiceChatCommandKey, 0);
  voiceClickReleasePending = false;
}

dashboard::ThreadVisual threadVisual(const ThreadLight& light) {
  dashboard::ThreadVisual visual;
  visual.color = light.color;
  visual.brightness = light.brightness;
  visual.breathing = light.effect == "breath";
  return visual;
}

dashboard::AgentStatus classifyAgent(const ThreadLight& light) {
  return dashboard::classify(threadVisual(light));
}

uint32_t quotaResetRemaining() {
  if (!state.quota.available) return 0;
  const uint32_t elapsed = (millis() - state.quota.receivedAtMs) / 1000;
  return elapsed >= state.quota.resetInSeconds ? 0 : state.quota.resetInSeconds - elapsed;
}

dashboard::State dashboardState() {
  dashboard::State ui;
  ui.connected = state.connected;
  ui.quotaAvailable = state.quota.available;
  ui.quotaStale = state.quota.available &&
                  millis() - state.quota.receivedAtMs > kQuotaStaleAfterMs;
  ui.remainingPercent = state.quota.remainingPercent;
  ui.resetInSeconds = quotaResetRemaining();
  ui.leftPressed = leftPressed;
  ui.rightPressed = rightPressed || voiceTapBannerVisible;
  ui.sendPressed = touchSendPressed;
  ui.activeTouchAgent = touchAgentPressed ? activeTouchAgent : -1;
  ui.swipeDirection = static_cast<int>(activeSwipe);
  ui.completedAgent =
      completedAgent >= 0 &&
              static_cast<int32_t>(completionBannerUntilMs - millis()) > 0
          ? completedAgent
          : -1;
  for (int i = 0; i < 6; ++i) ui.threads[i] = threadVisual(state.threads[i]);
  return ui;
}

void drawScreen() {
  dashboard::render(canvas, dashboardState(), millis());
  canvas.pushSprite(0, 0);
  lastDrawMs = millis();
}

int8_t agentAtPoint(int x, int y) {
  return static_cast<int8_t>(dashboard::agentAtPoint(x, y));
}

void beginTouchAgent(int8_t agent) {
  if (agent < 0 || agent >= 6) return;
  touchAgentPressed = true;
  activeTouchAgent = agent;
  drawScreen();
}

void commitTouchAgent() {
  if (!touchAgentPressed || activeTouchAgent < 0) return;
  const int8_t agent = activeTouchAgent;
  startHaptic(kTouchHapticIntensity, kTouchHapticDurationMs);
  codex.sendKey(kAgentKeys[agent], 1, agent);
  delay(kTouchKeyPulseMs);
  codex.sendKey(kAgentKeys[agent], 0, agent);
  // Stop here for a deterministic pulse; leaving it to the loop-end check
  // stretched the buzz by however long the next full redraw took.
  stopHaptic();
  touchAgentPressed = false;
  activeTouchAgent = -1;
  drawScreen();
}

void beginTouchSend() {
  if (touchSendPressed) return;
  touchSendPressed = true;
  drawScreen();
}

void commitTouchSend() {
  if (!touchSendPressed) return;
  startHaptic(kTouchHapticIntensity, kTouchHapticDurationMs);
  codex.sendKey(kSendKey, 1);
  delay(kTouchKeyPulseMs);
  codex.sendKey(kSendKey, 0);
  stopHaptic();
  touchSendPressed = false;
  drawScreen();
}

void clearTouchCandidate() {
  touchAgentPressed = false;
  touchSendPressed = false;
  activeTouchAgent = -1;
}

void beginTouchGesture(int x, int y) {
  touchTracking = true;
  touchStartX = static_cast<int16_t>(x);
  touchStartY = static_cast<int16_t>(y);
  activeSwipe = touch_gesture::Direction::None;

  const int8_t agent = agentAtPoint(x, y);
  Serial.printf("TOUCH begin x=%d y=%d agent=%d send=%d\n", x, y, agent,
                dashboard::sendAtPoint(x, y) ? 1 : 0);
  if (agent >= 0) {
    beginTouchAgent(agent);
  } else if (dashboard::sendAtPoint(x, y)) {
    beginTouchSend();
  }
}

void updateTouchGesture(int x, int y) {
  if (!touchTracking || activeSwipe != touch_gesture::Direction::None) return;
  const touch_gesture::Direction direction = touch_gesture::classifySwipe(
      x - touchStartX, y - touchStartY, kSwipeThresholdPx);
  if (direction == touch_gesture::Direction::None) return;

  clearTouchCandidate();
  activeSwipe = direction;
  const float angle = touch_gesture::normalizedAngle(direction);
  codex.sendJoystick(angle, 1.0f);
  startHaptic(kSwipeHapticIntensity, kSwipeHapticDurationMs);
  Serial.printf("SWIPE direction=%s angle=%.2f action=press\n",
                touch_gesture::name(direction), angle);
  drawScreen();
}

void finishTouchGesture() {
  if (!touchTracking) return;
  touchTracking = false;

  if (activeSwipe != touch_gesture::Direction::None) {
    const touch_gesture::Direction direction = activeSwipe;
    const float angle = touch_gesture::normalizedAngle(direction);
    codex.sendJoystick(angle, 0.0f);
    Serial.printf("SWIPE direction=%s angle=%.2f action=release\n",
                  touch_gesture::name(direction), angle);
    activeSwipe = touch_gesture::Direction::None;
    clearTouchCandidate();
    drawScreen();
    return;
  }

  if (touchAgentPressed) {
    commitTouchAgent();
  } else if (touchSendPressed) {
    commitTouchSend();
  } else {
    clearTouchCandidate();
  }
}

void startCompletionChime(int8_t agent) {
  noteActivity();  // a finished agent is worth lighting the screen for
  completedAgent = agent;
  completionBannerUntilMs = millis() + kCompletionBannerMs;
  M5.Speaker.playRaw(completionChimePcm.data(), completionChimePcm.size(),
                     kCompletionChimeSampleRate, false, 1, -1, true);
  Serial.printf("Agent %d completed; soft chime played\n", agent + 1);
}

void detectAgentTransitions(const CodexMicroState& latest) {
  for (int i = 0; i < 6; ++i) {
    const dashboard::AgentStatus next = classifyAgent(latest.threads[i]);
    if (agentStatusObserved[i] &&
        previousAgentStatuses[i] != dashboard::AgentStatus::Complete &&
        next == dashboard::AgentStatus::Complete) {
      startCompletionChime(static_cast<int8_t>(i));
    }
    // Requires-input also wakes the screen; routine status refreshes must not,
    // or host polling would keep the panel lit around the clock.
    if (agentStatusObserved[i] && previousAgentStatuses[i] != next &&
        next == dashboard::AgentStatus::RequiresInput) {
      noteActivity();
    }
    previousAgentStatuses[i] = next;
    agentStatusObserved[i] = true;
  }
}

void updateBattery() {
  if (lastBatteryMs != 0 && millis() - lastBatteryMs < 30000) return;
  lastBatteryMs = millis();
  const int level = M5.Power.getBatteryLevel();
  const bool charging = M5.Power.isCharging();
  codex.setBattery(level < 0 ? 100 : static_cast<uint8_t>(level), charging);
}

void pressMicSwitch(const char* key, bool& pressed) {
  if (pressed) return;
  pressed = true;
  startHaptic(kButtonHapticIntensity, kButtonHapticDurationMs);
  codex.sendKey(key, 1);
  drawScreen();
}

void releaseMicSwitch(const char* key, bool& pressed) {
  if (!pressed) return;
  pressed = false;
  codex.sendKey(key, 0);
  drawScreen();
}

bool needsAnimatedRedraw() {
  for (const ThreadLight& light : state.threads) {
    if (light.effect == "breath") return true;
  }
  return false;
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("Codex Micro StopWatch port boot");

  auto config = M5.config();
  config.clear_display = true;
  M5.begin(config);
  M5.Display.setRotation(0);
  M5.Display.setBrightness(kActiveBrightness);
  M5.Display.setTextWrap(false);
  M5.Speaker.setVolume(180);
  buildCompletionChime();

  canvas.setColorDepth(16);
  canvas.setPsram(true);
  if (canvas.createSprite(M5.Display.width(), M5.Display.height()) == nullptr) {
    M5.Display.fillScreen(TFT_BLACK);
    M5.Display.setTextColor(TFT_RED);
    M5.Display.setTextDatum(middle_center);
    M5.Display.drawString("Canvas allocation failed", M5.Display.width() / 2,
                          M5.Display.height() / 2);
    Serial.println("Canvas allocation failed");
    while (true) delay(1000);
  }
  canvas.setTextWrap(false);

  codex.begin();
  state = codex.snapshot();
  updateBattery();
  drawScreen();
  lastActivityMs = millis();
  Serial.println("CODEX_MICRO_STOPWATCH_READY");
}

void loop() {
  M5.update();
  codex.poll();

  const auto touch = M5.Touch.getDetail();
  // Serial captures proved the CST816S reports full-resolution framebuffer
  // coordinates despite the library's x_max=233 config claiming otherwise.
  const int touchX = touch.x;
  const int touchY = touch.y;
  if (touch.wasPressed()) {
    if (noteActivity()) {
      beginTouchGesture(touchX, touchY);
    } else {
      // The swallowed wake tap still answers with a short tick, so haptics
      // never read as randomly dead after the screen slept.
      startHaptic(kButtonHapticIntensity, kWakeHapticDurationMs);
    }
  }
  if (touchTracking && touch.isPressed()) {
    updateTouchGesture(touchX, touchY);
  }
  if (touch.wasReleased()) {
    finishTouchGesture();
  }

  // Physical validation on the C152 enclosure: BtnA/GPIO2 is the left key and
  // BtnB/GPIO1 is the right key.
  if (M5.BtnA.wasPressed()) {
    noteActivity();  // physical keys act even from a dark screen
    Serial.printf("BUTTON physical=left key=%s action=press\n", kLeftMicSwitch);
    pressMicSwitch(kLeftMicSwitch, leftPressed);
  }
  if (M5.BtnA.wasReleased()) {
    Serial.printf("BUTTON physical=left key=%s action=release\n", kLeftMicSwitch);
    releaseMicSwitch(kLeftMicSwitch, leftPressed);
  }
  if (M5.BtnB.wasPressed()) {
    noteActivity();
    rightPressedAtMs = millis();
    rightPressed = true;
    voiceTapBannerVisible = true;
    voiceTapBannerUntilMs = millis() + kVoiceTapBannerMs;
    startHaptic(kButtonHapticIntensity, kButtonHapticDurationMs);
    drawScreen();
  }
  if (M5.BtnB.wasReleased()) {
    const uint32_t heldMs = millis() - rightPressedAtMs;
    rightPressed = false;
    beginVoiceChatClick();
    Serial.printf("BUTTON physical=right key=%s physical_hold=%lums click_pulse=%lums\n",
                  kVoiceChatCommandKey, static_cast<unsigned long>(heldMs),
                  static_cast<unsigned long>(kVoiceClickPulseMs));
    drawScreen();
  }

  CodexMicroState latest = codex.snapshot();
  const bool shouldRedraw = latest.dirty;
  if (shouldRedraw) {
    detectAgentTransitions(latest);
  }
  state = latest;
  if (shouldRedraw) {
    drawScreen();
  }

  if (appliedBrightness > 0 &&
      ((needsAnimatedRedraw() && millis() - lastDrawMs > 80) ||
       (state.quota.available && millis() - lastDrawMs > 30000))) {
    drawScreen();
  }

  updateBattery();
  updateIdleDimming();
  updateHaptic();
  updateVoiceTapBanner();
  updateVoiceChatClick();
  delay(8);
}
