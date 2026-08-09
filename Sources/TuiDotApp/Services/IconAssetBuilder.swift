import AppKit
import Foundation

enum IconAssetBuilderError: LocalizedError {
    case unreadableImage
    case encodingFailed
    case iconutilFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "The selected icon image could not be opened."
        case .encodingFailed:
            "The selected icon could not be rendered."
        case let .iconutilFailed(message):
            "The macOS icon could not be created: \(message)"
        }
    }
}

enum IconAssetBuilder {
    private static let representations: [(name: String, pixels: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    static func createICNS(from source: URL, at destination: URL) throws {
        if source.pathExtension.lowercased() == "icns" {
            try FileManager.default.copyItem(at: source, to: destination)
            return
        }

        guard let image = NSImage(contentsOf: source), image.isValid else {
            throw IconAssetBuilderError.unreadableImage
        }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("tuidotapp-icon-\(UUID().uuidString)", isDirectory: true)
        let iconset = temporaryRoot.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        for representation in representations {
            let data = try pngData(image: image, pixels: representation.pixels)
            try data.write(
                to: iconset.appendingPathComponent(representation.name),
                options: .atomic
            )
        }

        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw IconAssetBuilderError.iconutilFailed(message)
        }
    }

    private static func pngData(image: NSImage, pixels: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw IconAssetBuilderError.encodingFailed
        }

        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw IconAssetBuilderError.encodingFailed
        }
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
        image.draw(
            in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        context.flushGraphics()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw IconAssetBuilderError.encodingFailed
        }
        return data
    }
}
