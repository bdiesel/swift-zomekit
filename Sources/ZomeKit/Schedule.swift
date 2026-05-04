import Foundation

/// A grouped row in the cut list — one row per unique (length, cutAngleA, cutAngleB) bucket.
public struct CutListEntry: Equatable, Sendable {
    public let label: String          // "T1" (longest) … "TN"
    public let quantity: Int
    public let length: Double
    public let cutAngleA: Double      // degrees, sorted ascending so flipped pieces hash together
    public let cutAngleB: Double
    public let width: Double
    public let thickness: Double
    public let faceLabels: String     // e.g. "C0/C1"
}

/// Cut-list grouping with bucket precision matching the Ruby/JS reference:
/// 1/16" on length, 0.5° on miter angle.
public enum CutList {
    public static let lengthPrecisionInches: Double = 1.0 / 16.0
    public static let angleStepDegrees: Double = 0.5

    /// Group identical timbers across all faces in the wedge, multiply by `numSpirals`,
    /// and sort longest first.
    public static func build(
        geometry: ZomeGeometry,
        params: ZomeParameters
    ) -> [CutListEntry] {
        struct Group {
            var count: Int = 0
            var sample: (length: Double, cutA: Double, cutB: Double)? = nil
            var faceLabels: Set<String> = []
        }

        var groups: [BucketKey: Group] = [:]

        for (fi, timbers) in geometry.faceTimbers.enumerated() {
            let faceLabel = geometry.faces[fi].label
            for t in timbers {
                let m = measure(t)
                let key = bucketKey(length: m.length, cutA: m.cutA, cutB: m.cutB)
                var g = groups[key, default: Group()]
                g.count += 1
                if g.sample == nil { g.sample = m }
                g.faceLabels.insert(faceLabel)
                groups[key] = g
            }
        }

        var rows: [CutListEntry] = groups.compactMap { (_, g) in
            guard let s = g.sample else { return nil }
            return CutListEntry(
                label: "",
                quantity: g.count * params.numSpirals,
                length: s.length,
                cutAngleA: s.cutA,
                cutAngleB: s.cutB,
                width: params.timberWidth,
                thickness: params.timberThickness,
                faceLabels: g.faceLabels.sorted().joined(separator: "/")
            )
        }

        rows.sort { $0.length > $1.length }
        return rows.enumerated().map { (i, r) in
            CutListEntry(
                label: "T\(i + 1)",
                quantity: r.quantity,
                length: r.length,
                cutAngleA: r.cutAngleA,
                cutAngleB: r.cutAngleB,
                width: r.width,
                thickness: r.thickness,
                faceLabels: r.faceLabels
            )
        }
    }

    /// Returns long-axis length and the two cap miter angles (degrees), sorted ascending.
    /// Cap angle = angle between the cap's normal and the long axis. 0 = square cut.
    public static func measure(_ timber: ZomeTimber) -> (length: Double, cutA: Double, cutB: Double) {
        let leftCenter = quadCenter(timber.a, timber.b, timber.f, timber.e)
        let rightCenter = quadCenter(timber.c, timber.d, timber.h, timber.g)
        let longAxis = rightCenter - leftCenter
        let length = longAxis.length

        let cutLeft = capAngleDeg(cap: [timber.a, timber.b, timber.f, timber.e], longAxis: longAxis)
        let cutRight = capAngleDeg(cap: [timber.c, timber.d, timber.h, timber.g], longAxis: longAxis)
        let sorted = [cutLeft, cutRight].sorted()
        return (length, sorted[0], sorted[1])
    }

    /// Format an inch value as `12'-7 1/16"` with 1/16" granularity.
    /// Convenience for an inch-based UI; ZomeKit math itself is unit-agnostic.
    public static func formatInches(_ value: Double) -> String {
        let sixteenths = Int((value * 16).rounded())
        let feet = sixteenths / (12 * 16)
        let rem = sixteenths - feet * 12 * 16
        let inch = rem / 16
        var num = rem - inch * 16
        var den = 16
        var frac = ""
        if num != 0 {
            while num.isMultiple(of: 2) && den.isMultiple(of: 2) {
                num /= 2; den /= 2
            }
            frac = " \(num)/\(den)"
        }
        return "\(feet > 0 ? "\(feet)'-" : "")\(inch)\(frac)\""
    }

    /// Render a cut list as a CSV string (no file I/O).
    public static func csv(_ rows: [CutListEntry]) -> String {
        var out = "Label,Qty,Length,Length (in),Width,Thickness,Cut A (deg),Cut B (deg),Faces\n"
        for r in rows {
            out += "\(r.label),\(r.quantity),"
            out += "\(round4(r.length)),\(formatInches(r.length)),"
            out += "\(r.width),\(r.thickness),"
            out += "\(round2(r.cutAngleA)),\(round2(r.cutAngleB)),"
            out += "\(r.faceLabels)\n"
        }
        return out
    }

    public static func totals(_ rows: [CutListEntry]) -> (pieceCount: Int, linearUnits: Double) {
        let pieces = rows.reduce(0) { $0 + $1.quantity }
        let linear = rows.reduce(0.0) { $0 + Double($1.quantity) * $1.length }
        return (pieces, linear)
    }

    // MARK: - Internals

    struct BucketKey: Hashable {
        let l: Int
        let a: Int
        let b: Int
    }

    static func bucketKey(length: Double, cutA: Double, cutB: Double) -> BucketKey {
        BucketKey(
            l: Int((length / lengthPrecisionInches).rounded()),
            a: Int((cutA / angleStepDegrees).rounded()),
            b: Int((cutB / angleStepDegrees).rounded())
        )
    }

    private static func quadCenter(_ p0: Vec3, _ p1: Vec3, _ p2: Vec3, _ p3: Vec3) -> Vec3 {
        (p0 + p1 + p2 + p3) * 0.25
    }

    private static func capAngleDeg(cap: [Vec3], longAxis: Vec3) -> Double {
        let n = Vec3.cross(cap[1] - cap[0], cap[2] - cap[0])
        let cosA = min(1.0, abs((n.normalized * longAxis.normalized).sum()))
        return acos(cosA) * 180.0 / .pi
    }

    private static func round4(_ v: Double) -> Double { (v * 10_000).rounded() / 10_000 }
    private static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
}
