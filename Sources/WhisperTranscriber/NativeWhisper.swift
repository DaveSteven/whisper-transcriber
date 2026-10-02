import AVFoundation
import Foundation
import whisper

enum NativeWhisper {
    static func transcribe(wav: URL, model: String, language: String, useGPU: Bool,
                           progress: @escaping @Sendable (Double) -> Void) async throws -> TranscriptionResult {
        let cancellation = NativeCancellation()
        let progressBox = NativeProgress(progress)
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try transcribeSync(wav: wav, model: model, language: language, useGPU: useGPU,
                                   cancellation: cancellation, progress: progressBox)
            }.value
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func transcribeSync(wav: URL, model: String, language: String, useGPU: Bool,
                                       cancellation: NativeCancellation, progress: NativeProgress) throws -> TranscriptionResult {
        let audioFile = try AVAudioFile(forReading: wav)
        let length = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: length) else {
            throw AppError("Audio memory could not be allocated.")
        }
        try audioFile.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else { throw AppError("Prepared audio could not be read.") }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))

        var contextParameters = whisper_context_default_params()
        contextParameters.use_gpu = useGPU
        contextParameters.flash_attn = true
        let context = model.withCString { whisper_init_from_file_with_params($0, contextParameters) }
        guard let context else { throw AppError("The whisper.cpp model could not be loaded.") }
        defer { whisper_free(context) }

        var parameters = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        parameters.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        parameters.print_progress = false
        parameters.print_realtime = false
        parameters.print_timestamps = false
        parameters.abort_callback = { pointer in
            guard let pointer else { return false }
            return Unmanaged<NativeCancellation>.fromOpaque(pointer).takeUnretainedValue().isCancelled
        }
        parameters.abort_callback_user_data = Unmanaged.passUnretained(cancellation).toOpaque()
        parameters.progress_callback = { _, _, value, pointer in
            guard let pointer else { return }
            Unmanaged<NativeProgress>.fromOpaque(pointer).takeUnretainedValue().report(Double(value) / 100)
        }
        parameters.progress_callback_user_data = Unmanaged.passUnretained(progress).toOpaque()

        let result: Int32 = language.withCString { languagePointer in
            parameters.language = language == "auto" ? nil : languagePointer
            return samples.withUnsafeBufferPointer { samplePointer in
                whisper_full(context, parameters, samplePointer.baseAddress, Int32(samplePointer.count))
            }
        }
        if cancellation.isCancelled { throw CancellationError() }
        guard result == 0 else { throw AppError("Native whisper.cpp transcription failed (code \(result)).") }

        var segments: [TranscriptSegment] = []
        for index in 0..<whisper_full_n_segments(context) {
            if let segment = whisper_full_get_segment_text(context, index) {
                segments.append(TranscriptSegment(
                    start: Double(whisper_full_get_segment_t0(context, index)) / 100,
                    end: Double(whisper_full_get_segment_t1(context, index)) / 100,
                    text: String(cString: segment)
                ))
            }
        }
        let text = segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        let languageID = whisper_full_lang_id(context)
        let detectedLanguage = whisper_lang_str(languageID).map { String(cString: $0) }
        return TranscriptionResult(text: text, language: detectedLanguage, segments: segments)
    }
}

private final class NativeCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.withLock { cancelled = true } }
    var isCancelled: Bool { lock.withLock { cancelled } }
}

private final class NativeProgress: @unchecked Sendable {
    private let callback: @Sendable (Double) -> Void
    init(_ callback: @escaping @Sendable (Double) -> Void) { self.callback = callback }
    func report(_ value: Double) { callback(value) }
}
