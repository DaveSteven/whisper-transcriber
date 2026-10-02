# Whisper Transcriber

一款原生 macOS 音视频转文字工具。文件和模型均在本机处理，支持通过
`whisper.cpp` 或 Apple Silicon 上的 MLX Whisper 完成转录。

## 功能

- 拖放或选择音频、视频文件
- 自动识别语言，或指定英语、中文、日语、韩语和西班牙语
- 支持 `whisper.cpp` 与 MLX Whisper，并可自动选择可用后端
- 提供 Large V3 Turbo（速度优先）和 Large V3（准确率优先）模型
- 实时显示模型下载与转录进度
- 预览和复制转录结果
- 导出 TXT、SRT 和 WebVTT 文件

## 系统要求

- macOS 14 Sonoma 或更高版本
- Swift 6 / Xcode 16 或更高版本（从源码构建时）
- 足够的磁盘空间用于模型：
  - Large V3 Turbo：约 1.6 GB
  - Large V3：约 3.1 GB

`whisper.cpp` 后端已随项目集成，无需额外安装。MLX 后端仅适用于 Apple
Silicon；应用可通过 Python 3 创建独立运行环境并安装 `mlx-whisper`。如果未安装
Python 3，可直接使用 `whisper.cpp`。

## 构建与运行

克隆项目后执行：

```bash
git clone git@github.com:DaveSteven/whisper-transcriber.git
cd whisper-transcriber
./build-app.sh
```

构建完成后，应用位于：

```text
dist/Whisper Transcriber.app
```

也可以直接通过 Swift Package Manager 运行或测试：

```bash
swift run
swift test
```

## 使用方法

1. 启动应用并选择转录模型，首次使用时按提示下载。
2. 将音频或视频拖入窗口，或点击 **Choose file** 选择文件。
3. 选择语言、导出格式和保存目录。
4. 开始转录，并在右侧预览结果。

模型默认保存在：

```text
~/Library/Application Support/Whisper Transcriber/Models
```

## 技术栈

- SwiftUI
- Swift Package Manager
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [MLX Whisper](https://github.com/ml-explore/mlx-examples/tree/main/whisper)

## 隐私

转录在本机完成。除下载所选模型和安装可选的 MLX 运行环境外，音视频内容无需上传到远程服务。
