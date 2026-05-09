import Testing
import Foundation
@testable import ZomeKit

@Suite("Assembly methods")
struct AssemblyMethodTests {
    private static let baseParams = ZomeParameters.goodKarmaDefault

    @Test("All three methods produce the same timber count for the default zome")
    func sameCountAcrossMethods() {
        let counts = AssemblyMethod.allCases.map { method in
            var p = Self.baseParams
            p.assemblyMethod = method
            return Zome.build(p).envelope.timbersPerSpiral
        }
        // All counts equal — methods just shape timbers differently, they
        // don't add or remove edges.
        for c in counts { #expect(c == counts[0]) }
    }

    @Test("Every timber has 8 finite vertices in every mode")
    func vertexValidityAcrossModes() {
        for method in AssemblyMethod.allCases {
            var p = Self.baseParams
            p.assemblyMethod = method
            let geom = Zome.build(p)
            for face in geom.faceTimbers {
                for timber in face {
                    #expect(timber.points.count == 8)
                    for v in timber.points {
                        #expect(v.x.isFinite)
                        #expect(v.y.isFinite)
                        #expect(v.z.isFinite)
                    }
                }
            }
        }
    }

    @Test("Beveled produces a different first-timber shape than GoodKarma")
    func beveledDiffersFromGoodKarma() {
        var pgk = Self.baseParams; pgk.assemblyMethod = .goodKarma
        var pbv = Self.baseParams; pbv.assemblyMethod = .beveled

        let gk = Zome.build(pgk).faceTimbers[0][0]
        let bv = Zome.build(pbv).faceTimbers[0][0]

        // At least one vertex differs by a meaningful amount — pure equality
        // would mean Beveled silently fell through to the GoodKarma branch.
        var differs = false
        for (a, b) in zip(gk.points, bv.points) {
            if (a - b).length > 1e-6 { differs = true; break }
        }
        #expect(differs)
    }

    @Test("Xpansion swaps the prism's top/bottom (E..H sit on the dome's outer surface)")
    func xpansionFlipsTopAndBottom() {
        var pgk = Self.baseParams; pgk.assemblyMethod = .goodKarma
        var px  = Self.baseParams; px.assemblyMethod  = .xpansion

        let gk = Zome.build(pgk).faceTimbers[0][0]
        let xp = Zome.build(px).faceTimbers[0][0]

        // GoodKarma: A,B,C,D = outer; E,F,G,H = inner.
        // Xpansion:  swap → outer corners now in E..H slots.
        // Compare the y-extents of the two sets — if Xpansion's "A..D"
        // are on average lower (more inward) than its "E..H", the swap
        // happened. Use centroid Y.
        let gkOuterY = (gk.a.y + gk.b.y + gk.c.y + gk.d.y) / 4
        let xpEFGHY  = (xp.e.y + xp.f.y + xp.g.y + xp.h.y) / 4
        #expect(approx(gkOuterY, xpEFGHY, tolerance: 0.05) || abs(gkOuterY - xpEFGHY) < 0.5,
                "Xpansion E..H Y should align (within reason) with GoodKarma A..D Y")
    }

    @Test("Codable round-trip preserves assemblyMethod")
    func codableRoundTrip() throws {
        var p = Self.baseParams
        p.assemblyMethod = .beveled

        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(ZomeParameters.self, from: data)
        #expect(decoded.assemblyMethod == .beveled)
        #expect(decoded == p)
    }

    @Test("Old .zome JSON without assemblyMethod decodes to .goodKarma")
    func backwardCompatibilityForOldFiles() throws {
        let oldJson = """
        {
          "numSpirals": 10,
          "thetaDegrees": 53.25,
          "kiteRatio": 1.0,
          "heightRatio": 0.7,
          "zomeHeight": 122.0,
          "timberWidth": 3.5,
          "timberThickness": 1.5,
          "binduRatios": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ZomeParameters.self, from: oldJson)
        #expect(decoded.assemblyMethod == .goodKarma)
        #expect(decoded.numSpirals == 10)
    }
}
