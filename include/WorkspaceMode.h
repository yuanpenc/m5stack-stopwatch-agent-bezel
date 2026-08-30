// SPDX-License-Identifier: MIT
#pragma once

#include <ArduinoJson.h>

#include <cstdint>
#include <cstring>

namespace workspace_mode {

constexpr std::uint32_t kLeaseMs = 15000;

enum class Mode : std::uint8_t { Codex, Super };
enum class Command : std::uint8_t { Invalid, Codex, Super };

inline Command parse(JsonObjectConst params) {
  const JsonVariantConst modeValue = params["mode"];
  if (!modeValue.is<const char*>()) return Command::Invalid;

  const char* mode = modeValue.as<const char*>();
  if (std::strcmp(mode, "codex") == 0) {
    return params.size() == 1 ? Command::Codex : Command::Invalid;
  }
  if (std::strcmp(mode, "super") != 0 || params.size() != 2) {
    return Command::Invalid;
  }

  const JsonVariantConst ttl = params["ttl_ms"];
  if (!ttl.is<JsonInteger>() || ttl.as<JsonInteger>() != kLeaseMs) {
    return Command::Invalid;
  }
  return Command::Super;
}

class Lease {
 public:
  bool apply(Command command, std::uint16_t connectionId,
             std::uint32_t nowMs) {
    if (command == Command::Invalid) return false;
    if (command == Command::Codex) return clear();

    if (mode_ == Mode::Super &&
        (!ownerValid_ || ownerConnectionId_ != connectionId)) {
      return false;
    }

    const bool changed = mode_ != Mode::Super;
    mode_ = Mode::Super;
    ownerConnectionId_ = connectionId;
    ownerValid_ = true;
    refreshedAtMs_ = nowMs;
    return changed;
  }

  bool disconnect(std::uint16_t connectionId) {
    if (!ownerValid_ || ownerConnectionId_ != connectionId) return false;
    return clear();
  }

  bool expire(std::uint32_t nowMs) {
    if (mode_ != Mode::Super ||
        static_cast<std::uint32_t>(nowMs - refreshedAtMs_) < kLeaseMs) {
      return false;
    }
    return clear();
  }

  Mode mode() const { return mode_; }

 private:
  bool clear() {
    const bool changed = mode_ != Mode::Codex;
    mode_ = Mode::Codex;
    ownerConnectionId_ = 0;
    ownerValid_ = false;
    refreshedAtMs_ = 0;
    return changed;
  }

  Mode mode_ = Mode::Codex;
  std::uint16_t ownerConnectionId_ = 0;
  bool ownerValid_ = false;
  std::uint32_t refreshedAtMs_ = 0;
};

}  // namespace workspace_mode
