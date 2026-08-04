# Project boundaries

- Target hardware is M5Stack StopWatch Dev Kit C152 only.
- Treat Codex Micro compatibility as experimental and undocumented.
- Do not claim a build, flash, pairing, button action, or quota update is
  validated until it is observed on physical C152 hardware.
- Never infer an upload port. Resolve and report the exact `/dev/cu.*` target
  immediately before any flash operation.
- Do not flash without a known factory-firmware recovery path.
- Keep OpenAI/ChatGPT authentication and rate-limit reads on the Mac companion.
  Never place account tokens in firmware or BLE payloads.
- Keep the emulated vendor HID path and the private quota GATT path separate.
- Do not imply that this is official OpenAI, Work Louder, or M5Stack hardware.
- Preserve upstream MIT attribution and `NOTICE.md` when redistributing.
- The C152 microphone is intentionally out of scope for the current MVP.
  ACT10/ACT09 only trigger Codex voice controls; ChatGPT Desktop uses the Mac's
  selected microphone. Keep the completed USB/BLE microphone experiments
  isolated from the dashboard firmware unless the user explicitly resumes them.

## Installation workflow for coding agents

- Read `README.md`, this file, and M5Stack's official StopWatch recovery guide
  before changing the machine or the device.
- Confirm the connected target is an M5Stack StopWatch Dev Kit C152. Do not
  build or flash the deferred microphone/audio experiments.
- Begin with read-only checks. Explain any missing dependency before installing
  it, and use the narrowest standard installation method available on the Mac.
- Build the `m5stack-stopwatch` PlatformIO environment before flashing.
- Resolve the exact newly connected `/dev/cu.*` device immediately before an
  upload. Report it to the user and obtain confirmation before flashing.
- After flashing, verify the serial marker
  `CODEX_MICRO_STOPWATCH_READY`, then guide the user through macOS Bluetooth
  pairing and ChatGPT Desktop's Codex Micro settings.
- Build the quota companion from source. Use demo discovery to obtain this
  Mac's CoreBluetooth UUID, require that UUID for real writes, and store it only
  in local ignored output or the user's `~/Library` files.
- Never request an OpenAI API key for this project. Never write credentials,
  account identifiers, prompts, task text, device MAC addresses, CoreBluetooth
  UUIDs, usernames, home-directory paths, or captured audio into tracked files.
- Do not claim success from a build alone. Report build, flash, pairing,
  controls, Agent status, and quota sync as separate validation layers.
