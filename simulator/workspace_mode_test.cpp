#include <ArduinoJson.h>

#include <cassert>
#include <cstdint>
#include <limits>

#include "WorkspaceMode.h"

namespace {

workspace_mode::Command parseParams(const char* json) {
  StaticJsonDocument<256> document;
  if (deserializeJson(document, json) ||
      !document.is<JsonObjectConst>()) {
    return workspace_mode::Command::Invalid;
  }
  return workspace_mode::parse(document.as<JsonObjectConst>());
}

void testStrictParsing() {
  using workspace_mode::Command;

  assert(parseParams(R"({"mode":"super","ttl_ms":15000})") ==
         Command::Super);
  assert(parseParams(R"({"mode":"codex"})") == Command::Codex);

  assert(parseParams(R"({})") == Command::Invalid);
  assert(parseParams(R"({"mode":"super"})") == Command::Invalid);
  assert(parseParams(R"({"mode":"codex","ttl_ms":15000})") ==
         Command::Invalid);
  assert(parseParams(
             R"({"mode":"super","ttl_ms":15000,"label":"SUPER"})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":"15000"})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":-1})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":15000.0})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":15000.5})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":4294967296})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":14999})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":42,"ttl_ms":15000})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"SUPER","ttl_ms":15000})") ==
         Command::Invalid);
  assert(parseParams(R"([])") == Command::Invalid);
}

void testOwnershipAndRefresh() {
  using workspace_mode::Command;
  using workspace_mode::Lease;
  using workspace_mode::Mode;

  Lease lease;
  assert(lease.mode() == Mode::Codex);
  assert(!lease.apply(Command::Invalid, 7, 100));

  assert(lease.apply(Command::Super, 7, 100));
  assert(lease.mode() == Mode::Super);

  // The owner can renew without requesting a redraw.
  assert(!lease.apply(Command::Super, 7, 10'000));
  assert(!lease.expire(24'999));

  // Another connection cannot take ownership or refresh the deadline.
  assert(!lease.apply(Command::Super, 8, 24'000));
  assert(lease.expire(25'000));
  assert(lease.mode() == Mode::Codex);

  // Any valid Codex command can fail closed out of SUPER mode.
  assert(lease.apply(Command::Super, 7, 30'000));
  assert(lease.apply(Command::Codex, 8, 30'001));
  assert(lease.mode() == Mode::Codex);
  assert(!lease.apply(Command::Codex, 7, 30'002));

  Lease invalidHeartbeatLease;
  assert(invalidHeartbeatLease.apply(Command::Super, 7, 100));
  assert(!invalidHeartbeatLease.apply(
      parseParams(R"({"mode":"super","ttl_ms":15000,"extra":true})"),
      7, 9'000));
  assert(!invalidHeartbeatLease.expire(15'099));
  assert(invalidHeartbeatLease.expire(15'100));
}

void testDisconnectAndExpiryBoundary() {
  using workspace_mode::Command;
  using workspace_mode::Lease;
  using workspace_mode::Mode;

  Lease lease;
  assert(lease.apply(Command::Super, 11, 1'000));
  assert(!lease.disconnect(12));
  assert(lease.mode() == Mode::Super);
  assert(!lease.expire(15'999));
  assert(lease.expire(16'000));
  assert(lease.mode() == Mode::Codex);

  assert(lease.apply(Command::Super, 11, 20'000));
  assert(lease.disconnect(11));
  assert(lease.mode() == Mode::Codex);
  assert(!lease.disconnect(11));
}

void testMillisRollover() {
  using workspace_mode::Command;
  using workspace_mode::Lease;
  using workspace_mode::Mode;

  constexpr std::uint32_t start =
      std::numeric_limits<std::uint32_t>::max() - 9'999;
  Lease lease;
  assert(lease.apply(Command::Super, 21, start));
  assert(!lease.expire(4'999));
  assert(lease.expire(5'000));
  assert(lease.mode() == Mode::Codex);
}

}  // namespace

int main() {
  testStrictParsing();
  testOwnershipAndRefresh();
  testDisconnectAndExpiryBoundary();
  testMillisRollover();
}
