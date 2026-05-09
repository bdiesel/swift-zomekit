import Foundation

/// How timber prisms are framed against the dome's faces.
///
/// Ports z5omes' `assembly_method` parameter (core.js Polygon3D.compute_framework).
/// All three modes produce the same N timbers per face, just shaped differently
/// — same vertex layout (`A..H`), so callers don't need to know the mode.
public enum AssemblyMethod: Int, Codable, Sendable, CaseIterable, Identifiable {
    /// Each timber's faces are framed with planes through a single vanishing
    /// point. Cleanest miter-only joinery; the most-built historical style.
    case goodKarma = 0
    /// Like GoodKarma but uses the face-vertex angle (θ) to compute a
    /// pivoted offset, giving timbers that bevel against their neighbors
    /// rather than miter through them. Auto-clamps thickness when the
    /// opposite-face geometry would otherwise exceed `timberThickness`.
    case beveled = 1
    /// Same θ-based pivoted offset as Beveled, but uses the vertical
    /// projection (not the vanishing point) for the wall plane — giving
    /// outward-pointing timbers, useful for inverted / "outward-expansion"
    /// constructions. Top and bottom of each prism are swapped versus the
    /// other modes.
    case xpansion = 2

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .goodKarma: return "GoodKarma"
        case .beveled:   return "Beveled"
        case .xpansion:  return "Xpansion"
        }
    }
}
