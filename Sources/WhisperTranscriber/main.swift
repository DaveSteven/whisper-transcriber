import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct WhisperTranscriberApp: App {
    @StateObject private var model = Transcriber()
    var body: some Scene { WindowGroup { ContentView().environmentObject(model) } }
}

struct ContentView: View {
    @EnvironmentObject var worker: Transcriber
    @State private var hovering = false
    @State private var showOnboarding = false
    @State private var copied = false
    @AppStorage("completedOnboarding") private var completedOnboarding = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    fileCard
                    settingsCard
                    activityCard
                    actionBar
                    resultCard
                }
                .frame(maxWidth: 880)
                .padding(.horizontal, 34)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .tint(.quizletBlue)
        .frame(minWidth: 780, minHeight: 720)
        .onAppear { showOnboarding = !completedOnboarding }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding, completed: $completedOnboarding)
                .environmentObject(worker)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AppBrandIcon(size: 48, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 2) {
                Text("Whisper Transcriber").font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Turn audio and video into text").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if worker.setupReady {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold)).foregroundStyle(.green)
            }
        }
    }

    private var fileCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.quizletBlue.opacity(0.09))
                Image(systemName: worker.file == nil ? "arrow.up.doc.fill" : "waveform")
                    .font(.system(size: 27, weight: .semibold)).foregroundStyle(Color.quizletBlue)
            }
            .frame(width: 58, height: 58)
            Text(worker.file?.lastPathComponent ?? "Drop an audio or video file here")
                .font(.title3.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
            Text(worker.file == nil ? "MP3, WAV, M4A, MP4, MOV and more" : "Ready to transcribe")
                .font(.callout).foregroundStyle(.secondary)
            Button(worker.file == nil ? "Choose file" : "Choose another file", action: chooseFile)
                .buttonStyle(SecondaryActionButtonStyle()).disabled(worker.isBusy)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .padding(24)
        .background(hovering ? Color.quizletBlue.opacity(0.06) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(style: StrokeStyle(lineWidth: hovering ? 2 : 1, dash: [7])))
        .foregroundStyle(.primary)
        .onDrop(of: [.fileURL], isTargeted: $hovering) { providers in
            guard !worker.isBusy, let provider = providers.first else { return false }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in worker.select(url) }
            }
            return true
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Transcription options").font(.title3.bold())
            HStack(alignment: .top, spacing: 28) {
                settingField("Quality") {
                    HStack {
                        Picker("Quality", selection: $worker.managedModel) {
                            ForEach(ManagedModel.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6).frame(height: 36)
                        .background(Color.appBackground).clipShape(RoundedRectangle(cornerRadius: 9))
                        .disabled(worker.isBusy)
                        if worker.selectedModelInstalled {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button("Download") { worker.downloadSelectedModel() }
                                .buttonStyle(PreviewActionButtonStyle()).disabled(worker.isBusy)
                        }
                    }
                }
                settingField("Language") {
                    Picker("Language", selection: $worker.language) {
                        Text("Automatic").tag("auto")
                        Text("English").tag("en")
                        Text("Chinese").tag("zh")
                        Text("Japanese").tag("ja")
                        Text("Korean").tag("ko")
                        Text("Spanish").tag("es")
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6).frame(height: 36)
                    .background(Color.appBackground).clipShape(RoundedRectangle(cornerRadius: 9))
                    .disabled(worker.isBusy)
                }
            }
            Divider()
            settingField("Export formats") {
                HStack(spacing: 10) {
                    FormatToggle(title: "TXT", isOn: $worker.exportTXT)
                    FormatToggle(title: "SRT", isOn: $worker.exportSRT)
                    FormatToggle(title: "VTT", isOn: $worker.exportVTT)
                }.disabled(worker.isBusy)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save to").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(worker.outputDirectoryDisplayName).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Button(action: chooseOutputDirectory) {
                    Label("Change", systemImage: "folder")
                }
                .buttonStyle(PreviewActionButtonStyle()).disabled(worker.isBusy)
                if worker.outputDirectory != nil {
                    Button("Use source folder") { worker.outputDirectory = nil }
                        .buttonStyle(PreviewActionButtonStyle()).disabled(worker.isBusy)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder private var activityCard: some View {
        if worker.isDownloading || worker.isRunning || worker.progress > 0 && worker.progress < 1 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(worker.isDownloading ? worker.downloadStatus : worker.status).font(.callout.weight(.semibold))
                    Spacer()
                    Text("\(Int((worker.isDownloading ? worker.downloadProgress : worker.progress) * 100))%")
                        .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressView(value: worker.isDownloading ? worker.downloadProgress : worker.progress)
                if worker.isDownloading {
                    Button("Cancel download", role: .destructive) { worker.cancelDownload() }
                }
            }.cardStyle()
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    worker.start()
                } label: {
                    Label(worker.isRunning ? "Transcribing…" : "Transcribe", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(worker.file == nil || worker.isBusy || worker.selectedFormats.isEmpty)

                if worker.isRunning {
                    Button { worker.cancel() } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(CancelActionButtonStyle())
                    .help("Cancel transcription")
                }
            }
            if !worker.message.isEmpty {
                Label(worker.message, systemImage: worker.failed ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(worker.failed ? .red : .secondary)
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Preview").font(.title3.bold())
                Spacer()
                if worker.latestResult != nil {
                    Button(action: copyPreview) {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(width: 66)
                    }
                    .buttonStyle(PreviewActionButtonStyle(confirmed: copied))
                    if let output = worker.outputURL {
                        Button { NSWorkspace.shared.activateFileViewerSelecting(worker.outputURLs.isEmpty ? [output] : worker.outputURLs) } label: {
                            Label("Open folder", systemImage: "folder")
                        }
                        .buttonStyle(PreviewActionButtonStyle())
                    }
                }
            }
            if worker.latestResult == nil {
                VStack(spacing: 8) {
                    Image(systemName: "text.alignleft").font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text("Your transcript preview will appear here").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 150)
            } else {
                if worker.generatedFormats.count > 1 {
                    PreviewFormatTabs(
                        formats: worker.orderedGeneratedFormats,
                        selection: $worker.previewFormat
                    )
                } else if let format = worker.orderedGeneratedFormats.first {
                    Text("\(format.title) preview")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                TranscriptPreview(
                    text: worker.previewText,
                    monospaced: worker.previewFormat != .txt
                )
                .frame(minHeight: 210, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.cardStyle()
    }

    private func settingField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copyPreview() {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(worker.previewText, forType: .string) else { return }
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.15)) { copied = false }
            }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .movie, .mpeg4Movie]
        if panel.runModal() == .OK, let url = panel.url { worker.select(url) }
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { worker.outputDirectory = url.path }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var worker: Transcriber
    @Binding var isPresented: Bool
    @Binding var completed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            AppBrandIcon(size: 58, cornerRadius: 16)
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Whisper Transcriber").font(.title.bold())
                Text("Choose a transcription quality to get started.").foregroundStyle(.secondary)
            }

            Picker("Quality", selection: $worker.managedModel) {
                ForEach(ManagedModel.allCases) { model in
                    Text(model.title).tag(model)
                }
            }.pickerStyle(.radioGroup).disabled(worker.isBusy)

            if worker.isDownloading {
                Text(worker.downloadStatus)
                ProgressView(value: worker.downloadProgress)
                Button("Cancel", role: .destructive) { worker.cancelDownload() }
            } else if !worker.setupReady {
                Button("Download and set up") { worker.downloadSelectedModel() }
                    .buttonStyle(PrimaryActionButtonStyle())
            } else {
                Label("Transcription engine is ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if !worker.message.isEmpty {
                Text(worker.message).font(.callout).foregroundStyle(worker.failed ? .red : .secondary)
            }
            HStack {
                Spacer()
                Button("Continue") {
                    completed = true
                    isPresented = false
                }.buttonStyle(PrimaryActionButtonStyle()).disabled(!worker.setupReady || worker.isBusy)
            }
        }
        .padding(34).frame(width: 540).background(Color.appBackground).tint(.quizletBlue)
        .interactiveDismissDisabled(!worker.setupReady)
    }
}

