#!/usr/bin/env python3
"""Privacy-safe USB microphone WAV capture and validation for macOS."""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import wave
from array import array
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence


DEFAULT_TARGET_HZ = 1_000.0
DEFAULT_ZERO_RUN_MS = 20.0
DEFAULT_REPEAT_BLOCK_FRAMES = 480
DEFAULT_JUMP_THRESHOLD = 0.5
DEFAULT_PHASE_WINDOW_MS = 20.0
DEFAULT_PHASE_STEP_RADIANS = 0.25
DEFAULT_FREQUENCY_TOLERANCE_HZ = 5.0
# M5Unified saturates 16-bit microphone output 16 counts inside the nominal
# PCM rails. Treat those values as clipping instead of waiting for -32768 or
# +32767, which this capture path cannot emit.
M5UNIFIED_PCM16_CLIP_MIN = -32_752
M5UNIFIED_PCM16_CLIP_MAX = 32_751
MAX_CAPTURE_SECONDS = 120.0
CAPTURE_TIMEOUT_MARGIN_SECONDS = 30.0
CAPTURE_DURATION_TOLERANCE_SECONDS = 0.1
VALIDATION_FAILED_EXIT = 3


class ValidationError(Exception):
    """A concise, user-actionable validation failure."""


@dataclass(frozen=True)
class WavSamples:
    sample_rate: int
    channels: int
    sample_width_bytes: int
    frame_count: int
    raw_frames: bytes
    mono: array
    zero_frames: bytearray
    sum_squares: float
    peak: float
    clipped_samples: int
    clip_min_integer: int
    clip_max_integer: int
    max_delta: float
    discontinuities: int

    @property
    def scalar_sample_count(self) -> int:
        return self.frame_count * self.channels


def _is_within(path: Path, parent: Path) -> bool:
    current = path if path.exists() else path.parent
    while True:
        try:
            if current.samefile(parent):
                return True
        except OSError:
            pass
        if current == current.parent:
            return False
        current = current.parent


def _validate_output_path(path: Path, *, reject_repository: bool) -> Path:
    if not path.is_absolute():
        raise ValidationError("The output path must be absolute.")
    if path.suffix.lower() != ".wav":
        raise ValidationError("The output path must end in .wav.")

    resolved = path.resolve(strict=False)
    if resolved.exists():
        raise ValidationError("Refusing to overwrite the output file.")
    if not resolved.parent.is_dir():
        raise ValidationError("The output parent directory does not exist.")

    if reject_repository:
        repository = Path(__file__).resolve().parent.parent
        if _is_within(resolved, repository):
            raise ValidationError(
                "Recordings must use a temporary path outside the repository."
            )
    return resolved


def _decode_scalar(raw: bytes, offset: int, width: int) -> tuple[int, int]:
    if width == 1:
        value = raw[offset] - 128
        return value, 128
    if width == 2:
        value = int.from_bytes(raw[offset : offset + 2], "little", signed=True)
        return value, 32_768
    if width == 3:
        unsigned = int.from_bytes(raw[offset : offset + 3], "little", signed=False)
        value = unsigned - (1 << 24) if unsigned & (1 << 23) else unsigned
        return value, 1 << 23
    if width == 4:
        value = int.from_bytes(raw[offset : offset + 4], "little", signed=True)
        return value, 1 << 31
    raise ValidationError("Only 8-, 16-, 24-, and 32-bit PCM WAV files are supported.")


def _clipping_limits(width: int) -> tuple[int, int]:
    if width == 2:
        return M5UNIFIED_PCM16_CLIP_MIN, M5UNIFIED_PCM16_CLIP_MAX
    scale = 128 if width == 1 else 1 << (width * 8 - 1)
    return -scale, scale - 1


