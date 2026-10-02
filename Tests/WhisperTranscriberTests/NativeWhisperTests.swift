import AVFoundation
import XCTest
@testable import WhisperTranscriber

final class NativeWhisperTests: XCTestCase {
    func testNativeFrameworkLoadsModelAndTranscribes() async throws {
        guard let model = ProcessInfo.processInfo.environment["WHISPER_TEST_MODEL"],
              FileManager.default.fileExists(atPath: model) else {
            throw XCTSkip("Set WHISPER_TEST_MODEL to run the native integration test.")
        }
        let wav = FileManager.default.temporaryDirectory
            .appendingPathComponent("native-whisper-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wav) }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        do {
            let file = try AVAudioFile(forWriting: wav, settings: settings)
            let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
            let silence = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_000))
            silence.frameLength = 8_000
            memset(silence.floatChannelData![0], 0, Int(silence.frameLength) * MemoryLayout<Float>.size)
            try file.write(from: silence)
        }

        let result = try await NativeWhisper.transcribe(wav: wav, model: model, language: "auto", useGPU: false) { _ in }
        XCTAssertNotNil(result.language)
    }
}