private struct AppBrandIcon: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct FormatToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                Text(title).fontWeight(.semibold)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(isOn ? Color.quizletBlue : .secondary)
            .background(isOn ? Color.quizletBlue.opacity(0.1) : Color.appBackground)
            .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
}

private struct PreviewFormatTabs: View {
    let formats: [TranscriptFormat]
    @Binding var selection: TranscriptFormat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(formats) { format in
                Button { selection = format } label: {
                    Text(format.title)
                        .font(.caption.weight(.bold))
                        .frame(minWidth: 54)
                        .padding(.horizontal, 9).padding(.vertical, 7)
                        .foregroundStyle(selection == format ? .white : Color.secondary)
                        .background(selection == format ? Color.quizletBlue : Color.white.opacity(0.001))
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .accessibilityAddTraits(selection == format ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.appBackground)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TranscriptPreview: NSViewRepresentable {
    let text: String
    let monospaced: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(red: 0.965, green: 0.969, blue: 0.985, alpha: 1)

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.usesFindPanel = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        if textView.string != text {
            textView.string = text
            textView.scrollToBeginningOfDocument(nil)
        }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Color.quizletBlue.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold)).foregroundStyle(Color.quizletBlue)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Color.quizletBlue.opacity(configuration.isPressed ? 0.16 : 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct CancelActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.quizletBlue)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(configuration.isPressed ? Color.quizletBlue.opacity(0.12) : .white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizletBlue.opacity(0.3), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PreviewActionButtonStyle: ButtonStyle {
    var confirmed = false

    func makeBody(configuration: Configuration) -> some View {
        let color: Color = confirmed ? .green : .quizletBlue
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(color.opacity(configuration.isPressed ? 0.16 : 0.08))
            .clipShape(Capsule())
    }
}

private extension View {
    func cardStyle() -> some View {
        self.padding(20).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
    }
}

private extension Color {
    static let quizletBlue = Color(red: 0.26, green: 0.28, blue: 0.95)
    static let appBackground = Color(red: 0.965, green: 0.969, blue: 0.985)
}

@MainActor
final class Transcriber: ObservableObject {
    @Published var file: URL?
    @Published var status = "Ready"
    @Published var progress = 0.0
    @Published var transcript = ""
    @Published var latestResult: TranscriptionResult?
    @Published var generatedFormats: Set<TranscriptFormat> = []
    @Published var previewFormat: TranscriptFormat = .txt
    @Published var previewContents: [TranscriptFormat: String] = [:]
    @Published var message = ""
    @Published var failed = false
    @Published var isRunning = false
    @Published var outputURL: URL?
    @Published var outputURLs: [URL] = []
    @Published var isDownloading = false
    @Published var downloadProgress = 0.0
    @Published var downloadStatus = ""
    @Published var managedModel: ManagedModel {
        didSet { UserDefaults.standard.set(managedModel.rawValue, forKey: SettingsKey.managedModel) }
    }
    @Published var modelPath: String {
        didSet { UserDefaults.standard.set(modelPath, forKey: SettingsKey.modelPath) }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: SettingsKey.language) }
    }
    @Published var exportTXT: Bool {
        didSet { UserDefaults.standard.set(exportTXT, forKey: SettingsKey.exportTXT) }
    }
    @Published var exportSRT: Bool {
        didSet { UserDefaults.standard.set(exportSRT, forKey: SettingsKey.exportSRT) }
    }
    @Published var exportVTT: Bool {
        didSet { UserDefaults.standard.set(exportVTT, forKey: SettingsKey.exportVTT) }
    }
    @Published var outputDirectory: String? {
        didSet { UserDefaults.standard.set(outputDirectory, forKey: SettingsKey.outputDirectory) }
    }

    private var process: Process?
    private var task: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var activeRunID: UUID?
    private var mlxWhisper: String? { ToolLocator.mlxWhisper() }

    init() {
        let defaults = UserDefaults.standard
        modelPath = defaults.string(forKey: SettingsKey.modelPath) ?? ToolLocator.whisperModel() ?? ""
        language = defaults.string(forKey: SettingsKey.language) ?? "auto"
        exportTXT = defaults.object(forKey: SettingsKey.exportTXT) as? Bool ?? true
        exportSRT = defaults.object(forKey: SettingsKey.exportSRT) as? Bool ?? false
        exportVTT = defaults.object(forKey: SettingsKey.exportVTT) as? Bool ?? false
        outputDirectory = defaults.string(forKey: SettingsKey.outputDirectory)
        managedModel = ManagedModel(rawValue: defaults.string(forKey: SettingsKey.managedModel) ?? "") ?? .turbo
        if modelPath.isEmpty && managedModel.isNativeInstalled { modelPath = managedModel.nativePath.path }
    }

    var isBusy: Bool { isRunning || isDownloading }

    var selectedFormats: Set<TranscriptFormat> {
        var formats: Set<TranscriptFormat> = []
        if exportTXT { formats.insert(.txt) }
        if exportSRT { formats.insert(.srt) }
        if exportVTT { formats.insert(.vtt) }
        return formats
    }

    var orderedGeneratedFormats: [TranscriptFormat] {
        TranscriptFormat.allCases.filter(generatedFormats.contains)
    }

    var previewText: String {
        previewContents[previewFormat] ?? ""
    }

    private var downloadBackend: TranscriptionBackend {
        ToolLocator.supportsMLX && (mlxWhisper != nil || ToolLocator.python3() != nil) ? .mlx : .whisperCpp
    }

    var selectedModelInstalled: Bool {
        if downloadBackend == .mlx { return managedModel.isInstalled }
        return managedModel.isNativeInstalled || (!modelPath.isEmpty && FileManager.default.fileExists(atPath: modelPath))
    }

    var setupReady: Bool {
        let localModelReady = !modelPath.isEmpty && FileManager.default.fileExists(atPath: modelPath)
        return localModelReady || (mlxWhisper != nil && managedModel.isInstalled) || managedModel.isNativeInstalled
    }

    var outputDirectoryDisplayName: String {
        guard let outputDirectory else { return "Same folder as source" }
        return (outputDirectory as NSString).abbreviatingWithTildeInPath
    }

    func select(_ url: URL) {
        file = url; status = "Ready"; progress = 0; transcript = ""; latestResult = nil
        generatedFormats = []; previewContents = [:]; message = ""; outputURL = nil; outputURLs = []
    }

    func downloadSelectedModel() {
        guard !isBusy else { return }
        let model = managedModel
        let targetBackend = downloadBackend
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Preparing \(model.title)…"
        failed = false
        message = ""
        downloadTask = Task { await install(model, for: targetBackend) }
    }

    func cancelDownload() {
        guard isDownloading else { return }
        downloadStatus = "Cancelling download…"
        downloadTask?.cancel()
        process?.terminate()
    }

    func start() {
        guard let input = file else { return }
        let runID = UUID()
        activeRunID = runID
        isRunning = true; failed = false; progress = 0; transcript = ""; latestResult = nil
        generatedFormats = []; previewContents = [:]; message = ""
        task = Task { await run(input, id: runID) }
    }

    func cancel() {
        guard isRunning else { return }
        status = "Cancelling…"
        message = "Waiting for the current process to stop."
        task?.cancel()
        process?.terminate()
    }

    private func run(_ input: URL, id: UUID) async {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("whisper-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temp) }
        do {
            let engine = try resolvedBackend()
            if let outputDirectory {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: outputDirectory, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    throw AppError("The selected output folder no longer exists. Choose another folder.")
                }
                guard FileManager.default.isWritableFile(atPath: outputDirectory) else {
                    throw AppError("The selected output folder is not writable.")
                }
            }
            status = "Preparing audio…"; progress = 0.03
            try await AudioPreparer.convertToWhisperWAV(input: input, output: temp)
            try Task.checkCancellation()
            status = "Transcribing…"; progress = 0.08
            let output = availableOutputPrefix(for: input)
            let result: TranscriptionResult
            switch engine {
            case .mlx:
                result = try await mlxRun(temp: temp)
            case .whisperCpp:
                result = try await whisperRun(temp: temp)
            case .automatic:
                throw AppError("No transcription engine is available.")
            }
            let outputs = try TranscriptExporter.write(result, prefix: output, formats: selectedFormats)
            guard activeRunID == id else { return }
            transcript = result.text
            latestResult = result
            generatedFormats = selectedFormats
            previewContents = Dictionary(uniqueKeysWithValues: selectedFormats.map {
                ($0, TranscriptExporter.render(result, as: $0))
            })
            previewFormat = TranscriptFormat.allCases.first(where: selectedFormats.contains) ?? .txt
            outputURLs = outputs
            outputURL = outputs.first
            progress = 1; status = "Complete"; message = outputs.count == 1 ? "Saved \(outputs[0].lastPathComponent)" : "Saved \(outputs.count) files"
            finish(id)
        } catch {
            guard activeRunID == id else { return }
            if Task.isCancelled || error is CancellationError {
                status = "Cancelled"; message = "Transcription cancelled."
            } else {
                failed = true; status = "Failed"; message = error.localizedDescription
            }
            finish(id)
        }
    }

    private func resolvedBackend() throws -> TranscriptionBackend {
        if ToolLocator.supportsMLX && mlxWhisper != nil && managedModel.isInstalled {
            guard mlxWhisper != nil else {
                throw AppError("MLX Whisper is not installed yet. Install mlx-whisper, or choose Automatic to use whisper.cpp.")
            }
            guard managedModel.isInstalled else {
                throw AppError("\(managedModel.title) has not been downloaded yet. Click Download in Transcription Settings.")
            }
            return .mlx
        }
        guard !modelPath.isEmpty, FileManager.default.fileExists(atPath: modelPath) else {
            throw AppError("The selected whisper.cpp model was not found. Choose an existing ggml-*.bin model.")
        }
        return .whisperCpp
    }

    private func mlxRun(temp: URL) async throws -> TranscriptionResult {
        guard let mlxWhisper else { throw AppError("mlx_whisper is not installed.") }
        guard let python = ToolLocator.pythonForMLX(executable: mlxWhisper) else {
            throw AppError("The Python runtime for MLX Whisper was not found.")
        }
        guard let script = Bundle.main.resourceURL?.appendingPathComponent("mlx_transcribe.py"),
              FileManager.default.fileExists(atPath: script.path) else {
            throw AppError("The MLX transcription component is missing from the application.")
        }
        let json = FileManager.default.temporaryDirectory.appendingPathComponent("mlx-result-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: json) }
        try await execute(python, [script.path, temp.path, "--model", managedModel.directory.path,
                                   "--output", json.path,
                                   "--language", language])
        return try JSONDecoder().decode(TranscriptionResult.self, from: Data(contentsOf: json))
    }

    private func install(_ model: ManagedModel, for targetBackend: TranscriptionBackend) async {
        if targetBackend == .whisperCpp {
            await installNative(model)
        } else {
            await installMLX(model)
        }
    }

    private func installMLX(_ model: ManagedModel) async {
        let fm = FileManager.default
        let staging = ModelStorage.root.appendingPathComponent(".\(model.rawValue).download", isDirectory: true)
        do {
            try await ensureMLXRuntime()
            try Task.checkCancellation()
            try fm.createDirectory(at: ModelStorage.root, withIntermediateDirectories: true)
            let values = try ModelStorage.root
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = values.volumeAvailableCapacityForImportantUsage,
               available < model.expectedBytes + 1_000_000_000 {
                throw AppError("Not enough free disk space. Free at least \(ByteCountFormatter.string(fromByteCount: model.expectedBytes + 1_000_000_000, countStyle: .file)).")
            }
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            downloadStatus = "Downloading model information…"
            try await download(model.downloadURL(for: "config.json"), to: staging.appendingPathComponent("config.json"), showProgress: false)
            try Task.checkCancellation()
            downloadStatus = "Downloading \(model.title)…"
            try await download(model.downloadURL(for: model.weightFile), to: staging.appendingPathComponent(model.weightFile), showProgress: true)
            try Task.checkCancellation()
            let size = try staging.appendingPathComponent(model.weightFile).resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard Int64(size) > model.expectedBytes * 8 / 10 else {
                throw AppError("The downloaded model is incomplete. You can retry to resume the download.")
            }
            if fm.fileExists(atPath: model.directory.path) { try fm.removeItem(at: model.directory) }
            try fm.moveItem(at: staging, to: model.directory)
            downloadProgress = 1
            downloadStatus = "Installed \(model.title)"
            message = "The model is ready to use."
        } catch {
            if Task.isCancelled || error is CancellationError {
                downloadStatus = "Download cancelled"
                message = "The partial download was kept and can be resumed later."
            } else {
                failed = true
                downloadStatus = "Download failed"
                message = error.localizedDescription
            }
        }
        process = nil
        downloadTask = nil
        isDownloading = false
    }

    private func installNative(_ model: ManagedModel) async {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: model.nativeDirectory, withIntermediateDirectories: true)
            let values = try model.nativeDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = values.volumeAvailableCapacityForImportantUsage,
               available < model.expectedBytes + 500_000_000 {
                throw AppError("Not enough free disk space. Free at least \(ByteCountFormatter.string(fromByteCount: model.expectedBytes + 500_000_000, countStyle: .file)).")
            }
            downloadStatus = "Downloading \(model.title) for the built-in engine…"
            try await download(model.nativeDownloadURL, to: model.nativePath, showProgress: true)
            let size = try model.nativePath.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard Int64(size) > model.expectedBytes * 8 / 10 else {
                throw AppError("The downloaded model is incomplete. You can retry to resume the download.")
            }
            modelPath = model.nativePath.path
            downloadProgress = 1
            downloadStatus = "Installed \(model.title)"
            message = "The built-in transcription engine is ready to use."
        } catch {
            if Task.isCancelled || error is CancellationError {
                downloadStatus = "Download cancelled"
                message = "The partial download was kept and can be resumed later."
            } else {
                failed = true
                downloadStatus = "Download failed"
                message = error.localizedDescription
            }
        }
        process = nil
        downloadTask = nil
        isDownloading = false
    }

