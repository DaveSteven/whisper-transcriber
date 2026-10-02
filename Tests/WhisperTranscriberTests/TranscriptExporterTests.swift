import Foundation
import XCTest
@testable import WhisperTranscriber

final class TranscriptExporterTests: XCTestCase {
    func testWritesTXTAndSubtitleFormats() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcript-export-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = TranscriptionResult(text: "Hello world", language: "en", segments: [
            TranscriptSegment(start: 1.234, end: 3.5, text: "Hello"),
            TranscriptSegment(start: 3.5, end: 65.001, text: "world")
        ])

        let outputs = try TranscriptExporter.write(result, prefix: directory.appendingPathComponent("sample"),
                                                     formats: Set(TranscriptFormat.allCases))

        XCTAssertEqual(outputs.count, 3)
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("sample.txt"), encoding: .utf8), "Hello world\n")
        let srt = try String(contentsOf: directory.appendingPathComponent("sample.srt"), encoding: .utf8)
        XCTAssertTrue(srt.contains("00:00:01,234 --> 00:00:03,500"))
        XCTAssertTrue(srt.contains("00:00:03,500 --> 00:01:05,001"))
        let vtt = try String(contentsOf: directory.appendingPathComponent("sample.vtt"), encoding: .utf8)
        XCTAssertTrue(vtt.hasPrefix("WEBVTT\n\n"))
        XCTAssertTrue(vtt.contains("00:00:01.234 --> 00:00:03.500"))
    }
}
