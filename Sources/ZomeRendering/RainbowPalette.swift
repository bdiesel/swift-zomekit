import Foundation
import SwiftUI
import ZomeKit

#if canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#endif

/// Per-timber rainbow coloring. Same timbers (same length within 1/16″ at the
/// chosen unit scale) get the same color, so cut-list groupings read at a
/// glance against the 3D model. Matches the z5omes 3D-viewport look.
public enum RainbowPalette {
    public static func color(for timber: ZomeTimber) -> PlatformColor {
        color(forLength: CutList.measure(timber).length)
    }

    /// Direct length-keyed entry point — handy for code paths (cut-list
    /// previews) that have a `CutListEntry` but not a full `ZomeTimber`.
    public static func color(forLength length: Double) -> PlatformColor {
        let h = hue(forLength: length)
        return PlatformColor(hue: CGFloat(h), saturation: 0.65, brightness: 0.78, alpha: 1.0)
    }

    public static func swiftUIColor(forLength length: Double) -> Color {
        Color(hue: hue(forLength: length), saturation: 0.65, brightness: 0.78)
    }

    private static func hue(forLength length: Double) -> Double {
        let bucket = Int((length * 16).rounded())
        return Double(stableHash(bucket) % 360) / 360.0
    }

    /// Stable across runs. `Int.hashValue` is randomised per process; this is not.
    private static func stableHash(_ value: Int) -> Int {
        // Knuth's multiplicative hash, masked to non-negative.
        let h = UInt64(bitPattern: Int64(value)) &* 2_654_435_761
        return Int(truncatingIfNeeded: h & 0x7FFF_FFFF)
    }
}
