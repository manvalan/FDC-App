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

    func testRailwayTopologyPathfinding() {
        let n1 = Node(id: "A", name: "A", type: .station)
        let n2 = Node(id: "B", name: "B", type: .station)
        let edge = Edge(from: "A", to: "B", distance: 10, trackType: .regional, maxSpeed: 100)
        let topology = RailwayTopology(nodes: [n1, n2], edges: [edge])
        XCTAssertEqual(topology.findPathEdges(from: "A", to: "B")?.count, 1)
    }
}