def read_wav(path: Path, *, jump_threshold: float) -> WavSamples:
    if not path.is_file():
        raise ValidationError("The WAV input does not exist or is not a regular file.")

    try:
        with wave.open(str(path), "rb") as handle:
            channels = handle.getnchannels()
            sample_rate = handle.getframerate()
            sample_width = handle.getsampwidth()
            frame_count = handle.getnframes()
            compression = handle.getcomptype()
            raw_frames = handle.readframes(frame_count)
    except (EOFError, OSError, wave.Error) as exc:
        raise ValidationError("The input is not a supported PCM WAV file.") from exc

    if compression != "NONE":
        raise ValidationError("Compressed WAV files are not supported.")
    if channels < 1 or sample_rate < 1 or frame_count < 1:
        raise ValidationError("The WAV must contain at least one PCM audio frame.")
    if sample_width not in (1, 2, 3, 4):
        raise ValidationError("Only 8-, 16-, 24-, and 32-bit PCM WAV files are supported.")

    expected_bytes = frame_count * channels * sample_width
    if len(raw_frames) != expected_bytes:
        raise ValidationError("The WAV PCM payload is truncated.")

    mono = array("d")
    zero_frames = bytearray(frame_count)
    previous = [None] * channels
    sum_squares = 0.0
    peak = 0.0
    clipped_samples = 0
    max_delta = 0.0
    discontinuities = 0
    clip_min_integer, clip_max_integer = _clipping_limits(sample_width)
    offset = 0

    for frame_index in range(frame_count):
        frame_sum = 0.0
        frame_is_zero = True
        for channel_index in range(channels):
            integer, scale = _decode_scalar(raw_frames, offset, sample_width)
            offset += sample_width
            normalized = integer / scale
            frame_sum += normalized
            sum_squares += normalized * normalized
            absolute = abs(normalized)
            peak = max(peak, absolute)
            frame_is_zero = frame_is_zero and integer == 0

            if integer <= clip_min_integer or integer >= clip_max_integer:
                clipped_samples += 1

            prior = previous[channel_index]
            if prior is not None:
                delta = abs(normalized - prior)
                max_delta = max(max_delta, delta)
                if delta >= jump_threshold:
                    discontinuities += 1
            previous[channel_index] = normalized

        mono.append(frame_sum / channels)
        zero_frames[frame_index] = int(frame_is_zero)

    return WavSamples(
        sample_rate=sample_rate,
        channels=channels,
        sample_width_bytes=sample_width,
        frame_count=frame_count,
        raw_frames=raw_frames,
        mono=mono,
        zero_frames=zero_frames,
        sum_squares=sum_squares,
        peak=peak,
        clipped_samples=clipped_samples,
        clip_min_integer=clip_min_integer,
        clip_max_integer=clip_max_integer,
        max_delta=max_delta,
        discontinuities=discontinuities,
    )


def _dbfs(value: float) -> float | None:
    if value <= 0:
        return None
    return 20.0 * math.log10(value)


def _round(value: float | None, places: int = 9) -> float | None:
    return None if value is None else round(value, places)


def _zero_run_metrics(samples: WavSamples, minimum_frames: int) -> dict[str, Any]:
    run_count = 0
    max_frames = 0
    current = 0
    for is_zero in samples.zero_frames:
        if is_zero:
            current += 1
            continue
        if current >= minimum_frames:
            run_count += 1
            max_frames = max(max_frames, current)
        current = 0

    if current >= minimum_frames:
        run_count += 1
        max_frames = max(max_frames, current)

    return {
        "minimum_frames": minimum_frames,
        "minimum_seconds": _round(minimum_frames / samples.sample_rate),
        "run_count": run_count,
        "max_run_frames": max_frames,
        "max_run_seconds": _round(max_frames / samples.sample_rate),
    }


