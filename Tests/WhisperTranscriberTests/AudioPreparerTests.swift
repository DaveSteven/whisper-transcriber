import AVFoundation
import XCTest
@testable import WhisperTranscriber

final class AudioPreparerTests: XCTestCase {
    func testConvertsStereoAudioToWhisperWAV() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-preparer-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("source.wav")
        let output = directory.appendingPathComponent("converted.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        do {
            let source = try AVAudioFile(forWriting: input, settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
            buffer.frameLength = 4_410
            for channel in 0..<2 {
                guard let samples = buffer.floatChannelData?[channel] else { XCTFail("Missing channel data"); return }
                for frame in 0..<Int(buffer.frameLength) {
                    samples[frame] = sin(Float(frame) * 0.04) * 0.2
                }
            }
            try source.write(from: buffer)
        }

        try await AudioPreparer.convertToWhisperWAV(input: input, output: output)

        let converted = try AVAudioFile(forReading: output)
        XCTAssertEqual(converted.fileFormat.sampleRate, 16_000)
        XCTAssertEqual(converted.fileFormat.channelCount, 1)
        XCTAssertGreaterThan(converted.length, 0)
        let header = try Data(contentsOf: output).prefix(4)
        XCTAssertEqual(String(decoding: header, as: UTF8.self), "RIFF")
    }
}
