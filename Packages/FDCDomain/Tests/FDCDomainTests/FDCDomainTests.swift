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

    func testNetworkTopologyService_neighborStationsSkipsJunctions() {
        let hub = Node(id: "H", name: "Hub", type: .junction)
        let a = Node(id: "A", name: "A", type: .station)
        let b = Node(id: "B", name: "B", type: .station)
        let e1 = Edge(from: "A", to: "H", distance: 1, trackType: .regional, maxSpeed: 80)
        let e2 = Edge(from: "H", to: "B", distance: 1, trackType: .regional, maxSpeed: 80)
        let service = NetworkTopologyService(nodes: [a, hub, b], edges: [e1, e2])

        XCTAssertEqual(Set(service.getNeighborStations(for: "A")), ["B"])
    }

    func testNetworkTopologyService_calculateDistance() {
        let n1 = Node(id: "A", name: "A", type: .station, latitude: 0, longitude: 0)
        let n2 = Node(id: "B", name: "B", type: .station, latitude: 1, longitude: 0)
        let service = NetworkTopologyService(nodes: [n1, n2], edges: [])

        XCTAssertGreaterThan(service.calculateDistance(from: n1, to: n2), 0)
    }

    func testScheduleConflictIdentifiable() {
        let conflict = ScheduleConflict(
            trainAId: UUID(), trainBId: UUID(),
            trainAName: "A", trainBName: "B",
            locationType: .station,
            locationName: "Hub", locationId: "TRACK::B::1",
            timeStart: Date(), timeEnd: Date().addingTimeInterval(300),
            capacity: 1, occupantsCount: 2
        )
        XCTAssertFalse(conflict.id.isEmpty)
    }

    func testHubTopology_resolvesClassicAndAVEndpoints() {
        let parent = Node(id: "MIL", name: "Milano", type: .station, latitude: 45.0, longitude: 9.0)
        let satellite = Node(
            id: "MIL_AV", name: "Milano AV", type: .station,
            latitude: 45.0, longitude: 9.0,
            parentHubId: "MIL", hubOffsetDirection: .topRight
        )
        let hub = HubTopology(nodes: [parent, satellite])

        XCTAssertEqual(hub.endpointNodeId(for: "MIL", trackType: .regional), "MIL")
        XCTAssertEqual(hub.endpointNodeId(for: "MIL", trackType: .highSpeed), "MIL_AV")
        XCTAssertEqual(hub.endpointNodeId(for: "MIL_AV", trackType: .regional), "MIL")
        XCTAssertEqual(hub.endpointNodeId(for: "MIL_AV", trackType: .highSpeed), "MIL_AV")
        XCTAssertEqual(hub.hubVisualRole(for: parent), .classicCenter)
        XCTAssertEqual(hub.hubVisualRole(for: satellite), .avSatellite)
    }

    func testHubTopology_canvasOffsetEightPositions() {
        XCTAssertEqual(HubTopology.canvasOffset(for: .top).y, -25)
        XCTAssertEqual(HubTopology.canvasOffset(for: .right).x, 25)
        XCTAssertEqual(HubTopology.canvasOffset(for: .topLeft).x, -25)
    }
}
