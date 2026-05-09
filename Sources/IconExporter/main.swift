import Foundation
#if canImport(AppKit)
import AppKit
import SwiftUI
import ZomeKit
import ZomeRendering

@MainActor
struct IconExport {
    let dir: URL

    static func main() {
        let argDir = CommandLine.arguments.dropFirst().first ?? "/tmp/zome-icon"
        let url = URL(fileURLWithPath: argDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let exporter = IconExport(dir: url)
        exporter.run()
    }

    func run() {
        // Composite icon at every pixel size Mac AppIcon.appiconset wants
        // (16/32/64/128/256/512/1024). Rendered at exact pixel dimensions
        // so each is independently anti-aliased rather than scaled down
        // from a single master.
        export(ZomeIcon(),            name: "zome-icon-1024.png",   size: 1024)
        export(ZomeIcon(),            name: "zome-icon-512.png",     size: 512)
        export(ZomeIcon(),            name: "zome-icon-256.png",     size: 256)
        export(ZomeIcon(),            name: "zome-icon-128.png",     size: 128)
        export(ZomeIcon(),            name: "zome-icon-64.png",      size: 64)
        export(ZomeIcon(),            name: "zome-icon-32.png",      size: 32)
        export(ZomeIcon(),            name: "zome-icon-16.png",      size: 16)

        // Per-layer renders for the visionOS solid-image-stack asset.
        export(ZomeIconBackLayer(),   name: "zome-icon-back-1024.png",   size: 1024)
        export(ZomeIconMiddleLayer(), name: "zome-icon-middle-1024.png", size: 1024)
        export(ZomeIconFrontLayer(),  name: "zome-icon-front-1024.png",  size: 1024)

        print("\nDone — \(dir.path)")
    }

    private func export(_ view: some View, name: String, size: CGFloat) {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1
        guard let cg = renderer.cgImage else {
            print("✗ \(name): ImageRenderer produced no image"); return
        }
        guard let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            print("✗ \(name): PNG encoding failed"); return
        }
        do {
            try data.write(to: dir.appendingPathComponent(name))
            print("✓ \(name)")
        } catch {
            print("✗ \(name): \(error.localizedDescription)")
        }
    }
}

IconExport.main()
#else
print("IconExporter is macOS-only.")
#endif
