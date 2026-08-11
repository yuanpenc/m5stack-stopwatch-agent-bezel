#!/usr/bin/env swift

import AVFoundation
import CoreMedia
import Darwin
import Foundation

private let helpText = """
Capture one macOS audio input to a private PCM WAV file.

Usage:
  swift usb_mic_capture.swift --device <exact-product-name> --output <absolute-temp.wav> [--seconds <n>]
  swift usb_mic_capture.swift --list-inputs
  swift usb_mic_capture.swift --help

Options:
  --device NAME    Exact, case-sensitive audio product name.
  --output PATH    Caller-supplied absolute .wav path. The file must not exist.
  --seconds N      Capture duration in seconds (0.25 through 120; default: 10).
  --list-inputs    Print available audio product names without persistent IDs.
  -h, --help       Show this help.

The output is created mode 0600. No device ID, path, or audio is printed.
Use a temporary location outside the repository and remove it after validation.
"""

private let finishTimeout: DispatchTimeInterval = .seconds(10)
private let stagingDirectoryEnvironmentKey = "USB_MIC_CAPTURE_STAGING_DIRECTORY"
private let publicDeviceName = "Codex StopWatch Mic"
private let legacyDeviceNames = ["Codex Micro StopWatch Mic", "TinyUSB UAC1"]

private enum CaptureFailure: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case let .message(message):
            return message
        }
    }
}

private struct Configuration {
    let deviceName: String
    let outputURL: URL
    let seconds: TimeInterval
}

private struct CaptureSummary {
    let frames: Int64
    let sampleRate: Double
    let channels: UInt32
}

private struct StagingLocation {
    let fileURL: URL
    let ownedDirectoryURL: URL?
}

private func writeStderr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

private func audioDevices() -> [AVCaptureDevice] {
    if #available(macOS 14.0, *) {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    let legacyMicrophone = AVCaptureDevice.DeviceType(
        rawValue: "AVCaptureDeviceTypeBuiltInMicrophone"
    )
    let legacyExternal = AVCaptureDevice.DeviceType(
        rawValue: "AVCaptureDeviceTypeExternalUnknown"
    )
    return AVCaptureDevice.DiscoverySession(
        deviceTypes: [legacyMicrophone, legacyExternal],
        mediaType: .audio,
        position: .unspecified
    ).devices
}

private func matchingAudioDevices(named requestedName: String) -> [AVCaptureDevice] {
    let devices = audioDevices()
    let exactMatches = devices.filter { $0.localizedName == requestedName }
    if !exactMatches.isEmpty || requestedName != publicDeviceName {
        return exactMatches
    }

    // Accept only the two exact names exposed by older project firmware. A
    // duplicate still fails later instead of selecting an ambiguous input.
    return devices.filter { legacyDeviceNames.contains($0.localizedName) }
}

private func isWithinRepository(_ url: URL) -> Bool {
    let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .resolvingSymlinksInPath()
        .standardizedFileURL
    let candidate = url.resolvingSymlinksInPath().standardizedFileURL
    let repositoryPath = repository.path.hasSuffix("/") ? repository.path : repository.path + "/"
    return candidate.path == repository.path || candidate.path.hasPrefix(repositoryPath)
}

private func stagingLocation(for outputURL: URL) throws -> StagingLocation {
    let parent = outputURL.deletingLastPathComponent()
    let directory: URL
    let ownedDirectory: URL?
    if let configured = ProcessInfo.processInfo.environment[stagingDirectoryEnvironmentKey] {
        directory = URL(fileURLWithPath: configured)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard directory.deletingLastPathComponent() == parent else {
            throw CaptureFailure.message("The private capture staging directory is invalid.")
        }
        ownedDirectory = nil
    } else {
        directory = parent.appendingPathComponent(
            ".usb-mic-capture-\(UUID().uuidString)",
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw CaptureFailure.message("Could not create a private capture staging directory.")
        }
        ownedDirectory = directory
    }

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
          isDirectory.boolValue
    else {
        throw CaptureFailure.message("The private capture staging directory is unavailable.")
    }

    return StagingLocation(
        fileURL: directory.appendingPathComponent("capture.partial.wav", isDirectory: false),
        ownedDirectoryURL: ownedDirectory
    )
}

private func publish(stagingURL: URL, to outputURL: URL) throws {
    guard Darwin.link(stagingURL.path, outputURL.path) == 0 else {
        if errno == EEXIST {
            throw CaptureFailure.message("Refusing to overwrite the output file.")
        }
        throw CaptureFailure.message("The WAV output could not be published safely.")
    }

    guard Darwin.unlink(stagingURL.path) == 0 else {
        throw CaptureFailure.message("The private WAV staging file could not be removed.")
    }
}

