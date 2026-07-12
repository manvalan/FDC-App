import XCTest
@testable import FdC_Railway_Manager

@MainActor
final class ServicesSchedulingTests: XCTestCase {

    private var topology: RailwayTopology!
    private var testRoute: TrainRoute!

    override func setUp() {
        super.setUp()
        makeFixtures()
    }

    private func makeFixtures() {
        let nodeA = RailwayNode(
            id: "A", name: "Stazione A", type: .station,
            latitude: 43.0, longitude: 11.0, altitude: 0
        )
        let nodeB = RailwayNode(
            id: "B", name: "Stazione B", type: .interchange,
            latitude: 43.1, longitude: 11.0, altitude: 100
        )
        let nodeC = RailwayNode(
            id: "C", name: "Stazione C", type: .station,
            latitude: 43.2, longitude: 11.0, altitude: 50
        )
        topology = RailwayTopology(nodes: [nodeA, nodeB, nodeC], edges: [
            RailwayEdge(
                from: "A", to: "B", distance: 10.0,
                trackType: .single, maxSpeed: 120
            ),
            RailwayEdge(
                from: "B", to: "C", distance: 10.0,
                trackType: .single, maxSpeed: 100
            ),
        ])
        testRoute = TrainRoute(
            id: "route_test",
            name: "Test Route",
            originStationId: "A",
            destinationStationId: "C",
            stationIds: ["A", "B", "C"]
        )
    }

    // MARK: - Smoke

    func test_smoke_topologyCreated() {
        XCTAssertEqual(topology.nodes.count, 3)
    }

    // MARK: - PathResolver Tests

    func test_kinematicInit_only() {
        _ = KinematicCalculator(topology: topology)
        XCTAssertEqual(topology.edges.count, 2)
    }

    func testPathResolverSequence() {
        let resolver = PathResolver(topology: topology)
        let sequence = resolver.resolveStationSequence(
            route: testRoute, startId: "A", endId: "C"
        )

        XCTAssertEqual(sequence, ["A", "B", "C"])
    }

    func testPathResolverHasHighSpeed() {
        let resolver = PathResolver(topology: topology)
        XCTAssertFalse(
            resolver.hasHighSpeedTrack(stationSequence: ["A", "B", "C"])
        )

        var topologyWithHS = RailwayTopology(
            nodes: topology.nodes,
            edges: topology.edges + [
                RailwayEdge(
                    from: "A", to: "C", distance: 18.0,
                    trackType: .highSpeed, maxSpeed: 300
                ),
            ]
        )
        let hsResolver = PathResolver(topology: topologyWithHS)
        XCTAssertTrue(
            hsResolver.hasHighSpeedTrack(stationSequence: ["A", "C"])
        )
    }

    // MARK: - KinematicCalculator Tests

    func testKinematicCalculatorLegTime() {
        let calculator = KinematicCalculator(topology: topology)
        let train = Train(
            number: 101, name: "Test", type: "regional",
            departureTime: Date(), stops: [],
            maxSpeed: 160, acceleration: 1.0,
            deceleration: 1.0, mass: 200, power: 2600,
            isMainTrain: true
        )

        let minutes = calculator.legTravelMinutes(
            from: "A", to: "B", train: train
        )

        XCTAssertGreaterThan(minutes, 5.0)
        XCTAssertLessThan(minutes, 8.0)
    }

    func testAltitudeCharacteristics() {
        let calculator = KinematicCalculator(topology: topology)
        let chars = calculator.calculateAltitudeCharacteristics(
            stationSequence: ["A", "B", "C"]
        )

        XCTAssertEqual(chars.totalElevationGain, 100.0)
        XCTAssertNotNil(chars.maxGradient)
    }

    // MARK: - TaktEngine Tests

    func testTaktEngineSuggestions() {
        var nodes = topology.nodes
        if let idx = nodes.firstIndex(where: { $0.id == "B" }) {
            nodes[idx].taktMinutes = 30
        }
        let taktTopology = RailwayTopology(nodes: nodes, edges: topology.edges)

        let kinematic = KinematicCalculator(topology: taktTopology)
        let engine = TaktEngine(
            topology: taktTopology,
            kinematicCalculator: kinematic
        )

        let suggestions = engine.calculateTaktSuggestions(
            stationSequence: ["A", "B", "C"]
        )
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].taktMinute, 30)
        XCTAssertFalse(suggestions[0].suggestedArrival.isEmpty)
    }

    // MARK: - VehicleSuitabilityEngine Tests

    func testVehicleSuitability() {
        let flatNodes = topology.nodes.map { node -> Node in
            var n = node
            n.altitude = 0
            return n
        }
        let flatTopology = RailwayTopology(
            nodes: flatNodes, edges: topology.edges
        )
        let kinematic = KinematicCalculator(topology: flatTopology)
        let engine = VehicleSuitabilityEngine(
            kinematicCalculator: kinematic
        )

        let regionalVehicle = Vehicle(
            id: UUID(), name: "Regionale", model: "Minuetto",
            maxSpeed: 160, acceleration: 1.0, deceleration: 1.0,
            mass: 200, power: 2600, isElectric: true
        )
        let freightVehicle = Vehicle(
            id: UUID(), name: "Merci", model: "E652",
            maxSpeed: 100, acceleration: 0.2, deceleration: 0.5,
            mass: 2000, power: 5000, isElectric: true
        )

        let scoreReg = engine.calculateSuitabilityScore(
            vehicle: regionalVehicle, lineMaxSpeed: 160,
            stationSequence: ["A", "B", "C"],
            estimatedDistance: 20.0, isLineElectrified: true
        )
        let scoreFreight = engine.calculateSuitabilityScore(
            vehicle: freightVehicle, lineMaxSpeed: 160,
            stationSequence: ["A", "B", "C"],
            estimatedDistance: 20.0, isLineElectrified: true
        )

        XCTAssertGreaterThan(scoreReg, scoreFreight)
    }
}
