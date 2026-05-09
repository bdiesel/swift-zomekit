import Testing
import Foundation
@testable import ZomeKit

@Suite("Footing prisms + floor slab")
struct FootingTests {
    // MARK: Floor polygon

    @Test func defaultFloorHasMatchingPolygonCount() {
        let params = ZomeParameters.goodKarmaDefault
        let geom = Zome.build(params)
        let polygon = Zome.floorPolygon(for: geom, params: params)
        // 10-spiral default — at least 10 distinct outer corners on the floor.
        #expect(polygon.count >= params.numSpirals)
    }

    @Test("All floor polygon vertices share Y")
    func floorPolygonIsHorizontal() {
        let params = ZomeParameters.goodKarmaDefault
        let geom = Zome.build(params)
        let polygon = Zome.floorPolygon(for: geom, params: params)
        guard let firstY = polygon.first?.y else { return }
        for p in polygon {
            #expect(approx(p.y, firstY, tolerance: 1e-9))
        }
    }

    @Test("Floor polygon is sorted CCW around the Y axis")
    func floorPolygonIsSortedByAngle() {
        let params = ZomeParameters.goodKarmaDefault
        let geom = Zome.build(params)
        let polygon = Zome.floorPolygon(for: geom, params: params)
        guard polygon.count > 2 else { return }
        let angles = polygon.map { atan2($0.z, $0.x) }
        for i in 1..<angles.count {
            #expect(angles[i] >= angles[i - 1])
        }
    }

    // MARK: Footing prisms

    @Test func defaultsHaveAtLeastOneFooting() {
        let params = ZomeParameters.goodKarmaDefault
        let geom = Zome.build(params)
        let footings = Zome.footings(for: geom, params: params)
        #expect(footings.count >= 1)
    }

    @Test("Each footing has 8 vertices")
    func eightVerticesPerFooting() {
        let params = ZomeParameters.goodKarmaDefault
        let geom = Zome.build(params)
        let footings = Zome.footings(for: geom, params: params)
        for f in footings {
            #expect(f.points.count == 8)
        }
    }

    @Test("All floor corners share one Y, offset below the lowest timber-bottom corner")
    func floorIsConsistentAndOffsetByTimberThickness() {
        let params = ZomeParameters.goodKarmaDefault
        let geom = Zome.build(params)
        let footings = Zome.footings(for: geom, params: params)
        guard !footings.isEmpty else { return }

        // Floor corners (A,C,E,G — positions 0,2,4,6) all sit on a single
        // horizontal plane.
        let floorYs = footings.flatMap { f in
            [f.points[0].y, f.points[2].y, f.points[4].y, f.points[6].y]
        }
        let firstY = floorYs[0]
        for y in floorYs {
            #expect(approx(y, firstY, tolerance: 1e-9))
        }

        // The lowest timber-bottom corner (B,D,F,H — positions 1,3,5,7) is
        // exactly `timberThickness` above that floor plane.
        var minBottomY = Double.infinity
        for f in footings {
            for idx in [1, 3, 5, 7] {
                if f.points[idx].y < minBottomY { minBottomY = f.points[idx].y }
            }
        }
        #expect(approx(firstY, minBottomY - params.timberThickness, tolerance: 1e-9))
    }

    @Test("Floor corners sit directly below the timber-bottom corners")
    func floorCornersAreDroppedVerticals() {
        let params = ZomeParameters.goodKarmaDefault
        let geom = Zome.build(params)
        let footings = Zome.footings(for: geom, params: params)
        for f in footings {
            // Pairs (floor, timber-bottom): (A,B), (C,D), (E,F), (G,H)
            for (floorIdx, edgeIdx) in [(0, 1), (2, 3), (4, 5), (6, 7)] {
                let floor = f.points[floorIdx]
                let edge = f.points[edgeIdx]
                #expect(approx(floor.x, edge.x, tolerance: 1e-9))
                #expect(approx(floor.z, edge.z, tolerance: 1e-9))
                #expect(floor.y < edge.y)
            }
        }
    }
}
