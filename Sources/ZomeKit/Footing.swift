import Foundation

extension Zome {
    /// Build footing prisms for the dome's ground-contacting faces.
    ///
    /// One 8-vertex prism per ground face in the first-spiral wedge — the
    /// caller rotates each by `geometry.rotationAngles` to populate every
    /// spiral. Each prism extends straight down from the timber's bottom
    /// edge to a floor plane sitting `params.timberThickness` *below* the
    /// lowest timber corner across the wedge (matches z5omes' `add_footing=1`
    /// behaviour).
    ///
    /// Vertex layout matches `ZomeTimber` (A..H): A,C,E,G are the four
    /// corners on the floor plane; B,D,F,H are the four corners at the
    /// timber's existing bottom edge.
    public static func footings(
        for geometry: ZomeGeometry,
        params: ZomeParameters
    ) -> [ZomeTimber] {
        var lowestY = Double.infinity
        var candidates: [(b: Vec3, d: Vec3, f: Vec3, h: Vec3)] = []

        for (fi, face) in geometry.faces.enumerated() {
            guard touchesGround(face: face, index: fi, allFaces: geometry.faces) else {
                continue
            }
            let timbers = geometry.faceTimbers[fi]
            let bottomIndex = bottomTimberIndex(for: face)
            guard bottomIndex < timbers.count else { continue }
            let timber = timbers[bottomIndex]

            // Use the timber's outer-top and inner-top corners. Matches the
            // Ruby reference: B=A, D=B (outer top), F=E, H=F (inner top).
            let b = timber.a
            let d = timber.b
            let f = timber.e
            let h = timber.f

            for p in [b, d, f, h] {
                if p.y < lowestY { lowestY = p.y }
            }
            candidates.append((b, d, f, h))
        }

        guard !candidates.isEmpty, lowestY.isFinite else { return [] }

        let floorY = lowestY - params.timberThickness
        let floorPlane = Plane(a: 0, b: 1, c: 0, d: -floorY)
        let down = Vec3(0, -1, 0)

        return candidates.map { c in
            let a = intersection(point: c.b, direction: down, plane: floorPlane)
            let cv = intersection(point: c.d, direction: down, plane: floorPlane)
            let e = intersection(point: c.f, direction: down, plane: floorPlane)
            let g = intersection(point: c.h, direction: down, plane: floorPlane)
            return ZomeTimber(points: [a, c.b, cv, c.d, e, c.f, g, c.h])
        }
    }

    /// Edge-index within the per-face timbers array that corresponds to the
    /// face's ground-touching edge. Matches the Ruby reference.
    private static func bottomTimberIndex(for face: ZomeFace) -> Int {
        switch face.points.count {
        case 3: return 0           // closing triangle
        case 4: return 2           // bottom kite — last edge of A,B,D,C
        case 5: return 2           // truncated kite — bottom horizontal edge
        default: return 0
        }
    }

    /// True if `face` lies on the ground ring of the wedge. Heuristic
    /// ported from Ruby's face_touches_ground?: the very last face of
    /// the wedge is always a candidate, plus 4-point bindu-bottom rhombi
    /// that have a vertex at Y≈0.
    private static func touchesGround(
        face: ZomeFace,
        index: Int,
        allFaces: [ZomeFace]
    ) -> Bool {
        let n = face.points.count
        let isLast = index + 1 == allFaces.count
        if (n == 3 || n == 5) && isLast { return true }
        if n == 4 && isLast {
            return face.points.contains { abs($0.y) < 0.01 }
        }
        return false
    }
}
