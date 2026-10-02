import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: make_icns.swift <iconset> <output.icns>")
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let entries = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianBytes(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return Data(bytes: &number, count: MemoryLayout<UInt32>.size)
}

var body = Data()
for (type, filename) in entries {
    let image = try Data(contentsOf: directory.appendingPathComponent(filename))
    body.append(type.data(using: .ascii)!)
    body.append(bigEndianBytes(image.count + 8))
    body.append(image)
}

var icon = Data("icns".utf8)
icon.append(bigEndianBytes(body.count + 8))
icon.append(body)
try icon.write(to: output, options: .atomic)