    private func ensureMLXRuntime() async throws {
        if mlxWhisper != nil { return }
        guard let python = ToolLocator.python3() else {
            throw AppError("Python 3 is required to install MLX Whisper. Install Python with Homebrew, then retry.")
        }
        downloadStatus = "Creating an isolated MLX environment…"
        try FileManager.default.createDirectory(at: ModelStorage.runtime.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await execute(python, ["-m", "venv", ModelStorage.runtime.path])
        try Task.checkCancellation()
        let pip = ModelStorage.runtime.appendingPathComponent("bin/pip").path
        downloadStatus = "Installing MLX Whisper…"
        try await execute(pip, ["install", "--upgrade", "mlx-whisper"])
        guard mlxWhisper != nil else { throw AppError("MLX Whisper installation completed, but its executable was not found.") }
    }

    private func download(_ url: URL, to destination: URL, showProgress: Bool) async throws {
        let partial = destination.appendingPathExtension("partial")
        try await execute("/usr/bin/curl", ["--location", "--fail", "--retry", "3", "--continue-at", "-",
                                                   "--progress-bar", "--output", partial.path, url.absoluteString],
                          parseDownloadProgress: showProgress)
        try Task.checkCancellation()
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: partial, to: destination)
    }

    private func whisperRun(temp: URL) async throws -> TranscriptionResult {
        try await NativeWhisper.transcribe(wav: temp, model: modelPath, language: language,
                                           useGPU: false) { [weak self] value in
            Task { @MainActor in self?.progress = 0.08 + min(1, max(0, value)) * 0.92 }
        }
    }

