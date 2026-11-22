import AVFoundation
import Flutter
import UIKit

#if QURAN_ASR_NATIVE && (DEBUG || QURAN_ASR_PROFILE || QURAN_ASR_TESTFLIGHT)
final class QuranASRDiagnostics {
  private let fileURL: URL
  private let maximumBytes: Int
  private let lock = NSLock()
  private var recordingID: UUID?
  private var debugCaptureID: UUID?
  private var retainDebugTranscripts = false
  private var snapshotSequence = 0
  private var completeSlots = Set<Int>()

  private var snapshotRoot: URL {
    fileURL.deletingLastPathComponent()
      .appendingPathComponent("quran-asr-debug", isDirectory: true)
  }

  init(
    fileURL: URL = FileManager.default.temporaryDirectory
      .appendingPathComponent("quran-asr-diagnostics.jsonl"),
    maximumBytes: Int = 768 * 1024
  ) {
    self.fileURL = fileURL
    self.maximumBytes = maximumBytes
  }

  func record(
    _ event: String, metrics: [String: Double] = [:], transcript: String? = nil
  ) {
    lock.lock()
    defer { lock.unlock() }
    do {
      var entry: [String: Any] = [
        "time": Date().timeIntervalSince1970, "event": event, "metrics": metrics
      ]
      if retainDebugTranscripts, recordingID != nil, let transcript {
        entry["transcript"] = transcript
      }
      var line = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
      line.append(10)
      let size: Int
      if FileManager.default.fileExists(atPath: fileURL.path) {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        let previousSize = try handle.seekToEnd()
        try handle.write(contentsOf: line)
        size = Int(previousSize) + line.count
      } else {
        try line.write(to: fileURL, options: .atomic)
        size = line.count
      }
      if size > maximumBytes {
        var data = try Data(contentsOf: fileURL)
        let overflow = data.count - maximumBytes
        if let newline = data[overflow...].firstIndex(of: 10) {
          data.removeSubrange(...newline)
        } else {
          data.removeAll()
        }
        try data.write(to: fileURL, options: .atomic)
      }
    } catch {
      NSLog("Quran ASR diagnostics could not be saved: %@", error.localizedDescription)
    }
  }

  func beginCapture(
    retainDebugAudio: Bool, retainDebugTranscripts: Bool = false
  ) -> UUID? {
    lock.lock()
    defer { lock.unlock() }
    let id = UUID()
    do {
      try Data().write(to: fileURL, options: .atomic)
      recordingID = id
    } catch {
      recordingID = nil
      NSLog("Quran ASR diagnostic log could not be reset: %@", error.localizedDescription)
    }
    debugCaptureID = retainDebugAudio ? recordingID : nil
    self.retainDebugTranscripts = retainDebugTranscripts
    snapshotSequence = 0
    completeSlots.removeAll()
    do {
      try FileManager.default.removeItem(at: snapshotRoot)
    } catch let error as NSError where error.domain == NSCocoaErrorDomain
        && error.code == NSFileNoSuchFileError {
      // No previous snapshots.
    } catch {
      NSLog("Quran ASR debug snapshots could not be removed: %@", error.localizedDescription)
    }
    return debugCaptureID
  }

