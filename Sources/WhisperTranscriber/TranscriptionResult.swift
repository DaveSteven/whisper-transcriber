import Foundation

struct TranscriptionResult: Codable, Sendable {
    let text: String
    let language: String?
    let segments: [TranscriptSegment]
}

struct TranscriptSegment: Codable, Sendable {
    let start: Double
    let end: Double
    let text: String
}

enum TranscriptFormat: String, CaseIterable, Identifiable {
    case txt
    case srt
    case vtt

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

enum TranscriptExporter {
    static func render(_ result: TranscriptionResult, as format: TranscriptFormat) -> String {
        switch format {
        case .txt:
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        case .srt:
            return result.segments.enumerated().map { index, segment in
                "\(index + 1)\n\(timestamp(segment.start, separator: ",")) --> \(timestamp(segment.end, separator: ","))\n\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))"
            }.joined(separator: "\n\n") + "\n"
        case .vtt:
            let cues = result.segments.map { segment in
                "\(timestamp(segment.start, separator: ".")) --> \(timestamp(segment.end, separator: "."))\n\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))"
            }.joined(separator: "\n\n")
            return "WEBVTT\n\n\(cues)\n"
        }
    }

    static func write(_ result: TranscriptionResult, prefix: URL,
                      formats: Set<TranscriptFormat>) throws -> [URL] {
        var outputs: [URL] = []
        for format in TranscriptFormat.allCases where formats.contains(format) {
            let url = prefix.appendingPathExtension(format.rawValue)
            try render(result, as: format).write(to: url, atomically: true, encoding: .utf8)
            outputs.append(url)
        }
        return outputs
    }

    private static func timestamp(_ seconds: Double, separator: Character) -> String {
        let milliseconds = max(0, Int((seconds * 1_000).rounded()))
        let hours = milliseconds / 3_600_000
        let minutes = milliseconds / 60_000 % 60
        let secs = milliseconds / 1_000 % 60
        let millis = milliseconds % 1_000
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, String(separator), millis)
    }
}