    private func finish(_ id: UUID) {
        guard activeRunID == id else { return }
        activeRunID = nil
        task = nil
        process = nil
        isRunning = false
    }

    private func availableOutputPrefix(for input: URL) -> URL {
        let directory = outputDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? input.deletingLastPathComponent()
        let base = directory.appendingPathComponent(input.deletingPathExtension().lastPathComponent)
        if selectedFormats.allSatisfy({ !FileManager.default.fileExists(atPath: base.appendingPathExtension($0.rawValue).path) }) { return base }
        let name = base.lastPathComponent + "-transcript"
        var candidate = directory.appendingPathComponent(name)
        var index = 2
        while selectedFormats.contains(where: { FileManager.default.fileExists(atPath: candidate.appendingPathExtension($0.rawValue).path) }) {
            candidate = directory.appendingPathComponent("\(name)-\(index)")
            index += 1
        }
        return candidate
    }

    private func execute(_ executable: String, _ arguments: [String], parseProgress: Bool = false,
                         parseDownloadProgress: Bool = false) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let p = Process(); let pipe = Pipe(); let output = ProcessOutputBuffer()
            p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
            p.standardOutput = pipe; p.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                let text = String(decoding: data, as: UTF8.self)
                output.append(text)
                if parseProgress, let match = text.matches(of: /progress\s*=\s*(\d+)%/).last,
                   let value = Double(match.1) {
                    Task { @MainActor in self?.progress = min(1, max(0.08, 0.08 + value * 0.0092)) }
                }
                if parseDownloadProgress,
                   let match = text.matches(of: /(\d+(?:\.\d+)?)%/).last,
                   let value = Double(match.1) {
                    Task { @MainActor in self?.downloadProgress = min(1, max(0, value / 100)) }
                }
            }
            p.terminationHandler = { [weak self] process in
                pipe.fileHandleForReading.readabilityHandler = nil
                output.append(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
                Task { @MainActor in
                    if self?.process === process { self?.process = nil }
                }
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CommandError(executable: executable, status: process.terminationStatus, output: output.text))
                }
            }
            do { try p.run(); self.process = p } catch { continuation.resume(throwing: error) }
        }
    }
}

