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
}
