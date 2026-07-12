import XCTest
@testable import FdC_Railway_Manager

/// Regressione per unificazione getBestTrack → getPreferredTracks
/// (TAKTFAHRPLAN_120MIN_FIX.md, Problema 2).
@MainActor
final class TrackAssignmentTests: XCTestCase {

    private var network: NetworkModel!
    private var manager: LinesManager!

    override func setUp() {
        super.setUp()
        var node = RailwayNode(
            id: "S1", name: "Stazione Test",
            type: .station, platforms: 4
        )
        node.routingConstraints = [
            RoutingConstraint(
                routeId: "line_roma_pisa",
                directionStationId: "pisa",
                allowedTracks: ["1", "2", "3", "4"],
                transitTracks: ["3", "4"],
                stopTracks: ["1", "2"]
            ),
        ]
        network = NetworkModel(nodes: [node], edges: [])
        manager = LinesManager(network: network)
    }

    func test_getBestTrack_stop_matches_getPreferredTracks_first() {
        let node = network.nodes[0]
        let dummy = Train(
            number: 0, name: "", type: "R",
            lineId: "line_roma_pisa",
            departureTime: Date(), stops: []
        )

        let best = manager.getBestTrack(
            stationId: "S1",
            directionId: "pisa",
            routeId: "line_roma_pisa",
            isSkipping: false
        )
        let preferred = dummy.getPreferredTracks(
            at: node,
            prevStationId: nil,
            nextStationId: "pisa",
            for: nil,
            isSkipping: false
        )

        XCTAssertEqual(best, preferred.first)
        XCTAssertEqual(best, "1")
    }

    func test_getBestTrack_transit_matches_getPreferredTracks_first() {
        let node = network.nodes[0]
        let dummy = Train(
            number: 0, name: "", type: "R",
            lineId: "line_roma_pisa",
            departureTime: Date(), stops: []
        )

        let best = manager.getBestTrack(
            stationId: "S1",
            directionId: "pisa",
            routeId: "line_roma_pisa",
            isSkipping: true
        )
        let preferred = dummy.getPreferredTracks(
            at: node,
            prevStationId: nil,
            nextStationId: "pisa",
            for: nil,
            isSkipping: true
        )

        XCTAssertEqual(best, preferred.first)
        XCTAssertEqual(best, "3")
    }

    func test_getPreferredTracks_stopBeforeTransit_whenStopping() {
        let node = network.nodes[0]
        let train = Train(
            number: 101, name: "IC", type: "R",
            lineId: "line_roma_pisa",
            departureTime: Date(), stops: []
        )
        let tracks = train.getPreferredTracks(
            at: node,
            prevStationId: nil,
            nextStationId: "pisa",
            for: nil,
            isSkipping: false
        )

        XCTAssertEqual(tracks.prefix(2).map { $0 }, ["1", "2"])
    }

    func test_getPreferredTracks_transitBeforeStop_whenSkipping() {
        let node = network.nodes[0]
        let train = Train(
            number: 102, name: "IC", type: "R",
            lineId: "line_roma_pisa",
            departureTime: Date(), stops: []
        )
        let tracks = train.getPreferredTracks(
            at: node,
            prevStationId: nil,
            nextStationId: "pisa",
            for: nil,
            isSkipping: true
        )

        XCTAssertEqual(tracks.prefix(2).map { $0 }, ["3", "4"])
    }
}