private enum SettingsKey {
    static let modelPath = "modelPath"
    static let language = "language"
    static let exportTXT = "exportTXT"
    static let exportSRT = "exportSRT"
    static let exportVTT = "exportVTT"
    static let outputDirectory = "outputDirectory"
    static let managedModel = "managedModel"
}

private enum ToolLocator {
    static var supportsMLX: Bool {
#if arch(arm64)
        true
#else
        false
#endif
    }

    static func executable(named name: String) -> String? {
        let candidates = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func whisperModel() -> String? {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("models/whisper", isDirectory: true)
        let preferred = directory.appendingPathComponent("ggml-large-v3-turbo.bin").path
        if FileManager.default.fileExists(atPath: preferred) { return preferred }
        let models = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return models.filter { $0.lastPathComponent.hasPrefix("ggml-") && $0.pathExtension == "bin" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }.first?.path
    }

    static func mlxWhisper() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let managed = ModelStorage.runtime.appendingPathComponent("bin/mlx_whisper").path
        let candidates = [managed, "/opt/homebrew/bin/mlx_whisper", "/usr/local/bin/mlx_whisper",
                          "\(home)/.local/bin/mlx_whisper", "\(home)/.pyenv/shims/mlx_whisper"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }


    static func python3() -> String? {
        let candidates = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func pythonForMLX(executable: String) -> String? {
        let directory = URL(fileURLWithPath: executable).deletingLastPathComponent()
        let localCandidates = [directory.appendingPathComponent("python3").path,
                               directory.appendingPathComponent("python").path]
        return localCandidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? python3()
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""

    func append(_ value: String) {
        lock.lock(); defer { lock.unlock() }
        storage += value
        if storage.count > 16_000 { storage.removeFirst(storage.count - 16_000) }
    }

    var text: String {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}

private struct CommandError: LocalizedError {
    let executable: String
    let status: Int32
    let output: String

    var isMetalFailure: Bool {
        output.lowercased().split(whereSeparator: \Character.isNewline).contains { line in
            (line.contains("metal") || line.contains("mtl") || line.contains("gpu")) &&
                (line.contains("error") || line.contains("failed") || line.contains("unavailable"))
        }
    }

    var errorDescription: String? {
        let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = detail.isEmpty ? "No diagnostic output was produced." : detail
        return "\(URL(fileURLWithPath: executable).lastPathComponent) failed (exit \(status)).\n\(summary)"
    }
}

struct AppError: LocalizedError {
    let text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}