def _repeated_block_metrics(samples: WavSamples, block_frames: int) -> dict[str, Any]:
    frame_bytes = samples.channels * samples.sample_width_bytes
    block_count = samples.frame_count // block_frames
    equal_pairs = 0
    longest_run_blocks = 0
    comparison_frames = max(0, samples.frame_count - block_frames)
    raw = memoryview(samples.raw_frames)
    equal_run_start = 0
    equal_run_frames = 0

    def finish_equal_run() -> None:
        nonlocal equal_pairs, longest_run_blocks
        pair_count = equal_run_frames // block_frames
        nonzero_pairs = 0
        for pair_index in range(pair_count):
            start = equal_run_start + pair_index * block_frames
            if not all(samples.zero_frames[start : start + 2 * block_frames]):
                nonzero_pairs += 1
        equal_pairs += nonzero_pairs
        if nonzero_pairs:
            longest_run_blocks = max(longest_run_blocks, nonzero_pairs + 1)

    for frame_index in range(comparison_frames):
        left = frame_index * frame_bytes
        right = (frame_index + block_frames) * frame_bytes
        if raw[left : left + frame_bytes] == raw[right : right + frame_bytes]:
            if equal_run_frames == 0:
                equal_run_start = frame_index
            equal_run_frames += 1
            continue
        if equal_run_frames:
            finish_equal_run()
            equal_run_frames = 0

    if equal_run_frames:
        finish_equal_run()

    return {
        "block_frames": block_frames,
        "block_seconds": _round(block_frames / samples.sample_rate),
        "alignment": "any_frame",
        "full_block_count": block_count,
        "compared_adjacent_pairs": max(0, samples.frame_count - 2 * block_frames + 1),
        "equal_adjacent_pairs_excluding_zero": equal_pairs,
        "longest_equal_run_blocks": longest_run_blocks,
    }


def _positive_crossing_frequency(values: Sequence[float], sample_rate: int) -> tuple[float | None, int]:
    crossings: list[float] = []
    for index in range(1, len(values)):
        previous = values[index - 1]
        current = values[index]
        if previous <= 0 < current and current != previous:
            fraction = -previous / (current - previous)
            crossings.append((index - 1) + fraction)

    if len(crossings) < 3:
        return None, len(crossings)

    periods = [right - left for left, right in zip(crossings, crossings[1:])]
    median_period = statistics.median(periods)
    if median_period <= 0:
        return None, len(crossings)
    return sample_rate / median_period, len(crossings)


def _circular_distance(left: float, right: float) -> float:
    difference = right - left
    return abs(math.atan2(math.sin(difference), math.cos(difference)))


def _tone_metrics(
    samples: WavSamples,
    *,
    target_hz: float,
    phase_window_ms: float,
    phase_step_threshold: float,
    frequency_tolerance_hz: float,
) -> dict[str, Any]:
    estimated_hz, crossing_count = _positive_crossing_frequency(samples.mono, samples.sample_rate)
    window_frames = max(8, round(samples.sample_rate * phase_window_ms / 1_000.0))
    frequency_error = None if estimated_hz is None else estimated_hz - target_hz
    frequency_in_tolerance = (
        frequency_error is not None and abs(frequency_error) <= frequency_tolerance_hz
    )
    phase_reference_hz = estimated_hz if estimated_hz is not None else target_hz
    angular_step = 2.0 * math.pi * phase_reference_hz / samples.sample_rate
    phases: list[float] = []

    for start in range(0, samples.frame_count - window_frames + 1, window_frames):
        window = samples.mono[start : start + window_frames]
        window_rms = math.sqrt(sum(value * value for value in window) / window_frames)
        if window_rms < 0.01:
            continue

        real = 0.0
        imaginary = 0.0
        angle = angular_step * start
        cosine = math.cos(angle)
        sine = math.sin(angle)
        cosine_step = math.cos(angular_step)
        sine_step = math.sin(angular_step)

        for value in window:
            real += value * cosine
            imaginary -= value * sine
            next_cosine = cosine * cosine_step - sine * sine_step
            sine = sine * cosine_step + cosine * sine_step
            cosine = next_cosine
        phases.append(math.atan2(imaginary, real))

    phase_steps = [_circular_distance(left, right) for left, right in zip(phases, phases[1:])]
    phase_break_count = sum(step >= phase_step_threshold for step in phase_steps)
    max_phase_step = max(phase_steps, default=None)
    enough_phase_windows = len(phases) >= 2
    phase_continuous = enough_phase_windows and phase_break_count == 0

    return {
        "target_frequency_hz": target_hz,
        "estimated_frequency_hz": _round(estimated_hz, 6),
        "frequency_error_hz": _round(frequency_error, 6),
        "frequency_tolerance_hz": frequency_tolerance_hz,
        "frequency_in_tolerance": frequency_in_tolerance,
        "phase_reference_frequency_hz": _round(phase_reference_hz, 6),
        "positive_crossing_count": crossing_count,
        "phase_window_frames": window_frames,
        "phase_window_seconds": _round(window_frames / samples.sample_rate),
        "active_phase_windows": len(phases),
        "phase_step_threshold_radians": phase_step_threshold,
        "max_phase_step_radians": _round(max_phase_step),
        "phase_break_count": phase_break_count,
        "phase_continuous": phase_continuous,
        "passed": frequency_in_tolerance and phase_continuous,
    }


