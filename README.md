# Whisper Transcriber

A native macOS app that turns audio and video into text. Your media and models
are processed locally using either `whisper.cpp` or MLX Whisper on Apple Silicon.

## Features

- Drag and drop audio or video files, or select them from Finder
- Detect the spoken language automatically, or choose English, Chinese,
  Japanese, Korean, or Spanish
- Use `whisper.cpp`, MLX Whisper, or automatically select an available backend
- Choose between Large V3 Turbo for speed and Large V3 for accuracy
- Track model download and transcription progress
- Preview and copy transcripts in the app
- Export transcripts as TXT, SRT, or WebVTT files

## Requirements

- macOS 14 Sonoma or later
- Swift 6 / Xcode 16 or later when building from source
- Enough disk space for your selected model:
  - Large V3 Turbo: approximately 1.6 GB
  - Large V3: approximately 3.1 GB

The `whisper.cpp` backend is included with the project and does not require a
separate installation. The MLX backend is available on Apple Silicon only. The
app can create an isolated Python environment and install `mlx-whisper` when
Python 3 is available; otherwise, you can use `whisper.cpp` directly.

## Build and Run

Clone the repository and run the build script:

```bash
git clone git@github.com:DaveSteven/whisper-transcriber.git
cd whisper-transcriber
./build-app.sh
```

The packaged app will be created at:

```text
dist/Whisper Transcriber.app
```

You can also run or test the project with Swift Package Manager:

```bash
swift run
swift test
```

## Usage

1. Launch the app and select a transcription model. Follow the prompt to
   download it on first use.
2. Drop an audio or video file into the window, or click **Choose file**.
3. Select the language, export formats, and output directory.
4. Start the transcription and preview the result in the app.

Models are stored by default in:

```text
~/Library/Application Support/Whisper Transcriber/Models
```

## Technology

- SwiftUI
- Swift Package Manager
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [MLX Whisper](https://github.com/ml-explore/mlx-examples/tree/main/whisper)

## Privacy

Transcription runs locally on your Mac. Your audio and video files do not need
to be uploaded to a remote service. Network access is only used to download the
selected model and install the optional MLX runtime.
