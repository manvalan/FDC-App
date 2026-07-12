import XCTest
@testable import FdC_Railway_Manager

@MainActor
final class TrackLayoutTests: XCTestCase {

    func test_applyTrackLayout_highSpeedPairedToSingle_removesPartnerWithoutCrash() {
        let railroad = RailroadNetwork()
        let parentA = Node(id: "A", name: "Alpha", type: .station)
        let avA = Node(
            id: "A_AV", name: "Alpha AV", type: .station,
            parentHubId: "A", hubOffsetDirection: .bottomRight
        )
        let parentB = Node(id: "B", name: "Beta", type: .station)
        let avB = Node(
            id: "B_AV", name: "Beta AV", type: .station,
            parentHubId: "B", hubOffsetDirection: .bottomRight
        )
        railroad.network.nodes = [parentA, avA, parentB, avB]

        let bwdId = UUID()
        let fwdId = UUID()
        // Partner listed before anchor — previously caused stale-index crash in dissolvePair.
        let bwd = Edge(
            id: bwdId, from: "B_AV", to: "A_AV",
            distance: 10, trackType: .highSpeed, maxSpeed: 300,
            pairedEdgeId: fwdId
        )
        let fwd = Edge(
            id: fwdId, from: "A_AV", to: "B_AV",
            distance: 10, trackType: .highSpeed, maxSpeed: 300,
            pairedEdgeId: bwdId
        )
        railroad.network.edges = [bwd, fwd]

        railroad.applyTrackLayout(.single, to: fwdId, singleMaxSpeed: 120, highSpeedMaxSpeed: 300)

        XCTAssertEqual(railroad.network.edges.count, 1)
        let remaining = railroad.network.edges[0]
        XCTAssertEqual(remaining.id, fwdId)
        XCTAssertEqual(remaining.trackType, .single)
        XCTAssertNil(remaining.pairedEdgeId)
        XCTAssertEqual(remaining.from, "A")
        XCTAssertEqual(remaining.to, "B")
    }

    func test_applyTrackLayout_unpairedHighSpeedToSingle_remapsHubEndpoints() {
        let railroad = RailroadNetwork()
        let parent = Node(id: "MIL", name: "Milano", type: .station)
        let av = Node(
            id: "MIL_AV", name: "Milano AV", type: .station,
            parentHubId: "MIL", hubOffsetDirection: .bottomRight
        )
        let other = Node(id: "X", name: "Other", type: .station)
        railroad.network.nodes = [parent, av, other]

        let edgeId = UUID()
        railroad.network.edges = [
            Edge(id: edgeId, from: "MIL_AV", to: "X", distance: 5, trackType: .highSpeed, maxSpeed: 300)
        ]

        railroad.applyTrackLayout(.single, to: edgeId, singleMaxSpeed: 120, highSpeedMaxSpeed: 300)

        let edge = railroad.network.edges[0]
        XCTAssertEqual(edge.trackType, .single)
        XCTAssertEqual(edge.from, "MIL")
        XCTAssertEqual(edge.to, "X")
    }
}