def analyze_wav(
    path: Path,
    *,
    zero_run_ms: float = DEFAULT_ZERO_RUN_MS,
    repeat_block_frames: int = DEFAULT_REPEAT_BLOCK_FRAMES,
    jump_threshold: float = DEFAULT_JUMP_THRESHOLD,
    synthetic_1khz: bool = False,
    target_hz: float = DEFAULT_TARGET_HZ,
    phase_window_ms: float = DEFAULT_PHASE_WINDOW_MS,
    phase_step_threshold: float = DEFAULT_PHASE_STEP_RADIANS,
    frequency_tolerance_hz: float = DEFAULT_FREQUENCY_TOLERANCE_HZ,
) -> dict[str, Any]:
    if zero_run_ms <= 0:
        raise ValidationError("--zero-run-ms must be positive.")
    if repeat_block_frames <= 0:
        raise ValidationError("--repeat-block-frames must be positive.")
    if not 0 < jump_threshold <= 2:
        raise ValidationError("--jump-threshold must be greater than 0 and at most 2.")
    if target_hz <= 0 or phase_window_ms <= 0 or phase_step_threshold <= 0:
        raise ValidationError("Synthetic tone thresholds must be positive.")
    if frequency_tolerance_hz <= 0:
        raise ValidationError("--frequency-tolerance-hz must be positive.")

    samples = read_wav(path, jump_threshold=jump_threshold)
    rms = math.sqrt(samples.sum_squares / samples.scalar_sample_count)
    minimum_zero_frames = max(1, math.ceil(samples.sample_rate * zero_run_ms / 1_000.0))

    report: dict[str, Any] = {
        "format": {
            "channels": samples.channels,
            "sample_rate_hz": samples.sample_rate,
            "sample_width_bits": samples.sample_width_bytes * 8,
        },
        "timing": {
            "frame_count": samples.frame_count,
            "sample_count": samples.scalar_sample_count,
            "duration_seconds": _round(samples.frame_count / samples.sample_rate),
        },
        "levels": {
            "rms": _round(rms),
            "rms_dbfs": _round(_dbfs(rms), 6),
            "peak": _round(samples.peak),
            "peak_dbfs": _round(_dbfs(samples.peak), 6),
            "clip_min_integer": samples.clip_min_integer,
            "clip_max_integer": samples.clip_max_integer,
            "clipped_sample_count": samples.clipped_samples,
            "clipped_sample_fraction": _round(
                samples.clipped_samples / samples.scalar_sample_count
            ),
        },
        "zero_runs": _zero_run_metrics(samples, minimum_zero_frames),
        "repeated_adjacent_blocks": _repeated_block_metrics(samples, repeat_block_frames),
        "discontinuities": {
            "absolute_delta_threshold": jump_threshold,
            "count": samples.discontinuities,
            "max_absolute_delta": _round(samples.max_delta),
        },
    }

    if synthetic_1khz:
        report["synthetic_1khz"] = _tone_metrics(
            samples,
            target_hz=target_hz,
            phase_window_ms=phase_window_ms,
            phase_step_threshold=phase_step_threshold,
            frequency_tolerance_hz=frequency_tolerance_hz,
        )
    return report


