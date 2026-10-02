import Foundation

enum TranscriptionBackend: String, CaseIterable, Identifiable {
    case automatic
    case mlx
    case whisperCpp

    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Automatic (Recommended)"
        case .mlx: "MLX Whisper"
        case .whisperCpp: "whisper.cpp"
        }
    }
}

enum ManagedModel: String, CaseIterable, Identifiable {
    case turbo
    case largeV3

    var id: String { rawValue }
    var title: String { self == .turbo ? "Fast (Recommended)" : "Highest Accuracy" }
    var detail: String {
        self == .turbo ? "Large V3 Turbo · about 1.6 GB" : "Large V3 · about 3.1 GB"
    }
    var repository: String {
        self == .turbo ? "mlx-community/whisper-large-v3-turbo" : "mlx-community/whisper-large-v3-mlx"
    }
    var weightFile: String { self == .turbo ? "weights.safetensors" : "weights.npz" }
    var expectedBytes: Int64 { self == .turbo ? 1_610_000_000 : 3_080_000_000 }
    var nativeFile: String { self == .turbo ? "ggml-large-v3-turbo.bin" : "ggml-large-v3.bin" }

    var directory: URL { ModelStorage.root.appendingPathComponent(rawValue, isDirectory: true) }
    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent("config.json").path) &&
            FileManager.default.fileExists(atPath: directory.appendingPathComponent(weightFile).path)
    }
    var nativeDirectory: URL { ModelStorage.root.appendingPathComponent("Native", isDirectory: true) }
    var nativePath: URL { nativeDirectory.appendingPathComponent(nativeFile) }
    var isNativeInstalled: Bool { FileManager.default.fileExists(atPath: nativePath.path) }

    func downloadURL(for file: String) -> URL {
        URL(string: "https://huggingface.co/\(repository)/resolve/main/\(file)?download=true")!
    }

    var nativeDownloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(nativeFile)?download=true")!
    }
}

enum ModelStorage {
    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Whisper Transcriber/Models", isDirectory: true)
    }

    static var runtime: URL {
        root.deletingLastPathComponent().appendingPathComponent("Runtime", isDirectory: true)
    }
}
