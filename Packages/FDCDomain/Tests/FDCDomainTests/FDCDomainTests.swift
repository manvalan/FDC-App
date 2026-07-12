import XCTest
@testable import FDCDomain

final class FDCDomainTests: XCTestCase {
    func testElectrificationTypeIsElectrified() {
        XCTAssertTrue(ElectrificationType.dc3kv.isElectrified)
        XCTAssertFalse(ElectrificationType.none.isElectrified)
    }

    func testTrackSegmentDefaults() {
        let segment = TrackSegment(order: 0, length: 100)
        XCTAssertFalse(segment.isOccupied)
        XCTAssertNil(segment.signal)
    }
}