def _tone_samples(
    *,
    sample_rate: int,
    seconds: float,
    frequency_hz: float,
    amplitude: float,
) -> list[int]:
    frame_count = round(sample_rate * seconds)
    scale = 32_767
    return [
        round(scale * amplitude * math.sin(2.0 * math.pi * frequency_hz * index / sample_rate))
        for index in range(frame_count)
    ]


def _inject_faults(values: list[int], sample_rate: int) -> None:
    if len(values) < 8 * DEFAULT_REPEAT_BLOCK_FRAMES:
        raise ValidationError("The fault-injected fixture must be at least 0.25 seconds.")

    zero_start = len(values) // 8
    zero_length = max(round(sample_rate * 0.05), math.ceil(sample_rate * DEFAULT_ZERO_RUN_MS / 1_000))
    zero_end = min(len(values), zero_start + zero_length)
    values[zero_start:zero_end] = [0] * (zero_end - zero_start)

    source_block = 4
    source_start = source_block * DEFAULT_REPEAT_BLOCK_FRAMES
    source_end = source_start + DEFAULT_REPEAT_BLOCK_FRAMES
    destination_start = source_end
    destination_end = destination_start + DEFAULT_REPEAT_BLOCK_FRAMES
    values[destination_start:destination_end] = values[source_start:source_end]

    jump_index = len(values) // 2
    # Exercise the actual M5Unified saturation rails, not only nominal PCM
    # full scale, so the validator catches clipping produced by this firmware.
    values[jump_index : jump_index + 4] = [
        M5UNIFIED_PCM16_CLIP_MAX,
        M5UNIFIED_PCM16_CLIP_MIN,
        M5UNIFIED_PCM16_CLIP_MAX,
        M5UNIFIED_PCM16_CLIP_MIN,
    ]

    phase_start = (3 * len(values)) // 4
    amplitude = 0.5
    for index in range(phase_start, len(values)):
        values[index] = round(
            32_767
            * amplitude
            * math.sin(
                2.0 * math.pi * DEFAULT_TARGET_HZ * index / sample_rate + math.pi / 2.0
            )
        )


