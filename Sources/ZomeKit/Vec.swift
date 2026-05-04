import Foundation

public typealias Vec3 = SIMD3<Double>

extension Vec3 {
    public static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        Vec3(a.y * b.z - a.z * b.y,
             a.z * b.x - a.x * b.z,
             a.x * b.y - a.y * b.x)
    }

    public var length: Double { (self * self).sum().squareRoot() }

    public var normalized: Vec3 {
        let l = length
        return l == 0 ? self : self / l
    }

    public func distance(to other: Vec3) -> Double { (other - self).length }

    public static func midpoint(_ a: Vec3, _ b: Vec3) -> Vec3 { (a + b) * 0.5 }

    /// Point at signed distance `d` from `origin` along the direction of `vec` (vec is normalized).
    public static func point(from origin: Vec3, towards vec: Vec3, distance d: Double) -> Vec3 {
        origin + vec.normalized * d
    }
}

/// Plane in implicit form: `a x + b y + c z + d = 0`.
public struct Plane: Equatable, Sendable {
    public let a, b, c, d: Double

    public init(a: Double, b: Double, c: Double, d: Double) {
        self.a = a; self.b = b; self.c = c; self.d = d
    }

    /// Plane through three points; normal is `(p2-p1) × (p3-p1)`.
    public init(through p1: Vec3, _ p2: Vec3, _ p3: Vec3) {
        let n = Vec3.cross(p2 - p1, p3 - p1)
        self.a = n.x; self.b = n.y; self.c = n.z
        self.d = -((n * p1).sum())
    }

    public var normal: Vec3 { Vec3(a, b, c) }
}

/// Intersection of the line `p + t · v` with `plane`. Mirrors `plan_intersection` in z5omes core.js.
/// The line is assumed not parallel to the plane (denominator non-zero).
public func intersection(point p: Vec3, direction v: Vec3, plane: Plane) -> Vec3 {
    let denom = plane.a * v.x + plane.b * v.y + plane.c * v.z
    let t = -(plane.a * p.x + plane.b * p.y + plane.c * p.z + plane.d) / denom
    return p + v * t
}
