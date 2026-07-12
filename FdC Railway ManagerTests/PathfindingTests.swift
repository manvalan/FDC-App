import XCTest
@testable import FdC_Railway_Manager

final class PathfindingTests: XCTestCase {

    func test_findShortestPath_twoNodes_returnsDirectPath() {
        let n1 = Node(id: "A", name: "A", type: .station, latitude: 0, longitude: 0)
        let n2 = Node(id: "B", name: "B", type: .station, latitude: 0, longitude: 1)
        let edge = Edge(from: "A", to: "B", distance: 10, trackType: .regional, maxSpeed: 100)

        let result = NetworkPathfinder.findShortestPath(
            from: "A", to: "B", nodes: [n1, n2], edges: [edge]
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.0, ["A", "B"])
        XCTAssertEqual(result!.1, 10, accuracy: 0.001)
    }

    func test_railwayTopology_findPathEdges_delegatesToPathfinder() {
        let n1 = Node(id: "A", name: "A", type: .station, latitude: 0, longitude: 0)
        let n2 = Node(id: "B", name: "B", type: .station, latitude: 0, longitude: 1)
        let edge = Edge(from: "A", to: "B", distance: 5, trackType: .regional, maxSpeed: 80)
        let topology = RailwayTopology(nodes: [n1, n2], edges: [edge])

        let path = topology.findPathEdges(from: "A", to: "B")

        XCTAssertEqual(path?.count, 1)
        XCTAssertEqual(path?.first?.from, "A")
        XCTAssertEqual(path?.first?.to, "B")
    }

    func test_networkTopologyService_calculateDistance() {
        let n1 = Node(id: "A", name: "A", type: .station, latitude: 0, longitude: 0)
        let n2 = Node(id: "B", name: "B", type: .station, latitude: 1, longitude: 0)
        let service = NetworkTopologyService(nodes: [n1, n2], edges: [])

        XCTAssertGreaterThan(service.calculateDistance(from: n1, to: n2), 0)
    }

    func test_neighborStations_skipsJunctions() {
        let hub = Node(id: "H", name: "Hub", type: .junction)
        let a = Node(id: "A", name: "A", type: .station)
        let b = Node(id: "B", name: "B", type: .station)
        let e1 = Edge(from: "A", to: "H", distance: 1, trackType: .regional, maxSpeed: 80)
        let e2 = Edge(from: "H", to: "B", distance: 1, trackType: .regional, maxSpeed: 80)
        let service = NetworkTopologyService(nodes: [a, hub, b], edges: [e1, e2])

        let neighbors = Set(service.getNeighborStations(for: "A"))

        XCTAssertEqual(neighbors, ["B"])
    }
}