private func parseConfiguration(_ arguments: [String]) throws -> Configuration? {
    if arguments.contains("--help") || arguments.contains("-h") {
        print(helpText)
        return nil
    }

    if arguments == ["--list-inputs"] {
        try requireMicrophoneAccess()
        let names = Set(audioDevices().map(\.localizedName)).sorted()
        if names.isEmpty {
            print("No audio inputs are currently available.")
        } else {
            names.forEach { print($0) }
        }
        return nil
    }

    var deviceName: String?
    var outputPath: String?
    var seconds: TimeInterval = 10
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--device", "--output", "--seconds":
            guard index + 1 < arguments.count else {
                throw CaptureFailure.message("Missing value for \(argument). Use --help for usage.")
            }
            let value = arguments[index + 1]
            switch argument {
            case "--device":
                deviceName = value
            case "--output":
                outputPath = value
            default:
                guard let parsed = TimeInterval(value), parsed.isFinite else {
                    throw CaptureFailure.message("--seconds must be a finite number.")
                }
                seconds = parsed
            }
            index += 2
        default:
            throw CaptureFailure.message("Unknown argument: \(argument). Use --help for usage.")
        }
    }

    guard let deviceName, !deviceName.isEmpty else {
        throw CaptureFailure.message("--device is required and must be an exact product name.")
    }
    guard let outputPath, !outputPath.isEmpty else {
        throw CaptureFailure.message("--output is required.")
    }
    guard (0.25 ... 120).contains(seconds) else {
        throw CaptureFailure.message("--seconds must be between 0.25 and 120.")
    }
    guard outputPath.hasPrefix("/") else {
        throw CaptureFailure.message("--output must be an absolute path.")
    }

    let requestedURL = URL(fileURLWithPath: outputPath).standardizedFileURL
    let canonicalParent = requestedURL.deletingLastPathComponent()
        .resolvingSymlinksInPath()
        .standardizedFileURL
    let outputURL = canonicalParent.appendingPathComponent(
        requestedURL.lastPathComponent,
        isDirectory: false
    )
    guard outputURL.pathExtension.lowercased() == "wav" else {
        throw CaptureFailure.message("--output must end in .wav.")
    }
    guard !FileManager.default.fileExists(atPath: outputURL.path) else {
        throw CaptureFailure.message("Refusing to overwrite the output file.")
    }

    var isDirectory: ObjCBool = false
    let parentPath = outputURL.deletingLastPathComponent().path
    guard FileManager.default.fileExists(atPath: parentPath, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw CaptureFailure.message("The output parent directory does not exist.")
    }
    guard !isWithinRepository(outputURL) else {
        throw CaptureFailure.message("The output must be outside the repository.")
    }

    return Configuration(deviceName: deviceName, outputURL: outputURL, seconds: seconds)
}

private func requireMicrophoneAccess() throws {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
        return
    case .denied, .restricted:
        throw CaptureFailure.message(
            "Microphone access is denied. Grant access to the invoking terminal, then retry."
        )
    case .notDetermined:
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        AVCaptureDevice.requestAccess(for: .audio) { allowed in
            granted = allowed
            semaphore.signal()
        }
        semaphore.wait()
        guard granted else {
            throw CaptureFailure.message("Microphone access was not granted.")
        }
    @unknown default:
        throw CaptureFailure.message("Microphone authorization is unavailable.")
    }
}