  func retainSnapshot(
    _ source: URL, report: [String: Any]?, provisional: Bool,
    windowStart: Double, requested: Date, errorCode: Int, captureID: UUID
  ) {
    let savedSlot: Int
    do {
      lock.lock()
      defer { lock.unlock() }
      guard debugCaptureID == captureID else { return }
      let audio = try Data(contentsOf: source)
      guard audio.count <= 960044 else {
        throw NSError(domain: "QuranASRDiagnostics", code: 1)
      }
      let directory = snapshotRoot.appendingPathComponent(captureID.uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let slot = snapshotSequence % 6
      snapshotSequence += 1
      let metadata: [String: Any] = [
        "requested": requested.timeIntervalSince1970,
        "returned": Date().timeIntervalSince1970,
        "preview": provisional, "windowStart": windowStart,
        "errorCode": errorCode, "report": report ?? [:]
      ]
      let json = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
      guard json.count <= 65536 else {
        throw NSError(domain: "QuranASRDiagnostics", code: 2)
      }
      completeSlots.remove(slot)
      try audio.write(
        to: directory.appendingPathComponent("snapshot-\(slot).wav"), options: .atomic
      )
      try json.write(
        to: directory.appendingPathComponent("snapshot-\(slot).json"), options: .atomic
      )
      completeSlots.insert(slot)
      savedSlot = slot
    } catch {
      NSLog("Quran ASR debug snapshot could not be saved: %@", error.localizedDescription)
      record("debug_snapshot_failed")
      return
    }
    record("debug_snapshot_saved", metrics: [
      "slot": Double(savedSlot), "requested": requested.timeIntervalSince1970
    ])
  }

  func exportedFilePaths(includeSnapshots: Bool = true) -> [String] {
    lock.lock()
    defer { lock.unlock() }
    guard recordingID != nil else { return [] }
    return [fileURL.path] + (includeSnapshots ? snapshotPaths() : [])
  }

  func cloudDiagnostics(includeSnapshots: Bool) throws -> [String: Any]? {
    lock.lock()
    defer { lock.unlock() }
    guard let recordingID else { return nil }
    let log = try String(contentsOf: fileURL, encoding: .utf8)
    return [
      "id": recordingID.uuidString.lowercased(),
      "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
      "log": log,
      "snapshotPaths": includeSnapshots ? snapshotPaths() : []
    ]
  }

  private func snapshotPaths() -> [String] {
    guard let debugCaptureID else { return [] }
    var paths: [String] = []
    let fm = FileManager.default
    let directory = snapshotRoot.appendingPathComponent(debugCaptureID.uuidString, isDirectory: true)
    for slot in completeSlots.sorted() {
      let json = directory.appendingPathComponent("snapshot-\(slot).json").path
      let wav = directory.appendingPathComponent("snapshot-\(slot).wav").path
      if fm.fileExists(atPath: json), fm.fileExists(atPath: wav) {
        paths.append(contentsOf: [json, wav])
      }
    }
    return paths
  }
}

// A bounded in-memory PCM snapshot avoids reading a WAV file while its header
// is still being written by a recorder.
final class QuranASRCapture {
  struct Snapshot {
    let wav: Data
    let startSeconds: Double
  }

  private let lock = NSLock()
  private let converter: AVAudioConverter
  private let output: AVAudioFormat
  private var pcm = Data()
  private var captureError: Error?
  private let maximumBytes = 16000 * 2 * 30
  private var capturedSamples: Int64 = 0

  init(format: AVAudioFormat) throws {
    guard format.sampleRate > 0, format.channelCount > 0,
          let output = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16000,
            channels: 1, interleaved: false
          ),
          let converter = AVAudioConverter(from: format, to: output) else {
      throw NSError(domain: "QuranASR", code: 5, userInfo: [
        NSLocalizedDescriptionKey: "Unsupported microphone format."
      ])
    }
    self.output = output
    self.converter = converter
  }

  func append(_ buffer: AVAudioPCMBuffer) {
    lock.lock()
    defer { lock.unlock() }
    guard captureError == nil else { return }
    let capacity = AVAudioFrameCount(
      ceil(Double(buffer.frameLength) * 16000 / buffer.format.sampleRate) + 32
    )
    guard let converted = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else {
      captureError = NSError(domain: "QuranASR", code: 5)
      return
    }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: converted, error: &error) { _, inputStatus in
      if supplied {
        inputStatus.pointee = .noDataNow
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return buffer
    }
    if status == .error {
      captureError = error ?? NSError(domain: "QuranASR", code: 5)
      return
    }
    guard let samples = converted.int16ChannelData else {
      captureError = NSError(domain: "QuranASR", code: 5, userInfo: [
        NSLocalizedDescriptionKey: "Could not read converted microphone samples."
      ])
      return
    }
    let count = Int(converted.frameLength) * 2
    capturedSamples += Int64(converted.frameLength)
    let bytes = UnsafeRawPointer(samples[0]).assumingMemoryBound(to: UInt8.self)
    if count >= maximumBytes {
      pcm = Data(bytes: bytes.advanced(by: count - maximumBytes), count: maximumBytes)
    } else {
      let overflow = max(0, pcm.count + count - maximumBytes)
      if overflow > 0 { pcm.removeFirst(overflow) }
      pcm.append(bytes, count: count)
    }
  }

  var capturedSeconds: Double {
    lock.lock()
    defer { lock.unlock() }
    return Double(capturedSamples) / 16000
  }

