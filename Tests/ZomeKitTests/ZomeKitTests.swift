import Testing
@testable import ZomeKit

/// Golden-value tests for the GoodKarma default zome from the reference
/// screenshot (10-spiral, θ=53.25°, K=1, h_ratio=0.7, height=122").
/// Reference numbers:
///   - 270 timbers total (27 per spiral × 10 spirals)
///   - 16 unique sizes in the cut list
///   - envelope 10'-2" × 12'-7 1/16"  (height 122", diameter 151.0625")
@Suite("Zome golden defaults")
struct ZomeKitTests {
    @Test func derivedQuantitiesFromDefaults() {
        let p = ZomeParameters.goodKarmaDefault
        #expect(p.numSpirals == 10)
        #expect(approx(p.kSum, 10.0))                       // K=1 → kSum = N
        #expect(approx(p.totalHeight, 122.0 / 0.7, tolerance: 1e-9))
        #expect(p.firstCrownRadius > 0)
        #expect(p.firstCrownHeight > 0)
    }

    @Test func envelopeMatchesReferenceScreenshot() {
        let geom = Zome.build(.goodKarmaDefault)
        #expect(approx(geom.envelope.height, 122.0, tolerance: 0.01))
        #expect(approx(geom.envelope.diameter, 151.0625, tolerance: 1.0))
    }

    @Test("270 timbers: 27 per spiral × 10 spirals")
    func defaultTimberCount() {
        let geom = Zome.build(.goodKarmaDefault)
        let total = geom.envelope.timbersPerSpiral * geom.parameters.numSpirals
        #expect(total == 270)
    }

    @Test("16 unique sizes in the cut list")
    func defaultCutListUniqueSizes() {
        let geom = Zome.build(.goodKarmaDefault)
        let rows = CutList.build(geometry: geom, params: geom.parameters)
        #expect(rows.count == 16)
        let pieces = rows.reduce(0) { $0 + $1.quantity }
        #expect(pieces == 270)
    }

    @Test func cutListIsSortedLongestFirstAndLabelled() {
        let geom = Zome.build(.goodKarmaDefault)
        let rows = CutList.build(geometry: geom, params: geom.parameters)
        for i in 1..<rows.count {
            #expect(rows[i - 1].length >= rows[i].length)
        }
        #expect(rows.first?.label == "T1")
    }

    @Test func everyFaceHasOneTimberPerEdgeAnd8Corners() {
        let geom = Zome.build(.goodKarmaDefault)
        #expect(!geom.faces.isEmpty)
        #expect(geom.faces.count == geom.faceTimbers.count)
        for (face, timbers) in zip(geom.faces, geom.faceTimbers) {
            #expect(timbers.count == face.points.count)
            for t in timbers { #expect(t.points.count == 8) }
        }
    }

    @Test func firstCrownFaceTouchesApex() {
        let geom = Zome.build(.goodKarmaDefault)
        let zh = geom.parameters.zomeHeight
        let firstFace = try! #require(geom.faces.first)
        let hasApex = firstFace.points.contains {
            abs($0.x) < 1e-9 && abs($0.z) < 1e-9 && abs($0.y - zh) < 1e-9
        }
        #expect(hasApex)
    }
}