private final class WaveWriter: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let outputURL: URL
    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var failure: CaptureFailure?
    private var frameCount: Int64 = 0
    private var sampleRate: Double = 0
    private var channels: UInt32 = 0

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard failure == nil else { return }

        if assetWriter == nil {
            do {
                try startWriter(with: sampleBuffer)
            } catch let captureFailure as CaptureFailure {
                failure = captureFailure
                return
            } catch {
                failure = .message("Could not initialize the WAV writer.")
                return
            }
        }

        guard let assetWriter, let writerInput else {
            failure = .message("The WAV writer was not initialized.")
            return
        }
        guard assetWriter.status == .writing else {
            failure = .message("The WAV writer stopped before capture completed.")
            return
        }
        guard writerInput.isReadyForMoreMediaData else {
            failure = .message("The WAV writer could not keep up with realtime audio.")
            return
        }
        guard writerInput.append(sampleBuffer) else {
            failure = .message("A captured audio buffer could not be written.")
            return
        }

        frameCount += Int64(CMSampleBufferGetNumSamples(sampleBuffer))
    }

    private func startWriter(with sampleBuffer: CMSampleBuffer) throws {
        guard
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
            throw CaptureFailure.message("The input did not provide a PCM audio format.")
        }

        let format = streamDescription.pointee
        guard format.mSampleRate > 0, format.mChannelsPerFrame > 0 else {
            throw CaptureFailure.message("The input reported an invalid audio format.")
        }

        sampleRate = format.mSampleRate
        channels = format.mChannelsPerFrame

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(channels),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
        } catch {
            throw CaptureFailure.message("Could not create the WAV output.")
        }

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw CaptureFailure.message("The input audio format cannot be written as PCM WAV.")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw CaptureFailure.message("The PCM WAV writer could not start.")
        }
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

        assetWriter = writer
        writerInput = input
    }

    func finish() throws -> CaptureSummary {
        if let failure {
            throw failure
        }
        guard frameCount > 0, let assetWriter, let writerInput else {
            throw CaptureFailure.message("No audio frames were captured.")
        }

        writerInput.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        assetWriter.finishWriting {
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + finishTimeout) == .success else {
            assetWriter.cancelWriting()
            throw CaptureFailure.message("Timed out while finalizing the WAV output.")
        }

        guard assetWriter.status == .completed else {
            throw CaptureFailure.message("The WAV output could not be finalized.")
        }
        return CaptureSummary(frames: frameCount, sampleRate: sampleRate, channels: channels)
    }
}

private func capture(_ configuration: Configuration) throws -> CaptureSummary {
    // macOS 26 can return an empty discovery session until the invoking process
    // has audio-capture permission, so authorization must precede exact-name
    // device matching.
    try requireMicrophoneAccess()

    let matches = matchingAudioDevices(named: configuration.deviceName)
    guard matches.count == 1, let device = matches.first else {
        if matches.isEmpty {
            throw CaptureFailure.message("No audio input exactly matched --device. Use --list-inputs to inspect names.")
        }
        throw CaptureFailure.message("More than one audio input has that product name; exact-name selection is ambiguous.")
    }

    let input: AVCaptureDeviceInput
    do {
        input = try AVCaptureDeviceInput(device: device)
    } catch {
        throw CaptureFailure.message("The selected audio input could not be opened.")
    }

    let session = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    let writer = WaveWriter(outputURL: configuration.outputURL)
    let writerQueue = DispatchQueue(label: "usb-mic-wave-writer")
    audioOutput.setSampleBufferDelegate(writer, queue: writerQueue)

    session.beginConfiguration()
    guard session.canAddInput(input) else {
        session.commitConfiguration()
        throw CaptureFailure.message("The selected audio input cannot be added to a capture session.")
    }
    session.addInput(input)
    guard session.canAddOutput(audioOutput) else {
        session.commitConfiguration()
        throw CaptureFailure.message("An audio data output cannot be added to the capture session.")
    }
    session.addOutput(audioOutput)
    session.commitConfiguration()

    session.startRunning()
    guard session.isRunning else {
        throw CaptureFailure.message("The audio capture session did not start.")
    }

    Thread.sleep(forTimeInterval: configuration.seconds)
    session.stopRunning()

    return try writerQueue.sync {
        try writer.finish()
    }
}

umask(S_IRWXG | S_IRWXO)

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let configuration = try parseConfiguration(arguments) else {
        exit(EXIT_SUCCESS)
    }

    let staging = try stagingLocation(for: configuration.outputURL)
    let stagingURL = staging.fileURL
    defer {
        try? FileManager.default.removeItem(at: stagingURL)
        if let ownedDirectoryURL = staging.ownedDirectoryURL {
            try? FileManager.default.removeItem(at: ownedDirectoryURL)
        }
    }

    let stagingConfiguration = Configuration(
        deviceName: configuration.deviceName,
        outputURL: stagingURL,
        seconds: configuration.seconds
    )
    let summary = try capture(stagingConfiguration)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: stagingURL.path
    )
    try publish(stagingURL: stagingURL, to: configuration.outputURL)

    let capturedSeconds = Double(summary.frames) / summary.sampleRate
    writeStderr(
        String(
            format: "capture_complete frames=%lld seconds=%.3f channels=%u",
            summary.frames,
            capturedSeconds,
            summary.channels
        )
    )
    exit(EXIT_SUCCESS)
} catch let failure as CaptureFailure {
    writeStderr("error: \(failure.description)")
    exit(2)
} catch {
    writeStderr("error: Unexpected capture failure.")
    exit(2)
}
