import Testing
@testable import ZomeKit

@Suite("Vec + plane math")
struct VecTests {
    @Test func crossProductIsRightHanded() {
        #expect(Vec3.cross(Vec3(1, 0, 0), Vec3(0, 1, 0)) == Vec3(0, 0, 1))
    }

    @Test func lengthAndNormalize() {
        let v = Vec3(3, 4, 0)
        #expect(approx(v.length, 5))
        #expect(approx(v.normalized.length, 1))
    }

    @Test func midpoint() {
        #expect(Vec3.midpoint(Vec3(0, 0, 0), Vec3(2, 4, 6)) == Vec3(1, 2, 3))
    }

    @Test("Plane through 3 points + line/plane intersection drops a perpendicular ray onto the XY plane")
    func planeAndIntersection() {
        let plane = Plane(through: Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0))
        let hit = intersection(point: Vec3(2, 3, 5), direction: Vec3(0, 0, -1), plane: plane)
        #expect(approx(hit.x, 2))
        #expect(approx(hit.y, 3))
        #expect(approx(hit.z, 0))
    }
}

func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-12) -> Bool {
    abs(a - b) <= tolerance
}