def _write_pcm16_mono(path: Path, values: Sequence[int], sample_rate: int) -> None:
    old_umask = os.umask(0o077)
    try:
        encoded = array("h", values)
        if sys.byteorder != "little":
            encoded.byteswap()
        with wave.open(str(path), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(sample_rate)
            handle.writeframes(encoded.tobytes())
        path.chmod(0o600)
    except Exception:
        try:
            path.unlink()
        except FileNotFoundError:
            pass
        raise
    finally:
        os.umask(old_umask)


def generate_fixture(
    path: Path,
    *,
    profile: str,
    sample_rate: int,
    seconds: float,
) -> None:
    if sample_rate < 8_000 or sample_rate > 192_000:
        raise ValidationError("--sample-rate must be between 8000 and 192000.")
    if seconds < 0.25 or seconds > 10:
        raise ValidationError("--seconds must be between 0.25 and 10 for fixtures.")

    output = _validate_output_path(path, reject_repository=True)
    values = _tone_samples(
        sample_rate=sample_rate,
        seconds=seconds,
        frequency_hz=DEFAULT_TARGET_HZ,
        amplitude=0.5,
    )
    if profile == "fault-injected-1khz":
        _inject_faults(values, sample_rate)

    _write_pcm16_mono(output, values, sample_rate)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(f"Self-test failed: {message}")


def run_self_test() -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="usb-mic-self-test-") as directory:
        root = Path(directory)
        clean = root / "clean.wav"
        faulty = root / "faulty.wav"
        detuned = root / "detuned.wav"
        off_grid_repeat = root / "off-grid-repeat.wav"
        generate_fixture(clean, profile="clean-1khz", sample_rate=48_000, seconds=1.0)
        generate_fixture(faulty, profile="fault-injected-1khz", sample_rate=48_000, seconds=1.0)
        _write_pcm16_mono(
            detuned,
            _tone_samples(
                sample_rate=48_000,
                seconds=1.0,
                frequency_hz=1_003.0,
                amplitude=0.5,
            ),
            48_000,
        )

        state = 1
        nonperiodic: list[int] = []
        for _ in range(4_000):
            state = (1_103_515_245 * state + 12_345) & 0x7FFF_FFFF
            nonperiodic.append((state % 40_001) - 20_000)
        repeat_start = 1_337
        repeat_end = repeat_start + DEFAULT_REPEAT_BLOCK_FRAMES
        nonperiodic[repeat_end : repeat_end + DEFAULT_REPEAT_BLOCK_FRAMES] = nonperiodic[
            repeat_start:repeat_end
        ]
        _write_pcm16_mono(off_grid_repeat, nonperiodic, 48_000)

        _require((clean.stat().st_mode & 0o777) == 0o600, "clean fixture permissions")
        _require((faulty.stat().st_mode & 0o777) == 0o600, "fault fixture permissions")

        clean_report = analyze_wav(clean, synthetic_1khz=True)
        faulty_report = analyze_wav(faulty, synthetic_1khz=True)
        detuned_report = analyze_wav(detuned, synthetic_1khz=True)
        repeat_report = analyze_wav(off_grid_repeat)

        _require(clean_report["timing"]["frame_count"] == 48_000, "clean frame count")
        _require(clean_report["timing"]["sample_count"] == 48_000, "clean sample count")
        _require(clean_report["timing"]["duration_seconds"] == 1.0, "clean duration")
        _require(abs(clean_report["levels"]["rms"] - math.sqrt(0.125)) < 0.0001, "clean RMS")
        _require(0.49 < clean_report["levels"]["peak"] < 0.51, "clean peak")
        _require(clean_report["levels"]["clipped_sample_count"] == 0, "clean clipping")
        _require(
            clean_report["levels"]["clip_min_integer"]
            == M5UNIFIED_PCM16_CLIP_MIN,
            "M5Unified negative clipping rail",
        )
        _require(
            clean_report["levels"]["clip_max_integer"]
            == M5UNIFIED_PCM16_CLIP_MAX,
            "M5Unified positive clipping rail",
        )
        _require(clean_report["zero_runs"]["run_count"] == 0, "clean zero runs")
        _require(clean_report["discontinuities"]["count"] == 0, "clean discontinuities")
        _require(clean_report["synthetic_1khz"]["passed"], "clean 1 kHz continuity")

        _require(faulty_report["levels"]["clipped_sample_count"] >= 4, "fault clipping")
        _require(faulty_report["zero_runs"]["run_count"] >= 1, "fault zero run")
        _require(faulty_report["discontinuities"]["count"] >= 3, "fault discontinuities")
        _require(faulty_report["synthetic_1khz"]["phase_break_count"] >= 1, "fault phase break")
        _require(not faulty_report["synthetic_1khz"]["passed"], "fault tone rejection")
        _require(detuned_report["synthetic_1khz"]["frequency_in_tolerance"], "detuned frequency")
        _require(detuned_report["synthetic_1khz"]["passed"], "detuned phase continuity")
        _require(
            repeat_report["repeated_adjacent_blocks"]["equal_adjacent_pairs_excluding_zero"] >= 1,
            "off-grid repeated block",
        )
        _require(_validation_exit_code(clean_report) == 0, "clean validation exit")
        _require(
            _validation_exit_code(faulty_report) == VALIDATION_FAILED_EXIT,
            "fault validation exit",
        )
        capture_timing_pass = {"timing": {"duration_seconds": 0.95}}
        _add_capture_timing(capture_timing_pass, 1.0)
        _require(_validation_exit_code(capture_timing_pass) == 0, "capture timing pass")
        capture_timing_fail = {"timing": {"duration_seconds": 0.8}}
        _add_capture_timing(capture_timing_fail, 1.0)
        _require(
            _validation_exit_code(capture_timing_fail) == VALIDATION_FAILED_EXIT,
            "capture timing failure exit",
        )

        return {
            "self_test": "passed",
            "fixtures": {
                "clean_1khz": {
                    "frames": clean_report["timing"]["frame_count"],
                    "tone_passed": clean_report["synthetic_1khz"]["passed"],
                },
                "fault_injected_1khz": {
                    "clipped_samples": faulty_report["levels"]["clipped_sample_count"],
                    "zero_runs": faulty_report["zero_runs"]["run_count"],
                    "repeated_block_pairs": faulty_report["repeated_adjacent_blocks"][
                        "equal_adjacent_pairs_excluding_zero"
                    ],
                    "discontinuities": faulty_report["discontinuities"]["count"],
                    "phase_breaks": faulty_report["synthetic_1khz"]["phase_break_count"],
                    "tone_passed": faulty_report["synthetic_1khz"]["passed"],
                },
                "detuned_1khz": {
                    "estimated_hz": detuned_report["synthetic_1khz"][
                        "estimated_frequency_hz"
                    ],
                    "tone_passed": detuned_report["synthetic_1khz"]["passed"],
                },
                "off_grid_repeated_480": {
                    "repeated_block_pairs": repeat_report["repeated_adjacent_blocks"][
                        "equal_adjacent_pairs_excluding_zero"
                    ],
                },
            },
        }


