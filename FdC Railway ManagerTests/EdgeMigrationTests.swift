import XCTest
@testable import FdC_Railway_Manager

final class EdgeMigrationTests: XCTestCase {

    // MARK: - Case 1: multiple .highSpeed edges (all converted)

    func test_migrate_multipleHighSpeedEdges_allConverted() {
        let edge1 = Edge(from: "A", to: "B", distance: 10,
                         trackType: .highSpeed, maxSpeed: 300)
        let edge2 = Edge(from: "B", to: "C", distance: 20,
                         trackType: .highSpeed, maxSpeed: 300)

        let (result, count) = Edge.migrateDoubleTracksToSingleOriented([edge1, edge2])

        XCTAssertEqual(count, 2)
        XCTAssertEqual(result.count, 4)
    }

    // MARK: - Case 2: .highSpeed only

    func test_migrate_highSpeedOnly_producesTwoPairedHighSpeedEdges() {
        let original = Edge(from: "A", to: "B", distance: 50,
                            trackType: .highSpeed, maxSpeed: 300)

        let (result, count) = Edge.migrateDoubleTracksToSingleOriented([original])

        XCTAssertEqual(count, 1)
        XCTAssertEqual(result.count, 2)
        let fwd = result.first { $0.from == "A" && $0.to == "B" }
        let bwd = result.first { $0.from == "B" && $0.to == "A" }
        XCTAssertEqual(fwd?.trackType, .highSpeed)
        XCTAssertEqual(bwd?.trackType, .highSpeed)
        XCTAssertEqual(fwd?.pairedEdgeId, bwd?.id)
        XCTAssertEqual(bwd?.pairedEdgeId, fwd?.id)
    }

    // MARK: - Case 3: mixed .single + .highSpeed

    func test_migrate_mixed_onlyHighSpeedIsConverted() {
        let single = Edge(from: "A", to: "B", distance: 5,
                          trackType: .single, maxSpeed: 80)
        let highSpeed = Edge(from: "B", to: "C", distance: 10,
                             trackType: .highSpeed, maxSpeed: 300)

        let (result, count) = Edge.migrateDoubleTracksToSingleOriented([single, highSpeed])

        XCTAssertEqual(count, 1)
        XCTAssertEqual(result.count, 3)
        let passedThrough = result.first { $0.id == single.id }
        XCTAssertEqual(passedThrough?.trackType, .single)
        XCTAssertNil(passedThrough?.pairedEdgeId)
    }

    // MARK: - Case 4: idempotency

    func test_migrate_alreadyMigratedEdges_noNewEdgesCreated() {
        let bwdId = UUID()
        let fwdId = UUID()
        let fwd = Edge(from: "A", to: "B", distance: 10,
                       trackType: .single, maxSpeed: 120, pairedEdgeId: bwdId)
        let bwd = Edge(from: "B", to: "A", distance: 10,
                       trackType: .single, maxSpeed: 120, pairedEdgeId: fwdId)
        let firstPass = [fwd, bwd]

        let (result, count) = Edge.migrateDoubleTracksToSingleOriented(firstPass)

        XCTAssertEqual(count, 0)
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Case 5: controlPoints reversed in B→A

    func test_migrate_withControlPoints_bwdHasReversedPoints() {
        let cp1 = TrackControlPoint(latitude: 1, longitude: 1, altitude: 100)
        let cp2 = TrackControlPoint(latitude: 2, longitude: 2, altitude: 200)
        let cp3 = TrackControlPoint(latitude: 3, longitude: 3, altitude: 150)
        var original = Edge(from: "A", to: "B", distance: 10,
                            trackType: .highSpeed, maxSpeed: 300)
        original.controlPoints = [cp1, cp2, cp3]

        let (result, _) = Edge.migrateDoubleTracksToSingleOriented([original])

        let fwd = result.first { $0.from == "A" && $0.to == "B" }
        let bwd = result.first { $0.from == "B" && $0.to == "A" }
        XCTAssertEqual(fwd?.controlPoints, [cp1, cp2, cp3])
        XCTAssertEqual(bwd?.controlPoints, [cp3, cp2, cp1])
    }
}
