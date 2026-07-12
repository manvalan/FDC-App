import XCTest
@testable import FDCScheduling
@testable import FDCDomain

@MainActor
final class FDCSchedulingTests: XCTestCase {

    private var topology: RailwayTopology!
    private var travel: StubTravelTimeCalculator!
    private var testRoute: TrainRoute!

    override func setUp() {
        super.setUp()
        travel = StubTravelTimeCalculator()
        let nodeA = Node(id: "A", name: "Stazione A", type: .station, latitude: 43.0, longitude: 11.0, altitude: 0)
        let nodeB = Node(id: "B", name: "Stazione B", type: .interchange, latitude: 43.1, longitude: 11.0, altitude: 100)
        let nodeC = Node(id: "C", name: "Stazione C", type: .station, latitude: 43.2, longitude: 11.0, altitude: 50)
        topology = RailwayTopology(nodes: [nodeA, nodeB, nodeC], edges: [
            Edge(from: "A", to: "B", distance: 10.0, trackType: .single, maxSpeed: 120),
            Edge(from: "B", to: "C", distance: 10.0, trackType: .single, maxSpeed: 100),
        ])
        testRoute = TrainRoute(
            id: "route_test",
            name: "Test Route",
            originStationId: "A",
            destinationStationId: "C",
            stationIds: ["A", "B", "C"]
        )
    }

    func testPathResolverSequence() {
        let resolver = PathResolver(topology: topology)
        let sequence = resolver.resolveStationSequence(route: testRoute, startId: "A", endId: "C")
        XCTAssertEqual(sequence, ["A", "B", "C"])
    }

    func testKinematicCalculatorLegTime() {
        let calculator = KinematicCalculator(topology: topology, travelTimeCalculator: travel)
        let train = Train(
            number: 101, name: "Test", type: "regional",
            departureTime: Date(), stops: [],
            maxSpeed: 160, acceleration: 1.0,
            deceleration: 1.0, mass: 200, power: 2600,
            isMainTrain: true
        )
        let minutes = calculator.legTravelMinutes(from: "A", to: "B", train: train)
        XCTAssertGreaterThan(minutes, 0)
    }

    func testTaktEngineSuggestions() {
        var nodes = topology.nodes
        if let idx = nodes.firstIndex(where: { $0.id == "B" }) {
            nodes[idx].taktMinutes = 30
        }
        let taktTopology = RailwayTopology(nodes: nodes, edges: topology.edges)
        let kinematic = KinematicCalculator(topology: taktTopology, travelTimeCalculator: travel)
        let engine = TaktEngine(
            topology: taktTopology,
            kinematicCalculator: kinematic,
            travelTimeCalculator: travel
        )
        let suggestions = engine.calculateTaktSuggestions(stationSequence: ["A", "B", "C"])
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].taktMinute, 30)
    }

    func testVehicleSuitabilityPrefersRegionalOverFreight() {
        let flatNodes = topology.nodes.map { node -> Node in
            var n = node
            n.altitude = 0
            return n
        }
        let flatTopology = RailwayTopology(nodes: flatNodes, edges: topology.edges)
        let kinematic = KinematicCalculator(topology: flatTopology, travelTimeCalculator: travel)
        let engine = VehicleSuitabilityEngine(kinematicCalculator: kinematic)

        let regional = Vehicle(
            id: UUID(), name: "Regionale", model: "Minuetto",
            maxSpeed: 160, acceleration: 1.0, deceleration: 1.0,
            mass: 200, power: 2600, isElectric: true
        )
        let freight = Vehicle(
            id: UUID(), name: "Merci", model: "E652",
            maxSpeed: 100, acceleration: 0.2, deceleration: 0.5,
            mass: 2000, power: 5000, isElectric: true
        )

        let scoreReg = engine.calculateSuitabilityScore(
            vehicle: regional, lineMaxSpeed: 160,
            stationSequence: ["A", "B", "C"],
            estimatedDistance: 20.0, isLineElectrified: true
        )
        let scoreFreight = engine.calculateSuitabilityScore(
            vehicle: freight, lineMaxSpeed: 160,
            stationSequence: ["A", "B", "C"],
            estimatedDistance: 20.0, isLineElectrified: true
        )
        XCTAssertGreaterThan(scoreReg, scoreFreight)
    }
}

struct StubTravelTimeCalculator: TrainTravelTimeCalculating {
    func travelTimeHours(
        distanceKm: Double,
        maxSpeedKmh: Double,
        train: Train,
        initialSpeedKmh: Double,
        finalSpeedKmh: Double,
        gradient: Double
    ) -> Double {
        distanceKm / max(maxSpeedKmh, 1.0)
    }

    func travelTimeBetweenNodes(
        from: String,
        to: String,
        train: Train,
        nodes: [Node],
        edges: [Edge],
        isStarting: Bool,
        isStopping: Bool
    ) -> TimeInterval {
        guard let edge = edges.first(where: {
            ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from)
        }) else { return 0 }
        return travelTimeHours(
            distanceKm: edge.distance,
            maxSpeedKmh: Double(edge.maxSpeed),
            train: train,
            initialSpeedKmh: 0,
            finalSpeedKmh: 0,
            gradient: 0
        ) * 3600
    }
}
