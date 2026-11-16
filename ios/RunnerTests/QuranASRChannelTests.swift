#if QURAN_ASR_NATIVE && DEBUG
import Flutter
import AVFoundation
import XCTest
@testable import Runner

final class QuranASRChannelTests: XCTestCase {
  func testConsentedDebugSnapshotsKeepOnlySixAudioTranscriptPairs() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.wav")
    let diagnostics = QuranASRDiagnostics(fileURL: root.appendingPathComponent("diagnostics.jsonl"))
    for index in 0..<8 {
      try Data(repeating: UInt8(index), count: 100).write(to: source)
      diagnostics.retainSnapshot(
        source, report: ["transcript": "fixture-\(index)"],
        provisional: index < 7, windowStart: Double(index),
        requested: Date(timeIntervalSince1970: Double(index)), errorCode: 0
      )
    }
    let directory = root.appendingPathComponent("quran-asr-debug")
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 12)
    for index in 2..<8 {
      let slot = index % 6
      let audio = try Data(contentsOf: directory.appendingPathComponent("snapshot-\(slot).wav"))
      XCTAssertEqual(audio, Data(repeating: UInt8(index), count: 100))
      let metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
        contentsOf: directory.appendingPathComponent("snapshot-\(slot).json")
      )) as? [String: Any])
      XCTAssertEqual((metadata["report"] as? [String: String])?["transcript"], "fixture-\(index)")
      XCTAssertEqual(metadata["requested"] as? Double, Double(index))
    }
    try Data(repeating: 0, count: 960045).write(to: source)
    diagnostics.retainSnapshot(
      source, report: nil, provisional: true, windowStart: 0,
      requested: Date(), errorCode: 0
    )
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 12)
  }

  func testDiagnosticsRetainBoundedCompleteNumericRecords() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    defer { try? FileManager.default.removeItem(at: url) }
    let diagnostics = QuranASRDiagnostics(fileURL: url, maximumBytes: 1024)
    for index in 0..<100 {
      diagnostics.record("progress", metrics: ["visibleWords": Double(index)])
    }
    let data = try Data(contentsOf: url)
    XCTAssertLessThanOrEqual(data.count, 1024)
    let text = try XCTUnwrap(String(data: data, encoding: .utf8))
    let records = try text.split(separator: "\n").map {
      try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
    }
    XCTAssertGreaterThan(records.count, 1)
    XCTAssertEqual(records.last?["metrics"] as? [String: Double], ["visibleWords": 99])
    XCTAssertEqual(Set(try XCTUnwrap(records.last).keys), ["time", "event", "metrics"])
  }

  func testDiagnosticsRejectTranscriptPayloads() {
    let channel = QuranASRChannel()
    channel.handle(FlutterMethodCall(
      methodName: "traceProgress", arguments: ["transcript": "not permitted"]
    )) { value in
      XCTAssertEqual((value as? FlutterError)?.code, "invalid_diagnostics")
    }
    channel.handle(FlutterMethodCall(
      methodName: "traceProgress", arguments: ["unexpected": 5]
    )) { value in
      XCTAssertEqual((value as? FlutterError)?.code, "invalid_diagnostics")
    }
    channel.handle(FlutterMethodCall(
      methodName: "traceProgress", arguments: [
        "schemaVersion": 2, "recordingIndex": 0, "cursorIndex": 2,
        "cursorWords": 1, "displayedBefore": 9, "rawCompleted": 0,
        "rawWordIndex": 0, "rawMismatch": 1, "combinedPrefix": 10,
        "cursorRawPrefix": 0, "cursorTailPrefix": 2
      ]
    )) { value in
      XCTAssertNil(value)
    }
  }

  func testCaptureConvertsStereoHardwareAudioAndBoundsSnapshots() throws {
    let format = try XCTUnwrap(AVAudioFormat(
      commonFormat: .pcmFormatFloat32, sampleRate: 48000,
      channels: 2, interleaved: false
    ))
    let capture = try QuranASRCapture(format: format)
    XCTAssertNil(try capture.snapshot())
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000))
    buffer.frameLength = 48000
    let samples = try XCTUnwrap(buffer.floatChannelData)
    for channel in 0..<2 {
      for frame in 0..<48000 {
        samples[channel][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / 48000)) * 0.2
      }
    }
    capture.append(buffer)
    let first = try XCTUnwrap(capture.snapshot()).wav
    XCTAssertGreaterThan(first.count, 30000)
    XCTAssertLessThanOrEqual(first.count, 32044)
    XCTAssertEqual(String(data: first.prefix(4), encoding: .ascii), "RIFF")
    XCTAssertEqual(String(data: first[8..<12], encoding: .ascii), "WAVE")
    for _ in 0..<31 { capture.append(buffer) }
    let window = try XCTUnwrap(capture.snapshot())
    let bounded = window.wav
    XCTAssertEqual(bounded.count, 960044)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    try bounded.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let file = try AVAudioFile(forReading: url)
    XCTAssertEqual(file.processingFormat.sampleRate, 16000)
    XCTAssertEqual(file.processingFormat.channelCount, 1)
    XCTAssertEqual(file.length, 480000)
    XCTAssertGreaterThan(window.startSeconds, 1.9)
    XCTAssertLessThan(window.startSeconds, 2.1)
    let preview = try XCTUnwrap(capture.snapshot(forPreview: true))
    XCTAssertEqual(preview.wav.count, 256044)
    XCTAssertEqual(preview.startSeconds - window.startSeconds, 22, accuracy: 0.001)
    XCTAssertEqual(Data(preview.wav.dropFirst(44)), Data(bounded.suffix(256000)))
    XCTAssertEqual(try capture.snapshot()?.wav, bounded)
    for channel in 0..<2 {
      for frame in 0..<48000 { samples[channel][frame] = 0.6 }
    }
    for _ in 0..<60 { capture.append(buffer) }
    let later = try XCTUnwrap(capture.snapshot())
    XCTAssertEqual(later.wav.count, 960044)
    XCTAssertGreaterThan(later.startSeconds, 61.9)
    try later.wav.write(to: url)
    let latestFile = try AVAudioFile(forReading: url)
    let latestBuffer = try XCTUnwrap(AVAudioPCMBuffer(
      pcmFormat: latestFile.processingFormat, frameCapacity: AVAudioFrameCount(latestFile.length)
    ))
    try latestFile.read(into: latestBuffer)
    let latestSamples = try XCTUnwrap(latestBuffer.floatChannelData)
    XCTAssertEqual(latestSamples[0][Int(latestBuffer.frameLength) - 1], 0.6, accuracy: 0.01)
    // The old snapshot remains independently readable after multiple rollovers.
    XCTAssertEqual(String(data: first.prefix(4), encoding: .ascii), "RIFF")
    XCTAssertNotEqual(Data(first.suffix(1000)), Data(later.wav.suffix(1000)))
  }

  private func reference() throws -> FlutterStandardTypedData {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "quran-asr-reference", withExtension: "wav"))
    return FlutterStandardTypedData(bytes: try Data(contentsOf: url))
  }

  func testReferenceResultAndRepeatCheck() throws {
    let channel = QuranASRChannel()
    let audio = try reference()
    for _ in 0..<2 {
      let finished = expectation(description: "Local recognition completes")
      channel.handle(FlutterMethodCall(methodName: "checkWav", arguments: audio)) { value in
        guard let report = value as? [String: Any] else {
          XCTFail("Recognition must return a report, not an error")
          finished.fulfill()
          return
        }
        XCTAssertFalse((report["transcript"] as? String ?? "").isEmpty)
        XCTAssertGreaterThan((report["durationSeconds"] as? Double ?? 0), 0)
        XCTAssertGreaterThan((report["inferenceSeconds"] as? Double ?? 0), 0)
        finished.fulfill()
      }
      wait(for: [finished], timeout: 30)
    }
  }

  func testMalformedInputCleansUpAndAllowsNextAttempt() throws {
    let channel = QuranASRChannel()
    let rejected = expectation(description: "Malformed WAV rejected")
    channel.handle(FlutterMethodCall(
      methodName: "checkWav", arguments: FlutterStandardTypedData(bytes: Data([1, 2, 3]))
    )) { value in
      XCTAssertNotNil(value as? FlutterError)
      rejected.fulfill()
    }
    wait(for: [rejected], timeout: 10)
    let recovered = expectation(description: "Subsequent reference succeeds")
    channel.handle(FlutterMethodCall(methodName: "checkWav", arguments: try reference())) { value in
      XCTAssertNotNil(value as? [String: Any])
      recovered.fulfill()
    }
    wait(for: [recovered], timeout: 30)
  }

  func testCancelDiscardsPendingInferenceAndBlocksConcurrentWork() throws {
    let channel = QuranASRChannel()
    let audio = try reference()
    let cancelled = expectation(description: "In-flight report discarded")
    channel.handle(FlutterMethodCall(methodName: "checkWav", arguments: audio)) { value in
      XCTAssertEqual((value as? FlutterError)?.code, "cancelled")
      cancelled.fulfill()
    }
    channel.handle(FlutterMethodCall(methodName: "cancel", arguments: nil)) { value in
      XCTAssertNil(value)
    }
    channel.handle(FlutterMethodCall(methodName: "checkWav", arguments: audio)) { value in
      XCTAssertEqual((value as? FlutterError)?.code, "invalid_audio")
    }
    wait(for: [cancelled], timeout: 30)
    let recovered = expectation(description: "New attempt after cancellation")
    channel.handle(FlutterMethodCall(methodName: "checkWav", arguments: audio)) { value in
      XCTAssertNotNil(value as? [String: Any])
      recovered.fulfill()
    }
    wait(for: [recovered], timeout: 30)
  }
}
#endif