def _add_analysis_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--synthetic-1khz",
        action="store_true",
        help="also validate a synthetic/reference 1 kHz tone's frequency and phase continuity",
    )
    parser.add_argument("--zero-run-ms", type=float, default=DEFAULT_ZERO_RUN_MS)
    parser.add_argument(
        "--repeat-block-frames", type=int, default=DEFAULT_REPEAT_BLOCK_FRAMES
    )
    parser.add_argument("--jump-threshold", type=float, default=DEFAULT_JUMP_THRESHOLD)
    parser.add_argument("--target-hz", type=float, default=DEFAULT_TARGET_HZ)
    parser.add_argument("--phase-window-ms", type=float, default=DEFAULT_PHASE_WINDOW_MS)
    parser.add_argument(
        "--phase-step-radians", type=float, default=DEFAULT_PHASE_STEP_RADIANS
    )
    parser.add_argument(
        "--frequency-tolerance-hz",
        type=float,
        default=DEFAULT_FREQUENCY_TOLERANCE_HZ,
    )


def _analysis_kwargs(arguments: argparse.Namespace) -> dict[str, Any]:
    return {
        "zero_run_ms": arguments.zero_run_ms,
        "repeat_block_frames": arguments.repeat_block_frames,
        "jump_threshold": arguments.jump_threshold,
        "synthetic_1khz": arguments.synthetic_1khz,
        "target_hz": arguments.target_hz,
        "phase_window_ms": arguments.phase_window_ms,
        "phase_step_threshold": arguments.phase_step_radians,
        "frequency_tolerance_hz": arguments.frequency_tolerance_hz,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Capture an exact-name macOS audio input and report privacy-safe PCM WAV metrics. "
            "Reports never include the device name or recording path."
        ),
        epilog=(
            "Example: python3 usb_mic_validate.py record --device 'Exact Product Name' "
            "--output \"$TMPDIR/usb-mic-check.wav\" --seconds 10"
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    record = subparsers.add_parser(
        "record", help="capture to a caller-supplied temporary WAV and analyze it"
    )
    record.add_argument("--device", required=True, help="exact, case-sensitive product name")
    record.add_argument("--output", required=True, type=Path, help="absolute temporary .wav path")
    record.add_argument("--seconds", type=float, default=10.0)
    _add_analysis_options(record)

    analyze = subparsers.add_parser("analyze", help="analyze an existing PCM WAV")
    analyze.add_argument("--input", required=True, type=Path)
    _add_analysis_options(analyze)

    generate = subparsers.add_parser(
        "generate", help="generate a deterministic 1 kHz PCM WAV fixture outside the repository"
    )
    generate.add_argument("--output", required=True, type=Path)
    generate.add_argument(
        "--profile",
        choices=("clean-1khz", "fault-injected-1khz"),
        default="clean-1khz",
    )
    generate.add_argument("--sample-rate", type=int, default=48_000)
    generate.add_argument("--seconds", type=float, default=1.0)

    subparsers.add_parser(
        "self-test", help="generate temporary clean/fault fixtures, validate, then delete them"
    )
    return parser


def _print_report(report: dict[str, Any]) -> None:
    print(json.dumps(report, indent=2, sort_keys=True, allow_nan=False))


def _add_capture_timing(report: dict[str, Any], requested_seconds: float) -> None:
    recorded_seconds = float(report["timing"]["duration_seconds"])
    difference = recorded_seconds - requested_seconds
    report["capture_request"] = {
        "requested_seconds": _round(requested_seconds),
        "recorded_seconds": _round(recorded_seconds),
        "difference_seconds": _round(difference),
        "tolerance_seconds": CAPTURE_DURATION_TOLERANCE_SECONDS,
        "within_tolerance": abs(difference) <= CAPTURE_DURATION_TOLERANCE_SECONDS,
    }


def _validation_exit_code(report: dict[str, Any]) -> int:
    capture_request = report.get("capture_request")
    if capture_request is not None and not capture_request["within_tolerance"]:
        return VALIDATION_FAILED_EXIT
    tone = report.get("synthetic_1khz")
    if tone is not None and not tone["passed"]:
        return VALIDATION_FAILED_EXIT
    return 0


def main(arguments: Iterable[str] | None = None) -> int:
    parser = build_parser()
    parsed = parser.parse_args(arguments)

    try:
        if parsed.command == "self-test":
            _print_report(run_self_test())
            return 0

        if parsed.command == "generate":
            generate_fixture(
                parsed.output,
                profile=parsed.profile,
                sample_rate=parsed.sample_rate,
                seconds=parsed.seconds,
            )
            report = analyze_wav(
                parsed.output,
                synthetic_1khz=True,
            )
            _print_report(report)
            return _validation_exit_code(report)

        if parsed.command == "analyze":
            report = analyze_wav(parsed.input, **_analysis_kwargs(parsed))
            _print_report(report)
            return _validation_exit_code(report)

        if parsed.command == "record":
            if not 0.25 <= parsed.seconds <= MAX_CAPTURE_SECONDS:
                raise ValidationError("--seconds must be between 0.25 and 120.")
            output = _validate_output_path(parsed.output, reject_repository=True)
            swift = shutil.which("swift")
            if swift is None:
                raise ValidationError("Swift is required for macOS capture but was not found.")
            capture_script = Path(__file__).with_name("usb_mic_capture.swift")
            with tempfile.TemporaryDirectory(
                prefix=".usb-mic-capture-", dir=output.parent
            ) as staging_directory, tempfile.TemporaryDirectory(
                prefix="usb-mic-swift-cache-"
            ) as cache:
                environment = os.environ.copy()
                environment["SWIFT_MODULECACHE_PATH"] = cache
                environment["CLANG_MODULE_CACHE_PATH"] = cache
                environment["USB_MIC_CAPTURE_STAGING_DIRECTORY"] = staging_directory
                try:
                    completed = subprocess.run(
                        [
                            swift,
                            str(capture_script),
                            "--device",
                            parsed.device,
                            "--output",
                            str(output),
                            "--seconds",
                            str(parsed.seconds),
                        ],
                        check=False,
                        env=environment,
                        timeout=parsed.seconds + CAPTURE_TIMEOUT_MARGIN_SECONDS,
                    )
                except subprocess.TimeoutExpired as exc:
                    raise ValidationError(
                        "The macOS capture helper exceeded its bounded runtime."
                    ) from exc
            if completed.returncode != 0:
                return completed.returncode
            report = analyze_wav(output, **_analysis_kwargs(parsed))
            _add_capture_timing(report, parsed.seconds)
            _print_report(report)
            return _validation_exit_code(report)

        raise ValidationError("Unknown command.")
    except ValidationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
