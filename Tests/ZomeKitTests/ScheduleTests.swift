import Testing
@testable import ZomeKit

@Suite("Cut list formatting")
struct ScheduleTests {
    @Test func formatsWholeFeetAndInches() {
        #expect(CutList.formatInches(122.0) == "10'-2\"")
    }

    @Test func formatsSixteenthFraction() {
        #expect(CutList.formatInches(151.0625) == "12'-7 1/16\"")
    }

    @Test func reducesEvenFractions() {
        #expect(CutList.formatInches(0.5) == "0 1/2\"")
        #expect(CutList.formatInches(12.25) == "1'-0 1/4\"")
    }

    @Test func formatsZero() {
        #expect(CutList.formatInches(0) == "0\"")
    }
}