  func snapshot(forPreview: Bool = false, recoveryContextSeconds: Int? = nil) throws -> Snapshot? {
    lock.lock()
    defer { lock.unlock() }
    if let captureError { throw captureError }
    if let seconds = recoveryContextSeconds, seconds != 12 && seconds != 28 {
      throw NSError(domain: "QuranASR", code: 5)
    }
    guard !pcm.isEmpty else { return nil }
    // Long hypotheses can omit whole earlier ayahs; live checks use an
    // overlapping short 3s tail (~70-90ms on Metal GPU) while final checks
    // use a 4s tail (~100ms) so inference stays fast from start to finish.
    let tailSeconds = forPreview ? (recoveryContextSeconds ?? 3) : 4
    let audio = pcm.suffix(16000 * 2 * tailSeconds)
    var wav = Data()
    func ascii(_ text: String) { wav.append(contentsOf: text.utf8) }
    func integer<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) }
    }
    ascii("RIFF")
    integer(UInt32(36 + audio.count))
    ascii("WAVEfmt ")
    integer(UInt32(16))
    integer(UInt16(1))
    integer(UInt16(1))
    integer(UInt32(16000))
    integer(UInt32(32000))
    integer(UInt16(2))
    integer(UInt16(16))
    ascii("data")
    integer(UInt32(audio.count))
    wav.append(audio)
    return Snapshot(
      wav: wav,
      startSeconds: Double(capturedSamples - Int64(audio.count / 2)) / 16000
    )
  }
}

final class QuranASRChannel {
  private let diagnostics = QuranASRDiagnostics()
  private let worker = DispatchQueue(label: "quran.asr.inference", qos: .userInitiated)
  private var engine: AVAudioEngine?
  private var capture: QuranASRCapture?
  private var audioURL: URL?
  private var processing = false
  private var previewCancellation: QuranASRCancellation?
  private var starting = false
  private var debugCaptureID: UUID?
  private var generation = 0
  private var previousCategory: AVAudioSession.Category?
  private var previousMode: AVAudioSession.Mode?
  private var previousOptions: AVAudioSession.CategoryOptions?
  private var interruptionObserver: NSObjectProtocol?

