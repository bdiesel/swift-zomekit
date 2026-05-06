import Foundation
import CoreGraphics
import RealityKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import ZomeKit

/// Visual style for the dome's timbers.
public enum TimberAppearance: String, CaseIterable, Identifiable, Sendable {
    /// Each unique cut-list size gets a stable hue from the rainbow palette.
    /// Useful while designing — at-a-glance correlation with the cut list.
    case rainbow
    /// Procedural wood-grain texture tinted with a warm oak base color.
    /// Useful for client renderings / immersive walk-through.
    case wood

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .rainbow: return "Rainbow"
        case .wood:    return "Wood"
        }
    }
}

/// Build double-sided `PhysicallyBasedMaterial`s for the dome's timbers.
/// Materials are double-sided (`faceCulling = .none`) so the dome reads
/// cleanly from inside (visionOS walk-through) AND from outside (orbit).
@MainActor
public enum TimberMaterials {
    /// Resolve a material for a single timber under the chosen appearance.
    public static func material(
        for timber: ZomeTimber,
        appearance: TimberAppearance
    ) -> PhysicallyBasedMaterial {
        switch appearance {
        case .rainbow: return rainbowMaterial(for: timber)
        case .wood:    return woodMaterial()
        }
    }

    /// Procedurally generate a tileable wood-grain CGImage. Pure CoreGraphics
    /// — runs on any actor. Returned as a near-grayscale image so callers
    /// can tint it through `PhysicallyBasedMaterial.BaseColor.init(tint:texture:)`.
    public nonisolated static func makeWoodCGImage(
        width: Int = 512,
        height: Int = 64
    ) -> CGImage? {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }

        // Light base — the material multiplies this by the tint colour.
        ctx.setFillColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Deterministic pseudo-grain: a stack of darker vertical stripes whose
        // x positions, widths, and shades come from sin() so the result is
        // identical across runs (no RNG seeded against process startup).
        let stripeCount = 90
        for i in 0..<stripeCount {
            let phase = Double(i) * 1.71
            let xNorm = (sin(phase) * 0.5 + 0.5)
            let xPos  = Int(xNorm * Double(width)) % width
            let darkness = 0.04 + 0.22 * abs(sin(phase * 0.61))
            let stripeWidth = max(1, Int(3.0 * abs(sin(phase * 1.13))))
            ctx.setFillColor(
                red:   CGFloat(0.86 - darkness),
                green: CGFloat(0.86 - darkness),
                blue:  CGFloat(0.86 - darkness),
                alpha: 1.0
            )
            ctx.fill(CGRect(x: xPos, y: 0, width: stripeWidth, height: height))
        }

        // A few faint highlight streaks.
        for i in 0..<8 {
            let phase = Double(i) * 4.21 + 0.7
            let xNorm = (sin(phase) * 0.5 + 0.5)
            let xPos  = Int(xNorm * Double(width)) % width
            let lightness = 0.05
            ctx.setFillColor(
                red:   CGFloat(0.86 + lightness),
                green: CGFloat(0.86 + lightness),
                blue:  CGFloat(0.86 + lightness),
                alpha: 1.0
            )
            ctx.fill(CGRect(x: xPos, y: 0, width: 1, height: height))
        }

        return ctx.makeImage()
    }

    // MARK: - Internals

    private static var cachedWoodTexture: TextureResource?

    private static func sharedWoodTexture() -> TextureResource? {
        if let cached = cachedWoodTexture { return cached }
        guard let image = makeWoodCGImage() else { return nil }
        let tex = try? TextureResource.generate(
            from: image,
            options: .init(semantic: .color)
        )
        cachedWoodTexture = tex
        return tex
    }

    private static func rainbowMaterial(for timber: ZomeTimber) -> PhysicallyBasedMaterial {
        var pbr = PhysicallyBasedMaterial()
        pbr.baseColor = .init(tint: RainbowPalette.color(for: timber))
        pbr.roughness = .init(floatLiteral: 0.6)
        pbr.metallic = .init(floatLiteral: 0.0)
        pbr.faceCulling = .none
        return pbr
    }

    private static func woodMaterial() -> PhysicallyBasedMaterial {
        var pbr = PhysicallyBasedMaterial()
        let oak = PlatformColor(red: 0.66, green: 0.46, blue: 0.28, alpha: 1.0)
        if let tex = sharedWoodTexture() {
            pbr.baseColor = .init(tint: oak, texture: .init(tex))
        } else {
            pbr.baseColor = .init(tint: oak)
        }
        pbr.roughness = .init(floatLiteral: 0.75)
        pbr.metallic = .init(floatLiteral: 0.0)
        pbr.faceCulling = .none
        return pbr
    }
}
