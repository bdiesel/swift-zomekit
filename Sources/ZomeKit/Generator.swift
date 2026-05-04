import Foundation

/// One outer-surface face of the first-spiral wedge.
/// Y is up. Points wind around the outside of the dome.
public struct ZomeFace: Equatable, Sendable {
    public let points: [Vec3]
    public let crownIndex: Int
    public let label: String
}

/// Port of `make_zome()` from z5omes/index.html — outer-shell vertex generation only.
/// Builds the `1/N`-symmetry wedge; the caller rotates it `N` times for the full dome.
struct Generator {
    let params: ZomeParameters
    private(set) var faces: [ZomeFace] = []
    private(set) var crownCount: Int = 0
    let rotationAngles: [Double]

    init(params: ZomeParameters) {
        self.params = params
        self.rotationAngles = (0..<params.numSpirals).map {
            Double($0) * 2.0 * .pi / Double(params.numSpirals)
        }
    }

    mutating func build() {
        let n = params.numSpirals
        let k = params.kiteRatio
        let zomeHeight = params.zomeHeight
        var vertices: [Vec3] = []
        vertices.append(Vec3(0, zomeHeight, 0))     // apex

        let firstRadius = params.firstCrownRadius
        let firstY = max(0.0, zomeHeight - params.firstCrownHeight)
        for i in 0..<n {
            let a = rotationAngles[i]
            vertices.append(Vec3(firstRadius * sin(a), firstY, firstRadius * cos(a)))
        }

        var hitGround = false
        var truncatedIndexes: [Int] = []
        var crownIndex = 0
        let m = n - 1

        while crownIndex < m && !hitGround {
            let firstIdxCurr = crownIndex * n + 1
            let firstIdxPrev = firstIdxCurr - n

            for spiral in 0..<n {
                let kk = (spiral + 1) % n
                let iA = (crownIndex == 0) ? 0 : firstIdxPrev + kk
                let iB = firstIdxCurr + spiral
                let iC = firstIdxCurr + kk

                let A = vertices[iA]
                let B = vertices[iB]
                let C = vertices[iC]
                let mid = Vec3.midpoint(B, C)

                // Reflect A through the midpoint of the previous crown's outer edge,
                // scaled by (1 + k) — this produces the kite's far point D.
                var D = A + (mid - A) * (1.0 + k)

                if crownIndex < params.binduRatios.count {
                    let br = params.binduRatios[crownIndex]
                    if br != 1.0 {
                        D = Vec3(D.x * br, D.y, D.z * br)
                    }
                }

                let y = roundForGroundTest(D.y)

                if y + 0.001 >= 0 {
                    let iD = vertices.count
                    vertices.append(D)
                    if spiral == 0 {
                        faces.append(ZomeFace(
                            points: [A, B, D, C],
                            crownIndex: crownIndex,
                            label: "C\(crownIndex)"
                        ))
                    }
                    let yRounded2 = (y * 100).rounded() / 100.0
                    if yRounded2 == 0 {
                        hitGround = true
                        truncatedIndexes.append(contentsOf: [iD, iD, iC])
                    }
                } else {
                    // Truncate kite by ground plane Y=0.
                    let u = -B.y / (D.y - B.y)
                    let E = B + (D - B) * u
                    let F = C + (D - C) * u
                    let iE = vertices.count; vertices.append(E)
                    let iF = vertices.count; vertices.append(F)
                    if spiral == 0 {
                        faces.append(ZomeFace(
                            points: [A, B, E, F, C],
                            crownIndex: crownIndex,
                            label: "C\(crownIndex)"
                        ))
                    }
                    truncatedIndexes.append(contentsOf: [iE, iF, iC])
                    hitGround = true
                }
            }
            crownIndex += 1
        }

        // Close the apex/top of the last ring with a triangle if the previous
        // pass left three usable indexes that aren't degenerate.
        if !truncatedIndexes.isEmpty {
            let len = truncatedIndexes.count
            let aT = vertices[truncatedIndexes[2 % len]]
            let bT = vertices[truncatedIndexes[1 % len]]
            let cT = vertices[truncatedIndexes[3 % len]]
            let dist = (bT - cT).length
            if (dist * 100).rounded() / 100.0 != 0 {
                faces.append(ZomeFace(
                    points: [aT, bT, cT],
                    crownIndex: crownIndex,
                    label: "C\(crownIndex)"
                ))
                crownIndex += 1
            }
        }

        self.crownCount = crownIndex
    }

    /// Match z5omes' `to_decimal(D[1])` rounding behaviour for the ground test.
    /// FLOAT_PRECISION = 7 in core.js.
    private func roundForGroundTest(_ y: Double) -> Double {
        let scale = 1e7
        return (y * scale).rounded() / scale
    }
}
