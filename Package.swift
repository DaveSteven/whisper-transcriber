// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhisperTranscriber",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WhisperTranscriber",
            dependencies: ["WhisperFramework"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .binaryTarget(name: "WhisperFramework", path: "Vendor/build-apple/whisper.xcframework"),
        .testTarget(name: "WhisperTranscriberTests", dependencies: ["WhisperTranscriber"])
    ]
)
