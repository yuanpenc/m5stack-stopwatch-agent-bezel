// SPDX-License-Identifier: MIT
// Copyright (c) 2026 imliubo
// StopWatch port changes copyright (c) 2026 Codex Micro for StopWatch contributors

#pragma once

#include <Arduino.h>
#include <ArduinoJson.h>
#include <BLECharacteristic.h>
#include <BLEHIDDevice.h>
#include <BLEServer.h>
#include <freertos/queue.h>

#include <array>

struct ThreadLight {
  uint32_t color = 0;
  float brightness = 0.0f;
  String effect = "off";
};

struct QuotaState {
  float remainingPercent = 0.0f;
  uint32_t resetInSeconds = 0;
  uint32_t receivedAtMs = 0;
  bool available = false;
};

struct CodexMicroState {
  std::array<ThreadLight, 6> threads;
  QuotaState quota;
  bool connected = false;
  bool dirty = true;
};

class CodexMicroBle {
 public:
  static constexpr uint16_t kVendorId = 0x303A;
  static constexpr uint16_t kProductId = 0x8360;
  static constexpr uint8_t kReportId = 6;

  void begin();
  void poll();
  void setBattery(uint8_t percentage, bool charging);
  void sendKey(const char* key, uint8_t action, int8_t agent = -1);
  void sendJoystick(float angle, float distance);
  bool connected();
  CodexMicroState snapshot();

 private:
  class ServerCallbacks;
  class OutputCallbacks;
  class QuotaCallbacks;

  struct PendingOutputReport {
    uint8_t length = 0;
    std::array<uint8_t, 64> data = {};
  };

  void onConnected(bool connected);
  void onOutput(const uint8_t* data, size_t length);
  void processOutput(const uint8_t* data, size_t length);
  void onQuotaWrite(const uint8_t* data, size_t length);
  void handleRpc(const JsonDocument& request);
  void sendResult(JsonVariantConst id, JsonVariantConst result);
  void sendSuccess(JsonVariantConst id);
  void sendJson(const String& json);
  void updateThreadLighting(JsonArrayConst values);

  BLEHIDDevice* hid_ = nullptr;
  BLECharacteristic* input_ = nullptr;
  SemaphoreHandle_t stateMutex_ = nullptr;
  QueueHandle_t outputQueue_ = nullptr;
  CodexMicroState state_;
  String rpcBuffer_;
  uint8_t batteryPercentage_ = 100;
  bool charging_ = false;
  uint8_t connectionCount_ = 0;
};