  func register(messenger: FlutterBinaryMessenger) {
    let allowedBundles: Set<String> = [
      "com.ebaidllc.tajweedpractice.quranailab",
      "com.ebaidllc.tajweedpractice",
    ]
    guard let bundleId = Bundle.main.bundleIdentifier, allowedBundles.contains(bundleId) else {
      NSLog("Quran ASR registration refused for unexpected bundle identifier.")
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.ebaidllc.tajweed_practice/quran_asr",
      binaryMessenger: messenger
    )
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      guard let self, self.engine != nil || self.starting,
            let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            value == AVAudioSession.InterruptionType.began.rawValue else { return }
      self.generation += 1
      do {
        try self.clearRecording()
        channel.invokeMethod("interrupted", arguments: nil)
      } catch {
        channel.invokeMethod("interrupted", arguments: error.localizedDescription)
      }
    }
    channel.setMethodCallHandler { [self] call, result in
      handle(call, result: result)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "available":
        result(Bundle.main.path(forResource: "quran-tiny", ofType: "bin") != nil)
      case "start":
        let arguments = call.arguments as? [String: Any]
        start(
          result,
          retainDebugAudio: arguments?["retainDebugAudio"] as? Bool == true,
          retainDebugTranscripts: arguments?["retainDebugTranscripts"] as? Bool == true
        )
      case "check":
        check(result)
      case "preview":
        if let arguments = call.arguments {
          guard let fields = arguments as? [String: Any],
                fields.count == 2, fields["recovery"] as? Bool == true,
                let contextSeconds = fields["contextSeconds"] as? Int,
                contextSeconds == 12 || contextSeconds == 28 else {
            result(FlutterError(code: "invalid_preview", message: "Expected explicit 12s or 28s recovery.", details: nil))
            return
          }
          preview(result, recoveryContextSeconds: contextSeconds)
        } else {
          preview(result)
        }
      case "tailPreview":
        guard let fields = call.arguments as? [String: Any], fields.count == 1,
              let after = (fields["afterSeconds"] as? NSNumber)?.doubleValue,
              after.isFinite, after >= 0 else {
          result(FlutterError(code: "invalid_preview", message: "Expected afterSeconds.", details: nil))
          return
        }
        tailPreview(result, afterSeconds: after)
      case "finishCapture":
        diagnostics.record("pause", metrics: ["processing": processing ? 1 : 0])
        previewCancellation?.cancel()
        stopCapture()
        do {
          try restoreSession()
          result(nil)
        } catch {
          result(failure(error))
        }
      case "cancel":
        if capture != nil || audioURL != nil || processing {
          diagnostics.record("cancel")
        }
        generation += 1
        do {
          try clearRecording()
          result(nil)
        } catch {
          result(failure(error))
        }
      case "traceProgress":
        let allowed: Set<String> = [
          "expectedIndex", "rawWords", "visibleWords", "final", "contradiction",
          "generation", "active", "stopping", "schemaVersion", "recordingIndex",
          "cursorIndex", "cursorWords", "displayedBefore", "rawCompleted",
          "rawWordIndex", "rawMismatch", "combinedPrefix", "cursorRawPrefix",
          "cursorTailPrefix"
        ]
        guard let fields = call.arguments as? [String: NSNumber],
              fields.keys.allSatisfy({ allowed.contains($0) }),
              fields.values.allSatisfy({ $0.doubleValue.isFinite && $0.doubleValue >= 0 }) else {
          result(FlutterError(code: "invalid_diagnostics", message: "Expected numeric progress counters.", details: nil))
          return
        }
        diagnostics.record("progress", metrics: fields.mapValues(\.doubleValue))
        result(nil)
      case "tracePreviewReveal":
        let required: Set<String> = [
          "generation", "audioEndSeconds", "newVisibleWords", "visibleWords", "snapshotToRevealMs"
        ]
        guard let fields = call.arguments as? [String: NSNumber],
              Set(fields.keys) == required,
              fields.values.allSatisfy({ $0.doubleValue.isFinite && $0.doubleValue >= 0 }),
              let newVisibleWords = fields["newVisibleWords"]?.doubleValue,
              newVisibleWords > 0 else {
          result(FlutterError(code: "invalid_diagnostics", message: "Expected numeric preview reveal metrics.", details: nil))
          return
        }
        diagnostics.record("preview_reveal", metrics: fields.mapValues(\.doubleValue))
        result(nil)
      case "exportDiagnostics":
        result(diagnostics.exportedFilePaths(includeSnapshots: engine == nil))
      case "exportCloudDiagnostics":
        do {
          result(try diagnostics.cloudDiagnostics(includeSnapshots: engine == nil))
        } catch {
          result(FlutterError(code: "diagnostics_export_failed", message: error.localizedDescription, details: nil))
        }
      case "checkWav":
        guard !processing, !starting, engine == nil, audioURL == nil,
              let bytes = call.arguments as? FlutterStandardTypedData,
              bytes.data.count <= 960044 else {
          result(FlutterError(code: "invalid_audio", message: "Invalid or busy audio input.", details: nil))
          return
        }
        do {
          let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
          try bytes.data.write(to: url, options: .atomic)
          audioURL = url
          check(result)
        } catch {
          result(failure(error))
        }
      default:
        result(FlutterMethodNotImplemented)
    }
  }

  deinit {
    if let interruptionObserver {
      NotificationCenter.default.removeObserver(interruptionObserver)
    }
  }

  private func failure(_ error: Error) -> FlutterError {
    FlutterError(code: "quran_asr_failed", message: error.localizedDescription, details: nil)
  }

  private func start(
    _ result: @escaping FlutterResult,
    retainDebugAudio: Bool,
    retainDebugTranscripts: Bool
  ) {
    guard !processing, !starting, engine == nil, audioURL == nil else {
      result(FlutterError(code: "busy", message: "Recognition is already active.", details: nil))
      return
    }
    guard Bundle.main.path(forResource: "quran-tiny", ofType: "bin") != nil else {
      result(FlutterError(code: "unavailable", message: "Experimental model is not installed.", details: nil))
      return
    }
    starting = true
    let requestGeneration = generation
    AVAudioSession.sharedInstance().requestRecordPermission { [self] allowed in
      DispatchQueue.main.async {
        self.starting = false
        guard requestGeneration == self.generation else {
          result(FlutterError(code: "cancelled", message: "Recording was cancelled.", details: nil))
          return
        }
        guard allowed else {
          result(FlutterError(code: "permission_denied", message: "Microphone permission is required.", details: nil))
          return
        }
        do {
          let session = AVAudioSession.sharedInstance()
          self.previousCategory = session.category
          self.previousMode = session.mode
          self.previousOptions = session.categoryOptions
          try session.setCategory(.record, mode: .measurement)
          var hapticsEnabled = false
          if #available(iOS 13.0, *) {
            do {
              try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
              hapticsEnabled = true
            } catch {
              NSLog("Quran ASR could not enable recording haptics: %@", error.localizedDescription)
            }
          }
          try session.setActive(true)
          let engine = AVAudioEngine()
          let input = engine.inputNode
          let format = input.outputFormat(forBus: 0)
          let capture = try QuranASRCapture(format: format)
          self.engine = engine
          self.capture = capture
          input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            capture.append(buffer)
          }
          engine.prepare()
          try engine.start()
          self.debugCaptureID = self.diagnostics.beginCapture(
            retainDebugAudio: retainDebugAudio,
            retainDebugTranscripts: retainDebugTranscripts
          )
          self.diagnostics.record("capture_started", metrics: ["platform": 1])
          self.diagnostics.record(
            hapticsEnabled ? "recording_haptics_enabled" : "recording_haptics_enable_failed"
          )
          result(nil)
        } catch {
          let original = error
          do { try self.clearRecording() } catch {
            result(self.failure(error))
            return
          }
          result(self.failure(original))
        }
      }
    }
  }

  private func restoreSession() throws {
    guard let category = previousCategory, let mode = previousMode,
          let options = previousOptions else { return }
    let session = AVAudioSession.sharedInstance()
    let targetCategory: AVAudioSession.Category = (category == .soloAmbient || category == .ambient || category == .record) ? .playback : category
    try session.setCategory(targetCategory, mode: mode == .measurement ? .default : mode, options: options)
    try session.setActive(true)
    previousCategory = nil
    previousMode = nil
    previousOptions = nil
  }

  private func clearRecording() throws {
    stopCapture()
    capture = nil
    var restoreError: Error?
    do { try restoreSession() } catch { restoreError = error }
    if let url = audioURL {
      try FileManager.default.removeItem(at: url)
      audioURL = nil
    }
    if let restoreError { throw restoreError }
  }

  private func stopCapture() {
    if let engine {
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
      self.engine = nil
    }
  }

  private func preview(_ result: @escaping FlutterResult, recoveryContextSeconds: Int? = nil) {
    guard !processing, !starting, engine != nil, let capture,
          let model = Bundle.main.path(forResource: "quran-tiny", ofType: "bin") else {
      result(FlutterError(code: "busy", message: "No available live recording.", details: nil))
      return
    }
    do {
      guard let snapshot = try capture.snapshot(forPreview: true, recoveryContextSeconds: recoveryContextSeconds), snapshot.wav.count >= 32044 else {
        result(nil)
        return
      }
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
      try snapshot.wav.write(to: url, options: .atomic)
      transcribe(
        url, model: model, provisional: true,
        windowStartSeconds: snapshot.startSeconds,
        debugCaptureID: debugCaptureID, recoveryContextSeconds: recoveryContextSeconds, result: result
      )
    } catch {
      result(failure(error))
    }
  }

  /// Decodes the final 8s after capture stops so trailing words missed by the
  /// last live preview are recognized before the bounded final check.
  private func tailPreview(_ result: @escaping FlutterResult, afterSeconds: Double) {
    guard !processing, !starting, engine == nil, let capture,
          let model = Bundle.main.path(forResource: "quran-tiny", ofType: "bin") else {
      result(FlutterError(code: "busy", message: "No stopped recording.", details: nil))
      return
    }
    guard capture.capturedSeconds - afterSeconds >= 0.25 else {
      result(nil)
      return
    }
    do {
      guard let snapshot = try capture.snapshot(forPreview: true), snapshot.wav.count >= 32044 else {
        result(nil)
        return
      }
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
      try snapshot.wav.write(to: url, options: .atomic)
      transcribe(
        url, model: model, provisional: true,
        windowStartSeconds: snapshot.startSeconds,
        debugCaptureID: debugCaptureID, result: result
      )
    } catch {
      result(failure(error))
    }
  }

  private func check(_ result: @escaping FlutterResult) {
    guard !processing else {
      result(FlutterError(code: "busy", message: "Recognition is already active.", details: nil))
      return
    }
    var windowStartSeconds = 0.0
    let snapshotCaptureID = capture == nil ? nil : debugCaptureID
    do {
      stopCapture()
      if let capture {
        if let snapshot = try capture.snapshot() {
          let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
          try snapshot.wav.write(to: url, options: .atomic)
          windowStartSeconds = snapshot.startSeconds
          audioURL = url
        }
        self.capture = nil
      }
    } catch {
      do { try clearRecording() } catch {
        result(failure(error))
        return
      }
      result(failure(error))
      return
    }
    guard let url = audioURL,
          let model = Bundle.main.path(forResource: "quran-tiny", ofType: "bin") else {
      do { try clearRecording() } catch {
        result(failure(error))
        return
      }
      result(FlutterError(code: "unavailable", message: "Audio or the experimental model is unavailable.", details: nil))
      return
    }
    do { try restoreSession() } catch {
      do { try clearRecording() } catch {
        result(failure(error))
        return
      }
      result(failure(error))
      return
    }
    audioURL = nil
    transcribe(
      url, model: model, provisional: false,
      windowStartSeconds: windowStartSeconds, debugCaptureID: snapshotCaptureID, result: result
    )
  }

  private func transcribe(
    _ url: URL, model: String, provisional: Bool,
    windowStartSeconds: Double, debugCaptureID: UUID?,
    recoveryContextSeconds: Int? = nil,
    result: @escaping FlutterResult
  ) {
    processing = true
    let cancellation = provisional ? QuranASRCancellation() : nil
    previewCancellation = cancellation
    let current = generation
    let requested = Date()
    var requestMetrics: [String: Double] = [
      "preview": provisional ? 1 : 0, "windowStart": windowStartSeconds
    ]
    if let seconds = recoveryContextSeconds {
      requestMetrics["recovery"] = 1
      requestMetrics["contextSeconds"] = Double(seconds)
    }
    diagnostics.record("inference_requested", metrics: requestMetrics)
    worker.async { [self] in
      var error: NSError?
      let report = QuranASRTranscribeCancellable(model, url.path, cancellation, &error)
      if let debugCaptureID {
        diagnostics.retainSnapshot(
          url, report: report as? [String: Any], provisional: provisional,
          windowStart: windowStartSeconds, requested: requested, errorCode: error?.code ?? 0,
          captureID: debugCaptureID
        )
      }
      var cleanupError: Error?
      do { try FileManager.default.removeItem(at: url) } catch { cleanupError = error }
      DispatchQueue.main.async {
        self.processing = false
        self.previewCancellation = nil
        self.diagnostics.record("inference_returned", metrics: [
          "preview": provisional ? 1 : 0,
          "elapsedSeconds": Date().timeIntervalSince(requested),
          "inferenceSeconds": (report?["inferenceSeconds"] as? NSNumber)?.doubleValue ?? 0,
          "durationSeconds": (report?["durationSeconds"] as? NSNumber)?.doubleValue ?? 0,
          "characters": Double((report?["transcript"] as? String)?.count ?? 0),
          "errorCode": Double(error?.code ?? 0),
          "cancelled": current != self.generation ? 1 : 0
        ], transcript: report?["transcript"] as? String)
        if let cleanupError {
          self.audioURL = url
          result(self.failure(cleanupError))
        } else if current != self.generation {
          result(FlutterError(code: "cancelled", message: "Recognition was cancelled.", details: nil))
        } else if provisional && error?.domain == "QuranASR" && error?.code == 5 {
          result(FlutterError(code: "preview_cancelled", message: "Preview was cancelled for final recognition.", details: nil))
        } else if provisional && error?.domain == "QuranASR" && error?.code == 4 {
          result(nil)
        } else if let report {
          var response = report
          response["windowStartSeconds"] = windowStartSeconds
          if provisional {
            response["snapshotRequestedAtUnixMs"] = requested.timeIntervalSince1970 * 1000
          }
          if let seconds = recoveryContextSeconds {
            response["recovery"] = true
            response["contextSeconds"] = seconds
          }
          result(response)
        } else {
          result(self.failure(error ?? NSError(domain: "QuranASR", code: 3)))
        }
      }
    }
  }
}
#endif
