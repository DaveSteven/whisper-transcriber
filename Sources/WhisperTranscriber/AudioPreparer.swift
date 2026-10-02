import AVFoundation
import Foundation

enum AudioPreparer {
    static func convertToWhisperWAV(input: URL, output: URL) async throws {
        let extracted = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-audio-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: extracted) }

        let source: AVAudioFile
        do {
            source = try AVAudioFile(forReading: input)
        } catch {
            try await extractAudio(from: input, to: extracted)
            source = try AVAudioFile(forReading: extracted)
        }

        guard let destinationFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                     sampleRate: 16_000,
                                                     channels: 1,
                                                     interleaved: false),
              let converter = AVAudioConverter(from: source.processingFormat, to: destinationFormat) else {
            throw AppError("This file's audio format cannot be converted.")
        }
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let destination = try AVAudioFile(forWriting: output, settings: fileSettings,
                                          commonFormat: .pcmFormatFloat32, interleaved: false)
        let inputCapacity: AVAudioFrameCount = 8_192

        do {
            while source.framePosition < source.length {
                try Task.checkCancellation()
                guard let input = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: inputCapacity) else {
                    throw AppError("Audio memory could not be allocated.")
                }
                try source.read(into: input)
                if input.frameLength == 0 { break }

                let ratio = destinationFormat.sampleRate / source.processingFormat.sampleRate
                let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * ratio)) + 32
                guard let converted = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: capacity) else {
                    throw AppError("Converted audio memory could not be allocated.")
                }
                var suppliedInput = false
                var conversionError: NSError?
                let status = converter.convert(to: converted, error: &conversionError) { _, state in
                    if suppliedInput {
                        state.pointee = .noDataNow
                        return nil
                    }
                    suppliedInput = true
                    state.pointee = .haveData
                    return input
                }
                if let conversionError { throw conversionError }
                guard status != .error else { throw AppError("Audio conversion failed.") }
                if converted.frameLength > 0 { try destination.write(from: converted) }
            }
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    private static func extractAudio(from input: URL, to output: URL) async throws {
        let asset = AVURLAsset(url: input)
        guard !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else {
            throw AppError("The selected file does not contain an audio track.")
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AppError("The audio track cannot be extracted from this file.")
        }
        let exporter = ExporterBox(session)
        exporter.session.outputURL = output
        exporter.session.outputFileType = .m4a
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                exporter.session.exportAsynchronously {
                    switch exporter.session.status {
                    case .completed: continuation.resume()
                    case .cancelled: continuation.resume(throwing: CancellationError())
                    default: continuation.resume(throwing: exporter.session.error ?? AppError("Audio extraction failed."))
                    }
                }
            }
        } onCancel: {
            exporter.session.cancelExport()
        }
    }
}

private final class ExporterBox: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
}
